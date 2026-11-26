#!/bin/bash
# boot1b.sh -- boot1.sh with three changes, for the workaround of the p4c4b round: the overlay's first
# boot ran WITHOUT an audio controller (probe r0e: with one, the first boot bugchecks before the wizard,
# DIVERGENCE.md U1); the model and the data disk are attached from this, the second boot, on.  Everything
# else is boot1.sh as the stopped round wrote it: the wizard closed by chords, BootDsp = 1 and Topology set
# (SelfTest stays 0), the data disk's drive letter found, the apitest's hash taken in the guest, one
# disable/enable cycle (run 1), the device lists to the data disk, dsploop_apitest with the live read (run 2),
# then SelfTest = 2 and one cycle, SelfTest = 0 for the next boot, the Sound applet (screenshots for the
# record), the S5.
set -u
RUN="${RUN:-r1b-secondboot-ace-dsploop-selftest2}"
. /tmp/qad-ev/p4c4b/tools/vmcommon.sh
log "boot1b: $RUN on disk/$OVERLAY.qcow2 (the overlay's first boot ran without an audio controller: r0e)"
start_vm
waitfor "Storage expansion not offered" 600 || log "!! no storage-expansion line in 600 s: the wizard is tried anyway"
sleep 5
g shot s1-desktop-before-wizard >/dev/null
wizard 15
g shot s2-after-wizard >/dev/null
console
g shot s3-console >/dev/null
regadd BootDsp REG_DWORD 1
regadd Topology REG_SZ sof-ipc4-loopback.tplg
pouchfind || true
totext exe-hash.txt "certutil -hashfile %POUCHDRV%:\\dsploop_apitest.exe SHA256"
g shot s4-reg-add-hash >/dev/null
# run 1: the child and the endpoint at a disable/enable cycle
n0=$(lines)
g type "pnputil /disable-device \"$ID\""; g key ret
waitfor "Safe removal" 60 "$n0" || log "!! the disable was not seen"
sleep 3
g type "pnputil /enable-device \"$ID\""; g key ret
waitfor "dsppcm.sys: endpoint .* registered as" 150 "$n0" || log "!! no registration line in 150 s"
sleep 20
log "run 1: driver lines after the disable (serial line $n0):"
norm | tail -n +"$((n0 + 1))" | grep -aE "intcdsp\.sys|dsppcm\.sys|Safe removal|PNP_DisableDevInst|DisableDeviceInstance|clock stalled|interrupt storm|Work queue|Fatal|bugcheck" \
    | grep -av "firmware \|BAR4\|NHLT\|reading BAR4\|HFINTIPPTR\|interrupts before\|subsystem powered\|code-loader\|ROM ready\|firmware entered\|FW_READY" \
    | cut -c1-330 | tee -a "$EV/driver.log"
sleep 10
totext enum-media.txt "pnputil /enum-devices /class Media /ids"
sleep 8
totext enum-endpoint.txt "pnputil /enum-devices /class AudioEndpoint /ids"
sleep 8
log "the lists on the data disk: enum-media.txt $(pouch_text enum-media.txt | wc -l) lines, $(pouch_text enum-media.txt | grep -ci 'INTCDSP') INTCDSP lines; enum-endpoint.txt $(pouch_text enum-endpoint.txt | wc -l) lines, $(pouch_text enum-endpoint.txt | grep -ci 'Loopback') Loopback lines; exe-hash.txt: $(pouch_text exe-hash.txt | tr '\n' ' ')"
g shot s5-lists >/dev/null
# run 2: dsploop_apitest through the audio stack; livecap.py sends the Enter and stops the VM at
# each run's first latency line until an input and an output stream both run
n1=$(lines)
g type "%POUCHDRV%\\dsploop_apitest.exe > %POUCHDRV%:\\dsploop-out.txt"
log "typed the apitest's command line without Enter (serial line $n1)"
LIVECAP_SENDKEY=ret LIVECAP_TIMEOUT=120 python3 "$T/livecap.py" "$SOCK" "$EV/serial.log" "$EV" \
    "r16=: latency: fifo" "r24=: latency: fifo" "r32=: latency: fifo" > "$EV/livecap.out" 2>&1 &
LCP=$!
sleep 15
for i in $(seq 1 240); do
    if pouch_text dsploop-out.txt | grep -q "tests executed"; then
        log "the apitest ended its output after about $((15 + 2 * i)) s: $(pouch_text dsploop-out.txt | tail -1)"
        break
    fi
    sleep 2
done
pouch_text dsploop-out.txt | grep -q "tests executed" || log "!! the apitest's output shows no 'tests executed' line in 495 s"
wait_livecap
sleep 3
totext dsploop-rc.txt "echo %ERRORLEVEL%"
g shot s6-after-dsploop >/dev/null
log "run 2: the apitest's output as the guest wrote it (dsploop-out.txt):"
pouch_text dsploop-out.txt | cut -c1-330 | tee -a "$EV/driver.log"
log "run 2: exit code line (dsploop-rc.txt): $(pouch_text dsploop-rc.txt | tr '\n' ' ')"
log "run 2: driver lines of the apitest (after serial line $n1):"
norm | tail -n +"$((n1 + 1))" | grep -aE "intcdsp\.sys|dsppcm\.sys|latency|clock stalled|interrupt storm|Work queue|Fatal|bugcheck" \
    | grep -av "boot .*after" | cut -c1-330 | tee -a "$EV/driver.log"
# run 2 of TESTING.md: SelfTest = 2 at one cycle (the sample-exact figure)
regadd SelfTest REG_DWORD 2
n2=$(lines)
g type "pnputil /disable-device \"$ID\""; g key ret
waitfor "Safe removal" 60 "$n2" || log "!! the disable was not seen (self-test cycle)"
sleep 3
g type "pnputil /enable-device \"$ID\""; g key ret
waitfor "loopback self-test: ran \(|self-test: .* failed|not captured" 180 "$n2" || log "!! no 'ran (' line in 180 s"
sleep 5
log "self-test lines of the cycle (after serial line $n2):"
norm | tail -n +"$((n2 + 1))" | grep -aE "loopback self-test|SelfTest = " | cut -c1-330 | tee -a "$EV/driver.log"
regadd SelfTest REG_DWORD 0
g shot s7-selftest0 >/dev/null
# the Sound applet for the record only (screenshots; nothing is read from them to decide anything)
g type "mmsys.cpl"; g key ret; sleep 30
g shot s8-sound-playback >/dev/null
g key ctrl-tab; sleep 6
g shot s9-sound-recording >/dev/null
g key esc; sleep 3
g shot s10-after-sound >/dev/null
s5
log "boot1b done"
