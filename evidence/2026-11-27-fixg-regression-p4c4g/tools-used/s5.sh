#!/bin/bash
# s5.sh -- S5 by hand on the VM s6.sh left (its bash stopped: the apitest of this build opens the
# render stream three times per run, not nine, so the injection is at the third open, the last
# depth's stream, as the run ends); then the next run at once, then pnputil's own texts for the
# DSP device's disable/enable in the faulted state; the VM is left running for S7 and S8.
set -u
RUN=r-s6
. /tmp/c6g/tools/r2-common.sh
LR=$(pgrep -f "^bash lib-run.sh$" | head -1)
[ -n "$LR" ] || { echo "no lib-run.sh of the VM found" >&2; exit 1; }
SOCK=$(cat "$EV/sock-dir.txt")
log "s5 (by hand): taking the VM over (lib-run pid $LR, sockets $SOCK); s6.sh was stopped by me: the apitest opens the render stream 3 times per run, not 9"
pouchfind
alive s5-start
n0=$(lines)
runfault s5-status-18 ipc-status=5:18 3 "$RUNMAX"
g shot s5-after >/dev/null
runfault s5-recovered none 0 "$RUNMAX"
cmd s5-dsp-disable.txt "pnputil /disable-device \"$ID\"" 60
cmd s5-dsp-enable.txt "pnputil /enable-device \"$ID\"" 60
n1=$(lines)
log "s5: the PnP lines of the two commands (after serial line $n0): $(norm | tail -n +"$((n0 + 1))" | grep -a -c -E 'PNP_|Safe removal'); stop lines: $(norm | grep -ac 'The system has been stopped'); fatal: $(grep -acE 'Fatal System Error|bugcheck' "$EV/serial.log"); ace_unexpected: $(grep -ac ace_unexpected "$EV/qemu-dbg.log")"
log "s5: done; the VM is left running for S7 and S8 (lib-run pid $LR, sockets $SOCK)"
echo "$LR" > "$EV/lib-run.pid"
