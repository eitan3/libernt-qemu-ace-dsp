#!/usr/bin/env python3
"""livecap.py -- the live read of the p3c3b round, as it last ran there (VM 4 of p3c3b),
with one addition for the p4c4b round (LIVECAP_SENDKEY): qtest and the monitor, reads only.

Stops the VM of lib-run.sh (QTESTSOCK=1) the moment a driver line reaches the
serial log, reads the HDA controller's stream descriptors and the descriptor
lists they name over qtest, saves the pages the lists name (one page more at
each end) with the monitor's pmemsave, prints the reading, and continues the
VM.  One process and one monitor connection, so the stop follows the line by
about a millisecond of host time (no other client may use the monitor socket
while this runs).

   livecap.py <sock-dir> <serial.log> <out-dir> <label>=<text> [<label>=<text> ...]

With LIVECAP_SENDKEY=<key> in the environment the tool first sends that one key through its
monitor connection (p4c4b: the Enter that starts the apitest, whose command line is typed
beforehand); LIVECAP_TIMEOUT bounds each wait (default 300 s).

Each <label>=<text> after the output directory is one stop: the VM is stopped
when <text> (a plain byte string) first appears in the serial log after the
text of the previous stop; an empty <text> stops at once.  The files are
<out-dir>/<label>-*.bin and the reading goes to stdout.  A label "wait" only
waits for its text.  A label ending in "end" is read once (the streams may be
stopped already); every other stop is repeated, 20 ms of host time apart, until
an output and an input stream are both running (the driver prints its line
before the streams run).  Windows saved at an earlier stop are saved again at
every later stop (suffix -after-<label>) and the capture's pages are compared
with the render's byte for byte.

BAR0 comes from the monitor's 'info pci' (QEMU's own view of the model's BARs;
the guest sees nothing of the query) and is cross-checked before anything is
read through it: the block must name 8086:7f50 and its BAR4 must be the
0x81000000 the bus driver's own serial line names.  (VM 1's attempt read the PCI
configuration space through q35's ECAM window at 0xb0000000 and read zeros:
the window is mapped only once a guest has enabled the MCH's PCIEXBAR.)  The
descriptors are printed as their four words, so the interrupt on completion is
read both ways the round lists for C6: the fourth word's bit 0 (what the driver
writes and the model reads) and bit 31 of the upper dword (the specification's
Buffer Descriptor List entry).
"""
import os
import re
import socket
import struct
import sys
import time

PAGE = 4096
VENDOR_DEVICE = '8086:7f50'   # the model on lib-run.sh's command line (bus 0, device 0x1b)
BAR4_NAMED = 0x81000000       # what the bus driver's own serial line names for BAR4


def now():
    t = time.time()
    return time.strftime('%H:%M:%S', time.gmtime(t)) + '.%03d' % ((t % 1) * 1000)


ANSI = re.compile(r'\x1b\[[0-9;?]*[A-Za-z]')


class Mon:
    """the human monitor over lib-run.sh's unix socket.  A reply is the echo of the
    command (readline's escapes around it), the output and a new prompt."""

    def __init__(self, path=None):
        self.raw = []
        if path:
            self._connect(path)
        self._read_to_prompt()          # the banner and the first prompt

    def _connect(self, path):
        self.s = socket.socket(socket.AF_UNIX)
        self.s.connect(path)
        self.s.settimeout(20)

    def _send(self, c):
        self.s.sendall((c + '\n').encode())

    def _read_to_prompt(self):
        out = b''
        while not out.rstrip().endswith(b'(qemu)'):
            chunk = self.s.recv(65536)
            if not chunk:
                break
            out += chunk
        return out.decode(errors='replace')

    def cmd(self, c):
        """the command's output: the prompt after it, the echo before it and readline's
        escapes dropped (tools/mon.py keeps what follows the last prompt, which is
        always empty -- it is used for sendkey and screendump only)"""
        self._send(c)
        raw = self._read_to_prompt()
        self.raw.append((c[:48], len(raw), raw.rstrip()[-8:]))
        self.lastraw = raw
        text = ANSI.sub('', raw)
        text = text.rsplit('(qemu)', 1)[0]
        i = text.find(c)
        if i >= 0:
            j = text.find('\n', i)
            text = text[j + 1:] if j >= 0 else ''
        return text.strip()


