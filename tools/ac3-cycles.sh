#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# qemu-ace-dsp: ac3-cycles.sh -- AC3's power-cycle rehearsal in one command:
# boot the overlay (BootDsp=1 persisted), open a console, run N
# disable/enable cycles of the DSP device (tools/cycle.sh: the model's
# registers read over qtest in the disabled state and after each boot), power
# the guest off. Everything is bounded; the VM is stopped on exit.
#
#   tools/ac3-cycles.sh <cycles> [first label = 1]
# env: DISK (the overlay), ISO (the image's ISO), EVID (evidence dir; a tmpfs
#      path keeps the log writes off a slow disk), ICOUNT=1|0 (default 1: guest
#      clock and model timers advance together), HEARTBEAT=1|0 (default 0),
#      WAIT (VM wall-clock cap, default 900 + 90 s per cycle)
# Result: <EVID>/cycles.log (cycle.sh's log), <EVID>/cycles-run.out and the
# summary line "<EVID>/summary.txt": N cycles, K boot ok, the others by outcome.
# A fresh first-boot overlay goes through the Setup wizard first (its three
# pages, by chords).  On an image whose guest has SelfTest = 2 or 3 every enable
# runs the loopback self-test after its boot (tools/cycle.sh waits for its
# closing line); the summary counts those cycles as "self-test ok" when the
# closing line says `ran (0x00000000)`, and an enable that boots nothing
# (BootAtStart = 0, no self-test) as "not booted".
# This work is licensed under the terms of the GNU GPL, version 2 or later.
# See the COPYING file in the top-level directory.
set -u
QAD="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
N="${1:?usage: ac3-cycles.sh <cycles> [first label]}"
START="${2:-1}"
DISK="${DISK:?overlay missing (DISK=)}"
ISO="${ISO:?ISO missing (ISO=; lib-run.sh wants it even with CDROM=none)}"
EVID="${EVID:?evidence dir missing (EVID=)}"
ICOUNT="${ICOUNT:-1}"
HEARTBEAT="${HEARTBEAT:-0}"
WAIT="${WAIT:-$(( 900 + N * 90 ))}"
mkdir -p "$EVID"; EVID="$(cd "$EVID" && pwd)"
q() { "$@" >/dev/null 2>&1; }

( cd "$QAD" && env DISK="$DISK" ISO="$ISO" CDROM=none TRACE=1 QTESTSOCK=1 ICOUNT="$ICOUNT" \
    WAIT="$WAIT" EVID="$EVID" ./run.sh > "$EVID/lib-run.out" 2>&1 ) &
lr=$!
cleanup() { ( cd "$QAD" && q tools/guest.sh "$EVID" stop ); wait $lr 2>/dev/null; }
trap cleanup EXIT

echo "== $(date -u +%FT%TZ) waiting for the shell" | tee -a "$EVID/cycles-run.out"
if ! ( cd "$QAD" && tools/waitline.sh "$EVID" "Program Manager" 900 >> "$EVID/cycles-run.out" 2>&1 ); then
    echo "!! the shell did not come up in 900 s" | tee -a "$EVID/cycles-run.out"; exit 1
fi
# a first boot of the overlay: the Setup wizard's three pages (the storage page's Next, the account page's Skip, the component page's Cancel), closed by chords
if ( cd "$QAD" && tools/waitline.sh "$EVID" "Storage expansion not offered" 240 >> "$EVID/cycles-run.out" 2>&1 ); then
    sleep 25
    ( cd "$QAD" && q tools/guest.sh "$EVID" key tab tab ret ); sleep 5
    ( cd "$QAD" && q tools/guest.sh "$EVID" key ret ); sleep 5
    ( cd "$QAD" && q tools/guest.sh "$EVID" key tab tab tab ret ); sleep 5
    echo "wizard: tab tab ret, ret, tab tab tab ret sent" | tee -a "$EVID/cycles-run.out"
fi
sleep 10
# the console by the shell's Win+R hotkey (cmd.exe in the Run dialog), as every console of these rounds
( cd "$QAD" && q tools/guest.sh "$EVID" key meta_l-r ); sleep 4
( cd "$QAD" && q tools/guest.sh "$EVID" key home shift-end ); sleep 1
( cd "$QAD" && q tools/guest.sh "$EVID" type "cmd.exe" ); ( cd "$QAD" && q tools/guest.sh "$EVID" key ret ); sleep 10
( cd "$QAD" && q tools/guest.sh "$EVID" shot console-start )
for i in $(seq 1 "$N"); do
    c=$(( START + i - 1 ))
    echo "=== cycle $c $(date -u +%FT%TZ)" >> "$EVID/cycles-run.out"
    ( cd "$QAD" && HEARTBEAT="$HEARTBEAT" TIMEOUT=90 tools/cycle.sh "$EVID" "c$c" >> "$EVID/cycles-run.out" 2>&1 )
done
( cd "$QAD" && q tools/guest.sh "$EVID" type "shutdown -s -t 0" ); ( cd "$QAD" && q tools/guest.sh "$EVID" key ret )
wait $lr 2>/dev/null
trap - EXIT
ok=$(awk '/^## cycle c[0-9]+ /{f=1; next} /^## cycle/{f=0} f && /intcdsp.sys: boot ok after/{n++} END{print n+0}' "$EVID/cycles.log")
to=$(awk '/^## cycle c[0-9]+ /{f=1; next} /^## cycle/{f=0} f && /intcdsp.sys: boot .*timeout after/{n++} END{print n+0}' "$EVID/cycles.log")
other=$(awk '/^## cycle c[0-9]+ /{f=1; next} /^## cycle/{f=0} f && /intcdsp.sys: boot/ && !/booting:/ && !/boot ok after/ && !/timeout after/{n++} END{print n+0}' "$EVID/cycles.log")
none=$(grep -ac "not seen" "$EVID/cycles.log")
stall=$(grep -ac "clock stalled" "$EVID/serial.log")
stok=$(awk '/^## cycle c[0-9]+ /{f=1; next} /^## cycle/{f=0} f && /loopback self-test: ran \(0x00000000\)/{n++} END{print n+0}' "$EVID/cycles.log")
nb=$(awk '/^## cycle c[0-9]+ /{f=1; next} /^## cycle/{f=0} f && /D0 entry: the DSP is not booted/{n++} END{print n+0}' "$EVID/cycles.log")
printf 'AC3 cycles: %d run, %d boot ok, %d self-test ok, %d not booted, %d bounded timeouts, %d other outcomes, %d waits not seen, clock stalled lines: %d (%s; icount=%s heartbeat=%s)\n' \
    "$N" "$ok" "$stok" "$nb" "$to" "$other" "$none" "$stall" "$(date -u +%FT%TZ)" "$ICOUNT" "$HEARTBEAT" | tee "$EVID/summary.txt"
