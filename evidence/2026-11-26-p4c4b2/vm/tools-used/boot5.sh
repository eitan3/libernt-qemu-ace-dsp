#!/bin/bash
# boot5.sh -- VM 5 of the p4c4b2 round: a fresh overlay's first boot with the data disk; then, in
# ONE disable/enable cycle, SelfTest = 2 (run 1's self-test half, the brief's run 1: the three
# runs at the D0 entry) and run 1's lines (the child and the endpoint's, which follow the
# self-test at the same D0 entry); SelfTest = 0; the device lists; then dsploop_apitest with the
# live read of the streams' descriptor lists (run 2, boot1.sh's part as the p4c4b round wrote
# it, with a launch check read from the serial log alone and one typed retry); the Sound applet
# (screenshots for the record); the S5.
# Why the order differs from boot1.sh (p4c4b's run 1 then its run 2): on this image the second
# disable of the DSP device -- the one with the PCM child present -- fails ('Failed to disable
# device: A device attached to the system is not functioning', VM 1), so a cycle after run 1's
# cycle cannot bring the D0 entry the self-test needs.  The first disable, with no child yet,
# completes (VM 1, run 1).  Nothing else differs from boot1.sh's flow.
set -u
RUN="${RUN:-r5-firstboot-cycle-selftest2-dsploop-live}"
OVERLAY="${OVERLAY:-p4c4b2-st2}"
. /tmp/qad-ev/p4c4b2/tools/vmcommon.sh
log "boot5: $RUN on disk/$OVERLAY.qcow2"
start_vm
waitfor "Storage expansion not offered|The system has been stopped" 900 || log "!! neither the first-boot setup's line nor a stop line in 900 s"
if norm | grep -aq "The system has been stopped"; then
    log "!! the first boot STOPPED; its lines:"
    norm | grep -anE "KsCreateBusEnumObject|The system has been stopped|Stop code|Parameter [1-4]|^ *#[0-9][0-9] |RIP=" | cut -c1-300 | tee -a "$EV/driver.log"
    exit 1
fi
log "run 0 (with the data disk): the first boot's lines:"
norm | grep -aE "KsCreateBusEnumObject|Safe removal: ROOT|First-boot setup|Storage expansion not offered|intcdsp\.sys: (BootDsp|SelfTest)" | cut -c1-300 | tee -a "$EV/driver.log"
log "stop lines in the boot's log: $(norm | grep -ac 'The system has been stopped'); ace_unexpected: $(grep -ac ace_unexpected "$EV/qemu-dbg.log")"
sleep 5
g shot s1-desktop-before-wizard >/dev/null
wizard 15
g shot s2-after-wizard >/dev/null
console
g shot s3-console >/dev/null
regadd BootDsp REG_DWORD 1
regadd Topology REG_SZ sof-ipc4-loopback.tplg
regadd SelfTest REG_DWORD 2
pouchfind || true
totext exe-hash.txt "certutil -hashfile %POUCHDRV%:\\dsploop_apitest.exe SHA256"
g shot s4-reg-add-hash >/dev/null
# the one cycle: the disable (no child yet), the enable: the self-test at the D0 entry, then the child and the endpoints
n0=$(lines)
g type "pnputil /disable-device \"$ID\""; g key ret
waitfor "Safe removal" 60 "$n0" || log "!! the disable was not seen"
sleep 3
g type "pnputil /enable-device \"$ID\""; g key ret
waitfor "loopback self-test: ran \(|self-test: .* failed|not captured" 300 "$n0" || log "!! no 'ran (' line in 300 s"
sleep 10
log "the cycle's driver lines (after serial line $n0):"
norm | tail -n +"$((n0 + 1))" | grep -aE "intcdsp\.sys|dsppcm\.sys|Safe removal|PNP_Disable|DisableDevice|clock stalled|interrupt storm|Work queue|Fatal|bugcheck" \
    | grep -av "BAR4\|NHLT\|reading BAR4\|HFINTIPPTR\|interrupts before\|subsystem powered\|code-loader\|ROM ready\|FW_READY" \
    | cut -c1-420 | tee -a "$EV/driver.log"
