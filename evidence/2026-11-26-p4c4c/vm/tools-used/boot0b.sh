#!/bin/bash
# boot0b.sh -- the take-over of VM 0 of the p4c4c round after boot0.sh was stopped by my own
# fault: vmcommon.sh's waitre required its third argument and `set -u` ended the script right
# after start_vm (the VM kept running: the launcher survived).  This script sets the launcher's
# pid and the socket directory from the run's files and takes boot0.sh's flow from its wait on.
set -u
RUN="${RUN:-r0-firstboot-nodisk}"
OVERLAY="${OVERLAY:-p4c4c-nodisk}"
POUCH=
. /tmp/qad-ev/p4c4c/tools/vmcommon.sh
LR=$(pgrep -f "^bash lib-run.sh$" | head -1)
SOCK=$(cat "$EV/sock-dir.txt")
log "boot0b: taking the running VM over (lib-run.sh pid $LR, sockets $SOCK); boot0.sh was stopped by my own fault (waitre's third argument)"
waitre "Storage expansion not offered|The system has been stopped" 60 || log "!! neither the first-boot setup's line nor a stop line in the log"
if norm | grep -aq "The system has been stopped"; then
    log "!! the first boot STOPPED; its lines:"
    norm | grep -anE "KsCreateBusEnumObject|The system has been stopped|Stop code|Parameter [1-4]|^ *#[0-9][0-9] |RIP=|Fatal|bugcheck" | cut -c1-300 | tee -a "$EV/driver.log"
    s5
    exit 1
fi
log "A1 (no data disk): the first boot's lines:"
norm | grep -aE "LiberNT 10\.0 build|AUTOCHK|KsCreateBusEnumObject|Safe removal|First-boot setup|Setup language|Storage expansion not offered|intcdsp\.sys: (BootDsp|SelfTest)|hdaudbus\.sys: (ADSP child|audio path)|Program Manager" | cut -c1-300 | tee -a "$EV/driver.log"
log "the swenum line is $(norm | grep -an 'KsCreateBusEnumObject' | cut -d: -f1 | tr '\n' ' ') of the normalised log, the storage-expansion line $(norm | grep -an 'Storage expansion not offered' | cut -d: -f1 | tr '\n' ' '); stop lines in the boot's log: $(norm | grep -ac 'The system has been stopped'); storport timeouts: $(norm | grep -ac 'Storport: a request'); ace_unexpected: $(grep -ac ace_unexpected "$EV/qemu-dbg.log")"
g shot s1-desktop-before-wizard >/dev/null
wizard 5
g shot s2-after-wizard >/dev/null
sleep 20
g shot s3-after-wizard-20s >/dev/null
sleep 20
g shot s4-after-wizard-40s >/dev/null
log "stop lines in the whole log: $(norm | grep -ac 'The system has been stopped'); fatal lines: $(grep -acE 'Fatal System Error|bugcheck' "$EV/serial.log"); driver lines: $(grep -acE 'hdaudbus\.sys|intcdsp\.sys' "$EV/serial.log")"
s5
log "boot0b done"
exit 0
