#!/bin/bash
# E5 block 4: the E1/E2 rows (tools/e2-round.sh) on the flow overlay (its later boot): DspIdleSec = 3 by the registry and
# a reboot (10 dsploop runs: a boot at each first open, an idle power-down after each), E1's two fault rows with a stream
# open (never-reply=19, crash-async=500) each followed by a run that must pass, then CYCLES cycles (0 here: the 22 cycles
# with BootAtStart = 1 are the matrix overlay's run).  A fresh copy of the flow pouch (the alive check counts files).
set -u
QAD=<project>
ps -eo comm | grep -qi "qemu-system" && { echo "!! a QEMU is already running"; exit 3; }
cp /tmp/e5/pouch/flow.img /tmp/e5/pouch/e2.img
for f in $(mdir -i /tmp/e5/pouch/e2.img@@32256 ::/ 2>/dev/null | awk 'NR>3 && $1!="" {print $1}' | tr 'a-z' 'A-Z' | grep -E "\.TXT$"); do mdel -i /tmp/e5/pouch/e2.img@@32256 "::$f" >/dev/null 2>&1; done
mdir -i /tmp/e5/pouch/e2.img@@32256 ::/ | grep -c "txt" ; echo "(txt files left on the e2 pouch)"
date '+start %T'
RUN=e2 OVERLAY=e5-flow POUCH=/tmp/e5/pouch/e2.img RUNS=10 CYCLES=0 IDLESEC=3 bash /tmp/e5/tools/e2-round.sh > /tmp/e5/e2.out 2>&1
echo "e2-round.sh rc=$?"
date '+end %T'
grep -a -E "##|!!|done|VM " /tmp/e5/e2.out | cut -c1-300 | tail -40
