#!/bin/bash
# boot2.sh -- VM 2 of the p4c4b round: a system boot with SelfTest = 0 and the topology kept
# (TESTING.md run 3 (iii) at a system boot: boot ok, ipc: link ready, the topology line and
# the modules line, the child and the endpoint's lines, no self-test line; the brief's run 4),
# then the S5.  If the settings line of this boot does not say SelfTest = 0, SelfTest = 0 is set
# in the console and the guest rebooted (REBOOT = 1); that boot is the regression.
set -u
RUN=r2-plainboot-selftest0
REBOOT=1
. /tmp/qad-ev/p4c4b/tools/vmcommon.sh
log "boot2: $RUN on disk/$OVERLAY.qcow2"
start_vm
boot=0
settings() { norm | tail -n +"$((boot + 1))" | grep -a "intcdsp.sys: SelfTest = " | head -1 | sed "s/.*SelfTest = \([0-9]*\),.*/\1/"; }
show() { norm | tail -n +"$((boot + 1))" | grep -aE "intcdsp\.sys: (SelfTest|BootDsp = |boot ok|topology|ipc: link|DSP power down)|audio child|dsppcm\.sys|clock stalled|interrupt storm|Work queue|Fatal|bugcheck" | cut -c1-330 | tee -a "$EV/driver.log"; }
waitfor "topology 'sof-ipc4-loopback.tplg'|topology: none selected|clock stalled" 900
sleep 5
st=$(settings)
log "this boot's settings line says SelfTest = $st"
if [ "$st" != "0" ]; then
    log "not the regression boot: SelfTest = 0 will be set and the guest rebooted"
    waitfor "Program Manager" 900
    sleep 20
    console
    regadd SelfTest REG_DWORD 0
    boot=$(lines)
    g type "shutdown -r -t 0"; g key ret
    log "reboot typed at serial line $boot"
    waitfor "SelfTest = 0, UseInterrupts" 600 "$boot"
    waitfor "topology 'sof-ipc4-loopback.tplg'" 600 "$boot"
    sleep 5
    log "the reboot's driver lines:"
    show
else
    boot=0
    log "the boot's driver lines (settings, boot ok, topology, the child, the endpoint, power-down):"
    show
fi
log "self-test lines of the regression boot (none expected): $(norm | tail -n +"$((boot + 1))" | grep -ac 'loopback self-test')"
log "registration lines of the regression boot: $(norm | tail -n +"$((boot + 1))" | grep -ac 'dsppcm.sys: endpoint .* registered as')"
waitfor "Program Manager" 900 "$boot"
sleep 20
g shot s1-desktop >/dev/null
s5
log "boot2 done"
