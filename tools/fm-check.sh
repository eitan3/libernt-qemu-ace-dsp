#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# qemu-ace-dsp: fm-check.sh -- read the collected rows of a fault-matrix run
# (tools/fault-matrix.sh with COLLECT=<dir>) and append to <dir>/fault-matrix.md
# the checks AC4 asks beyond "bounded", per row:
#   - the terminal line's own elapsed time ("after N us") is non-zero;
#   - the driver's two clock readings agree with it: "clock N us" in its
#     "booting:" line and "clock N' us" in the terminal line, N' - N - M within
#     +-5 ms (a stamp-free check of the D2 fix; the end clock is read when the
#     line is formatted, after the failed attempt's own power-down);
#   - the duration the serial log shows between the two lines (its print
#     timestamps carry up to one kernel clock tick of staleness, +-16 ms) is
#     consistent with M: observed - M/1e6 in [-20 ms, 500 ms];
#   - no bugcheck, no "Work queue ... no progress" (a hang);
#   - the recovery cycle's "boot ok" (RECOVER=1).
#
#   tools/fm-check.sh <collected evidence dir>
# Directories named fm-*-partial (a row stopped in flight) are skipped.
# This work is licensed under the terms of the GNU GPL, version 2 or later.
# See the COPYING file in the top-level directory.
set -u
D="${1:?usage: fm-check.sh <collected evidence dir>}"
D="$(cd "$D" && pwd)"
OUT="$D/fault-matrix.md"
norm() { sed "s/\x1b\[[0-9;]*[A-Za-z]//g" "$1" 2>/dev/null | tr -d "\0"; }
ts() { echo "$1" | grep -oE "^\[ *[0-9.]+\]" | tr -d "[] " | tr -d _; }
clock() { echo "$1" | grep -aoE "clock [0-9]+ us" | grep -aoE "[0-9]+" | head -1; }
printf '\n## Checks beyond "bounded" (%s)\n\n| row | the driver'"'"'s terminal line | after N us | N'"'"' - N - M (us) | serial booting -> line (s) | observed - N (ms) | elapsed ok | bugcheck | hang | recovery |\n|---|---|---|---|---|---|---|---|---|---|\n' "$(date -u +%FT%TZ)" >> "$OUT"
allok=0
for row in "$D"/fm-*; do
    [ -d "$row" ] || continue
    name=$(basename "$row")
    case "$name" in *-partial) continue;; esac
    [ -f "$row/serial.log" ] || continue
    boot=$(norm "$row/serial.log" | grep -a "intcdsp.sys: booting:" | head -1)
    term=$(norm "$row/serial.log" | awk -v t="$boot" 'f{print} $0==t{f=1}' | grep -aiE "intcdsp.*(boot (ok|.*timeout|ROM error|stopped|ABI|version|ipc|.*crash)|ipc bad reply|truncated)" | head -1)
    short=$(echo "$term" | sed 's/^\[ *[0-9.]*\] intcdsp.sys: //' | cut -c1-150 | tr '|' '/')
    if [ -z "$term" ]; then
        printf "| %s | **no terminal line** | - | - | - | - | **NO** | - | - | - |\n" "$name" >> "$OUT"; allok=$((allok+1)); continue
    fi
    after=$(echo "$term" | grep -aoE "after [0-9]+ us" | grep -aoE "[0-9]+" | head -1)
    cs=$(clock "$boot"); ce=$(clock "$term")
    dclock=$(awk -v a="${cs:-0}" -v b="${ce:-0}" -v m="${after:-0}" 'BEGIN{printf "%d", b-a-m}')
    obs=$(awk -v a="$(ts "$boot")" -v b="$(ts "$term")" 'BEGIN{printf "%.3f", b-a}')
    read -r delta ok < <(awk -v n="${after:-0}" -v o="$obs" -v d="$dclock" 'BEGIN{x=(o-n/1e6)*1000; printf "%.1f %s", x, (n>0 && d>=-5000 && d<=5000 && x>=-20 && x<=500) ? "yes" : "NO"}')
    [ "$ok" = yes ] || allok=$((allok+1))
    bug=$(norm "$row/serial.log" | grep -aci "bugcheck\|Fatal System Error")
    hang=$(norm "$row/serial.log" | grep -ac "Work queue .* no progress")
    rec="-"
    if [ -f "$row/recover.out" ]; then
        if grep -aq "intcdsp.sys: boot ok after" "$row/recover.out"; then rec="boot ok"; else rec="**NO**"; allok=$((allok+1)); fi
    else
        rec="not run"; allok=$((allok+1))
    fi
    printf "| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |\n" "$name" "$short" "${after:--}" "$dclock" "$obs" "$delta" "$ok" "$bug" "$hang" "$rec" >> "$OUT"
done
printf '\n%d row(s) with a failed check.\n' "$allok" >> "$OUT"
echo "$allok row(s) with a failed check -> $OUT"
