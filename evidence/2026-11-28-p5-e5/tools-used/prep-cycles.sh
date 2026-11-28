#!/bin/bash
# e5-prep-cycles.sh -- on the installed first-boot overlay of the final image (a later boot): the matrix's settings in
# the guest, by the registry and a clean shutdown (the D0 entry reads them at the next boot, N12-09): Topology deleted
# (no PCM child: with the child present the PnP disable of the DSP device is refused, D4) and BootAtStart = 1 (the D0
# rule boots nothing at an entry with BootAtStart = 0 and no self-test), SelfTest = 3 kept as the image has it.  The
# pouch carries the query's text out.
set -u
RUN="${RUN:-prepcyc}"
OVERLAY="${OVERLAY:-e5-firstboot}"
. /tmp/e5/tools/vmcommon.sh

log "e5 prep-cycles: $RUN on $QAD/disk/$OVERLAY.qcow2, image $(basename "$IMG")"
start_vm
waitre "Program Manager|Storage expansion not offered|desktop ready|The system has been stopped" 600 || { log "!! the desktop did not come up"; s5; exit 1; }
if norm | grep -aq "The system has been stopped"; then log "!! the boot STOPPED"; s5; exit 1; fi
if norm | grep -aq "Storage expansion not offered"; then wizard 25; else grep -aq "Program Manager" "$EV/serial.log" || sleep 45; fi
sleep 20
log "## the boot: boot ok $(norm | grep -ac 'intcdsp.sys: boot ok after'), selftest ok $(norm | grep -ac 'loopback self-test: ran (0x00000000)'), registered-as $(norm | grep -ac 'registered as'), stop lines $(norm | grep -ac 'The system has been stopped'), fatal $(grep -acE 'Fatal System Error|bugcheck' "$EV/serial.log")"
for i in 1 2 3; do console 3; pouchfind && alive boot && break; sleep 15; done
g type "${PDRV}:"; g key ret; sleep 2
cmd before.txt "reg query \"$KEY\"" 30
regadd SelfTest REG_DWORD 3 4
regadd BootAtStart REG_DWORD 1 4
g type "reg delete \"$KEY\" /v Topology /f"; g key ret; sleep 4; log "typed: reg delete Topology"
cmd after.txt "reg query \"$KEY\"" 30
g shot 50-after >/dev/null
s5
log "done: $(grep -a 'qemu exited' "$EV/lib-run.out")"
