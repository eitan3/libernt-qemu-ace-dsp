#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# qemu-ace-dsp: cycle.sh -- one disable/enable cycle of the DSP device in a
# running VM of lib-run.sh (QTESTSOCK=1), scripted and bounded, with the
# model's registers read over qtest before (disabled) and after (D0) the
# boot, appended to <evidence-dir>/cycles.log:
#
#   tools/cycle.sh <evidence-dir> <label> [instance id]
# env: HEARTBEAT=1  run tools/heartbeat.py (PERIOD us, default 1000) while the
#      driver boots -- a host whose timer delivery stalls under a spinning TCG
#      guest otherwise lets the main loop sleep through the model's timers
#      (README, "A note on the host")
#      TIMEOUT=<s>  cap on the wait for the driver's "boot ... after" line (60)
#
# The commands are typed into the guest's console window through the monitor
# (tools/guest.sh, one key per ~100 ms); the instance id defaults to the one
# the image assigns in this VM. Bounded: every wait has a timeout, a failed
# wait is recorded and the cycle ends with the device enabled.
# This work is licensed under the terms of the GNU GPL, version 2 or later.
# See the COPYING file in the top-level directory.
set -u
QAD="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EV="${1:?usage: cycle.sh <evidence-dir> <label> [instance id]}"
LABEL="${2:?label missing}"
ID="${3:-CSAUDIO\\ADSP&CTLR_VEN_8086&CTLR_DEV_7F50\\4&aeefd634&0&1000000000}"
EV="$(cd "$EV" && pwd)"
SOCK="$(cat "$EV/sock-dir.txt")"
LOG="$EV/cycles.log"
TIMEOUT="${TIMEOUT:-60}"
norm() { sed "s/\x1b\[[0-9;]*[A-Za-z]//g" "$EV/serial.log" | tr -d "\0"; }
lines() { norm | wc -l; }
st() { python3 "$QAD/tools/qtest.py" "$SOCK/qtest.sock" adspcs dsp2cxctl inten irqsts hfhipcie hfipcxtdr hfipcxida hfipcxctl hfipcxtddy fsr | awk '{printf "%s=%s ", $NF, substr($4, 11, 8)}'; echo; }
log() { printf '%s\n' "$*" | tee -a "$LOG"; }

n0=$(lines)
log "## cycle $LABEL $(date -u +%FT%TZ) (serial line $n0)"
tools_c() { (cd "$QAD" && tools/guest.sh "$EV" "$@" >/dev/null 2>&1); }
tools_c type "pnputil /disable-device \"$ID\""
tools_c key ret
if ! "$QAD/tools/waitline.sh" "$EV" "Safe removal" 30 "$n0" | cut -c1-200 | tee -a "$LOG"; then
    log "!! $LABEL: disable not seen"
fi
sleep 2
log "model (disabled): $(st)"
hb=""
if [ "${HEARTBEAT:-0}" = 1 ]; then
    hb="$EV/heartbeat-$LABEL.log"
    ( python3 "$QAD/tools/heartbeat.py" "$SOCK/qtest.sock" "$((TIMEOUT + 10))" "${PERIOD:-1000}" > "$hb" 2>&1 & )
fi
n1=$(lines)
tools_c type "pnputil /enable-device \"$ID\""
tools_c key ret
"$QAD/tools/waitline.sh" "$EV" "intcdsp.sys: boot .*after|clock stalled|Work queue|Fatal|bugcheck" "$TIMEOUT" "$n1" | cut -c1-700 | tee -a "$LOG"
rc=$?
sleep 3
pkill -f "heartbeat.py $SOCK" 2>/dev/null
[ -n "$hb" ] && tail -1 "$hb" | tee -a "$LOG"
log "model (D0): $(st)"
log "driver lines after this enable:"
norm | tail -n +"$((n1 + 1))" | grep -aE "intcdsp\.sys|Work queue|clock stalled|Fatal|bugcheck|PNP_" | grep -av "boot .*after" | cut -c1-400 | tee -a "$LOG"
exit $rc
