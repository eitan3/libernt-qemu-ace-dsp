#!/usr/bin/env python3
"""diffbox.py -- the bounding box of the pixels that differ between two QEMU screendump PNGs (the cursor's move).
   diffbox.py a.png b.png   -> prints "x0 y0 x1 y1 n" (or "none")"""
import sys
src = open("<project>/tools/pngzoom.py").read()
src = src[:src.index("def write_png")]
ns = {}
exec(src, ns)
read_png = ns["read_png"]

a = read_png(sys.argv[1])
b = read_png(sys.argv[2])
assert a[0] == b[0] and a[1] == b[1], (a[:2], b[:2])
w, h, bpp, ra = a
rb = b[1 * 3]
x0 = y0 = 10 ** 9
x1 = y1 = -1
n = 0
for y in range(h):
    if ra[y] == rb[y]:
        continue
    for x in range(w):
        pa = ra[y][x * bpp:x * bpp + 3]
        pb = rb[y][x * bpp:x * bpp + 3]
        if pa != pb:
            n += 1
            x0 = min(x0, x); x1 = max(x1, x); y0 = min(y0, y); y1 = max(y1, y)
if n == 0:
    print("none")
else:
    print(x0, y0, x1, y1, n)
