#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# qemu-ace-dsp: fm-check.sh -- read the collected rows of a fault-matrix run
# (tools/fault-matrix.sh with COLLECT=<dir>) and append to <dir>/fault-matrix.md
# the checks AC4 asks beyond "bounded": the terminal line's own elapsed time
# ("after N us") is non-zero and consistent with the duration the serial log
# shows between the driver's "booting:" line and the terminal line (N/1e6 <=
# observed + 2 ms, and observed - N/1e6 <= 0.5 s), no bugcheck, no "Work
# queue ... no progress" (hang), and the recovery cycle's "boot ok".
#
#   tools/fm-check.sh <collected evidence dir>
# This work is licensed under the terms of the GNU GPL, version 2 or later.
# See the COPYING file in the top-level directory.
set -u
D="${1:?usage: fm-check.sh <collected evidence dir>}"
D="$(cd "$D" && pwd)"
OUT="$D/fault-matrix.md"
norm() { sed "s/\x1b\[[0-9;]*[A-Za-z]//g" "$1" 2>/dev/null | tr -d "\0"; }
ts() { echo "$1" | grep -oE "^\[ *[0-9.]+\]" | tr -d "[] " | tr -d _; }
printf '\n## Checks beyond "bounded" (%s)\n\n| row | after N us | serial booting -> line (s) | observed - N (ms) | elapsed ok | bugcheck | hang | recovery |\n|---|---|---|---|---|---|---|---|\n' "$(date -u +%FT%TZ)" >> "$OUT"
allok=0
for row in "$D"/fm-*; do
    [ -f "$row/serial.log" ] || continue
    name=$(basename "$row")
    boot=$(norm "$row/serial.log" | grep -a "intcdsp.sys: booting:" | head -1)
    term=$(norm "$row/serial.log" | awk -v t="$boot" 'f{print} $0==t{f=1}' | grep -aiE "intcdsp.*(boot (ok|.*timeout|ROM error|stopped|ABI|version|ipc|.*crash)|ipc bad reply|truncated)" | head -1)
    after=$(echo "$term" | grep -aoE "after [0-9]+ us" | grep -aoE "[0-9]+" | head -1)
    obs=$(awk -v a="$(ts "$boot")" -v b="$(ts "$term")" 'BEGIN{printf "%.3f", b-a}')
    if [ -z "$term" ]; then
        printf "| %s | - | - | - | **no terminal line** | - | - | - |\n" "$name" >> "$OUT"; allok=$((allok+1)); continue
    fi
    read -r delta ok < <(awk -v n="${after:-0}" -v o="$obs" 'BEGIN{d=(o-n/1e6)*1000; printf "%.1f %s", d, (n>0 && d>=-2 && d<=500) ? "yes" : "NO"}')
    [ "$ok" = yes ] || allok=$((allok+1))
    bug=$(norm "$row/serial.log" | grep -aci "bugcheck\|Fatal System Error")
    hang=$(norm "$row/serial.log" | grep -ac "Work queue .* no progress")
    rec="-"
    if [ -f "$row/recover.out" ]; then
        if grep -aq "intcdsp.sys: boot ok after" "$row/recover.out"; then rec="boot ok"; else rec="**NO**"; allok=$((allok+1)); fi
    fi
    printf "| %s | %s | %s | %s | %s | %s | %s | %s |\n" "$name" "${after:--}" "$obs" "$delta" "$ok" "$bug" "$hang" "$rec" >> "$OUT"
done
printf '\n%d row(s) with a failed check.\n' "$allok" >> "$OUT"
echo "$allok row(s) with a failed check -> $OUT"
