#!/usr/bin/env python3
"""darkrows.py -- per row of a region, the x-ranges of dark pixels (a dark panel on a bright wallpaper) and the bright
runs inside them (a slider's bar and thumb).  darkrows.py <png> <x0> <y0> <w> <h>"""
import sys
src = open("<project>/tools/pngzoom.py").read()
src = src[:src.index("def write_png")]
ns = {}
exec(src, ns)
read_png = ns["read_png"]
path, x0, y0, w, h = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5])
width, height, bpp, rows = read_png(path)
prev = None
for y in range(y0, min(y0 + h, height)):
    line = rows[y]
    dark = [x for x in range(x0, min(x0 + w, width)) if line[x * bpp] < 60 and line[x * bpp + 1] < 60 and line[x * bpp + 2] < 80]
    if not dark:
        continue
    lo, hi = dark[0], dark[-1]
    bright = [x for x in range(lo, hi + 1) if line[x * bpp] > 120 and line[x * bpp + 1] > 120 and line[x * bpp + 2] > 120]
    runs, s, p = [], bright[0] if bright else None, bright[0] if bright else None
    for x in bright[1:]:
        if x != p + 1:
            runs.append((s, p)); s = x
        p = x
    if bright:
        runs.append((s, p))
    sig = (lo, hi, len(dark))
    if sig != prev:
        print(y, "dark %d-%d (%d px)" % (lo, hi, len(dark)), "bright:", " ".join("%d-%d" % r for r in runs))
    prev = sig