regadd SelfTest REG_DWORD 0
sleep 10
totext enum-media.txt "pnputil /enum-devices /class Media /ids"
sleep 8
totext enum-endpoint.txt "pnputil /enum-devices /class AudioEndpoint /ids"
sleep 8
log "the lists on the data disk: enum-media.txt $(pouch_text enum-media.txt | wc -l) lines, $(pouch_text enum-media.txt | grep -ci 'INTCDSP') INTCDSP lines; enum-endpoint.txt $(pouch_text enum-endpoint.txt | wc -l) lines; exe-hash.txt: $(pouch_text exe-hash.txt | cut -c1-150)"
g shot s5-lists >/dev/null
# run 2: dsploop_apitest through the audio stack; livecap.py sends the Enter and stops the VM at
# each of the first three latency lines until an input and an output stream both run.  The launch
# is read from the serial log alone while livecap holds the monitor; a launch without a driver
# line is typed once more.
launch() {
    L0=$(lines); LN=$L0
    g type "%POUCHDRV%\\dsploop_apitest.exe > %POUCHDRV%:\\dsploop-out.txt"
    log "typed the apitest's command line without Enter (attempt $1, serial line $L0)"
    LIVECAP_SENDKEY=ret LIVECAP_TIMEOUT=240 python3 "$T/livecap.py" "$SOCK" "$EV/serial.log" "$EV" \
        "r16=: latency: fifo" "r24=: latency: fifo" "r32=: latency: fifo" > "$EV/livecap-$1.out" 2>&1 &
    LCP=$!
}
LAUNCHRE="dsppcm\.sys: endpoint .* pin created|intcdsp\.sys: stream [0-9]+: latency|the DSP gives no stream|the pin.s format is refused"
launch 1
if waitfor "$LAUNCHRE" 150 "$LN"; then
    log "the apitest launched: its first driver line came (attempt 1)"
else
    log "!! no driver line of the apitest in 150 s after the Enter (attempt 1)"
    wait_livecap
    g shot s6-launch-1-no-driver-line >/dev/null
    launch 2
    if waitfor "$LAUNCHRE" 150 "$LN"; then log "the apitest launched: its first driver line came (attempt 2)"
    else log "!! no driver line of the apitest in 150 s after the Enter (attempt 2)"; fi
fi
sleep 15
for i in $(seq 1 240); do
    if pouch_text dsploop-out.txt | grep -q "tests executed"; then
        log "the apitest ended its output after about $((15 + 2 * i)) s: $(pouch_text dsploop-out.txt | tail -1 | cut -c1-200)"
        break
    fi
    sleep 2
done
pouch_text dsploop-out.txt | grep -q "tests executed" || log "!! the apitest's output shows no 'tests executed' line in 495 s"
wait_livecap
sleep 3
totext dsploop-rc.txt "echo %ERRORLEVEL%"
g shot s7-after-dsploop >/dev/null
log "run 2: the apitest's output as the guest wrote it (dsploop-out.txt):"
pouch_text dsploop-out.txt | cut -c1-330 | tee -a "$EV/driver.log"
log "run 2: exit code line (dsploop-rc.txt): $(pouch_text dsploop-rc.txt | tr '\n' ' ')"
log "run 2: driver lines of the apitest (after serial line $LN):"
norm | tail -n +"$((LN + 1))" | grep -aE "intcdsp\.sys: (endpoint|stream )|dsppcm\.sys|latency|clock stalled|interrupt storm|Work queue|Fatal|bugcheck" | cut -c1-330 | tee -a "$EV/driver.log"
# the Sound applet for the record only (screenshots; nothing is read from them to decide anything)
g type "mmsys.cpl"; g key ret; sleep 30
g shot s8-sound-playback >/dev/null
g key ctrl-tab; sleep 6
g shot s9-sound-recording >/dev/null
g key esc; sleep 3
g shot s10-after-sound >/dev/null
s5
log "boot5 done"
