#!/bin/bash
# boot4.sh -- VM 4 of the p4c4c round: the user-mode fixes by eye (TESTING.md D12-D14) and
# E16 (N5-05) with the audio service running, on the overlay of VM 1 (the DSP boots at the
# system boot with the topology; the exe on the system disk).  This script brings the VM to
# the desktop with a console, takes E16's row, opens the Sound applet and takes one screenshot;
# the rest of D is driven step by step from the host afterwards (small calls: a few keys, a
# screenshot each), as the brief asks for "by eye".  The S5 is taken by the last of those calls
# (boot4end.sh).
set -u
RUN="${RUN:-r4-byeye}"
OVERLAY="${OVERLAY:-p4c4c}"
. /tmp/qad-ev/p4c4c/tools/vmcommon.sh
log "boot4: $RUN on disk/$OVERLAY.qcow2 (the overlay of VMs 1 and 5), a new data disk"
start_vm
waitre "dsppcm\.sys: endpoint .* registered as|The system has been stopped|topology: none selected" 900 || log "!! no registration line in 900 s"
sleep 10
log "A3: the system boot's driver lines:"
norm | grep -aE "intcdsp\.sys: (SelfTest|BootDsp = |boot ok|topology|ipc: link|firmware ready|DSP power down|audio child|loopback self-test)|dsppcm\.sys|clock stalled|interrupt storm|Work queue|Fatal|bugcheck" | grep -av "booting:" | cut -c1-420 | tee -a "$EV/driver.log"
log "self-test lines of the boot: $(norm | grep -ac 'loopback self-test'); registration lines: $(norm | grep -ac 'dsppcm.sys: endpoint .* registered as'); stop lines: $(norm | grep -ac 'The system has been stopped')"
waitre "Program Manager" 900 || log "!! the shell did not come up in 900 s"
sleep 20
g shot s1-desktop >/dev/null
console
pouchfind || { g shot s2-no-data-disk-letter >/dev/null; log "!! the data disk was not found: stopped here"; exit 1; }
alive boot || { g shot s3-console-silent >/dev/null; log "!! the console is silent: stopped here"; exit 1; }
cmd x-exe-on-c.txt "dir C:\\dsploop_apitest.exe" 30
# E16 (N5-05) with the audio service running
n0=$(lines)
cmd x-n5-05-running.txt "pnputil /restart-device \"$CODEC\"" 180
sleep 5
log "N5-05 (the service running): the serial lines of the codec's restart (after serial line $n0):"
norm | tail -n +"$((n0 + 1))" | grep -aE "PNP_|DisableDevice|EnableDevice|RestartDevice|Safe removal|hdaudbus|hdaudio|HDAUDIO|kmixer|sysaudio|wdmaud|intcdsp|dsppcm|clock stalled|interrupt storm|Work queue|Fatal|bugcheck|err:" | cut -c1-420 | tee -a "$EV/driver.log"
cmd x-n5-05-media.txt "pnputil /enum-devices /class Media /ids" 60
# D12: the Sound applet, one screenshot of its first page
g type "mmsys.cpl"; g key ret; sleep 30
g shot d12-1-sound >/dev/null
log "boot4: the VM is at the Sound applet; D continues step by step from the host"
exit 0
