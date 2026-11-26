#!/usr/bin/env python3
"""expectcheck.py -- the driver's lines of the round (vm/measured-lines.txt) counted against
the lines TESTING.md of the image expects, character for character after the timestamp."""
import re
import sys

path = sys.argv[1]
A = [re.sub(r"^\[ *[0-9.]+\] ", "", l.rstrip("\n")) for l in open(path, errors="replace")]
Q = "'"
T1 = ("intcdsp.sys: topology " + Q + "sof-ipc4-loopback.tplg" + Q + ": ABI 3.29.1, 4286 bytes (model 2288 bytes), "
      "2 controls, 4 widgets, 2 edges, 1 pcm, 1 pipeline, 0 manifest items, from the registry override")
MODS = ("intcdsp.sys: topology: modules copier → id 5, gain → id 7; endpoint " + Q + "Loopback" + Q +
        " render+capture 48000 Hz 2 ch 16/24/32")
NONE = ("intcdsp.sys: topology: none selected (no override, no quirk, no _DSD name); the DSP is powered down, "
        "no audio endpoint")
CAP = re.compile(r"^intcdsp\.sys: loopback self-test: 4096 frames captured after (\d+) ms, offset (\d+) frames, "
                 r"max abs error (\d+), render rms ([0-9.]+), capture rms ([0-9.]+), ok$")
STOPPED = ("intcdsp.sys: loopback self-test: stopped at render position 0 (LPIB 0, buffer 0), capture position 0 "
           "(LPIB 0, buffer 0), 2 capture periods, released: 1 pipelines and 3 instances deleted, 2 streams freed, ok")
SUMM = ("intcdsp.sys: loopback self-test: 3 runs, 3 matched, 0 failed, 45 requests, 0 notifications, 0 timeouts, "
        "0 DSP interrupts, ok")
RAN = "intcdsp.sys: loopback self-test: ran (0x00000000), the DSP is left running"
caps = [m for m in (CAP.match(l) for l in A) if m]
boots = [l for l in A if l.startswith("intcdsp.sys: boot ok")]
rows = [
    ("the T1 topology line, exact", sum(1 for l in A if l == T1)),
    ("the modules line, exact", sum(1 for l in A if l == MODS)),
    ("the none-selected line, exact", sum(1 for l in A if l == NONE)),
    ("self-test runs started (endpoint lines)", sum(1 for l in A if "self-test: endpoint " in l)),
    ("captured lines", len(caps)),
    ("  of which `after 85 ms, offset 0 frames, max abs error 0`",
     sum(1 for m in caps if m.group(1) == "85" and m.group(2) == "0" and m.group(3) == "0")),
    ("  of which render rms = capture rms = 5793.911 (16-bit)",
     sum(1 for m in caps if m.group(4) == "5793.911" and m.group(5) == "5793.911")),
    ("  of which render rms = capture rms = 379742706.482 (24- and 32-bit)",
     sum(1 for m in caps if m.group(4) == "379742706.482" and m.group(5) == "379742706.482")),
    ("stopped-at lines, exact", sum(1 for l in A if l == STOPPED)),
    ("summary lines, exact", sum(1 for l in A if l == SUMM)),
    ("ran lines, exact", sum(1 for l in A if l == RAN)),
    ("settings lines (one per device start)", sum(1 for l in A if l.startswith("intcdsp.sys: SelfTest = "))),
    ("boot ok lines", len(boots)),
    ("  of which `, 0 DSP interrupts`", sum(1 for l in boots if ", 0 DSP interrupts" in l)),
    ("`DSP power down from state ready: ok`", sum(1 for l in A if "DSP power down from state ready: ok" in l)),
    ("`Entering sleep state S5`", sum(1 for l in A if "Entering sleep state S5" in l)),
    ("`clock stalled`", sum(1 for l in A if "clock stalled" in l)),
    ("`interrupt storm`", sum(1 for l in A if "interrupt storm" in l)),
    ("`Work queue`", sum(1 for l in A if "Work queue" in l)),
    ("fatal / bugcheck lines", sum(1 for l in A if "Fatal" in l or "bugcheck" in l)),
]
w = max(len(r[0]) for r in rows)
for name, n in rows:
    print("%4d  %s" % (n, name))
print("boot ok after (us):", ", ".join(sorted(set(re.search(r"after (\d+) us", l).group(1) for l in boots), key=int)))
print("settings lines seen:", sorted(set(re.search(r"SelfTest = (\d+)", l).group(1) for l in A if "SelfTest = " in l)))
