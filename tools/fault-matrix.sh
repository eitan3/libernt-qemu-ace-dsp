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
#      traffic off a slow disk: a log write that blocks holds the BQL and
#      stops the main loop -- and with it the model's timers), WINDOW (guest
#      seconds after "booting:" without a terminal driver line = unbounded,
#      default 30), TIMEOUT (cap on the wait for the line, default 60 s of
#      wall time per guest second, at least 3*WINDOW+90)
#      HEARTBEAT=1  open the qtest socket (QTESTSOCK=1) and run tools/heartbeat.py
#                   from the "booting:" line until the terminal line (PERIOD us,
#                   default 1000): keeps the main loop running its timers on a
#                   host whose timers stall under a spinning TCG guest (README,
#                   "A note on the host"); not needed with ICOUNT=1
#      ICOUNT=1    lib-run.sh runs the VM under -icount shift=auto,align=off,
#                   sleep=off (single-threaded TCG): guest clock and model timers
#                   advance together (README, "A note on the host")
#      RECOVER=1   after the terminal line: wait for the shell, open a console,
#                   clear the fault (set-fault.sh none, x-delay-scale 1) and run
#                   one disable/enable cycle (tools/cycle.sh); the row records
#                   whether a later power cycle recovers ("recovered: boot ok")
#      COLLECT=<dir>  copy each row's evidence there as it finishes (serial log,
#                   command, screenshot, the trace from the booting line as an
#                   excerpt + the whole trace gzipped)
#
# Self-test rows: on an overlay whose guest has SelfTest = 1 (persisted in its
# registry; set in the guest, see the README), a boot that ends "boot ok" goes on
# to the driver's IPC self-test. Such a row is recognised by the driver's settings
# line before its "booting:" line (SelfTest = 1); its terminal line is then the
# self-test's summary ("ipc self-test: N requests, ... ok" or "... failed at <step>"),
# which has the rest of WINDOW to show up like any terminal line (a self-test that
# prints no summary is unbounded, whatever its boot ok said). The row quotes the
# boot's own "boot ok" line and the failing exchange ("ipc: ... the link is
# faulted", whose "after N us" is the row's own elapsed) after the summary, and the
# model's registers read over qtest once the row is over. The recovery cycle then
# needs "boot ok" and the summary's "ok". A ':' of a typed fault (ipc-status=<n>:<type>)
# becomes '_' in the row's directory name (a portable path); the table keeps the value.
#
# bounded := the driver logs a terminal line (boot ok / boot <step> timeout /
#            ROM error / stopped / ABI / version / ipc / bad IPC reply / ... crash /
#            interrupt storm / clock stalled / ipc bad reply / truncated / DSP power
#            down, case-insensitive) within WINDOW guest-seconds of its "booting:"
#            line. (bad IPC reply is p2b4's D3 line; without it the row fell back
#            to the DSP power down line and fm-check.sh saw no terminal line.)
#
# This work is licensed under the terms of the GNU GPL, version 2 or later.
# See the COPYING file in the top-level directory.
set -u
QAD="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVROOT="${EVROOT:-/tmp/qad-fault-matrix}"
DISK="${DISK:-$QAD/disk/p2b2.qcow2}"
WINDOW="${WINDOW:-30}"
TERM='intcdsp.*(boot (ok|.*timeout|ROM error|stopped|ABI|version|ipc|bad IPC reply|.*crash|interrupt storm|clock stalled)|ipc bad reply|truncated|DSP power down)'
TERM_ST='intcdsp.*(ipc self-test: [0-9]+ requests, [0-9]+ replies, [0-9]+ notifications, [0-9]+ timeouts, [0-9]+ DSP interrupts, (ok|failed at .+)|loopback self-test: [0-9]+ runs, [0-9]+ matched, [0-9]+ failed, .*, (ok|failed))'
TERM_ST_OK='intcdsp.*(ipc self-test: [0-9]+ requests, [0-9]+ replies, [0-9]+ notifications, [0-9]+ timeouts, [0-9]+ DSP interrupts, ok|loopback self-test: [0-9]+ runs, [0-9]+ matched, 0 failed, .*, ok)'
mkdir -p "$EVROOT"
SUMMARY="$EVROOT/fault-matrix.md"

