#!/bin/bash
# dspdiff.sh <old txt> <new txt> -- the driver lines (`intcdsp.sys:`, `dsppcm.sys:`, `hdaudbus.sys:`)
# of two boot logs without their timestamps and model figures, as a diff; then the new ones whole.
set -u
o="${1:?old}"; n="${2:?new}"
pick() { tr -d '\r' < "$1" | grep -a -E 'intcdsp\.sys:|dsppcm\.sys:|hdaudbus\.sys:' | sed -E 's/^\[ *[0-9.]+\] //'; }
norm() { sed -E 's/[0-9]+/N/g'; }
echo "--- old driver lines: $(pick "$o" | wc -l), new: $(pick "$n" | wc -l); differ (digits folded):"
diff <(pick "$o" | norm) <(pick "$n" | norm) | grep -a -E '^[<>]' | cut -c1-200
echo "--- new driver lines, whole:"
pick "$n" | cut -c1-330 | nl -ba
