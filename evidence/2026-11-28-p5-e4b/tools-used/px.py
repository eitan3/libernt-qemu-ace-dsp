#!/usr/bin/env python3
"""px.py -- read pixels of a QEMU screendump PNG (8-bit RGB/RGBA, non-interlaced), stdlib only.
   px.py in.png x y [x y ...]        the RGB of each point
   px.py in.png x0 y0 x1 y1 [step]   the RGB of a grid over the rectangle
   px.py in.png x0 y0 x1 y1 blue     the y ranges in the rectangle whose pixels are mostly a selection blue"""
import struct
import sys
import zlib


def read_png(path):
    d = open(path, 'rb').read()
    assert d[:8] == b'\x89PNG\r\n\x1a\n'
    pos, idat, w, h, ctype = 8, b'', 0, 0, 0
    while pos < len(d):
        ln, = struct.unpack('>I', d[pos:pos + 4])
        typ = d[pos + 4:pos + 8]
        body = d[pos + 8:pos + 8 + ln]
        if typ == b'IHDR':
            w, h, depth, ctype, _, _, interlace = struct.unpack('>IIBBBBB', body)
            assert depth == 8 and interlace == 0, (depth, interlace)
        elif typ == b'IDAT':
            idat += body
        pos += 12 + ln
    bpp = {2: 3, 6: 4}[ctype]
    raw = zlib.decompress(idat)
    stride = w * bpp + 1
    rows = []
    prev = bytearray(w * bpp)
    for y in range(h):
        f = raw[y * stride]
        line = bytearray(raw[y * stride + 1:(y + 1) * stride])
        for i in range(len(line)):
            a = line[i - bpp] if i >= bpp else 0
            b = prev[i]
            c = prev[i - bpp] if i >= bpp else 0
            if f == 1:
                line[i] = (line[i] + a) & 255
            elif f == 2:
                line[i] = (line[i] + b) & 255
            elif f == 3:
                line[i] = (line[i] + (a + b) // 2) & 255
            elif f == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 255
        rows.append(line)
        prev = line
    return w, h, bpp, rows


def px(rows, bpp, x, y):
    r = rows[y]
    return (r[x * bpp], r[x * bpp + 1], r[x * bpp + 2])


def main():
    path = sys.argv[1]
    w, h, bpp, rows = read_png(path)
    args = sys.argv[2:]
    if len(args) == 5 and args[-1] == 'blue':
        x0, y0, x1, y1 = map(int, args[:4])
        # a selection row: a blue-dominant band (b > r + 40 and b > 120) over most of its width
        band = []
        for y in range(y0, min(y1, h)):
            n = sum(1 for x in range(x0, min(x1, w), 2) if (lambda c: c[2] > c[0] + 40 and c[2] > 120)(px(rows, bpp, x, y)))
            if n > (min(x1, w) - x0) // 4:
                band.append(y)
        # the contiguous ranges
        out, start = [], None
        for y in band:
            if start is None or y != prev + 1:
                if start is not None:
                    out.append((start, prev))
                start = y
            prev = y
        if start is not None:
            out.append((start, prev))
        print('blue bands (y ranges):', out)
        for (a, b) in out:
            print('  y %d-%d: x-colours at y=%d:' % (a, b, (a + b) // 2), [px(rows, bpp, x, (a + b) // 2) for x in range(x0, min(x1, w), max(1, (min(x1, w) - x0) // 8))])
        return
    if len(args) in (4, 5):
        x0, y0, x1, y1 = map(int, args[:4])
        step = int(args[4]) if len(args) == 5 else max(1, max(x1 - x0, y1 - y0) // 16)
        for y in range(y0, min(y1, h), step):
            print('y=%4d:' % y, ' '.join('%02x%02x%02x' % px(rows, bpp, x, y) for x in range(x0, min(x1, w), step)))
        return
    pts = list(map(int, args))
    for i in range(0, len(pts), 2):
        print('(%d,%d) = %02x%02x%02x' % ((pts[i], pts[i + 1]) + px(rows, bpp, pts[i], pts[i + 1])))


if __name__ == '__main__':
    main()
