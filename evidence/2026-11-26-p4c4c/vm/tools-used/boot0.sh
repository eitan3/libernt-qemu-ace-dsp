#!/bin/bash
# boot0.sh -- VM 0 of the p4c4c round: the first boot of a fresh overlay with NO data disk
# (TESTING.md A1's no-disk variant; the first boot of this master, ever).  Decided by serial
# lines alone: the first wait ends at the first-boot setup's line or at a stop line.
#   pass: 'Storage expansion not offered', a 'KsCreateBusEnumObject' line before it, no
#         stop line in the log of the boot; then the wizard is closed by chords (screenshots
#         for the record: A2, the desktop) and the S5 is taken
#   fail: 'The system has been stopped': the stop's lines are logged and the VM is waited for
set -u
RUN="${RUN:-r0-firstboot-nodisk}"
OVERLAY="${OVERLAY:-p4c4c-nodisk}"
POUCH=
. /tmp/qad-ev/p4c4c/tools/vmcommon.sh
log "boot0: $RUN on disk/$OVERLAY.qcow2, no data disk"
start_vm
waitre "Storage expansion not offered|The system has been stopped" 900 || log "!! neither the first-boot setup's line nor a stop line in 900 s"
if norm | grep -aq "The system has been stopped"; then
    log "!! the first boot STOPPED; its lines:"
    norm | grep -anE "KsCreateBusEnumObject|The system has been stopped|Stop code|Parameter [1-4]|^ *#[0-9][0-9] |RIP=|Fatal|bugcheck" | cut -c1-300 | tee -a "$EV/driver.log"
    for i in $(seq 1 120); do kill -0 "$LR" 2>/dev/null || break; sleep 1; done
    if kill -0 "$LR" 2>/dev/null; then g mon quit >/dev/null; fi
    wait $LR
    log "VM $RUN ended: $(grep -a 'qemu exited' "$EV/lib-run.out")"
    log "boot0: the first boot did not pass"
    exit 1
fi
log "A1 (no data disk): the first boot's lines:"
norm | grep -aE "LiberNT 10\.0 build|AUTOCHK|KsCreateBusEnumObject|Safe removal|First-boot setup|Setup language|Storage expansion not offered|intcdsp\.sys: (BootDsp|SelfTest)|hdaudbus\.sys: (ADSP child|audio path)|Program Manager" | cut -c1-300 | tee -a "$EV/driver.log"
log "the swenum line is $(norm | grep -an 'KsCreateBusEnumObject' | cut -d: -f1 | tr '\n' ' ') of the normalised log, the storage-expansion line $(norm | grep -an 'Storage expansion not offered' | cut -d: -f1 | tr '\n' ' '); stop lines in the boot's log: $(norm | grep -ac 'The system has been stopped'); ace_unexpected: $(grep -ac ace_unexpected "$EV/qemu-dbg.log")"
sleep 5
g shot s1-desktop-before-wizard >/dev/null
wizard 15
g shot s2-after-wizard >/dev/null
sleep 20
g shot s3-after-wizard-20s >/dev/null
sleep 20
g shot s4-after-wizard-40s >/dev/null
log "stop lines in the whole log: $(norm | grep -ac 'The system has been stopped'); fatal lines: $(grep -acE 'Fatal System Error|bugcheck' "$EV/serial.log"); driver lines: $(grep -acE 'hdaudbus\.sys|intcdsp\.sys' "$EV/serial.log")"
s5
log "boot0 done"
exit 0
