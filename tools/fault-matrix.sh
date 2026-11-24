#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# qemu-ace-dsp: fault-matrix.sh -- AC4 in the VM, unattended: one boot per fault
# on the stage-2 overlay (BootDsp=1 already set in the guest), the driver's
# outcome timed from its "booting:" line, bounded/unbounded by rule, the VM
# stopped; a markdown table of the rows in <evidence root>/fault-matrix.md.
#
#   tools/fault-matrix.sh [FAULT=<fault>]... [--scale=N]... [--root=<dir>]
# env: DISK (the overlay), ISO (the image's ISO; lib-run.sh wants it even with
#      CDROM=none), EVROOT (the evidence root; a tmpfs path keeps the trace
#      traffic off a slow disk), WINDOW (guest seconds after "booting:" without
#      a terminal driver line = unbounded, default 30)
#
# bounded := the driver logs a terminal line (boot ok / timeout / ROM error /
#            stopped / ABI / version / ipc / crashed / ipc bad reply /
#            truncated / DSP power down, case-insensitive) within WINDOW
#            guest-seconds of its "booting:" line.
#
# This work is licensed under the terms of the GNU GPL, version 2 or later.
# See the COPYING file in the top-level directory.
set -u
QAD="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVROOT="${EVROOT:-/tmp/qad-fault-matrix}"
DISK="${DISK:-$QAD/disk/p2b2.qcow2}"
WINDOW="${WINDOW:-30}"
TERM='intcdsp.*(boot (ok|timeout|ROM error|stopped|ABI|version|ipc|.*crashed)|ipc bad reply|truncated|DSP power down)'
mkdir -p "$EVROOT"
SUMMARY="$EVROOT/fault-matrix.md"

norm() { sed "s/\x1b\[[0-9;]*[A-Za-z]//g" "$1" 2>/dev/null | tr -d "\0"; }
gtime() { echo "$1" | grep -oE "^\[ *[0-9.]+\]" | tr -d "[] "; }
wall() { date +%s; }
# the serial log from the driver's "booting:" line on
after_booting() { norm "$1" | awk -v t="$(norm "$1" | grep -a 'intcdsp.sys: booting:' | head -1)" 'f{print} $0==t{f=1}'; }

run_one() {
    local fault="$1" scale="${2:-}"
    local name="fm-$fault${scale:+-scale$scale}" EV="$EVROOT/$name"
    rm -rf "$EV"; mkdir -p "$EV"
    local args=()
    [ "$fault" != none ] && args+=("FAULT=$fault")
    [ -n "$scale" ] && args+=("ACE_ARGS=x-delay-scale=$scale")
    local w0; w0=$(wall)
    ( cd "$QAD" && env DISK="$DISK" CDROM=none TRACE=1 WAIT=900 SETTLE=2 EVID="$EV" \
        "${args[@]}" ./run.sh > "$EV/lib-run.out" 2>&1 ) &
    local lr=$!
    # the driver's "booting:" line (guest time t0); a boot may sit at the boot
    # manager for minutes on a host whose timer delivery stalls (see README)
    local t0="" wb=0
    for i in $(seq 1 1200); do
        if [ -f "$EV/serial.log" ] && norm "$EV/serial.log" | grep -aq "intcdsp.sys: booting:"; then
            t0=$(gtime "$(norm "$EV/serial.log" | grep -a "intcdsp.sys: booting:" | head -1)")
            wb=$(wall); break
        fi
        kill -0 $lr 2>/dev/null || break
        [ $(( $(wall) - w0 )) -gt 120 ] && break
        sleep 0.5
    done
    if [ -z "$t0" ]; then
        printf "| %s | (no booting line within 120 s: the boot sat at the boot manager -- a host stall, retried) | - | not reached |\n" \
            "${fault}${scale:+ scale=$scale}" | tee -a "$SUMMARY"
        ( cd "$QAD" && tools/guest.sh "$EV" stop >/dev/null 2>&1 ); wait $lr 2>/dev/null; return
    fi
    local term="" gdt=""
    for i in $(seq 1 $(( WINDOW * 4 + 40 ))); do
        term=$(after_booting "$EV/serial.log" | grep -aiE "$TERM" | grep -aiv "DSP power down" | head -1)
        [ -z "$term" ] && term=$(after_booting "$EV/serial.log" | grep -aiE "intcdsp.*DSP power down" | head -1)
        if [ -n "$term" ]; then
            gdt=$(awk -v a="$t0" -v b="$(gtime "$term")" 'BEGIN{printf "%.3f", b-a}')
            break
        fi
        [ $(( $(wall) - wb )) -gt $(( WINDOW * 3 + 90 )) ] && break
        sleep 0.5
    done
    sleep 3
    local reads off txt verdict
    reads=$(grep -ac "ace_reg_read" "$EV/qemu-dbg.log" 2>/dev/null)
    off=$(grep -ac -- "-> off" "$EV/qemu-dbg.log" 2>/dev/null)
    if [ -z "$term" ]; then
        verdict="**unbounded**"; txt="none: $reads register polls, no line, no power-down"
    else
        txt=$(echo "$term" | sed 's/^\[ *[0-9.]*\] intcdsp.sys: //' | cut -c1-200)
        if awk -v d="$gdt" -v w="$WINDOW" 'BEGIN{exit !(d <= w)}'; then verdict="bounded"; else verdict="**late**"; fi
    fi
    printf "| %s | %s | %s | %s (power-downs in the trace: %s; wall %ss) |\n" \
        "${fault}${scale:+ scale=$scale}" "$txt" "${gdt:--}" "$verdict" "$off" "$(( $(wall) - w0 ))" | tee -a "$SUMMARY"
    ( cd "$QAD" && tools/guest.sh "$EV" shot desktop >/dev/null 2>&1 )
    ( cd "$QAD" && tools/guest.sh "$EV" stop >/dev/null 2>&1 )
    wait $lr 2>/dev/null
}

faults=()
while [ $# -gt 0 ]; do
    case "$1" in
        FAULT=*) faults+=("${1#FAULT=}") ;;
        --scale=*) faults+=("scale:${1#--scale=}") ;;
        --root=*) EVROOT="${1#--root=}"; mkdir -p "$EVROOT"; SUMMARY="$EVROOT/fault-matrix.md" ;;
        *) faults+=("$1") ;;
    esac
    shift
done
[ ${#faults[@]} -eq 0 ] && faults=(halt-rom=43 halt-rom=44 halt-fw=51 crash-notification abi=2 window-read-fail never-power never-ack never-ready never-enter never-fwready never-reply drop-requests ipc-status=5 bad-tuples truncated-reply version-shift scale:1550 scale:0.001)
if [ ! -f "$SUMMARY" ]; then
    printf "# AC4 fault matrix -- %s -- overlay %s\n\n| fault | the driver's terminal line (after its booting line) | booting -> line (guest s) | verdict |\n|---|---|---|---|\n" \
        "$(date -u +%FT%TZ)" "$DISK" > "$SUMMARY"
fi
for f in "${faults[@]}"; do
    # a boot may sit at the boot manager for minutes on a host whose timer
    # delivery stalls (see README): such a row is retried up to three times
    for attempt in 1 2 3; do
        case "$f" in
            scale:*) run_one none "${f#scale:}" ;;
            *) run_one "$f" ;;
        esac
        tail -1 "$SUMMARY" | grep -q "retried" || break
    done
done
