#!/usr/bin/env python3
"""Fill the E1/E2 cells of E5's README section and the evidence README's E1E2 cells (the fault rows' cells by a second run)."""
import sys
R = "<project>/README.md"
s = open(R, encoding="utf-8").read()
e1 = ("**`never-reply=19` at a run's first open** (the flow overlay, `DspIdleSec = 3` live by a reboot): `ipc: set pipeline state (19) 0x93010003|0x00000000 reply timeout after 500204 us; the link is faulted` → `fault during stream 1: reply timeout after 500 ms` → `streams: released after the fault; nothing is sent until the next stream open or D0 entry`; dsploop stopped by itself (`0 of 3 depths compared`, `9 tests executed … 2 failures`); the run after it: **`recovered: open ok after 6 ms`**, **PASS** (`3 of 3 depths compared`, 0 failures). `crash-async=500` set before a run (not at the first open as E1c did): **not produced** -- the run passed with the knob set, no exception line; E1c's row stands for the crash mid-stream. The D0 cycles with a stream open: not reachable in the VM (no S3/S4; the disable refused, D4), as E1b/E1c recorded")
e2 = ("**E2 (b)(c)(d)** on the flow overlay with `DspIdleSec = 3` (the registry, a reboot; the setting read at the reboot's D0 entry): from that entry on `booting 11, boot ok 11, selftest ok 1, boot at open ok 10, failed-boot 0, idle 11, recovered 0, render opens 30, timeouts 0, fault-during 0`; **10 of 10 dsploop runs PASS**, each with exactly one `boot at stream open: ok after 6 ms` at its first open and one `idle power down after 3 s` after it (the 11th idle power-down: 3 s after the boot's own self-test); 30 render opens (10 × 3), 0 timeouts. The plan's 50 cycles: 30 here (E2's own round has 51). **E2 (e)(f)** `BootAtStart = 1`, no topology: the 22-cycle matrix above (the matrix overlay)")
assert s.count("«E1»") == 1 and s.count("«E2»") == 1
s = s.replace("«E1»", e1).replace("«E2»", e2)
open(R, "w", encoding="utf-8").write(s)
E = "/tmp/e5/evidence-README.md"
t = open(E, encoding="utf-8").read()
t = t.replace("«E1E2»", "**PASS**: E2 (b)(c)(d) 10 of 10 runs, 10 boots at open, 11 idle power-downs, 30 render opens, 0 timeouts; E1 `never-reply=19` → `recovered: open ok after 6 ms`, the run after PASS; `crash-async=500` set before the run: not produced (E1c's row stands); rc 0, wall 537 s, 0 fatal (`vm/e1e2/rows.md`, `e5-e1e2-lines.txt`)")
t = t.replace("«E2D»", "E2 (d)'s 50 cycles were 30 here (10 runs × 3 opens); E2's own round has 51 on p5e2")
open(E, "w", encoding="utf-8").write(t)
print("filled E1/E2 cells; README lines", s.count("\n"))
