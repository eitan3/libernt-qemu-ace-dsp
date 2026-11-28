#!/usr/bin/env python3
"""brightrows.py -- per row of a region, the x-range of bright pixels (a slider's bar and thumb): prints rows that have
them.  brightrows.py <png> <x0> <y0> <w> <h> [thr]"""
import sys
src = open("<project>/tools/pngzoom.py").read()
src = src[:src.index("def write_png")]
ns = {}
exec(src, ns)
read_png = ns["read_png"]
path, x0, y0, w, h = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5])
thr = int(sys.argv[6]) if len(sys.argv) > 6 else 180
width, height, bpp, rows = read_png(path)
for y in range(y0, min(y0 + h, height)):
    line = rows[y]
    xs = [x for x in range(x0, min(x0 + w, width)) if line[x * bpp] > thr and line[x * bpp + 1] > thr and line[x * bpp + 2] > thr]
    if xs:
        # the runs
        runs, s, p = [], xs[0], xs[0]
        for x in xs[1:]:
            if x != p + 1:
                runs.append((s, p)); s = x
            p = x
        runs.append((s, p))
        print(y, " ".join("%d-%d" % r for r in runs))
