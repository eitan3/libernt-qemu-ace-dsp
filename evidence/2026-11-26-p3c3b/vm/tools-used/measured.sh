#!/bin/bash
# measured.sh -- evidence/2026-11-26-p3c3b/vm/measured-lines.txt: the driver's lines of
# the round's VMs in one file (settings, boot ok, topology, self-test, power-down, S5;
# ANSI escapes, NULs and the CR of the serial lines removed; long lines cut at 330).
set -u
QAD=<project>
EV=$QAD/evidence/2026-11-26-p3c3b/vm
out=$EV/measured-lines.txt
{
    echo "# The driver's lines of the four VMs of the p3c3b round (UTC; serial lines quoted without their CR LF)."
    for r in r1-firstboot-set-live r2-plainboot-live-then-selftest0 r3-plainboot-selftest0-then-live \
             r4-plainboot-regression-and-live; do
        d=$EV/$r
        echo
        echo "=== $r: $(cat "$d/start.txt") .. $(cat "$d/end.txt"); $(grep -a 'qemu exited' "$d/lib-run.out")"
        sed 's/\x1b\[[0-9;]*[A-Za-z]//g' "$d/serial.log" | tr -d "\0\r" \
            | grep -aE "intcdsp\.sys: (SelfTest|BootDsp = |boot ok|topology|loopback self-test|DSP power down)|Safe removal|Entering sleep state|clock stalled|interrupt storm|Work queue|Fatal|bugcheck" \
            | cut -c1-330
    done
} > "$out"
wc -l "$out"
