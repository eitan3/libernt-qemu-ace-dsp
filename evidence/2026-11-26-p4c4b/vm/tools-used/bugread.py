#!/usr/bin/env python3
"""bugread.py -- read the faulting thread's memory through the monitor while the VM stands
paused at its bugcheck (tools/bugpause.py).  Reads only: HMP 'x' of virtual memory.

   bugread.py <sock-dir> <RSP hex> <out-file>

RSP is the faulting thread's stack pointer as the bugcheck text printed it (RIP=... RSP=...).
The kernel is this image's and has no symbols, so nothing is read through structure offsets
that were not first read from the image.  Two things the image does give are used: at
[RSP+0x30] the loop of PiSetStackRemovePending keeps the device object it is looking at
(ntoskrnl+0x17de96: mov 0x30(%rsp),%rax), and a device object's DeviceObjectExtension is at
+0x138 (+0x17de9b) and its AttachedDevice at +0x18 (+0x17dec9).

What is printed, for the record:
  - the stack above RSP as qwords (the frames of PiSendRemoval's callers are there);
  - the device object at [RSP+0x30] and its chain: every pointer-sized field is followed
    one step (DriverObject, NextDevice, AttachedDevice, DeviceObjectExtension);
  - every kernel pointer met in those places and in the stack: the first 0x300 bytes of
    it are scanned for UNICODE_STRING pairs (Length, MaximumLength, 0, Buffer) whose buffer
    decodes as printable UTF-16 -- a device node's InstancePath, a driver's DriverName.
"""
import os
import re
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from livecap import Mon  # noqa: E402

KLO, KHI = 0xFFFF800000000000, 0xFFFFF80000000000   # pool, stacks, tables (not the images)
SCAN = 96                                          # qwords read at a candidate


def xwords(mon, addr, n):
    text = mon.cmd('x /%dgx 0x%x' % (n, addr))
    words = []
    for line in text.splitlines():
        if ':' in line:
            words += [int(w, 16) for w in re.findall(r'0x[0-9a-f]{16}', line.split(':', 1)[1])]
    return words


def ustr(mon, length, buf):
    ws = xwords(mon, buf, (length + 7) // 8)
    raw = b''.join(w.to_bytes(8, 'little') for w in ws)[:length]
    if len(raw) < length:
        return None
    return raw.decode('utf-16le', errors='replace')


def printable(s):
    return all(0x20 <= ord(c) < 0x7f for c in s)


def scan(mon, o, seen, out, title):
    """the UNICODE_STRING pairs in the first SCAN qwords at o"""
    if o in seen:
        return
    seen.add(o)
    q = xwords(mon, o, SCAN)
    if not q:
        return
    head = ' '.join('%016x' % v for v in q[:6])
    out.append('%s 0x%x: head %s' % (title, o, head))
    for i in range(len(q) - 1):
        a, b = q[i], q[i + 1]
        # the two dwords above the buffer pointer are Length and MaximumLength; the padding
        # of a UNICODE_STRING is whatever the compiler left there, so it is not looked at
        length, maxlen = a & 0xffff, (a >> 16) & 0xffff
        if not (0 < length <= maxlen <= 0x1000 and length % 2 == 0 and KLO <= b):
            continue
        s = ustr(mon, length, b)
        if s is None or not printable(s):
            continue
        out.append('%s 0x%x +0x%x: len %d max %d buffer 0x%x: %r' % (title, o, i * 8, length, maxlen, b, s))


def main():
    if len(sys.argv) < 4:
        print(__doc__)
        return 2
    sockdir, rsp, outf = sys.argv[1], int(sys.argv[2], 16), sys.argv[3]
    mon = Mon(os.path.join(sockdir, 'monitor.sock'))
    out = ['== bugread.py: RSP 0x%x, %s' % (rsp, time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()))]
    out.append(mon.cmd('info status'))
    stack = xwords(mon, rsp, 0x300 // 8)
    out.append('-- the stack above RSP, as qwords:')
    for i in range(0, len(stack), 4):
        out.append('   +0x%03x: %s' % (i * 8, ' '.join('%016x' % v for v in stack[i:i + 4])))
    dev = stack[6] if len(stack) > 6 else 0
    pdo = stack[8] if len(stack) > 8 else 0
    todo = []
    for title, o in (('the device object the loop looks at, [RSP+0x30]', dev),
                     ('the PDO, the function\'s first argument ([RSP+0x40], +0x17de64 mov %rcx,0x40(%rsp))', pdo)):
        out.append('-- %s: 0x%x' % (title, o))
        if not KLO <= o < KHI:
            out.append('   not in the kernel range 0x%x..0x%x' % (KLO, KHI))
            continue
        q = xwords(mon, o, 0x150 // 8)
        if title.startswith('the PDO'):
            for i in range(0, len(q), 4):
                out.append('   +0x%03x: %s' % (i * 8, ' '.join('%016x' % v for v in q[i:i + 4])))
        else:
            out.append('   its first 0x150 bytes as qwords: %s' % ' '.join('%016x' % v for v in q))
        out.append('   Type/Size/ReferenceCount (first qword): 0x%016x' % (q[0] if q else 0))
        for off, name in ((0x08, 'DriverObject'), (0x10, 'NextDevice'), (0x18, 'AttachedDevice'),
                          (0x138, 'DeviceObjectExtension')):
            if len(q) > off // 8:
                v = q[off // 8]
                out.append('   %-22s +0x%03x: 0x%016x' % (name, off, v))
                if title.startswith('the PDO'):
                    todo.append((name, v))
    seen = set()
    follow = []
    for name, v in todo:
        if not KLO <= v < KHI:
            continue
        q = xwords(mon, v, 0x100 // 8)
        out.append('-- the PDO\'s %s at 0x%x, its first 0x100 bytes as qwords:' % (name, v))
        for i in range(0, len(q), 4):
            out.append('   +0x%03x: %s' % (i * 8, ' '.join('%016x' % w for w in q[i:i + 4])))
        scan(mon, v, seen, out, 'pdo.' + name)
        follow += [(name, w) for w in q[:16] if KLO <= w < KHI]
    for name, v in follow:
        scan(mon, v, seen, out, 'pdo.%s->' % name)
        if name == 'DeviceObjectExtension':
            q = xwords(mon, v, 0x200 // 8)
            out.append('-- the object at 0x%x reached through the PDO\'s %s, 0x200 bytes as qwords:' % (v, name))
            for i in range(0, len(q), 4):
                out.append('   +0x%03x: %s' % (i * 8, ' '.join('%016x' % w for w in q[i:i + 4])))
    if KLO <= dev < KHI:
        scan(mon, dev, seen, out, 'field')
    for i, v in enumerate(stack):
        if KLO <= v < KHI:
            scan(mon, v, seen, out, 'stack+0x%03x' % (i * 8))
    text = '\n'.join(out)
    with open(outf, 'w') as f:
        f.write(text + '\n')
    print(text)
    return 0


if __name__ == '__main__':
    sys.exit(main())
