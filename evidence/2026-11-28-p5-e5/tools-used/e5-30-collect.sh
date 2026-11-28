#!/bin/bash
# E5: the evidence of the round under the simulator's evidence/2026-11-28-p5-e5, then normalised (no local paths).
#   e5-30-collect.sh   after every VM of the round ended: the cycles' and the refused attempt's, the flow row's,
#                      the E1/E2 rows' files; the fault rows are collected by tools/fault-matrix.sh itself (COLLECT)
set -u
Q=<project>
E=$Q/evidence/2026-11-28-p5-e5
if ps -eo comm | grep -qi "qemu-system"; then echo "!! a QEMU is running: the evidence of a round is collected after it ended"; exit 3; fi
mkdir -p "$E/vm" "$E/host" "$E/tools-used"
# the 22-cycle matrix (no-topology overlay) and the refused attempt on the image as burned (D4)
mkdir -p "$E/vm/s2-cycles" "$E/vm/s2-refused-as-burned"
for f in cycles.log cycles-run.out lib-run.out serial.log summary.txt console-start.png; do [ -f "/tmp/e5/ev/cycles/$f" ] && cp "/tmp/e5/ev/cycles/$f" "$E/vm/s2-cycles/"; done
cp /tmp/e5/cycles.out "$E/vm/s2-cycles/ac3-cycles.out" 2>/dev/null
for f in cycles.log cycles-run.out serial.log; do [ -f "/tmp/e5/ev/kept-cycles-refused/$f" ] && cp "/tmp/e5/ev/kept-cycles-refused/$f" "$E/vm/s2-refused-as-burned/"; done
for f in /tmp/e5/ev/cycles/console-start.png; do [ -f "$f" ] && cp "$f" "$E/vm/s2-refused-as-burned/console-start.png"; done
# the prep VM (the settings by the registry and a clean shutdown)
mkdir -p "$E/vm/s2-prep"; for f in driver.log before.txt after.txt 50-after.png lib-run.out; do [ -f "/tmp/e5/ev/prepcyc/$f" ] && cp "/tmp/e5/ev/prepcyc/$f" "$E/vm/s2-prep/"; done
cp /tmp/e5/prep.out "$E/vm/s2-prep/prep.out" 2>/dev/null
# the flow row (the first-session flow, E3, E5c's properties, LEG-1's rows)
mkdir -p "$E/vm/flow"
for f in serial.log driver.log lib-run.out setdef.txt hc-t0.txt hc-t10.txt dl-level.txt dl-after.txt rows.md e5-e1e2-lines.txt; do [ -f "/tmp/e5/ev/flow/$f" ] && cp "/tmp/e5/ev/flow/$f" "$E/vm/flow/"; done
for f in 01-boot 02-sound-playback 03-sound-recording 10-setdef 20-level 30-muted 40-ptr-tray 41-ptr-volume 50-sound-10min p4-flyout p5-dragging p5-dragged p11 p12-vol-dragging p13-vol-dragged p14 p16; do [ -f "/tmp/e5/ev/flow/$f.png" ] && cp "/tmp/e5/ev/flow/$f.png" "$E/vm/flow/"; done
cp /tmp/e5/ev/flow/p4-flyout-z.png /tmp/e5/ev/flow/p11-z.png /tmp/e5/ev/flow/cur-e.png "$E/vm/flow/" 2>/dev/null
cp /tmp/e5/flow.out "$E/vm/flow/flow.out" 2>/dev/null
# the E1/E2 rows
mkdir -p "$E/vm/e1e2"
for f in serial.log driver.log lib-run.out settings-before.txt settings-idle.txt rows.md summary.txt cycles.log cycles-run.out e5-e1e2-lines.txt; do [ -f "/tmp/e5/ev/e2/$f" ] && cp "/tmp/e5/ev/e2/$f" "$E/vm/e1e2/"; done
cp /tmp/e5/ev/e2/dl-*.txt "$E/vm/e1e2/" 2>/dev/null
cp /tmp/e5/ev/e2/*.png "$E/vm/e1e2/" 2>/dev/null
cp /tmp/e5/e2.out "$E/vm/e1e2/e2.out" 2>/dev/null
# host
cp /tmp/e5/build-dsploop.txt /tmp/e5/mmdevapi.txt /tmp/e5/host-ctest.txt "$E/host/" 2>/dev/null
(cd /tmp/e5/dsploop && sha256sum dsploop_apitest.exe; cd /tmp/e5/setdef && sha256sum setdefault.exe endpointmute.exe procinfo.exe) > "$E/host/SHA256SUMS"
cp /tmp/e5/setdef-src/procinfo.c /tmp/build-procinfo.py /tmp/build-dsploop.py "$E/tools-used/"
cp /tmp/e5/image-identity.txt "$E/host/" 2>/dev/null
# tools as they ran
cd /tmp/e5/tools && cp vmcommon.sh make-pouch.sh mkqcow2.py e5-flow.sh e2-round.sh prep-cycles.sh setdef.cmd dl.cmd mute.cmd hc.cmd snd.cmd vol.cmd "$E/tools-used/"
cp /tmp/e5-00-prep.sh /tmp/e5-10-cycles.sh /tmp/e5-11-flow.sh /tmp/e5-20-faults.sh /tmp/e5-30-collect.sh /tmp/e5-30-e2.sh /tmp/e5-40-host.sh /tmp/e5-50-chain.sh /tmp/e5-51-chain2.sh /tmp/e5-build-dsploop.sh /tmp/e5-60-readme.py /tmp/e5-61-fill.py "$E/tools-used/" 2>/dev/null
cp /tmp/e5/tools/ptr.sh /tmp/e5/cur.sh /tmp/e5/tools/diffbox.py /tmp/e5/tools/traycols.py /tmp/e5/tools/brightrows.py /tmp/e5/tools/darkrows.py /tmp/e5/tools/bluebox.py "$E/tools-used/" 2>/dev/null
cp /tmp/e5/ptr.sh /tmp/e5/cur.sh "$E/tools-used/" 2>/dev/null
cp /tmp/e5/findings.md "$E/../2026-11-28-p5-e5-new-findings-copy.md" 2>/dev/null; rm -f "$E/../2026-11-28-p5-e5-new-findings-copy.md"
# the E1/E2 rows' launcher output and the flow's hand-driven screenshots are in the VM dirs already
cp /tmp/e5-11-flow.out "$E/vm/flow/host-gate-and-launcher.out" 2>/dev/null
cp /tmp/p5-h-checklist.md "$E/tools-used/p5-h-checklist.md"
(cd "$Q" && bash normalise-evidence.sh | tail -3)
echo "files: $(find "$E" -type f | wc -l), $(du -sh "$E" | cut -f1)"
find "$E" -maxdepth 2 | sort | head -60
