#!/bin/bash
# postfail.sh -- VM 1 of the p4c4b2 round after boot1.sh was stopped (the DSP device's disable
# with its child present had failed: 'Failed to disable device: A device attached to the system
# is not functioning', no 'Safe removal' line), and the ACPI power button had brought no S5:
# a second console (Win+R, cmd.exe), a marker file (is the console answered?), the device
# lists of the Media and the System classes to the data disk, then the shutdown typed; if no
# S5 follows the VM is ended by the monitor.  The data disk's drive is D: (the first console's
# %POUCHDRV% is not in this console's environment).
# Correction written after the run (2026-11-26): the sentence about the power button was
# wrong.  boot1.sh was stopped before its s5 (its output ends at the ctrl-tab echo), so the
# button was never sent in this VM; the header's claim stands as written only to show what
# the run believed.  The marker file's 25 s poll below missed the answer too: the console
# took longer, and alive-postfail.txt is on the data disk.
set -u
RUN=r1-firstboot-cycle-dsploop-selftest2
. /tmp/qad-ev/p4c4b2/tools/vmcommon.sh
LR=$(pgrep -f "^bash lib-run.sh$" | head -1)   # the launcher survived the stopped script
log "postfail: the second console (lib-run.sh pid $LR, sockets $(cat "$EV/sock-dir.txt"))"
g key meta_l-r; sleep 4
g key home shift-end
g type "cmd.exe"; g key ret; sleep 10
g shot p1-second-console >/dev/null
n=$(mdir -i "$POUCH" ::/ 2>/dev/null | grep -c "alive")
g type "echo alive > D:\\alive-postfail.txt"; g key ret
for i in $(seq 1 25); do
    [ "$(mdir -i "$POUCH" ::/ 2>/dev/null | grep -c "alive")" -gt "$n" ] && { log "the second console answers (alive-postfail.txt after about $i s)"; break; }
    sleep 1
done
mdir -i "$POUCH" ::/ 2>/dev/null | grep -c "alive" | sed "s/^/alive marker files on the data disk: /" | tee -a "$EV/driver.log"
g type "pnputil /enum-devices /class Media /ids > D:\\postfail-media.txt"; g key ret; sleep 20
g type "pnputil /enum-devices /class System /ids > D:\\postfail-system.txt"; g key ret; sleep 25
g shot p2-after-lists >/dev/null
log "postfail-media.txt: $(pouch_text postfail-media.txt | wc -l) lines, $(pouch_text postfail-media.txt | grep -c 'Instance ID') devices; postfail-system.txt: $(pouch_text postfail-system.txt | wc -l) lines, $(pouch_text postfail-system.txt | grep -c 'Instance ID') devices"
log "the Media list after the failed disable (as the guest wrote it):"
pouch_text postfail-media.txt | cut -c1-200 | tee -a "$EV/driver.log"
log "the System list's DSP, HDA and software-bus entries (as the guest wrote it):"
pouch_text postfail-system.txt | grep -A4 -i -e "Instance ID:.*ADSP" -e "Instance ID:.*HDA" -e "Instance ID:.*ROOT.SYSTEM" | cut -c1-200 | tee -a "$EV/driver.log"
log "the shutdown typed"
g type "shutdown -s -t 0"; g key ret
if waitfor "Entering sleep state S5" 120; then
    for i in $(seq 1 120); do kill -0 "$LR" 2>/dev/null || break; sleep 1; done
    kill -0 "$LR" 2>/dev/null && { log "!! QEMU still running 120 s after the S5 line: quit"; g mon quit >/dev/null; sleep 5; }
    log "VM $RUN ended: $(grep -a 'qemu exited' "$EV/lib-run.out")"
else
    log "!! no S5 in 120 s after 'shutdown -s -t 0'; the VM is ended by the monitor"
    g mon quit >/dev/null; sleep 5
    log "VM $RUN ended: $(grep -a 'qemu exited' "$EV/lib-run.out" 2>/dev/null)"
fi
log "postfail done"
