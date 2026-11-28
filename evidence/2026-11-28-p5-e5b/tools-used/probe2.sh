#!/bin/bash
# probe2.sh -- the E5b probe on the installed overlay of the diag VHD (the first boot done by probe.sh): the
# mmdevapi apitest's devicetopology test and the tip's dsploop_apitest.exe with WINEDEBUG=warn+mmdevapi on
# its own line (the DLL's WARN lines on the serial log), at unity and at -8 dB by the tray's keys; the VM
# ended by the ACPI button.
#   env: RUN (probe2), DISKFILE (the overlay)
set -u
RUN="${RUN:-probe2}"
. /tmp/e5b/tools/vmcommon.sh

log "probe2: $RUN on $DISKFILE, image $(basename "$IMG")"
start_vm
waitre "intcdsp.sys: boot .*after|The system has been stopped" 600 || { log "!! no boot line in 600 s"; g shot 98-no-boot >/dev/null; s5; exit 1; }
if norm | grep -aq "The system has been stopped"; then log "!! the boot STOPPED"; s5; exit 1; fi
sleep 45
for i in 1 2 3 4; do console 2; pouchfind && alive boot && break; sleep 20; done
norm | grep -a -E "SelfTest =|boot ok after|loopback self-test: [0-9]* runs|registered as" | cut -c1-200 | sed 's/^/    /' | tee -a "$EV/driver.log" | head -8
# the probe: the device topology test of the mmdevapi apitests, the DLL's warnings on the serial log
g type "set WINEDEBUG=warn+mmdevapi"; g key ret; sleep 2
N0=$(lines)
cmd probe.txt "%POUCHDRV%\\mmdevapi_apitest.exe devicetopology" 300
sleep 8
N1=$(lines)
log "## the serial lines of the probe (from $N0 to $N1): $(norm | tail -n +"$((N0 + 1))" | head -n $((N1 - N0)) | grep -ac 'mmdevapi')"
norm | tail -n +"$((N0 + 1))" | head -n $((N1 - N0)) | grep -a -v "DIAG-PNP" | cut -c1-420 | sed 's/^/    /' | tee -a "$EV/driver.log" | head -120
# the tip's dsploop at unity, the same warnings
g type "set LIBERNT_APITEST_REQUIRED=1"; g key ret; sleep 2
N1b=$(lines)
cmd dsploop-unity.txt "%POUCHDRV%\\dsploop_apitest.exe" 420
sleep 8
N2=$(lines)
log "## the serial lines of dsploop at unity (from $N1b to $N2)"
norm | tail -n +"$((N1b + 1))" | head -n $((N2 - N1b)) | grep -a -v "DIAG-PNP" | cut -c1-420 | sed 's/^/    /' | tee -a "$EV/driver.log" | head -80
# -8 dB by the tray's keys (Win+D, volumedown x4), as E4b did, then dsploop again
g key meta_l-d; sleep 3
for i in 1 2 3 4; do g key volumedown; sleep 2; done
sleep 3
N2b=$(lines)
cmd dsploop-level.txt "%POUCHDRV%\\dsploop_apitest.exe" 420
sleep 8
N3=$(lines)
log "## the serial lines of dsploop at -8 dB (from $N2b to $N3)"
norm | tail -n +"$((N2b + 1))" | head -n $((N3 - N2b)) | grep -a -v "DIAG-PNP" | cut -c1-420 | sed 's/^/    /' | tee -a "$EV/driver.log" | head -80
g shot 90-end >/dev/null
s5
log "done: fatal $(grep -acE 'Fatal System Error|bugcheck' "$EV/serial.log"), ace_unexpected $(grep -ac ace_unexpected "$EV/qemu-dbg.log")"
