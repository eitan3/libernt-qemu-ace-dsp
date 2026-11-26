#!/usr/bin/env python3
"""bugpause.py -- stop the VM of lib-run.sh the moment a line reaches the serial log, and exit.

The guest's bugcheck handler waits three seconds and then resets the machine (the HAL's
ACPI reset), so the memory of the faulting thread is gone moments after the bugcheck text:
this tool holds the monitor connection, polls the serial log, and stops the VM within a
millisecond of the needle, leaving it paused and the monitor free for tools/bugread.py.

   bugpause.py <sock-dir> <serial.log> <text> [timeout s, default 900]

The needle is a plain byte string looked for in what the log gains after the start.  With
CHECK=<ntoskrnl.exe> in the environment the read primitive is validated first, while the VM
is stopped: the 16 bytes the monitor's 'x' reads at CS:RIP must be found in the image's
ntoskrnl.exe, at the same image base for RIP and RIP+16 (that base is then printed).
"""
import os
import re
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from livecap import Mon  # noqa: E402


def wait_for(log, needle, timeout):
    off = os.path.getsize(log) if os.path.exists(log) else 0
    buf = b''
    t0 = time.time()
    while needle not in buf:
        size = os.path.getsize(log) if os.path.exists(log) else 0
        if size > off:
            with open(log, 'rb') as f:
                f.seek(off)
                buf += f.read(size - off)
            off = size
        if time.time() - t0 > timeout:
            return False
        time.sleep(0.0005)
    return True


def xwords(mon, addr, n):
    text = mon.cmd('x /%dgx 0x%x' % (n, addr))
    words = []
    for line in text.splitlines():
        if ':' in line:
            words += [int(w, 16) for w in re.findall(r'0x[0-9a-f]{16}', line.split(':', 1)[1])]
    return words, text


def check(mon, images, log):
    """the bytes 'x' reads at CS:RIP against the image files: one base for RIP and RIP+16; and
    the KPCR the loader named in the serial log ('Pcr = ...'): its NtTib.Self (+0x18) is itself"""
    regs = mon.cmd('info registers')
    m = re.search(r'^RIP=([0-9a-fA-F]{16})', regs, re.M)
    if not m:
        return None, 'no RIP in info registers:\n' + regs
    rip = int(m.group(1), 16)
    out = []
    base = None
    for a in (rip, rip + 16):
        words, text = xwords(mon, a, 2)
        if len(words) != 2:
            return None, 'x at 0x%x did not answer two words: %r' % (a, text)
        raw = b''.join(w.to_bytes(8, 'little') for w in words)
        found = []
        for name in images:
            with open(name, 'rb') as f:
                image = f.read()
            i = image.find(raw)
            while i >= 0:
                found.append((name, i))
                i = image.find(raw, i + 1)
        out.append('   x at RIP+0x%x: %s; the same 16 bytes in the image file(s) at file offset(s) %s'
                   % (a - rip, raw.hex(), ', '.join('%s:0x%x' % (os.path.basename(n), h) for n, h in found) or 'none'))
        if not found:
            out.append('   (RIP in a driver, or in a section whose file offset is not its RVA: no base from this stop)')
            pcr_check(out, mon, log)
            return None, '\n'.join(out)
        bases = sorted(set(a - h for _, h in found))
        out.append('   x at RIP+0x%x gives image base candidate(s) %s (a code read gives the page-aligned one)'
                   % (a - rip, ', '.join('0x%x' % b for b in bases)))
        if base is None:
            base = bases
        else:
            common = [b for b in bases if b in base and b & 0xfff == 0]
            if not common:
                out.append('   !! no page-aligned base common to the two reads')
                pcr_check(out, mon, log)
                return None, '\n'.join(out)
            base = common
    pcr_check(out, mon, log)
    out.append('   read primitive checked at 0x%x: the 16 bytes at RIP and at RIP+16 are image bytes, base 0x%x both times'
               % (rip, base[0]))
    return base[0], '\n'.join(out)


def pcr_check(out, mon, log):
    """the KPCR the loader named in the serial log ('Pcr = ...'): its first four qwords, read
    and reported as they are (this kernel's KPCR does not fill NtTib.Self)"""
    m = re.search(rb'Pcr = ([0-9A-Fa-f]{16})', open(log, 'rb').read())
    if not m:
        out.append('   (no "Pcr =" line in the serial log: the KPCR not read)')
        return
    pcr = int(m.group(1), 16)
    words, _ = xwords(mon, pcr, 4)
    out.append('   the KPCR the loader named, 0x%x: its first four qwords %s'
               % (pcr, ' '.join('%016x' % w for w in words)))


def main():
    if len(sys.argv) < 4:
        print(__doc__)
        return 2
    sockdir, log, needle = sys.argv[1], sys.argv[2], sys.argv[3].encode()
    timeout = float(sys.argv[4]) if len(sys.argv) > 4 else 900.0
    mon = Mon(os.path.join(sockdir, 'monitor.sock'))
    t0 = time.time()
    if not wait_for(log, needle, timeout):
        print('-- %r not seen in %d s' % (needle, timeout))
        return 1
    t = time.time()
    mon.cmd('stop')
    print('[%s] %r reached the log; stopped %.1f ms later (%.1f s of wait)'
          % (time.strftime('%H:%M:%S', time.gmtime()), needle, (time.time() - t) * 1000,
             time.time() - t0))
    print(mon.cmd('info status'))
    if os.environ.get('CHECK'):
        base, text = check(mon, os.environ['CHECK'].split(':'), log)
        print(text)
        print('CHECK_BASE=0x%x' % base if base is not None else 'CHECK failed')
    return 0


if __name__ == '__main__':
    sys.exit(main())
