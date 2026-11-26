#!/bin/bash
# stats.sh -- the per-VM figures and the round's totals of the p4c4b2 round, read from the
# evidence tree (vm/<run>/start.txt, end.txt, lib-run.out, serial.txt, qemu-dbg.log.gz).
set -u
QAD=<project>
cd "$QAD/evidence/2026-11-26-p4c4b2/vm" || exit 2
RUNS="r0b-firstboot-nodisk r1-firstboot-cycle-dsploop-selftest2 r5-firstboot-cycle-selftest2-dsploop-live r2-plainboot-selftest0 r3-plainboot-attribution r4-freshboot-notopology"
echo "--- per VM: run | start | end | wall | guest boots (LiberNT kernel banner) | ace_* lines | ace_unexpected"
total=0
for r in $RUNS; do
    w=$(grep -a -o 'wall [0-9]* s' "$r/lib-run.out" | tr -dc '0-9')
    total=$((total + w))
    a=$(zcat "$r/qemu-dbg.log.gz" | grep -ac '^ace_')
    u=$(zcat "$r/qemu-dbg.log.gz" | grep -ac 'ace_unexpected')
    echo "$r | $(cat "$r/start.txt") | $(cat "$r/end.txt") | $w s | settings lines $(grep -ac 'intcdsp.sys: SelfTest = ' "$r/serial.txt") | $a | $u"
done
echo "total wall: $total s = $(awk -v t="$total" 'BEGIN{printf "%.1f", t/60}') minutes"
echo "--- the first boots (guest timestamps): swenum, the ROOT removal, swenum again, the Setup phase"
for r in r0b-firstboot-nodisk r1-firstboot-cycle-dsploop-selftest2 r5-firstboot-cycle-selftest2-dsploop-live r4-freshboot-notopology; do
    echo "$r:"
    grep -a 'KsCreateBusEnumObject\|Safe removal: ROOT\|Storage expansion not offered' "$r/serial.txt" | cut -c1-120 | sed 's/^/   /'
done
echo "--- totals: settings lines $(cat */serial.txt | grep -ac 'intcdsp.sys: SelfTest = '); BootDsp = 0 starts $(cat */serial.txt | grep -ac 'BootDsp = 0: probe only'); boot ok $(cat */serial.txt | grep -ac 'boot ok after') with '0 DSP interrupts' $(cat */serial.txt | grep -a 'boot ok after' | grep -ac '0 DSP interrupts'); stopped $(cat */serial.log | grep -ac 'The system has been stopped'); stop code $(cat */serial.log | grep -ac 'Stop code'); clock stalled $(cat */serial.txt | grep -ac 'clock stalled'); interrupt storm $(cat */serial.txt | grep -ac 'interrupt storm'); S5 $(cat */serial.txt | grep -ac 'Entering sleep state S5')"
echo "--- the update agent's line: $(cat */serial.txt | grep -ac 'updagent.c') (VMs: $(grep -alc 'updagent.c' */serial.txt | tr '\n' ' '))"
echo "--- ace_unexpected: $(for f in */qemu-dbg.log.gz; do zcat "$f" | grep -ac ace_unexpected; done | awk '{s+=$1} END{print s+0}'); ace_audio lines: $(for f in */qemu-dbg.log.gz; do zcat "$f" | grep -ac '^ace_audio'; done | awk '{s+=$1} END{print s+0}')"
