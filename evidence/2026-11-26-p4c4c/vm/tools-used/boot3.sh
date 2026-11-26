#!/bin/bash
# boot3.sh -- VM 3 of the p4c4c round: a fresh overlay's first boot with the data disk;
# BootDsp = 1, Topology = sof-ipc4-loopback.tplg, SelfTest = 0; the one cycle that brings the
# child (the disable completes: no child exists yet): run 1's lines at the D0 entry; the lists
# and the MMDevices registry to the data disk; then
#   C10 -- a disable of the DSP device with the audio service running: expected REFUSED (the
#          upstream veto); pnputil's own text and the serial lines recorded;
#   C11 -- the audio service stopped (the running services listed first, its name taken from
#          the list), then three disable/enable cycles with the child present: the child and
#          its endpoints go and return (the lists while disabled), the model's registers read
#          over qtest before and after each, the serial lines of each;
#   the pin-open attempt -- the apitest in a loop (each iteration to its own file on the data
#          disk) in a second console across a fourth cycle: the iterations that straddle the
#          disable are the generation check's rows;
#   E16 (N5-05) -- pnputil /restart-device on the codec, with the service still stopped;
# then the S5.  Every command's own text comes from the data disk.
set -u
RUN="${RUN:-r3-topology-pnp-cycles}"
OVERLAY="${OVERLAY:-p4c4c-tp}"
. /tmp/qad-ev/p4c4c/tools/vmcommon.sh
st() { python3 "$QAD/tools/qtest.py" "$(cat "$EV/sock-dir.txt")/qtest.sock" adspcs dsp2cxctl inten irqsts hfhipcie hfipcxtdr hfipcxida hfipcxctl hfipcxtddy fsr | awk '{printf "%s=%s ", $NF, substr($4, 11, 8)}'; echo; }
log "boot3: $RUN on disk/$OVERLAY.qcow2"
start_vm
waitre "Storage expansion not offered|The system has been stopped" 900 || log "!! neither the first-boot setup's line nor a stop line in 900 s"
if norm | grep -aq "The system has been stopped"; then
    log "!! the first boot STOPPED; its lines:"
    norm | grep -anE "KsCreateBusEnumObject|The system has been stopped|Stop code|Parameter [1-4]|^ *#[0-9][0-9] |RIP=" | cut -c1-300 | tee -a "$EV/driver.log"
    s5
    exit 1
fi
log "A1: the first boot's lines:"
norm | grep -aE "KsCreateBusEnumObject|Safe removal|First-boot setup|Storage expansion not offered|intcdsp\.sys: (BootDsp|SelfTest)|Program Manager" | cut -c1-300 | tee -a "$EV/driver.log"
log "stop lines in the boot's log: $(norm | grep -ac 'The system has been stopped'); storport timeouts: $(norm | grep -ac 'Storport: a request'); ace_unexpected: $(grep -ac ace_unexpected "$EV/qemu-dbg.log")"
sleep 5
g shot s1-desktop-before-wizard >/dev/null
wizard 15
g shot s2-after-wizard >/dev/null
sleep 20
g shot s3-after-wizard-20s >/dev/null
console
if ! pouchfind; then g shot s4-no-data-disk-letter >/dev/null; log "!! the console did not find the data disk: stopped here"; exit 1; fi
alive firstboot || { g shot s4b-console-silent >/dev/null; log "!! the console is silent: stopped here"; exit 1; }
regadd BootDsp REG_DWORD 1
regadd Topology REG_SZ sof-ipc4-loopback.tplg
regadd SelfTest REG_DWORD 2      # B7's D0-entry variant: the self-test runs at the cycle's D0 entry (as p4c4b2's r5 took it)
# the cycle that brings the child: the disable completes (no child yet), the enable boots the DSP with the topology
n0=$(lines)
cmd x-c1-disable.txt "pnputil /disable-device \"$ID\"" 120
waitre "Safe removal: CSAUDIO" 120 "$n0" || log "!! the first disable was not seen"
sleep 3
cmd x-c1-enable.txt "pnputil /enable-device \"$ID\"" 120
waitre "loopback self-test: ran \(|self-test: .* failed|not captured" 300 "$n0" || log "!! no 'ran (' line in 300 s"
waitre "dsppcm\.sys: endpoint .* registered as" 240 "$n0" || log "!! no registration line in 240 s"
sleep 15
log "B7 (D0 entry) and run 1 at the cycle (after serial line $n0):"
norm | tail -n +"$((n0 + 1))" | grep -aE "intcdsp\.sys: (SelfTest|BootDsp = |boot ok|topology|ipc: link|firmware ready|DSP power down|audio child|loopback self-test)|dsppcm\.sys|Safe removal|clock stalled|interrupt storm|Work queue|Fatal|bugcheck" \
    | grep -av "booting:" | cut -c1-420 | tee -a "$EV/driver.log"