class QTest:
    def __init__(self, path):
        self.s = socket.socket(socket.AF_UNIX)
        self.s.connect(path)
        self.s.settimeout(20)
        self.f = self.s.makefile('rwb', buffering=0)

    def rd(self, cmd):
        self.f.write((cmd + '\n').encode())
        rep = self.f.readline()
        if not rep.startswith(b'OK'):
            raise RuntimeError('%s -> %r' % (cmd, rep))
        parts = rep.split()
        return int(parts[1], 16) if len(parts) > 1 else 0

    def readl(self, a):
        return self.rd('readl 0x%x' % a)

    def readw(self, a):
        return self.rd('readw 0x%x' % a)

    def readb(self, a):
        return self.rd('readb 0x%x' % a)

    def close(self):
        self.s.close()


def config(mon):
    """the model's block of the monitor's 'info pci' and two of its BARs as QEMU
    holds them: (block, (kind, addr, end) of BAR0, the same of BAR4)"""
    text = mon.cmd('info pci')
    for para in re.split(r'\n(?=\s*Bus\s+\d+, device)', text):
        if VENDOR_DEVICE not in para:
            continue
        bars = {}
        for m in re.finditer(r'BAR(\d+): (.*?) at 0x([0-9a-fA-F]+) \[0x([0-9a-fA-F]+)\]', para):
            bars[int(m.group(1))] = (m.group(2).strip(), int(m.group(3), 16), int(m.group(4), 16))
        return para.strip(), bars.get(0), bars.get(4)
    return text.strip(), None, None


def read_stream(qt, bar0, i):
    b = bar0 + 0x80 + 0x20 * i
    ctl = qt.readl(b) & 0xffffff          # SD_CTL as the specification lays it out
    return {
        'i': i, 'dir': 'input' if i < 4 else 'output', 'ctl': ctl,
        'run': (ctl >> 1) & 1, 'tag': (ctl >> 20) & 0xf, 'stripe': (ctl >> 8) & 0xff,
        'strpe': (ctl >> 2) & 1, 'tp': (ctl >> 3) & 1, 'ioce': (ctl >> 4) & 1,
        'feie': (ctl >> 5) & 1, 'deie': (ctl >> 6) & 1,
        'sts': qt.readb(b + 3), 'lpib': qt.readl(b + 4), 'cbl': qt.readl(b + 8),
        'lvi': qt.readw(b + 0xc), 'fmt': qt.readw(b + 0x12),
        'bdl': qt.readl(b + 0x18) | (qt.readl(b + 0x1c) << 32),
    }


def entries(qt, d):
    out = []
    if d['bdl'] and d['lvi'] <= 64:
        for e in range(d['lvi'] + 1):
            a = d['bdl'] + 16 * e
            out.append([qt.readl(a + 4 * k) for k in range(4)])
    return out


def fmt_stream(d):
    return ('st[%d] %-6s ctl=0x%06x (RUN %d, STRPE %d, TP %d, IOCE %d, FEIE %d, DEIE %d, STRIPE 0x%02x, '
            'tag %d) sts=0x%02x lpib=%d cbl=%d lvi=%d fmt=0x%04x bdl=0x%x'
            % (d['i'], d['dir'], d['ctl'], d['run'], d['strpe'], d['tp'], d['ioce'],
               d['feie'], d['deie'], d['stripe'], d['tag'], d['sts'], d['lpib'], d['cbl'],
               d['lvi'], d['fmt'], d['bdl']))


