#!/usr/bin/env python3
"""bluebox.py -- the bounding box of the blue pixels (an accent-coloured slider handle) in a region.
bluebox.py <png> <x0> <y0> <w> <h>"""
import sys
src = open("<project>/tools/pngzoom.py").read()
src = src[:src.index("def write_png")]
ns = {}
exec(src, ns)
read_png = ns["read_png"]
path, x0, y0, w, h = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5])
width, height, bpp, rows = read_png(path)
xs, ys = [], []
for y in range(y0, min(y0 + h, height)):
    line = rows[y]
    for x in range(x0, min(x0 + w, width)):
        r, g, b = line[x * bpp], line[x * bpp + 1], line[x * bpp + 2]
        if b > 150 and r < 110 and g < 160:
            xs.append(x); ys.append(y)
if xs:
    print("blue box: x %d-%d y %d-%d (%d px)" % (min(xs), max(xs), min(ys), max(ys), len(xs)))
else:
    print("no blue pixels")