log "ace_audio lines of the VM: $(grep -ac '^ace_audio ' "$EV/qemu-dbg.log")"
regadd SelfTest REG_DWORD 0
cmd enum-media.txt "pnputil /enum-devices /class Media /ids" 60
cmd enum-endpoint.txt "pnputil /enum-devices /class AudioEndpoint /ids" 60
cmd reg-mmdev.txt "reg query HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\MMDevices\\Audio /s" 90
log "the lists: enum-media.txt $(pouch_text enum-media.txt | grep -ci 'INTCDSP') INTCDSP lines; enum-endpoint.txt $(pouch_text enum-endpoint.txt | grep -ci 'Loopback') Loopback lines; reg-mmdev.txt $(pouch_text reg-mmdev.txt | grep -c 'Intel SST Loopback') 'Intel SST Loopback' lines"
# C10: the disable with the audio service running -- expected refused
n1=$(lines)
cmd x-c10-disable.txt "pnputil /disable-device \"$ID\"" 150
sleep 5
log "C10: the serial lines of the disable (after serial line $n1):"
norm | tail -n +"$((n1 + 1))" | grep -aE "PNP_|DisableDevice|Safe removal|intcdsp\.sys|dsppcm\.sys|umpnpmgr|veto|Veto|clock stalled|interrupt storm|Work queue|Fatal|bugcheck|err:" | grep -av "boot .*after" | cut -c1-420 | tee -a "$EV/driver.log"
log "C10: Safe removal lines after the ask: $(norm | tail -n +"$((n1 + 1))" | grep -ac 'Safe removal')"
cmd x-c10-media.txt "pnputil /enum-devices /class Media /ids" 60
log "C10: the Media list after the refused disable: $(pouch_text x-c10-media.txt | grep -aE "INTCDSP|Status" | tr -d '\r' | tr '\n' ' ' | cut -c1-400)"
g shot s5-after-c10 >/dev/null
# C11: the audio service stopped
cmd x-svc-list.txt "net start" 60
log "the running services (net start), the audio lines: $(pouch_text x-svc-list.txt | grep -ai "audio" | tr -d '\r' | tr '\n' '|')"
nm=$(pouch_text x-svc-list.txt | grep -ai "audio" | head -1 | tr -d '\r' | sed 's/^ *//;s/ *$//')
if [ -n "$nm" ]; then cmd x-svc-stop.txt "net stop \"$nm\"" 180; else cmd x-svc-stop.txt "net stop audiosrv" 180; fi
cmd x-svc-after.txt "net start | findstr /i audio" 60
log "C11: the audio services still running (net start | findstr /i audio): '$(pouch_text x-svc-after.txt | tr -d '\r' | tr '\n' '|')'"
# one cycle with the child present
cyc() {   # cyc <label>
    local l=$1 n i
    n=$(lines)
    cmd "x-$l-disable.txt" "pnputil /disable-device \"$ID\"" 180
    waitre "Safe removal: CSAUDIO" 180 "$n" || log "!! $l: the DSP device's Safe removal did not come"
    sleep 10
    log "$l: the serial lines of the disable (after serial line $n):"
    norm | tail -n +"$((n + 1))" | grep -aE "intcdsp\.sys|dsppcm\.sys|Safe removal|PNP_|DisableDevice|umpnpmgr|kmixer|sysaudio|wdmaud|portcls|clock stalled|interrupt storm|Work queue|Fatal|bugcheck|err:" | grep -av "boot .*after" | cut -c1-420 | tee -a "$EV/driver.log"
    log "$l: model (disabled): $(st)"
    cmd "x-$l-media-disabled.txt" "pnputil /enum-devices /class Media /ids" 60
    cmd "x-$l-endpoint-disabled.txt" "pnputil /enum-devices /class AudioEndpoint /ids" 60
    log "$l: while disabled: Media list INTCDSP lines $(pouch_text "x-$l-media-disabled.txt" | grep -ci INTCDSP), AudioEndpoint Loopback lines $(pouch_text "x-$l-endpoint-disabled.txt" | grep -ci Loopback)"
    cmd "x-$l-enable.txt" "pnputil /enable-device \"$ID\"" 180
    waitre "dsppcm\.sys: endpoint .* registered as" 240 "$n" || log "!! $l: no registration line in 240 s"
    sleep 15
    log "$l: the serial lines of the enable:"
    norm | tail -n +"$((n + 1))" | grep -aE "intcdsp\.sys: (SelfTest|BootDsp = |boot ok|topology|ipc: link|DSP power down|audio child|streams: released)|dsppcm\.sys|Safe removal|clock stalled|interrupt storm|Work queue|Fatal|bugcheck|err:" | grep -av "booting:" | cut -c1-420 | tee -a "$EV/driver.log"
    log "$l: model (D0): $(st)"
    log "stop lines so far: $(norm | grep -ac 'The system has been stopped'); fatal: $(grep -acE 'Fatal System Error|bugcheck' "$EV/serial.log")"
}
cyc c11-1
cyc c11-2
cyc c11-3
# the pin-open attempt: the apitest in a loop in a second console, a fourth cycle in a third
cmd x-copy.txt "copy %POUCHDRV%\\dsploop_apitest.exe C:\\dsploop_apitest.exe" 40
console
g type "for /L %i in (1,1,10) do @C:\\dsploop_apitest.exe > %POUCHDRV%:\\lap-%i.txt 2>&1"; g key ret
log "the apitest loop typed in a second console (10 iterations, each to its own file); 90 s before the fourth cycle"
sleep 90
console
cyc c11-4-pinopen
for i in $(seq 1 300); do
    [ "$(pouch_ls | grep -c 'lap-')" -ge 10 ] && break
    sleep 2
