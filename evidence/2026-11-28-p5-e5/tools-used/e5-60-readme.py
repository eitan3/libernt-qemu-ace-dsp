#!/usr/bin/env python3
"""Insert E5's section before the fault-matrix section of the simulator README and its evidence index entry."""
p = "<project>/README.md"
s = open(p, encoding="utf-8").read()
sec = open("/tmp/e5/readme-section.md", encoding="utf-8").read()
marker = "## The fault matrix in the VM (p2b4 image, 2026-11-25)\n"
assert s.count(marker) == 1
if "### The P5 regression on the final image" not in s:
    s = s.replace(marker, sec + marker, 1)
idx = "## Evidence index\n\n"
assert s.count(idx) == 1
entry = """## Evidence index

### 2026-11-28-p5-e5 (P5 E5: the regression on the final image `test-audio-p5final-9f023b460cc` -- the DSP boots by itself and its self-test at every boot; the 22-cycle matrix on the no-topology overlay and the fault rows; the image as burned refuses the first disable (D4); E3 by keys, by the mute key and by the pointer; E5c's properties in the registry (the DSP endpoint's form factor 1, not 10); LEG-1's no-jack rows; the P5-H checklist)

| Run | What it shows |
|---|---|
| `README.md`, `host/image-identity.txt`, `host/SHA256SUMS` | the round's record; the image's identity (`20261128-nt10.0-045-3158-g9f023b4`), the staging directory's `SHA256SUMS`, the exes' hashes |
| `vm/s2-refused-as-burned/` | the first 22-cycle attempt on the image as burned: the disable refused (D4), stopped after its first cycle |
| `vm/s2-prep/`, `vm/s2-cycles/` | the matrix overlay's settings by the registry (no topology, `BootAtStart = 1`, `SelfTest = 3`) and the 22 cycles (`cycles.log`, `summary.txt`: 22 boot ok) |
| `vm/flow/` | the first-session flow on a fresh first-boot overlay: the boot and the self-test, the Sound page, `setdef.txt` (the registry's properties), the tray's keys, dsploop at -8 dB, the mute key, the pointer path (`p4-flyout.png`, `p5-dragged.png`, `p11.png`, `p13-vol-dragged.png`), the 10-minute read (`hc-t*.txt`), the screenshots |
| `vm/e1e2/` | E2's idle power-downs with `DspIdleSec = 3` and E1's fault rows with a stream open (`rows.md`, `e5-e1e2-lines.txt`) |
| `vm/s3/` | the fault rows (`fault-matrix.md`, `fm/`: each row's serial log, command line, screenshot, trace excerpt) and `fm-check.sh`'s table |
| `host/mmdevapi.txt`, `host/build-dsploop.txt` | the host gates on the final tip: `mmdevapi: 317 checks, 0 failures`; the apitest's link |
| `tools-used/` | the scripts as they ran (`vmcommon.sh`, `make-pouch.sh`, `mkqcow2.py`, `e5-flow.sh`, `e2-round.sh`, `prep-cycles.sh`, the launchers, the pouch's `.cmd` files, `procinfo.c`, `build-procinfo.py`, `build-dsploop.py`, `diffbox.py`, `traycols.py`, `brightrows.py`, `darkrows.py`, `bluebox.py`, `ptr.sh`, `p5-h-checklist.md`) |

"""
if "### 2026-11-28-p5-e5" not in s:
    s = s.replace(idx, entry, 1)
open(p, "w", encoding="utf-8").write(s)
print("README: inserted; lines", s.count("\n"))
