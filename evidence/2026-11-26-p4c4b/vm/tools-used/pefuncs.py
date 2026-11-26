#!/usr/bin/env python3
"""pefuncs.py -- the function of an image's .pdata (RUNTIME_FUNCTION table) that holds an RVA.

   pefuncs.py <pe.exe> <0xRVA> [<0xRVA> ...]

Reads the section table itself (no symbols in the image): prints, for each RVA, the
[begin, end) of the function it is in, and every 'call rel32' in the image whose target
falls inside that function (the places it is called from), with the instruction's RVA.
"""
import struct
import sys


def sections(data):
    pe = struct.unpack_from('<I', data, 0x3C)[0]
    nsec = struct.unpack_from('<H', data, pe + 6)[0]
    opt = struct.unpack_from('<H', data, pe + 20)[0]
    base = struct.unpack_from('<Q', data, pe + 24 + 24)[0]
    out = []
    for i in range(nsec):
        o = pe + 24 + opt + 40 * i
        name = data[o:o + 8].rstrip(b'\0').decode()
        vsize, vaddr, rawsize, rawptr = struct.unpack_from('<IIII', data, o + 8)
        out.append((name, vaddr, max(vsize, rawsize), rawptr))
    return base, out


def main():
    data = open(sys.argv[1], 'rb').read()
    base, secs = sections(data)
    pd = [s for s in secs if s[0] == '.pdata'][0]
    funcs = sorted(struct.unpack_from('<III', data, pd[3] + 12 * i)[:2]
                   for i in range(pd[2] // 12))
    for a in sys.argv[2:]:
        rva = int(a, 16)
        f = [x for x in funcs if x[0] <= rva < x[1]]
        lo, hi = f[0] if f else (rva - 0x40, rva + 0x40)
        print('RVA 0x%x: function [0x%x, 0x%x) (%d bytes)' % (rva, lo, hi, hi - lo))
        # every call rel32 in .text whose target is in [lo, hi)
        t = [s for s in secs if s[0] == '.text'][0]
        calls = []
        blob = data[t[3]:t[3] + t[2]]
        i = blob.find(b'\xe8')
        while i >= 0 and i + 5 <= len(blob):
            rel = struct.unpack_from('<i', blob, i + 1)[0]
            src = t[1] + i
            if lo <= src + 5 + rel < hi:
                calls.append(src)
            i = blob.find(b'\xe8', i + 1)
        print('   called from (call rel32 sites, RVA): %s' % ', '.join('0x%x' % c for c in calls[:40]))
    return 0


if __name__ == '__main__':
    sys.exit(main())
