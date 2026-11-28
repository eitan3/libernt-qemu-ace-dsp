#!/bin/bash
# proof.sh -- the E5b proof VM: a fresh first-boot overlay over the diag VHD (the tip's drivers and mmdevapi.dll,
# the baked INF defaults: the DSP boots by itself), the wizard, the console, then dsploop_apitest.exe (the walk's
# direction fixed, carried by the data disk) at -8 dB set by the tray's keys, then at unity; a new console for
# each run (Win+D leaves the desktop in front), the drive letter typed explicit (POUCHDRV% in a typed line did
# not launch the exe in this image); the VM ended by the ACPI button.
#   env: RUN (proof), DISKFILE (the overlay), SRC (the directory holding dsploop_apitest.exe)
set -u
RUN="${RUN:-proof}"
. /tmp/e5b/tools/vmcommon.sh

runexe() {
    local F="$1" N0 N1 i
    N0=$(lines)
    mdel -i "$POUCH@@$POUCHOFF" "::$F" >/dev/null 2>&1
    console 2
    g type "set LIBERNT_APITEST_REQUIRED=1"; g key ret; sleep 2
    g type "${PDRV}:\\dsploop_apitest.exe > ${PDRV}:\\$F 2>&1"; g key ret
    for i in $(seq 1 420); do
        [ -n "$(pouch_text "$F" 2>/dev/null | grep -a 'tests executed')" ] && { sleep 3; break; }
        sleep 1
    done
    log "## dsploop ($F): the output after about $i s"
    pouch_text "$F" | tee "$EV/$F" | sed 's/^/    /' | tee -a "$EV/driver.log"
    sleep 4
    N1=$(lines)
    log "## the driver's lines of the run (serial $N0 to $N1):"
    norm | tail -n +"$((N0 + 1))" | head -n $((N1 - N0)) | grep -a -E "intcdsp\.sys: (gain:|boot at stream|endpoint 'Loopback' render: stream)|dsppcm\.sys: endpoint 'Loopback' render: pin created|dsploop" | cut -c1-240 | sed 's/^/    /' | tee -a "$EV/driver.log" | head -20
}

log "proof: $RUN on $DISKFILE, image $(basename "$IMG"), the exe $(sha256sum "$SRC/dsploop_apitest.exe" | cut -c1-16)"
start_vm
waitre "Storage expansion not offered|The system has been stopped|Program Manager" 900 || { log "!! neither the first-boot setup's line nor a stop line in 900 s"; g shot 00-no-setup-line >/dev/null; s5; exit 1; }
if norm | grep -aq "The system has been stopped"; then log "!! the first boot STOPPED"; s5; exit 1; fi
log "first boot: the desktop (or the setup) reached after $(lines) serial lines"
wizard 25
for i in 1 2 3; do console 3; pouchfind && alive first && break; sleep 15; done
waitre "loopback self-test: [0-9]* runs" 120 || log "-- no self-test summary in 120 s (the baked defaults)"
norm | grep -a -E "SelfTest =|boot ok after|loopback self-test: [0-9]* runs|registered as" | cut -c1-220 | sed 's/^/    /' | tee -a "$EV/driver.log" | head -8
# -8 dB by the tray's keys (Win+D, volumedown x4), as E4b did
g key meta_l-d; sleep 3
for i in 1 2 3 4; do g key volumedown; sleep 2; done
sleep 3
N0=$(lines)
log "## the tray's keys: $(norm | tail -n +"$((N0 - 40))" | grep -a 'gain: ' | tail -4 | cut -c1-120 | tr '\n' '|')"
runexe dsploop-level.txt
g shot 30-level >/dev/null
# unity: Win+D, volumeup x4 (E4b: -8.00 to 0.00 dB)
g key meta_l-d; sleep 3
for i in 1 2 3 4; do g key volumeup; sleep 2; done
sleep 3
N0=$(lines)
log "## the tray's keys: $(norm | tail -n +"$((N0 - 40))" | grep -a 'gain: ' | tail -4 | cut -c1-120 | tr '\n' '|')"
runexe dsploop-unity.txt
g shot 90-end >/dev/null
s5
log "done: fatal $(grep -acE 'Fatal System Error|bugcheck' "$EV/serial.log"), ace_unexpected $(grep -ac ace_unexpected "$EV/qemu-dbg.log")"