norm() { sed "s/\x1b\[[0-9;]*[A-Za-z]//g" "$1" 2>/dev/null | tr -d "\0"; }
gtime() { echo "$1" | grep -oE "^\[ *[0-9.]+\]" | tr -d "[] "; }
wall() { date +%s; }
# the serial log from the driver's "booting:" line on
after_booting() { norm "$1" | awk -v t="$(norm "$1" | grep -a 'intcdsp.sys: booting:' | head -1)" 'f{print} $0==t{f=1}'; }
# a self-test row: the driver's settings line before its "booting:" line says so (SelfTest = 1, the IPC self-test; 2 or 3, the loopback one)
st_row() { norm "$1" | awk '/intcdsp.sys: booting:/{exit} /intcdsp.sys: SelfTest = [123],/{f=1} END{print f ? "yes" : "no"}'; }
q() { "$@" >/dev/null 2>&1; }

collect() {
    local EV="$1" DST="$2"
    mkdir -p "$DST"
    cp -f "$EV"/serial.log "$EV"/command.txt "$EV"/qemu-args.txt "$EV"/start.txt "$EV"/end.txt \
          "$EV"/qemu.log "$EV"/lib-run.out "$DST"/ 2>/dev/null
    [ -f "$EV/desktop.png" ] && cp -f "$EV/desktop.png" "$DST"/
    [ -f "$EV/console.png" ] && cp -f "$EV/console.png" "$DST"/
    [ -f "$EV/heartbeat.log" ] && cp -f "$EV/heartbeat.log" "$DST"/
    [ -f "$EV/recover.out" ] && cp -f "$EV/recover.out" "$DST"/
    if [ -f "$EV/qemu-dbg.log" ]; then
        awk '/ace_state state subsystem-reset|ace_reg_write BAR4 \+0x1000 <- 0x00010000/{f=1} f' "$EV/qemu-dbg.log" > "$DST/qemu-dbg.excerpt.txt"
        gzip -c "$EV/qemu-dbg.log" > "$DST/qemu-dbg.log.gz"
    fi
}

