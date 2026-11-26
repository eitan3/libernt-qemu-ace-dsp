#!/bin/bash
# step.sh -- one small step of the by-eye part of the p4c4c round on the VM boot4.sh left
# running (VM 4): a chord or a few keys, a pause, a screenshot into the run directory.
#   step.sh <name> <pause s> <key chord>...       keys, then the pause, then the screenshot
#   step.sh <name> <pause s> type "<text>"        the text typed, then the pause, then the screenshot
#   step.sh end                                  the S5 (the ACPI power button), the launcher waited for
set -u
RUN="${RUN:-r4-byeye}"
POUCH=/tmp/qad-ev/p4c4c/pouch/r4-byeye.img
. /tmp/qad-ev/p4c4c/tools/vmcommon.sh
LR=$(pgrep -f "^bash lib-run.sh$" | head -1)
SOCK=$(cat "$EV/sock-dir.txt")
PDRV=$(pouch_text drive.txt | tr -d ' \n')
if [ "${1:-}" = end ]; then
    log "step end: the power button"
    g mon system_powerdown >/dev/null
    for i in $(seq 1 120); do [ -n "$LR" ] && [ -e "/proc/$LR" ] || break; sleep 1; done
    log "VM $RUN ended: $(grep -a 'qemu exited' "$EV/lib-run.out")"
    exit 0
fi
name=$1; pause=$2; shift 2
if [ "${1:-}" = type ]; then g type "$2"; log "step $name: typed '$2'"
else [ $# -gt 0 ] && g key "$@" >/dev/null; log "step $name: keys $*"; fi
sleep "$pause"
g shot "$name" >/dev/null
log "step $name: screenshot $name.png"
exit 0
