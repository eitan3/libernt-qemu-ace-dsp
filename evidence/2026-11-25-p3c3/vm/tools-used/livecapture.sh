#!/bin/bash
# livecapture.sh -- a disable/enable cycle of the DSP device in a running VM of
# lib-run.sh (QTESTSOCK=1) that STOPS the VM the moment the driver's self-test
# prints its first line, dumps the live stream descriptors, BDL entries and the
# memory around them over qtest (reads only), and continues the VM.
#   livecapture.sh <evidence-dir> <label> <bar0 hex>
# The commands are typed into the guest's console through the monitor as
# tools/cycle.sh types them; the console must be open and focused.
set -u
QAD=<project>
EV="${1:?usage: livecapture.sh <evidence-dir> <label> <bar0 hex>}"
LABEL="${2:?label missing}"
BAR0="${3:?bar0 missing}"
ID='CSAUDIO\ADSP&CTLR_VEN_8086&CTLR_DEV_7F50\4&aeefd634&0&1000000000'
EV="$(cd "$EV" && pwd)"
SOCK="$(cat "$EV/sock-dir.txt")"
LOG="$EV/livecapture-$LABEL.log"
OUT="$EV/livecapture-$LABEL.txt"
norm() { sed "s/\x1b\[[0-9;]*[A-Za-z]//g" "$EV/serial.log" | tr -d "\0"; }
lines() { norm | wc -l; }
log() { printf '%s\n' "$*" | tee -a "$LOG"; }
tools_c() { (cd "$QAD" && tools/guest.sh "$EV" "$@" >/dev/null 2>&1); }

n0=$(lines)
log "## livecapture $LABEL $(date -u +%FT%TZ) (serial line $n0)"
tools_c type "pnputil /disable-device \"$ID\""
tools_c key ret
"$QAD/tools/waitline.sh" "$EV" "Safe removal" 30 "$n0" | cut -c1-200 | tee -a "$LOG"
sleep 2
n1=$(lines)
log "## enable typed at $(date -u +%FT%TZ) (serial line $n1)"
tools_c type "pnputil /enable-device \"$ID\""
tools_c key ret
# the stop: a busy grep on the serial log, then the monitor's stop at once
t0=$(date +%s%3N)
until norm | tail -n +"$((n1 + 1))" | grep -aq "loopback self-test: endpoint"; do
    [ $(( $(date +%s%3N) - t0 )) -ge 120000 ] && { log "## !! the self-test's first line did not appear in 120 s"; exit 1; }
done
tools_c mon stop
t1=$(date +%s%3N)
log "## stopped $((t1 - t0)) ms after the enable; the serial log's last driver lines:"
norm | tail -n +"$((n1 + 1))" | grep -aE "intcdsp\.sys" | tail -4 | cut -c1-200 | tee -a "$LOG"
for attempt in 1 2 3 4 5 6; do
    python3 /tmp/qad-ev/p3c3/streamregs.py "$SOCK/qtest.sock" "$BAR0" 16 > "$OUT" 2>&1
    if grep -q "bdl=0x[1-9a-f]" "$OUT"; then
        log "## descriptors live on read $attempt: $OUT"
        break
    fi
    log "## read $attempt: no descriptor yet, continuing 0.3 s"
    tools_c mon cont
    sleep 0.3
    tools_c mon stop
done
tools_c mon cont
log "## continued at $(date -u +%FT%TZ)"
