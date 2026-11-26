#!/bin/bash
# boot3b.sh -- the take-over of VM 3 of the p4c4c round after boot3.sh was stopped by me: with the
# audio service stopped (net stop audiosrv: no text; the service's PnP notification registration
# unregistered in the serial log) the disable of the DSP device with the child present was STILL
# refused (x-c11-1-disable.txt), so the script's three cycles could only have waited.  This script
# reads the state (the service keys and their states), asks the child alone and the codec with the
# service stopped, tries the one other audio service there is (if the registry names one), records
# N5-05 (the codec's restart) with the service stopped, opens the Sound applet for a screenshot,
# and takes the S5.  Every command's own text comes from the data disk.
set -u
RUN="${RUN:-r3-topology-pnp-cycles}"
OVERLAY="${OVERLAY:-p4c4c-tp}"
. /tmp/qad-ev/p4c4c/tools/vmcommon.sh
st() { python3 "$QAD/tools/qtest.py" "$(cat "$EV/sock-dir.txt")/qtest.sock" adspcs dsp2cxctl inten irqsts hfhipcie hfipcxtdr hfipcxida hfipcxctl hfipcxtddy fsr | awk '{printf "%s=%s ", $NF, substr($4, 11, 8)}'; echo; }
LR=$(pgrep -f "^bash lib-run.sh$" | head -1)
SOCK=$(cat "$EV/sock-dir.txt")
PDRV=$(pouch_text drive.txt | tr -d ' \n')
log "boot3b: taking the running VM over (lib-run.sh pid $LR, sockets $SOCK, the data disk on $PDRV: in the guest); boot3.sh was stopped by me after the disable with the service stopped was refused"
# the state: the service keys with 'audio' or 'endpoint' in their names, and their states
cmd x-svc-keys.txt "reg query HKLM\\SYSTEM\\CurrentControlSet\\Services | findstr /i \"audio endpoint\"" 40
log "the service keys: $(pouch_text x-svc-keys.txt | tr -d '\r' | tr '\n' '|')"
for s in $(pouch_text x-svc-keys.txt | tr -d '\r' | grep -aoE "Services\\\\[A-Za-z0-9_]+$" | sed 's/.*\\//'); do
    cmd "x-svcq-$s.txt" "sc query $s" 40
    log "sc query $s: $(pouch_text "x-svcq-$s.txt" | tr -d '\r' | tr '\n' '|' | cut -c1-300)"
done
# the child alone and the codec, with the service stopped
n0=$(lines)
cmd x-c11-child-disable.txt "pnputil /disable-device \"$CHILD\"" 150
sleep 3
cmd x-c11-codec-disable.txt "pnputil /disable-device \"$CODEC\"" 150
sleep 3
log "the serial lines of the two asks (after serial line $n0):"
norm | tail -n +"$((n0 + 1))" | grep -aE "PNP_|DisableDevice|Safe removal|intcdsp\.sys|dsppcm\.sys|umpnpmgr|kmixer|sysaudio|wdmaud|portcls|clock stalled|interrupt storm|Work queue|Fatal|bugcheck|err:" | grep -av "boot .*after" | cut -c1-420 | tee -a "$EV/driver.log"
# the one other audio service, if the registry names one that is running: stopped, then the DSP device asked once more
other=$(for s in $(pouch_text x-svc-keys.txt | tr -d '\r' | grep -aoE "Services\\\\[A-Za-z0-9_]+$" | sed 's/.*\\//' | grep -viE "^audiosrv$"); do pouch_text "x-svcq-$s.txt" 2>/dev/null | grep -aq "RUNNING" && echo "$s"; done | head -1)
if [ -n "$other" ]; then
    cmd "x-svc-stop-$other.txt" "net stop $other" 180
    n1=$(lines)
    cmd x-c11-dsp-retry.txt "pnputil /disable-device \"$ID\"" 150
    sleep 3
    log "after net stop $other, the DSP device asked again: the serial lines (after serial line $n1):"
    norm | tail -n +"$((n1 + 1))" | grep -aE "PNP_|DisableDevice|Safe removal|intcdsp\.sys|dsppcm\.sys|streams: released|clock stalled|interrupt storm|Work queue|Fatal|bugcheck|err:" | grep -av "boot .*after" | cut -c1-420 | tee -a "$EV/driver.log"
    if norm | tail -n +"$((n1 + 1))" | grep -aq "Safe removal: CSAUDIO"; then
        sleep 10
        log "model (disabled): $(st)"
        cmd x-c11-media-disabled.txt "pnputil /enum-devices /class Media /ids" 60
        cmd x-c11-endpoint-disabled.txt "pnputil /enum-devices /class AudioEndpoint /ids" 60
        log "while disabled: Media list INTCDSP lines $(pouch_text x-c11-media-disabled.txt | grep -ci INTCDSP)"
        cmd x-c11-enable.txt "pnputil /enable-device \"$ID\"" 150
        waitre "dsppcm\.sys: endpoint .* registered as" 240 "$n1" || log "!! no registration line in 240 s"
        sleep 15
        log "the enable's serial lines:"
        norm | tail -n +"$((n1 + 1))" | grep -aE "intcdsp\.sys: (SelfTest|boot ok|topology|audio child|streams: released)|dsppcm\.sys|Safe removal|clock stalled|Fatal|bugcheck" | grep -av "booting:" | cut -c1-420 | tee -a "$EV/driver.log"
        log "model (D0): $(st)"
    fi
fi
# E16 (N5-05): the codec restarted with the service stopped
n2=$(lines)
cmd x-n5-05.txt "pnputil /restart-device \"$CODEC\"" 180
sleep 5
log "N5-05: the serial lines of the codec's restart (after serial line $n2):"
norm | tail -n +"$((n2 + 1))" | grep -aE "PNP_|DisableDevice|EnableDevice|RestartDevice|Safe removal|hdaudbus|hdaudio|HDAUDIO|kmixer|sysaudio|wdmaud|clock stalled|interrupt storm|Work queue|Fatal|bugcheck|err:" | cut -c1-420 | tee -a "$EV/driver.log"
# the Sound applet with the service stopped: one screenshot
g type "mmsys.cpl"; g key ret; sleep 30
g shot s5-sound-service-stopped >/dev/null
g key esc; sleep 2
log "stop lines in the whole log: $(norm | grep -ac 'The system has been stopped'); fatal lines: $(grep -acE 'Fatal System Error|bugcheck' "$EV/serial.log"); ace_unexpected: $(grep -ac ace_unexpected "$EV/qemu-dbg.log"); model now: $(st)"
g mon system_powerdown >/dev/null
for i in $(seq 1 120); do [ -n "$LR" ] && [ -e "/proc/$LR" ] || break; sleep 1; done
log "VM $RUN ended: $(grep -a 'qemu exited' "$EV/lib-run.out")"
log "boot3b done"
exit 0
