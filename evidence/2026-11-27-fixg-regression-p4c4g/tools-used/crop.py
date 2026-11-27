#!/usr/bin/env python3
# crop.py <in.png> <out.png> <x0> <y0> <x1> <y1> [scale] -- cut a region out of a screendump PNG
# (8-bit RGB/RGBA, non-interlaced) and enlarge it by a whole factor, so that small text can be
# read exactly; no image library is on the host, so the PNG is decoded and encoded here.
import struct
import sys
import zlib


def read_png(p):
    d = open(p, 'rb').read()
    assert d[:8] == b'\x89PNG\r\n\x1a\n', 'not a PNG'
    pos, idat = 8, b''
    while pos < len(d):
        ln, typ = struct.unpack('>I4s', d[pos:pos + 8])
        body = d[pos + 8:pos + 8 + ln]
        pos += 12 + ln
        if typ == b'IHDR':
            w, h, bd, ct, cm, fm, im = struct.unpack('>IIBBBBB', body)
            assert bd == 8 and im == 0, '8-bit non-interlaced only'
            bpp = {0: 1, 2: 3, 4: 2, 6: 4}[ct]
        elif typ == b'IDAT':
            idat += body
        elif typ == b'IEND':
            break
    raw = zlib.decompress(idat)
    stride = w * bpp
    rows, prev, i = [], bytearray(stride), 0
    for y in range(h):
        f = raw[i]
        i += 1
        line = bytearray(raw[i:i + stride])
        i += stride
        if f == 1:
            for x in range(bpp, stride):
                line[x] = (line[x] + line[x - bpp]) & 255
        elif f == 2:
            for x in range(stride):
                line[x] = (line[x] + prev[x]) & 255
        elif f == 3:
            for x in range(stride):
                a = line[x - bpp] if x >= bpp else 0
                line[x] = (line[x] + ((a + prev[x]) >> 1)) & 255
        elif f == 4:
            for x in range(stride):
                a = line[x - bpp] if x >= bpp else 0
                b = prev[x]
                c = prev[x - bpp] if x >= bpp else 0
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[x] = (line[x] + pr) & 255
        rows.append(line)
        prev = line
    return w, h, bpp, rows


def write_png(p, w, h, bpp, rows):
    ct = {1: 0, 3: 2, 2: 4, 4: 6}[bpp]
    raw = b''.join(b'\x00' + bytes(r) for r in rows)

    def chunk(t, b):
        return struct.pack('>I', len(b)) + t + b + struct.pack('>I', zlib.crc32(t + b) & 0xffffffff)
    png = (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, ct, 0, 0, 0))
           + chunk(b'IDAT', zlib.compress(raw, 6)) + chunk(b'IEND', b''))
    open(p, 'wb').write(png)


def main():
    src, dst = sys.argv[1], sys.argv[2]
    x0, y0, x1, y1 = (int(v) for v in sys.argv[3:7])
    s = int(sys.argv[7]) if len(sys.argv) > 7 else 3
    w, h, bpp, rows = read_png(src)
    x0, x1 = max(0, x0), min(w, x1)
    y0, y1 = max(0, y0), min(h, y1)
    out = []
    for y in range(y0, y1):
        px = bytes(rows[y][x0 * bpp:x1 * bpp])
        line = bytearray()
        for i in range(0, len(px), bpp):
            line += px[i:i + bpp] * s
        for _ in range(s):
            out.append(line)
    write_png(dst, (x1 - x0) * s, (y1 - y0) * s, bpp, out)
    print('%s: %dx%d from (%d,%d)-(%d,%d) x%d' % (dst, (x1 - x0) * s, (y1 - y0) * s, x0, y0, x1, y1, s))


if __name__ == '__main__':
    main()
