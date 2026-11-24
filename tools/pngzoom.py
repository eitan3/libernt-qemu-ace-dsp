#!/usr/bin/env python3
"""pngzoom.py — crop a region of a PNG and upscale it (nearest neighbour), stdlib only.
usage: pngzoom.py in.png out.png x y w h [scale]
Decodes 8-bit RGB/RGBA non-interlaced PNG (the QEMU screendump format)."""
import struct, sys, zlib

def read_png(path):
    d = open(path, 'rb').read()
    assert d[:8] == b'\x89PNG\r\n\x1a\n'
    pos, idat, w, h, ctype = 8, b'', 0, 0, 0
    while pos < len(d):
        ln, = struct.unpack('>I', d[pos:pos + 4]); typ = d[pos + 4:pos + 8]
        body = d[pos + 8:pos + 8 + ln]
        if typ == b'IHDR':
            w, h, depth, ctype, _, _, interlace = struct.unpack('>IIBBBBB', body)
            assert depth == 8 and interlace == 0, (depth, interlace)
        elif typ == b'IDAT':
            idat += body
        pos += 12 + ln
    bpp = {2: 3, 6: 4}[ctype]
    raw = zlib.decompress(idat)
    stride = w * bpp
    rows, prev = [], bytearray(stride)
    p = 0
    for y in range(h):
        f = raw[p]; p += 1
        line = bytearray(raw[p:p + stride]); p += stride
        for i in range(stride):
            a = line[i - bpp] if i >= bpp else 0
            b = prev[i]
            c = prev[i - bpp] if i >= bpp else 0
            if f == 1: line[i] = (line[i] + a) & 255
            elif f == 2: line[i] = (line[i] + b) & 255
            elif f == 3: line[i] = (line[i] + ((a + b) >> 1)) & 255
            elif f == 4:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 255
        rows.append(bytes(line)); prev = line
    return w, h, bpp, rows

def write_png(path, w, h, bpp, rows):
    raw = b''.join(b'\x00' + r for r in rows)
    def chunk(t, b): return struct.pack('>I', len(b)) + t + b + struct.pack('>I', zlib.crc32(t + b) & 0xffffffff)
    ctype = {3: 2, 4: 6}[bpp]
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, ctype, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw, 6)) + chunk(b'IEND', b'')
    open(path, 'wb').write(png)

def main():
    src, dst = sys.argv[1], sys.argv[2]
    x, y, cw, ch = map(int, sys.argv[3:7])
    s = int(sys.argv[7]) if len(sys.argv) > 7 else 3
    w, h, bpp, rows = read_png(src)
    x, y = max(0, x), max(0, y); cw, ch = min(cw, w - x), min(ch, h - y)
    out = []
    for j in range(ch):
        r = rows[y + j][x * bpp:(x + cw) * bpp]
        r = b''.join(r[i * bpp:(i + 1) * bpp] * s for i in range(cw))
        for _ in range(s): out.append(r)
    write_png(dst, cw * s, ch * s, bpp, out)
    print(dst, cw * s, ch * s)

main()