run_one() {
    local fault="$1" scale="${2:-}"
    local name="fm-$fault${scale:+-scale$scale}"
    name="${name//:/_}"
    local EV="$EVROOT/$name"
    rm -rf "$EV"; mkdir -p "$EV"
    local args=()
    [ "$fault" != none ] && args+=("FAULT=$fault")
    [ -n "$scale" ] && args+=("ACE_ARGS=x-delay-scale=$scale")
    [ "${HEARTBEAT:-0}" = 1 ] && args+=("QTESTSOCK=1")
    # the recovery cycle reads the model's registers over qtest (tools/cycle.sh)
    [ "${RECOVER:-0}" = 1 ] && args+=("QTESTSOCK=1")
    [ "${ICOUNT:-0}" = 1 ] && args+=("ICOUNT=1")
    local w0; w0=$(wall)
    ( cd "$QAD" && env DISK="$DISK" CDROM=none TRACE=1 WAIT=$(( WINDOW * 8 + 600 )) SETTLE=2 EVID="$EV" \
        "${args[@]}" ./run.sh > "$EV/lib-run.out" 2>&1 ) &
    local lr=$!
    # the driver's "booting:" line (guest time t0); a boot may sit at the boot
    # manager for minutes on a host whose timer delivery stalls (see README)
    local t0="" wb=0 SOCK=""
    for i in $(seq 1 1200); do
        if [ -f "$EV/serial.log" ] && norm "$EV/serial.log" | grep -aq "intcdsp.sys: booting:"; then
            t0=$(gtime "$(norm "$EV/serial.log" | grep -a "intcdsp.sys: booting:" | head -1)")
            wb=$(wall); break
        fi
        kill -0 $lr 2>/dev/null || break
        [ $(( $(wall) - w0 )) -gt 600 ] && break
        sleep 0.5
    done
    SOCK=$(cat "$EV/sock-dir.txt" 2>/dev/null)
    if [ -z "$t0" ]; then
        printf "| %s | (no booting line within the cap: the boot sat at the boot manager -- a host stall, retried) | - | - | not reached | - |\n" \
            "${fault}${scale:+ scale=$scale}" | tee -a "$SUMMARY"
        ( cd "$QAD" && q tools/guest.sh "$EV" stop ); wait $lr 2>/dev/null; return
    fi
    local strow; strow=$(st_row "$EV/serial.log")
    if [ "${HEARTBEAT:-0}" = 1 ] && [ -S "$SOCK/qtest.sock" ]; then
        ( python3 "$QAD/tools/heartbeat.py" "$SOCK/qtest.sock" $(( WINDOW * 3 + 120 )) "${PERIOD:-1000}" > "$EV/heartbeat.log" 2>&1 & )
    fi
    local term="" gdt=""
    for i in $(seq 1 $(( WINDOW * 4 + 40 ))); do
        term=$(after_booting "$EV/serial.log" | grep -aiE "$TERM" | grep -aiv "DSP power down" | head -1)
        [ -z "$term" ] && term=$(after_booting "$EV/serial.log" | grep -aiE "intcdsp.*DSP power down" | head -1)
        if [ "$strow" = yes ] && [ -n "$term" ] && echo "$term" | grep -aq "boot ok"; then
            # SelfTest set: boot ok is not the end of the row -- the self-test's
            # summary is, or the row is unbounded
            term=$(after_booting "$EV/serial.log" | grep -aiE "$TERM_ST" | head -1)
        fi
        if [ -n "$term" ]; then
            gdt=$(awk -v a="$t0" -v b="$(gtime "$term")" 'BEGIN{printf "%.3f", b-a}')
            break
        fi
        [ $(( $(wall) - wb )) -gt $(( WINDOW * 3 + 90 )) ] && break
        sleep 0.5
    done
    sleep 3
    [ -n "$SOCK" ] && pkill -f "heartbeat.py $SOCK" 2>/dev/null
    local reads off txt verdict after bootline faultline model
    # the heartbeat's own reads (+0x1108) are not the driver's polls
    reads=$(( $(grep -ac "ace_reg_read" "$EV/qemu-dbg.log" 2>/dev/null) - $(grep -ac "ace_reg_read BAR4 +0x1108" "$EV/qemu-dbg.log" 2>/dev/null) ))
    off=$(grep -ac -- "-> off" "$EV/qemu-dbg.log" 2>/dev/null)
    after=$(echo "$term" | grep -aoE "after [0-9]+ us" | head -1)
    if [ -z "$term" ]; then
        verdict="**unbounded**"; txt="none: $reads register polls, no line, no power-down"
    else
        txt=$(echo "$term" | sed 's/^\[ *[0-9.]*\] intcdsp.sys: //' | cut -c1-200 | sed 's/|/\\|/g')
        if awk -v d="$gdt" -v w="$WINDOW" 'BEGIN{exit !(d <= w)}'; then verdict="bounded"; else verdict="**late**"; fi
    fi
    if [ "$strow" = yes ] && echo "$term" | grep -aqE "(ipc|loopback) self-test:"; then
        # the boot's own line and the failing exchange after the summary; the
        # summary has no elapsed of its own, the failing exchange's is the row's
        bootline=$(after_booting "$EV/serial.log" | grep -a "intcdsp.sys: boot ok" | head -1 | sed 's/^\[ *[0-9.]*\] intcdsp.sys: //;s/[[:space:]]*$//' | cut -c1-270 | sed 's/|/\\|/g')
        faultline=$(after_booting "$EV/serial.log" | grep -aE "intcdsp.sys: ipc: .*the link is faulted" | head -1 | sed 's/^\[ *[0-9.]*\] intcdsp.sys: //;s/[[:space:]]*$//' | cut -c1-200)
        model=$(python3 "$QAD/tools/qtest.py" "$SOCK/qtest.sock" adspcs hfipcxida fsr 2>/dev/null | awk '{printf "%s=%s ", $NF, substr($4, 11, 8)}')
        after=$(echo "$faultline" | grep -aoE "after [0-9]+ us" | head -1)
        [ -n "$bootline" ] && txt="$txt; boot: $bootline"
        [ -n "$faultline" ] && txt="$txt; $(echo "$faultline" | sed 's/|/\\|/g')"
        [ -n "$model" ] && txt="$txt; model after it: ${model% }"
    fi
    ( cd "$QAD" && q tools/guest.sh "$EV" shot desktop )
    local rec="-"
    if [ "${RECOVER:-0}" = 1 ]; then
        if ( cd "$QAD" && tools/waitline.sh "$EV" "Program Manager" 420 >/dev/null 2>&1 ); then
            sleep 10
            # the console by the shell's Win+R hotkey (cmd.exe in the Run dialog), as every console of these rounds
            ( cd "$QAD" && q tools/guest.sh "$EV" key meta_l-r ); sleep 4
            ( cd "$QAD" && q tools/guest.sh "$EV" key home shift-end ); sleep 1
            ( cd "$QAD" && q tools/guest.sh "$EV" type "cmd.exe" ); ( cd "$QAD" && q tools/guest.sh "$EV" key ret ); sleep 10
            if [ -n "$scale" ]; then ( cd "$QAD" && q ./set-fault.sh "$EV" none x-delay-scale=1 )
            else ( cd "$QAD" && q ./set-fault.sh "$EV" none ); fi
            ( cd "$QAD" && HEARTBEAT="${HEARTBEAT:-0}" TIMEOUT="${TIMEOUT:-60}" tools/cycle.sh "$EV" recover > "$EV/recover.out" 2>&1 )
            if grep -aq "intcdsp.sys: boot ok" "$EV/recover.out"; then
                rec="recovered: boot ok"
                if [ "$strow" = yes ]; then
                    if grep -aqE "$TERM_ST_OK" "$EV/recover.out"; then rec="recovered: boot ok, self-test ok"
                    else rec="recovered: boot ok, **self-test not ok**"; fi
                fi
            else rec="recovered: NO"; fi
            ( cd "$QAD" && q tools/guest.sh "$EV" shot console )
        else
            rec="recovered: shell not reached"
        fi
    fi
    printf "| %s | %s | %s | %s | %s | %s (power-downs in the trace: %s; wall %ss; %s) |\n" \
        "${fault}${scale:+ scale=$scale}" "$txt" "${gdt:--}" "${after:--}" "$verdict" "$reads" "$off" "$(( $(wall) - w0 ))" "$rec" | tee -a "$SUMMARY"
    [ -n "${COLLECT:-}" ] && collect "$EV" "$COLLECT/$name"
    ( cd "$QAD" && q tools/guest.sh "$EV" stop )
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
    printf "# AC4 fault matrix -- %s -- overlay %s%s%s%s\n\n| fault | the driver's terminal line (after its booting line) | booting -> line (guest s) | the line's own elapsed | bounded | register polls (power-downs in the trace; wall; recovery) |\n|---|---|---|---|---|---|\n" \
        "$(date -u +%FT%TZ)" "$DISK" \
        "$([ "${ICOUNT:-0}" = 1 ] && echo ' -- -icount shift=auto,align=off,sleep=off')" \
        "$([ "${HEARTBEAT:-0}" = 1 ] && echo ' -- qtest heartbeat 1 ms')" \
        "$([ "${RECOVER:-0}" = 1 ] && echo ' -- recovery cycle per row')" > "$SUMMARY"
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
