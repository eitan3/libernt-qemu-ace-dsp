#!/usr/bin/env python3
"""livesum.py -- a livecap.py (or salvage.py) output as compact tables: per stop, the
streams that are running or programmed, each list's descriptors as addr:len:ioc (ioc is
the fourth word's bit 0; "+spec" if the upper dword's bit 31 is also set), each page's
first four frames with its zero and 0xCDCD word counts, the windows read again at a
later stop, and the capture-against-render verdicts.   livesum.py <out> [...]"""
import re
import sys

R_EQ = re.compile(r"^== (\S+?):")
R_ST = re.compile(r"^   st\[(\d)\] (input|output) .*\(RUN (\d).*tag (\d)\).*lpib=(\d+) cbl=(\d+) lvi=(\d+) fmt=(\S+) bdl=(\S+)")
R_LIST = re.compile(r"^   (input|output) stream (\d+): (\d+) descriptors at (\S+)")
R_BDL = re.compile(r"^      bdl\[(\d+)\] words (\S+) (\S+) (\S+) (\S+)  addr (\S+) len (\d+)  ioc: word 3 bit 0 = (\d), upper dword bit 31 = (\d)")
R_PAGE = re.compile(r"^      page (\d+) at (\S+): head i16: ((?:-?\d+ ?){8}) \| head i32: ((?:-?\d+ ?){2}).*?zero: (\d+)/\d+ words.*?0xCDCD: (\d+)/\d+ words")
R_AGAIN = re.compile(r"^   (\S+) stream (\d+) window again: (\S+) -> (\S+)$")
R_CMP = re.compile(r"^   (.*): capture against render, page by page")
R_VERD = re.compile(r"^      page (\d+) \(capture (\S+), render (\S+)\): (identical, \d+ bytes|differ at byte \d+: capture (-?\d+) \S+, render (-?\d+) \S+; differing bytes (\d+) of (\d+))")
R_MARK = re.compile(r"^\[[\d:.]+\] (\S+): (.*)$")


def frames(head):
    v = [int(x) for x in head.split()]
    return " ".join("%d,%d" % (v[2 * i], v[2 * i + 1]) for i in range(len(v) // 2))


for fn in sys.argv[1:]:
    print("=====", fn.rsplit("/", 1)[-1])
    label = cur = title = None
    out = {}
    marks = []
    for line in open(fn, errors="replace"):
        line = line.rstrip("\n")
        m = R_MARK.match(line)
        if m:
            if "stopped," in m.group(2) or "not seen" in m.group(2) or "reached the serial log" not in m.group(2):
                marks.append("%s: %s" % (m.group(1), m.group(2)[:90]))
            continue
        m = R_EQ.match(line)
        if m:
            label = m.group(1)
            out.setdefault(label, {"st": [], "lists": [], "cmp": []})
            cur = None
            continue
        if label is None:
            continue
        o = out[label]
        m = R_ST.match(line)
        if m:
            if m.group(3) == "1" or int(m.group(7)) > 0 or m.group(9) != "0x0":
                o["st"].append("st[%s] %s RUN %s tag %s lpib %s cbl %s lvi %s fmt %s bdl %s" % m.groups())
            continue
        m = R_AGAIN.match(line)
        if m:
            cur = {"name": "%s stream %s, read again (%s..%s)" % (m.group(1), m.group(2), m.group(3), m.group(4)),
                   "desc": [], "pages": []}
            o["lists"].append(cur)
            continue
        m = R_LIST.match(line)
        if m:
            if label is None:
                label = fn.rsplit("/", 1)[-1].replace(".out", "")
                out.setdefault(label, {"st": [], "lists": [], "cmp": []})
                o = out[label]
            cur = {"name": "%s stream %s, %s descriptors at %s" % (m.group(1), m.group(2), m.group(3), m.group(4)),
                   "desc": [], "pages": []}
            o["lists"].append(cur)
            continue
        m = R_BDL.match(line)
        if m and cur is not None:
            cur["desc"].append((int(m.group(6), 16), int(m.group(7)), int(m.group(8)), m.group(9)))
            continue
        m = R_PAGE.match(line)
        if m and cur is not None:
            cur["pages"].append((m.group(2), frames(m.group(3)), m.group(5), m.group(6)))
            continue
        m = R_CMP.match(line)
        if m:
            title = m.group(1)
            continue
        m = R_VERD.match(line)
        if m and title:
            o["cmp"].append("%s: page %s capture %s render %s: %s" % (title, m.group(1), m.group(2), m.group(3), m.group(4)))
            continue
    for mk in marks:
        print("  " + mk)
    for label, o in out.items():
        print("== %s" % label)
        for s in o["st"]:
            print("   " + s)
        for l in o["lists"]:
            n = len(l["desc"])
            iocs = [int(i) for _, _, i, _ in l["desc"]]
            want = [1 if k in (n // 2 - 1, n - 1) else 0 for k in range(n)]
            addrs = [a for a, _, _, _ in l["desc"]]
            contig = all(addrs[k + 1] - addrs[k] == 4096 for k in range(n - 1)) if n > 1 else None
            print("   %s: %s" % (l["name"], " | ".join(
                "%#x:%d:ioc %d%s" % (a, ln, i, "+spec31" if u == "1" else "") for a, ln, i, u in l["desc"])))
            if n:
                print("      ioc pattern %s (%s); %s; pages %#x..%#x" % (
                    iocs, "as expected" if iocs == want else "NOT as expected %s" % want,
                    "contiguous ascending pages" if contig else "NOT contiguous" if contig is False else "one page",
                    addrs[0], addrs[-1] + 4096))
            for a, fr, z, p in l["pages"]:
                print("      %#x: frames %s; zero words %s, 0xCDCD words %s" % (int(a, 16), fr, z, p))
        groups = {}
        for c in o["cmp"]:
            title, rest = c.split(": page ", 1)
            groups.setdefault(title, []).append(rest)
        for title, rests in groups.items():
            same = [r for r in rests if ": identical" in r]
            diff = [r for r in rests if ": identical" not in r]
            line = "   %s: %d identical of %d" % (title, len(same), len(rests))
            if diff:
                line += "; differing: " + " | ".join(d.replace(", render", " / render").split(": differ at byte")[0]
                                                   + " (" + d.split("; differing bytes ")[-1] + ")" for d in diff[:3])
            print(line)
