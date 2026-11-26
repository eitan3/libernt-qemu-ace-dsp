#!/usr/bin/env python3
"""pageverify.py -- for every descriptor list a livecap.py or salvage.py output prints, the
first frames of each page against the driver's sine (IntcDspSineQ31 at 1619498f85e):
16-bit containers are the sine >> 18 as int16 pairs (1024 frames a page), 24/32-bit
containers the sine >> 2 as int32 pairs (512 frames a page); page k of a list starts at
the sine's frame (1024 k) mod 48, or (512 k) mod 48.   pageverify.py <out> [...]"""
import re
import sys

T = [0, 280302863, 555809667, 821806413, 1073741823, 1307305214, 1518500249, 1703713325,
     1859775393, 1984016188, 2074309916, 2129111627, 2147483647, 2129111627, 2074309916,
     1984016188, 1859775393, 1703713325, 1518500249, 1307305214, 1073741823, 821806413,
     555809667, 280302863, 0, -280302863, -555809667, -821806413, -1073741823,
     -1307305214, -1518500249, -1703713325, -1859775393, -1984016188, -2074309916,
     -2129111627, -2147483647, -2129111627, -2074309916, -1984016188, -1859775393,
     -1703713325, -1518500249, -1307305214, -1073741824, -821806413, -555809667, -280302863]


def cdiv(v, n):
    """the C >> of a signed value: an arithmetic shift (Python's >> on ints is one)"""
    return v >> n


R_EQ = re.compile(r"^== (\S+?):")
R_LIST = re.compile(r"^   (input|output) stream (\d+): (\d+) descriptors at (\S+)")
R_PAGE = re.compile(r"^      page (\d+) at (\S+): head i16: ((?:-?\d+ ?){16}) \| head i32: ((?:-?\d+ ?){8})")
R_AGAIN = re.compile(r"^   (\S+) stream (\d+) window again")
R_ST = re.compile(r"^   st\[(\d)\] (input|output) .*cbl=(\d+) lvi=(\d+) fmt=(\S+)")


def s16(v):
    return v - 65536 if v >= 32768 else v


bad = 0
for fn in sys.argv[1:]:
    label = fn.rsplit("/", 1)[-1].replace(".out", "")
    cur = None
    fmt = {}
    print("=====", fn.rsplit("/", 1)[-1])
    for line in open(fn, errors="replace"):
        line = line.rstrip("\n")
        m = R_EQ.match(line)
        if m:
            label = m.group(1)
            cur = None
            continue
        m = R_ST.match(line)
        if m:
            fmt[(label, m.group(2), m.group(1))] = m.group(5)
            continue
        m = R_AGAIN.match(line)
        if m:
            cur = None
            continue
        m = R_LIST.match(line)
        if m:
            cur = {"name": "%s: %s stream %s" % (label, m.group(1), m.group(2)), "pages": [], "dir": m.group(1),
                   "st": m.group(2), "n": int(m.group(3))}
            continue
        m = R_PAGE.match(line)
        if m and cur is not None:
            cur["pages"].append((int(m.group(1)), m.group(2), [int(x) for x in m.group(3).split()],
                                 [int(x) for x in m.group(4).split()]))
            if len(cur["pages"]) == cur["n"]:
                f = fmt.get((label, cur["dir"], cur["st"]), "?")
                per = 1024 if f == "0x0011" else 512
                width = 2 if f == "0x0011" else 4
                verdicts = []
                for k, addr, h16, h32 in cur["pages"]:
                    start = (per * k) % 48
                    if width == 2:
                        got = [s16(h16[0]), s16(h16[2]), s16(h16[4]), s16(h16[6])]
                        want = [(T[(start + i) % 48] >> 18) for i in range(4)]
                    else:
                        got = [h32[0], h32[2], h32[4], h32[6]]
                        want = [(T[(start + i) % 48] >> 2) for i in range(4)]
                    ok = got == want
                    bad += 0 if ok or cur["dir"] == "input" else 1
                    verdicts.append("%s%s" % ("" if ok else "NOT ", "") if ok else "page %d NOT (got %s want %s)" % (k, got, want))
                res = "every page starts at the sine's frame" if all(v == "" for v in verdicts) else "; ".join(v for v in verdicts if v)
                print("   %s [%s pages, fmt %s]: %s %s" % (cur["name"], cur["n"], f, res,
                                                           "" if cur["dir"] == "output" else "(input: the capture's own content)"))
                if cur["dir"] == "input":
                    # say what the capture's pages hold, in one line
                    kinds = []
                    for k, addr, h16, h32 in cur["pages"]:
                        if all(v == -12851 for v in h16):
                            kinds.append("%d:poison" % k)
                        elif all(v == 0 for v in h16):
                            kinds.append("%d:zero" % k)
                        else:
                            kinds.append("%d:sine" % k)
                    print("      the capture's pages: %s" % " ".join(kinds))
                cur = None
print("lists whose render pages are not the sine's from their first frame:", bad)
