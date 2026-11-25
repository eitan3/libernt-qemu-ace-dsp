#!/usr/bin/env python3
"""streamregs.py -- read-only qtest dump of the HDA controller's stream
descriptors (BAR0 + 0x80 + 0x20*i), their BDL entries and the head/tail of each
descriptor's buffer.  qtest reads only (readb/readw/readl/readq); never writes.

   streamregs.py <qtest.sock> <bar0 hex> [words=16]
"""
import socket
import sys
import struct


def main():
    s = socket.socket(socket.AF_UNIX)
    s.connect(sys.argv[1])
    bar0 = int(sys.argv[2], 16)
    nwords = int(sys.argv[3]) if len(sys.argv) > 3 else 16

    def q(cmd):
        s.sendall((cmd + '\n').encode())
        out = b''
        while b'\n' not in out:
            chunk = s.recv(65536)
            if not chunk:
                break
            out += chunk
        rep = out.decode(errors='replace').strip()
        if not rep.startswith('OK'):
            raise RuntimeError('%s -> %s' % (cmd, rep))
        return int(rep.split()[1], 16)

    def rd(size, addr):
        return q({1: 'readb', 2: 'readw', 4: 'readl', 8: 'readq'}[size] + ' 0x%x' % addr)

    def mem(addr, n):
        out = b''
        while len(out) < n:
            v = q('readl 0x%x' % (addr + len(out)))
            out += struct.pack('<I', v)
        return out[:n]

    def samples16(buf):
        return ' '.join('%d' % v for v in struct.unpack('<%dh' % (len(buf) // 2), buf))

    for i in range(8):
        b = bar0 + 0x80 + 0x20 * i
        ctl = rd(4, b)
        ctl &= 0xffffff
        sts = rd(1, b + 3)
        lpib = rd(4, b + 4)
        cbl = rd(4, b + 8)
        lvi = rd(2, b + 0xc)
        fmt = rd(2, b + 0x12)
        bdlpl = rd(4, b + 0x18)
        bdlpu = rd(4, b + 0x1c)
        bdl = (bdlpu << 32) | bdlpl
        kind = 'input ' if i < 4 else 'output'
        print('st[%d] %s ctl=0x%06x (RUN %d, tag %d, IOCE %d) sts=0x%02x lpib=%d cbl=%d lvi=%d fmt=0x%04x bdl=0x%x'
              % (i, kind, ctl, ctl & 2, (ctl >> 20) & 0xf, (ctl >> 26) & 1, sts, lpib, cbl, lvi, fmt, bdl))
        if not bdl or lvi > 16:
            continue
        first_addr = None
        last_end = None
        for e in range(lvi + 1):
            ent = mem(bdl + 16 * e, 16)
            addr, ln, fl = struct.unpack('<QII', ent)
            if first_addr is None:
                first_addr = addr
            if ln:
                last_end = addr + ln
            print('   bdl[%d] addr=0x%x len=%d ioc=%d' % (e, addr, ln, fl & 1))
            if ln:
                head = mem(addr, 4 * nwords)
                tail = mem(addr + ln - 16, 16)
                print('      head: %s' % samples16(head))
                print('      tail: %s' % samples16(tail))
                if ln > 8192:
                    mid = mem(addr + 8192, 4 * nwords)
                    print('      +8192: %s' % samples16(mid))
        if first_addr is not None:
            # the memory around the window: where the driver's sine may sit
            for off in (-4096, 4096, 8192, 12288):
                a = first_addr + off
                if a > 0:
                    print('   window%+d (0x%x): %s' % (off, a, samples16(mem(a, 4 * nwords))))
            print('   window end (0x%x): %s' % (last_end, samples16(mem(last_end, 4 * nwords))))


if __name__ == '__main__':
    main()
