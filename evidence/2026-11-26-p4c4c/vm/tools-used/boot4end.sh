#!/bin/bash
# boot4end.sh -- the end of VM 4 of the p4c4c round, after the by-eye steps: D4's holder one step
# further -- the user-mode audio service and the kernel mixer stopped one after the other, each
# state read before and after (sc query), then the DSP device (the child present) asked once
# more; its text and serial lines recorded; then the S5.
set -u
RUN="${RUN:-r4-byeye}"
OVERLAY="${OVERLAY:-p4c4c}"
. /tmp/qad-ev/p4c4c/tools/vmcommon.sh
LR=$(pgrep -f "^bash lib-run.sh$" | head -1)
SOCK=$(cat "$EV/sock-dir.txt")
PDRV=$(pouch_text drive.txt | tr -d ' \n')
log "boot4end: the D4 holder probe (lib-run.sh pid $LR, the data disk on $PDRV:)"
console
alive end || { g shot s9b-console-silent-end >/dev/null; log "!! the console is silent: the S5 is taken"; }
cmd x-audiosrv-before.txt "sc query AudioSrv" 40
log "AudioSrv before: $(pouch_text x-audiosrv-before.txt | tr -d '\r' | tr -s ' \t' ' ' | tr '\n' '|' | cut -c1-200)"
cmd x-audiosrv-stop.txt "net stop audiosrv" 180
cmd x-audiosrv-after.txt "sc query AudioSrv" 40
log "AudioSrv after net stop audiosrv: $(pouch_text x-audiosrv-after.txt | tr -d '\r' | tr -s ' \t' ' ' | tr '\n' '|' | cut -c1-200)"
cmd x-sysaudio-before.txt "sc query sysaudio" 40
log "sysaudio before: $(pouch_text x-sysaudio-before.txt | tr -d '\r' | tr -s ' \t' ' ' | tr '\n' '|' | cut -c1-200)"
cmd x-sysaudio-stop.txt "net stop sysaudio" 180
cmd x-sysaudio-after.txt "sc query sysaudio" 40
log "sysaudio after net stop sysaudio: $(pouch_text x-sysaudio-after.txt | tr -d '\r' | tr -s ' \t' ' ' | tr '\n' '|' | cut -c1-200)"
n1=$(lines)
cmd x-dsp-disable-both-stopped.txt "pnputil /disable-device \"$ID\"" 180
sleep 5
log "the DSP device asked with both stopped: the serial lines (after serial line $n1):"
norm | tail -n +"$((n1 + 1))" | grep -aE "PNP_|DisableDevice|Safe removal|intcdsp\.sys|dsppcm\.sys|kmixer|sysaudio|wdmaud|streams: released|clock stalled|interrupt storm|Fatal|bugcheck|err:" | grep -av "boot .*after" | cut -c1-420 | tee -a "$EV/driver.log"
if norm | tail -n +"$((n1 + 1))" | grep -aq "Safe removal: CSAUDIO"; then
    sleep 10
    log "model (disabled): $(st)"
    cmd x-media-disabled.txt "pnputil /enum-devices /class Media /ids" 60
    log "while disabled: Media list INTCDSP lines $(pouch_text x-media-disabled.txt | grep -ci INTCDSP)"
    cmd x-enable-both-stopped.txt "pnputil /enable-device \"$ID\"" 180
    waitre "dsppcm\.sys: endpoint .* registered as" 240 "$n1" || log "!! no registration line in 240 s"
    sleep 15
    log "the enable's serial lines:"
    norm | tail -n +"$((n1 + 1))" | grep -aE "intcdsp\.sys: (SelfTest|boot ok|topology|audio child|streams: released)|dsppcm\.sys|Safe removal|clock stalled|Fatal|bugcheck" | grep -av "booting:" | cut -c1-420 | tee -a "$EV/driver.log"
    log "model (D0): $(st)"
fi
log "stop lines in the whole log: $(norm | grep -ac 'The system has been stopped'); fatal lines: $(grep -acE 'Fatal System Error|bugcheck' "$EV/serial.log"); ace_unexpected: $(grep -ac ace_unexpected "$EV/qemu-dbg.log")"
g mon system_powerdown >/dev/null
for i in $(seq 1 120); do [ -n "$LR" ] && [ -e "/proc/$LR" ] || break; sleep 1; done
log "VM $RUN ended: $(grep -a 'qemu exited' "$EV/lib-run.out")"
log "boot4end done"
exit 0
