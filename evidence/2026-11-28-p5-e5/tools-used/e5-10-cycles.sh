#!/bin/bash
# E5 block 2 (after D4): the matrix's settings on the installed overlay (prep VM, clean shutdown), then the 22-cycle
# matrix by tools/ac3-cycles.sh under ICOUNT=1.  Output to /tmp/e5/prep.out and /tmp/e5/cycles.out.
set -u
QAD=<project>
IMG=<home>/libernt-build-logs/test-audio-p5final-9f023b460cc
ps -eo comm | grep -qi "qemu-system" && { echo "!! a QEMU is already running"; exit 3; }
date '+start %T'
RUN=prepcyc OVERLAY=e5-firstboot bash /tmp/e5/tools/prep-cycles.sh > /tmp/e5/prep.out 2>&1
rc=$?
echo "prep rc=$rc"; grep -a -E "##|!!|done|reg add|typed|output after" /tmp/e5/prep.out | cut -c1-300
date '+prep end %T'
rm -rf /tmp/e5/ev/cycles; mkdir -p /tmp/e5/ev/cycles
cd "$QAD" && env DISK="$QAD/disk/e5-firstboot.qcow2" ISO="$IMG/LiberNT.iso" EVID=/tmp/e5/ev/cycles ICOUNT=1 HEARTBEAT=0 \
    bash tools/ac3-cycles.sh 22 > /tmp/e5/cycles.out 2>&1
echo "ac3-cycles.sh rc=$?"
date '+end %T'
cat /tmp/e5/ev/cycles/summary.txt 2>/dev/null
