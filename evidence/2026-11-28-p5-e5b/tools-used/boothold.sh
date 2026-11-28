#!/bin/bash
# boothold.sh -- boot the installed overlay to a console answering, then hold the VM until $EV/stop appears.
#   env: RUN, DISKFILE, POUCH (an existing pouch image)
set -u
. /tmp/e5b/tools/vmcommon.sh
log "boothold: $RUN on $DISKFILE"
N0=$(lines)
start_vm
sleep 20
N0=$(lines)
waitre "intcdsp.sys: boot .*after|The system has been stopped" 600 || { log "!! no boot line in 600 s"; s5; exit 1; }
if norm | grep -aq "The system has been stopped"; then log "!! the boot STOPPED"; s5; exit 1; fi
sleep 50
for i in 1 2 3 4; do console 2; pouchfind && alive boot && break; sleep 20; done
: > "$EV/ready"
log "## ready: the console answers; waiting for $EV/stop"
while [ ! -f "$EV/stop" ]; do sleep 3; done
g shot 90-end >/dev/null
s5
log "done: fatal $(grep -acE 'Fatal System Error|bugcheck' "$EV/serial.log"), ace_unexpected $(grep -ac ace_unexpected "$EV/qemu-dbg.log")"
