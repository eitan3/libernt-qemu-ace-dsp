#!/bin/bash
# s6.sh -- S6, then S5, on a boot of their own (the VM is left running for S7 and S8):
#   S6  the DSP's PCM child and the codec, no stream open: pnputil /disable-device then
#       /enable-device of each (one stop, one start), /restart-device where the disable is
#       refused; then the DSP device itself (the devnode cycle: the child is removed and made
#       again), each command's own text to the data disk; then dsploop must pass.
#   S5  ipc-status=5:18 (the delete-pipeline type) injected at the ninth open of the render
#       stream, as the run ends; the next run at once, then after a device cycle.
set -u
RUN="${RUN:-r-s6}"
. /tmp/c6g/tools/r2-common.sh
log "s6: $RUN on disk/$OVERLAY.qcow2 (BootDsp = 1 and the topology)"
session
n0=$(lines)
cmd s6-1-child-disable.txt "pnputil /disable-device \"$CHILD\"" 60
cmd s6-2-child-enable.txt "pnputil /enable-device \"$CHILD\"" 60
cmd s6-3-child-restart.txt "pnputil /restart-device \"$CHILD\"" 60
cmd s6-4-codec-disable.txt "pnputil /disable-device \"$CODEC\"" 60
cmd s6-5-codec-enable.txt "pnputil /enable-device \"$CODEC\"" 60
cmd s6-6-codec-restart.txt "pnputil /restart-device \"$CODEC\"" 60
cmd s6-7-enum-media.txt "pnputil /enum-devices /class Media /ids" 60
cmd s6-8-enum-system.txt "pnputil /enum-devices /class System /ids" 60
sleep 3
log "S6: the driver's lines during the six commands (after serial line $n0):"
norm | tail -n +"$((n0 + 1))" | grep -a -E "intcdsp\.sys:|dsppcm\.sys:|hdaudbus\.sys:|Safe removal|RestartDevice|DisableDevice|EnableDevice|QueryRemove|Surprise|PNP_|clock stalled|interrupt storm|Work queue|Fatal|bugcheck|The system has been stopped" | grep -a -v -E "booting:|interrupts before|subsystem powered|code-loader|ROM ready|firmware entered|FW_READY|loaded for|controller 8086|NHLT|reading BAR4|BAR4 \+|HFINTIPPTR" | cut -c1-300 | sed 's/^/    /' | tee -a "$EV/driver.log"
log "S6: the child's lines in enum-media.txt: $(pouch_text s6-7-enum-media.txt | grep -ci 'INTCDSP'); the codec's status: $(pouch_text s6-7-enum-media.txt | grep -a -A2 'HDAUDIO' | grep -a -i 'Status' | head -1 | tr -s ' ')"
# the devnode cycle of the DSP device itself, pnputil's own text to the disk
n1=$(lines)
cmd s6-10-dsp-disable.txt "pnputil /disable-device \"$ID\"" 90
cmd s6-11-dsp-enable.txt "pnputil /enable-device \"$ID\"" 90
sleep 3
log "S6: the driver's lines of the devnode cycle (after serial line $n1):"
norm | tail -n +"$((n1 + 1))" | grep -a -E "intcdsp\.sys: (boot ok|topology|DSP power down|audio child)|dsppcm\.sys|Safe removal|RestartDevice|DisableDevice|EnableDevice|QueryRemove|Surprise|PNP_|clock stalled|Fatal|bugcheck|The system has been stopped" | cut -c1-300 | sed 's/^/    /' | tee -a "$EV/driver.log"
if ! alive s6-dsp >/dev/null 2>&1; then
    log "S6: the console is silent after the devnode cycle; opening another"
    console 6 12; pouchfind
fi
cmd s6-12-enum-media-after.txt "pnputil /enum-devices /class Media /ids" 60
log "S6: the child after the cycle: $(pouch_text s6-12-enum-media-after.txt | grep -c 'INTCDSP') INTCDSP lines; stop lines: $(norm | grep -ac 'The system has been stopped'); fatal: $(grep -acE 'Fatal System Error|bugcheck' "$EV/serial.log"); ace_unexpected: $(grep -ac ace_unexpected "$EV/qemu-dbg.log")"
mustpass s6-recovered
# --- S5
runfault s5-status-18 ipc-status=5:18 9 "$RUNMAX"
g shot s5-after >/dev/null
mustpass s5-recovered
log "s6: done; the VM is left running for S7 and S8 (lib-run pid $LR, sockets $SOCK)"
echo "$LR" > "$EV/lib-run.pid"
