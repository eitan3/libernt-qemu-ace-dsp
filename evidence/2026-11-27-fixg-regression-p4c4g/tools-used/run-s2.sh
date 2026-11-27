#!/bin/bash
# run-s2.sh -- S2 of the p4c4g round: the overlay over the p4c4g LiberNT.vhd (BootDsp = 1, no
# topology), its first boot, then the close-out regression's 22 disable/enable cycles
# (boot2.sh = the p4c4c round's boot2.sh), the evidence collected into the evidence tree.
set -u
Q=<project>
E=$Q/evidence/2026-11-27-fixg-regression-p4c4g
IMG=<home>/libernt-build-logs/test-audio-intel-sst-p4c4g-6bdaaa5e920
T=/tmp/c6g/tools
cd "$Q"
if pgrep -f "qemu-system-x86_64 -L $Q/build/pc-bios" > /dev/null; then echo "REFUSED: a QEMU of this project is running" >&2; exit 3; fi
[ -e disk/p4c4g-nt.qcow2 ] && { echo "REFUSED: disk/p4c4g-nt.qcow2 exists" >&2; exit 3; }
VHD="$IMG/LiberNT.vhd" bash make-overlay.sh p4c4g-nt > "$E/logs/s2/overlay-made.txt" 2>&1
cat "$E/logs/s2/overlay-made.txt"
RUN=r2-notopology-cycles OVERLAY=p4c4g-nt bash "$T/boot2.sh" > /tmp/c6g/ev/boot2.out 2>&1
rc=$?
echo "boot2.sh rc=$rc"
tail -5 /tmp/c6g/ev/boot2.out
bash "$T/collect.sh" /tmp/c6g/ev/r2-notopology-cycles "$E/logs/s2/r2" s1-desktop-before-wizard s2-after-wizard s3-after-wizard-20s
cp /tmp/c6g/ev/boot2.out "$E/logs/s2/boot2.out"