done
log "the loop: $(pouch_ls | grep -c 'lap-') lap files after the wait"
for i in $(seq 1 12); do
    [ -n "$(pouch_text "lap-$i.txt" 2>/dev/null)" ] && log "lap-$i.txt: $(pouch_text "lap-$i.txt" | tr -d '\r' | grep -aE "dsploop|frames compared|depths|skipped|failed|error|0x8" | tr '\n' '|' | cut -c1-600)"
done
for i in $(seq 1 12); do
    [ -n "$(pouch_text "lap-$i.txt" 2>/dev/null)" ] && pouch_text "lap-$i.txt" > "$EV/lap-$i.txt"
done
# E16 (N5-05): the codec restarted with the audio service still stopped
n2=$(lines)
cmd x-n5-05.txt "pnputil /restart-device \"$CODEC\"" 180
sleep 5
log "N5-05: the serial lines of the codec's restart (after serial line $n2):"
norm | tail -n +"$((n2 + 1))" | grep -aE "PNP_|DisableDevice|EnableDevice|RestartDevice|Safe removal|hdaudbus|hdaudio|HDAUDIO|kmixer|sysaudio|wdmaud|clock stalled|interrupt storm|Work queue|Fatal|bugcheck|err:" | cut -c1-420 | tee -a "$EV/driver.log"
cmd x-n5-05-media.txt "pnputil /enum-devices /class Media /ids" 60
log "stop lines in the whole log: $(norm | grep -ac 'The system has been stopped'); fatal lines: $(grep -acE 'Fatal System Error|bugcheck' "$EV/serial.log"); ace_unexpected: $(grep -ac ace_unexpected "$EV/qemu-dbg.log")"
g shot s6-end >/dev/null
s5
log "boot3 done"
exit 0