def stats(page):
    h = struct.unpack('<%dh' % (len(page) // 2), page)
    w = struct.unpack('<%di' % (len(page) // 4), page)
    return ('head i16: %s | head i32: %s | zero: %d/%d words, %d/%d dwords | 0xCDCD: %d/%d words, '
            '0xCDCDCDCD: %d/%d dwords | i16 min %d max %d'
            % (' '.join('%d' % v for v in h[:16]), ' '.join('%d' % v for v in w[:8]),
               sum(1 for v in h if v == 0), len(h), sum(1 for v in w if v == 0), len(w),
               sum(1 for v in h if v == -12851), len(h),
               sum(1 for v in w if v == -842150451), len(w), min(h), max(h)))


def dump(mon, qt, bar0, out, label):
    """the eight stream descriptors; every stream with a list: its entries, the pages they
    name (saved with pmemsave, one page more at each end) and the statistics of each page.
    Returns {stream index: (pages, start, size, file)}."""
    res = {}
    for i in range(8):
        d = read_stream(qt, bar0, i)
        print('   ' + fmt_stream(d))
        ents = entries(qt, d)
        if not ents:
            continue
        print('   %s stream %d: %d descriptors at 0x%x' % (d['dir'], i, len(ents), d['bdl']))
        pages = []
        for e, w in enumerate(ents):
            addr = w[0] | ((w[1] & 0x7fffffff) << 32)
            print('      bdl[%d] words %08x %08x %08x %08x  addr 0x%x len %d  ioc: word 3 bit 0 = %d, '
                  'upper dword bit 31 = %d (word 3 = 0x%08x)'
                  % (e, w[0], w[1], w[2], w[3], addr, w[2], w[3] & 1, w[1] >> 31, w[3]))
            if w[2]:
                pages.append((addr, w[2]))
        if not pages:
            continue
        start = min(a for a, _ in pages) - PAGE
        end = max(a + n for a, n in pages) + PAGE
        f = os.path.join(out, '%s-st%d-window.bin' % (label, i))
        r = mon.cmd('pmemsave 0x%x 0x%x "%s"' % (start, end - start, f))   # HMP: the name quoted
        if r or not os.path.exists(f):
            raise RuntimeError('pmemsave 0x%x 0x%x "%s" -> %r' % (start, end - start, f, r))
        with open(f, 'rb') as fh:
            win = fh.read()
        print('      window 0x%x..0x%x (%d pages) saved to %s'
              % (start, end - 1, (end - start) // PAGE, os.path.basename(f)))
        for k, (a, n) in enumerate(pages):
            print('      page %d at 0x%x: %s' % (k, a, stats(win[a - start:a - start + n])))
        res[i] = (pages, start, end - start, f)
    return res


def compare(cap, ren, title):
    """the capture's pages against the render's, byte for byte, at the same list index"""
    pc, sc, _, fc = cap
    pr, sr, _, fr = ren
    with open(fc, 'rb') as fh:
        wc = fh.read()
    with open(fr, 'rb') as fh:
        wr = fh.read()
    print('   %s: capture against render, page by page at the same list index' % title)
    for k in range(min(len(pc), len(pr))):
        a = pc[k][0]
        b = pr[k][0]
        page = wc[a - sc:a - sc + pc[k][1]]
        ref = wr[b - sr:b - sr + pr[k][1]]
        if page == ref:
            print('      page %d (capture 0x%x, render 0x%x): identical, %d bytes'
                  % (k, a, b, len(page)))
        else:
            n = min(len(page), len(ref))
            x = next((j for j in range(n) if page[j] != ref[j]), n)
            h = struct.unpack('<h', page[x:x + 2].ljust(2, b'\0'))
            g = struct.unpack('<h', ref[x:x + 2].ljust(2, b'\0'))
            print('      page %d (capture 0x%x, render 0x%x): differ at byte %d: capture %d 0x%04x, '
                  'render %d 0x%04x; differing bytes %d of %d'
                  % (k, a, b, x, h[0], h[0] & 0xffff, g[0], g[0] & 0xffff,
                     sum(1 for j in range(n) if page[j] != ref[j]), n))


def pairs(res, title):
    for i in res:
        if i < 4:
            for o in res:
                if o >= 4:
                    compare(res[i], res[o], '%s (st%d against st%d)' % (title, i, o))


def main():
    if len(sys.argv) < 5:
        print(__doc__)
        return 2
    sockdir, log, out = sys.argv[1], sys.argv[2], sys.argv[3]
    specs = [a.split('=', 1) for a in sys.argv[4:]]
    mon = Mon(os.path.join(sockdir, 'monitor.sock'))
    # LIVECAP_SENDKEY: one sendkey chord through this connection before the wait begins (the
    # monitor serves one client at a time: the Enter that starts the command already typed
    # into the guest's console goes through the connection that then waits for the lines)
    if os.environ.get('LIVECAP_SENDKEY'):
        mon.cmd('sendkey ' + os.environ['LIVECAP_SENDKEY'])
    qpath = os.path.join(sockdir, 'qtest.sock')
    off = os.path.getsize(log) if os.path.exists(log) else 0
    earlier = []            # [(label, stream index, pages, start, size, file)] of the earlier stops
    for label, text in specs:
        needle = text.encode()
        buf = b''
        t0 = time.time()
        while needle not in buf:
            size = os.path.getsize(log) if os.path.exists(log) else 0
            if size > off:
                with open(log, 'rb') as f:
                    f.seek(off)
                    buf += f.read(size - off)
                off = size
            if time.time() - t0 > float(os.environ.get('LIVECAP_TIMEOUT', '300')):
                print('!! %s: %r not seen in time' % (label, text))
                return 1
            time.sleep(0.0005)
        off -= len(buf) - (buf.index(needle) + len(needle))
        print('[%s] %s: %r reached the serial log' % (now(), label, text))
        if label == 'wait':
            continue
        t_stop = time.time()
        mon.cmd('stop')
        print('[%s] %s: stopped, %.1f ms after the line was seen'
              % (now(), label, (time.time() - t_stop) * 1000))
        block, bar, b4 = config(mon)
        if bar is None or b4 is None or b4[1] != BAR4_NAMED or bar[1] == 0:
            print('!! the monitor does not name the model with its BARs (BAR4 must be 0x%x) -- '
                  'nothing read through BAR0:\n%s' % (BAR4_NAMED, block))
            print("   the monitor's replies so far (command, raw chars, tail): %s" % (mon.raw[-14:],))
            print('   the last reply, raw: %r' % mon.lastraw[:700])
            mon.cmd('cont')
            return 1
        bar0 = bar[1]
        print('== %s: the monitor\'s view of the model:\n%s' % (label, block))
        print('   BAR0 0x%x (%s, 0x%x bytes); BAR4 0x%x, the bus driver\'s own line names 0x%x'
              % (bar0, bar[0], bar[2] - bar0 + 1, b4[1], BAR4_NAMED))
        qt = QTest(qpath)
        ok = False
        for attempt in range(1, 51):
            streams = [read_stream(qt, bar0, i) for i in range(8)]
            out_run = [d for d in streams if d['dir'] == 'output' and d['run'] and d['bdl']]
            in_run = [d for d in streams if d['dir'] == 'input' and d['run'] and d['bdl']]
            if label.endswith('end') or label.startswith('now') or (out_run and in_run):
                ok = True
                break
            mon.cmd('cont')
            time.sleep(0.02)
            mon.cmd('stop')
        if not ok:
            print('!! %s: no stop with an output and an input stream running together (attempt %d)'
                  % (label, attempt))
        print('   reading %d: GCAP 0x%04x, VMIN/VMAJ 0x%02x/0x%02x, global CTL 0x%08x'
              % (attempt, qt.readw(bar0), qt.readb(bar0 + 2), qt.readb(bar0 + 3),
                 qt.readl(bar0 + 8)))
        res = dump(mon, qt, bar0, out, label)
        again = {}
        for (l2, i2, pages2, s2, n2, f2) in earlier:
            f3 = '%s-after-%s.bin' % (f2[:-4], label)
            r = mon.cmd('pmemsave 0x%x 0x%x "%s"' % (s2, n2, f3))
            if r or not os.path.exists(f3):
                raise RuntimeError('pmemsave 0x%x 0x%x "%s" -> %r' % (s2, n2, f3, r))
            with open(f3, 'rb') as fh:
                win = fh.read()
            print('   %s stream %d window again: 0x%x..0x%x -> %s'
                  % (l2, i2, s2, s2 + n2 - 1, os.path.basename(f3)))
            for k, (a, n) in enumerate(pages2):
                print('      page %d at 0x%x: %s' % (k, a, stats(win[a - s2:a - s2 + n])))
            again.setdefault(l2, {})[i2] = (pages2, s2, n2, f3)
        for l2, r2 in again.items():
            pairs(r2, '%s, read again at %s' % (l2, label))
        for i, r in res.items():
            earlier.append((label, i, r[0], r[1], r[2], r[3]))
        pairs(res, label)
        qt.close()
        mon.cmd('cont')
        print('[%s] %s: continued' % (now(), label))
    return 0


if __name__ == '__main__':
    sys.exit(main())
