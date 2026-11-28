#!/bin/bash
# probe.sh -- the E5b probe VM: a fresh first-boot overlay over the diag VHD (the tip's mmdevapi.dll, the
# baked INF defaults: the DSP boots by itself), the wizard, the console; then the mmdevapi apitest's
# devicetopology test and the tip's dsploop_apitest.exe with WINEDEBUG=warn+mmdevapi (the DLL's WARN lines on
# the serial log), at unity and at -8 dB by the tray's keys; the VM ended by the ACPI button.
#   env: RUN (probe), DISKFILE (the overlay)
set -u
RUN="${RUN:-probe}"
. /tmp/e5b/tools/vmcommon.sh
ID='CSAUDIO\ADSP&CTLR_VEN_8086&CTLR_DEV_7F50\4&aeefd634&0&1000000000'

log "probe: $RUN on $DISKFILE, image $(basename "$IMG")"
start_vm
waitre "Storage expansion not offered|The system has been stopped|Program Manager" 900 || { log "!! neither the first-boot setup's line nor a stop line in 900 s"; g shot 00-no-setup-line >/dev/null; s5; exit 1; }
if norm | grep -aq "The system has been stopped"; then log "!! the first boot STOPPED"; s5; exit 1; fi
log "first boot: the desktop (or the setup) reached after $(lines) serial lines"
wizard 25
for i in 1 2 3; do console 3; pouchfind && alive first && break; sleep 15; done
waitre "loopback self-test: [0-9]* runs" 120 || log "-- no self-test summary in 120 s (the baked defaults)"
norm | grep -a -E "SelfTest =|boot ok after|loopback self-test: [0-9]* runs|registered as|endpoint '" | cut -c1-260 | sed 's/^/    /' | tee -a "$EV/driver.log" | head -12
N0=$(lines)
# the probe: the device topology test of the mmdevapi apitests, the DLL's warnings on the serial log
cmd probe.txt "set \"WINEDEBUG=warn+mmdevapi\"&& %POUCHDRV%\\mmdevapi_apitest.exe devicetopology" 240
sleep 5
N1=$(lines)
log "## the serial lines of the probe (from $N0 to $N1): $(norm | tail -n +"$((N0 + 1))" | head -n $((N1 - N0)) | grep -ac 'mmdevapi')"
norm | tail -n +"$((N0 + 1))" | head -n $((N1 - N0)) | grep -a -i "mmdevapi\|warn\|err:" | cut -c1-400 | sed 's/^/    /' | tee -a "$EV/driver.log" | head -80
# the tip's dsploop at unity, the same warnings
cmd dsploop-unity.txt "set LIBERNT_APITEST_REQUIRED=1&& %POUCHDRV%\\dsploop_apitest.exe" 300
sleep 5
N2=$(lines)
log "## the serial lines of dsploop at unity (from $N1 to $N2)"
norm | tail -n +"$((N1 + 1))" | head -n $((N2 - N1)) | grep -a -i "mmdevapi\|warn\|err:" | cut -c1-400 | sed 's/^/    /' | tee -a "$EV/driver.log" | head -60
# -8 dB by the tray's keys (Win+D, volumedown x4), as E4b did, then dsploop again
g key meta_l-d; sleep 3
for i in 1 2 3 4; do g key volumedown; sleep 2; done
sleep 3
cmd dsploop-level.txt "set LIBERNT_APITEST_REQUIRED=1&& %POUCHDRV%\\dsploop_apitest.exe" 300
sleep 5
N3=$(lines)
log "## the serial lines of dsploop at -8 dB (from $N2 to $N3)"
norm | tail -n +"$((N2 + 1))" | head -n $((N3 - N2)) | grep -a -i "mmdevapi\|warn\|err:\|gain:" | cut -c1-400 | sed 's/^/    /' | tee -a "$EV/driver.log" | head -60
g shot 90-end >/dev/null
s5
log "done: fatal $(grep -acE 'Fatal System Error|bugcheck' "$EV/serial.log"), ace_unexpected $(grep -ac ace_unexpected "$EV/qemu-dbg.log")"
