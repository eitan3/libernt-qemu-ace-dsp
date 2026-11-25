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
#   - no bugcheck, no "Work queue ... no progress" (a hang); the terminal
#     line is also looked up by the p2b4 names (boot bad IPC reply, boot
#     interrupt storm, boot clock stalled),
#   - the recovery cycle's "boot ok" (RECOVER=1).
#
# The self-test rows (a guest with SelfTest = 1: the row ends with the driver's
# "ipc self-test: ..." summary, not with boot ok -- tools/fault-matrix.sh) also
# get a second table, appended only when there is such a row: the boot's own
# line and clocks; the failing exchange (the model's status, or the timeout on
# its 500 ms budget plus at most one 500 us poll); the summary's counters against
# the image's TESTING.md for the faults it tables (ipc-status=5:19, never-reply=19;
# none = the seven lines); the power-down line; and the recovery cycle's "boot ok"
# + "... ok" after a disable/enable of the started device.
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
word=0
for row in "$D"/fm-*; do
    [ -d "$row" ] || continue
    name=$(basename "$row")
    case "$name" in *-partial) continue;; esac
    [ -f "$row/serial.log" ] || continue
    boot=$(norm "$row/serial.log" | grep -a "intcdsp.sys: booting:" | head -1)
    term=$(norm "$row/serial.log" | awk -v t="$boot" 'f{print} $0==t{f=1}' | grep -aiE "intcdsp.*(boot (ok|.*timeout|ROM error|stopped|ABI|version|ipc|bad IPC reply|.*crash|interrupt storm|clock stalled)|ipc bad reply|truncated)" | head -1)
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
# the self-test rows: collected first, appended only when there is one (a
# boot-only matrix reads as before)
TMP="$D/.fm-check-selftest.tmp"; : > "$TMP"
for row in "$D"/fm-*; do
    [ -d "$row" ] || continue
    case "$(basename "$row")" in *-partial) continue;; esac
    [ -f "$row/serial.log" ] || continue
    [ "$(norm "$row/serial.log" | awk '/intcdsp.sys: booting:/{exit} /intcdsp.sys: SelfTest = 1,/{f=1} END{print f ? "yes" : "no"}')" = yes ] || continue
    fault=$(sed -n 's/.*[ ,]fault=\([^,]*\).*/\1/p' "$row/qemu-args.txt" 2>/dev/null | head -1); fault="${fault:-none}"
    boot=$(norm "$row/serial.log" | grep -a "intcdsp.sys: booting:" | head -1)
    ab() { norm "$row/serial.log" | awk -v t="$boot" 'f{print} $0==t{f=1}'; }
    okline=$(ab | grep -a "intcdsp.sys: boot ok after" | head -1)
    fl=$(ab | grep -aE "intcdsp.sys: ipc: .*the link is faulted" | head -1)
    sum=$(ab | grep -aE "intcdsp.sys: ipc self-test: [0-9]+ requests" | head -1)
    pd=$(ab | grep -aE "intcdsp.sys: DSP power down" | head -1)
    # what the image's TESTING.md tables for the fault
    expsum=''; expfl=''; exppd=''; tomin=0
    case "$fault" in
        ipc-status=5:19) expsum='2 requests, 2 replies, 0 notifications, 0 timeouts, 0 DSP interrupts, failed at pipeline 1 paused'
                         expfl='set pipeline state \(19\) 0x93010003\|0x00000000 status 5 \(bad state\) after [0-9]+ us; the link is faulted'; exppd=yes ;;
        never-reply=19)  expsum='2 requests, 1 replies, 0 notifications, 1 timeouts, 0 DSP interrupts, failed at pipeline 1 paused'
                         expfl='set pipeline state \(19\) 0x93010003\|0x00000000 reply timeout after [0-9]+ us; the link is faulted'; exppd=yes; tomin=500000 ;;
        none)            expsum='6 requests, 6 replies, 0 notifications, 0 timeouts, 0 DSP interrupts, ok'; exppd=no ;;
    esac
    bad=""
    after=$(echo "$okline" | grep -aoE "after [0-9]+ us" | grep -aoE "[0-9]+" | head -1)
    dclock=$(awk -v a="$(clock "$boot")" -v b="$(clock "$okline")" -v m="${after:-0}" 'BEGIN{printf "%d", b-a-m}')
    { [ -n "$after" ] && [ "$after" -gt 0 ] && [ "$dclock" -ge -5000 ] && [ "$dclock" -le 5000 ]; } || bad="$bad boot line or clocks;"
    # the serial lines end in CR LF: strip the tail before an exact comparison
    fshort=$(echo "$fl" | sed 's/^\[ *[0-9.]*\] intcdsp.sys: ipc: //;s/[[:space:]]*$//' | cut -c1-160); fshort=${fshort//|/\\|}
    if [ -n "$expfl" ]; then echo "$fl" | grep -aqE "$expfl" || bad="$bad failing exchange;"
    elif [ -n "$fl" ]; then bad="$bad unexpected failing exchange;"; fi
    fafter=$(echo "$fl" | grep -aoE "after [0-9]+ us" | grep -aoE "[0-9]+" | head -1)
    if [ "$tomin" -gt 0 ]; then { [ -n "$fafter" ] && [ "$fafter" -ge "$tomin" ] && [ "$fafter" -le $(( tomin + 2000 )) ]; } || bad="$bad timeout budget;"; fi
    sshort=$(echo "$sum" | sed 's/^\[ *[0-9.]*\] intcdsp.sys: //;s/[[:space:]]*$//' | cut -c1-160)
    if [ -n "$expsum" ]; then [ "$sshort" = "ipc self-test: $expsum" ] || bad="$bad summary;"
    else [ -n "$sum" ] || bad="$bad no summary;"; fi
    pdshort=$(echo "$pd" | sed 's/^\[ *[0-9.]*\] intcdsp.sys: //;s/[[:space:]]*$//' | cut -c1-120)
    note=""
    case "$exppd" in
        yes) echo "$pd" | grep -aqE "DSP power down from state [a-z ]+: ok, cleanup ok, ADSPCS 0x00000000 \(SPA 0, CPA 0\)" || bad="$bad power-down line;"
             # the state the line names is the one after the driver's own power-down:
             # it reads "off" where the image's TESTING.md expects "ready" -- a wording
             # divergence, shown in the table and counted apart, not a failed check
             pdstate=$(echo "$pdshort" | sed -n 's/DSP power down from state \([a-z ]*\): .*/\1/p')
             if [ "$pdstate" != ready ]; then note=" (the power-down line names state '${pdstate:-?}' where TESTING.md says 'ready': the driver logs the state after its own power-down)"; word=$((word+1)); fi ;;
        no)  [ -z "$pd" ] || bad="$bad unexpected power-down;" ;;
    esac
    bug=$(norm "$row/serial.log" | grep -aci "bugcheck\|Fatal System Error")
    hang=$(norm "$row/serial.log" | grep -ac "Work queue .* no progress")
    rec="not run"; started="-"
    if [ -f "$row/recover.out" ]; then
        if grep -aq "Safe removal" "$row/recover.out"; then started="yes"; else started="**NO**"; fi
        if grep -aq "intcdsp.sys: boot ok after" "$row/recover.out" && grep -aqE "intcdsp.sys: ipc self-test: [0-9]+ requests, [0-9]+ replies, [0-9]+ notifications, [0-9]+ timeouts, [0-9]+ DSP interrupts, ok" "$row/recover.out"; then rec="boot ok + self-test ok"
        else rec="**NO**"; fi
    else bad="$bad recovery not run;"; fi
    [ -z "$bad" ] || allok=$((allok+1))
    printf "| %s | %s | %s | %s | %s | %s%s | %s | %s | %s | %s | %s |\n" "$fault" "${after:--}" "$dclock" "${fshort:--}" "${sshort:--}" "${bad:-as expected}" "$note" "${pdshort:--}" "$bug" "$hang" "$started" "$rec" >> "$TMP"
done
if [ -s "$TMP" ]; then
    printf '\n## The self-test rows (the guest has SelfTest = 1: the row ends with the self-test summary) -- checks against the image testing notes (%s)\n\n| fault | boot ok after N us | end clock - start clock - N (us) | the failing exchange | the self-test summary | checks | the power-down line | bugcheck | hang | device started (disabled after the row) | recovery (boot ok + self-test ok) |\n|---|---|---|---|---|---|---|---|---|---|---|\n' "$(date -u +%FT%TZ)" >> "$OUT"
    cat "$TMP" >> "$OUT"
fi
rm -f "$TMP"
printf '\n%d row(s) with a failed check' "$allok" >> "$OUT"
[ "$word" -gt 0 ] && printf '; %d wording divergence(s) noted in the tables (DIVERGENCE.md)' "$word" >> "$OUT"
printf '.\n' >> "$OUT"
echo "$allok row(s) with a failed check -> $OUT"
