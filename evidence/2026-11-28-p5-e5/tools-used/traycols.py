#!/usr/bin/env python3
"""traycols.py -- the x-ranges (clusters) of bright pixels in a strip of a QEMU screendump PNG: the tray's icons and the
cursor.  traycols.py <png> <x0> <y0> <w> <h> [threshold]"""
import sys
src = open("<project>/tools/pngzoom.py").read()
src = src[:src.index("def write_png")]
ns = {}
exec(src, ns)
read_png = ns["read_png"]
path, x0, y0, w, h = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5])
thr = int(sys.argv[6]) if len(sys.argv) > 6 else 180
width, height, bpp, rows = read_png(path)
cols = [0] * w
rows_ = [0] * h
for y in range(y0, min(y0 + h, height)):
    line = rows[y]
    for x in range(x0, min(x0 + w, width)):
        o = x * bpp
        r, g, b = line[o], line[o + 1], line[o + 2]
        if r > thr and g > thr and b > thr:
            cols[x - x0] += 1
            rows_[y - y0] += 1
# clusters of columns with bright pixels
clusters = []
start = None
for i, c in enumerate(cols):
    if c and start is None:
        start = i
    if not c and start is not None:
        clusters.append((x0 + start, x0 + i - 1)); start = None
if start is not None:
    clusters.append((x0 + start, x0 + w - 1))
print("x clusters (x0-x1):", " ".join("%d-%d" % c for c in clusters))
print("y rows with bright pixels:", " ".join(str(y0 + i) for i, c in enumerate(rows_) if c))
