#!/bin/bash
# boot5.sh -- VM 5 of the p4c4c round: the stream, second attempt.  VM 1 could not bring the
# apitest from the data disk (both the launch by its absolute path and `copy` answered 'The system
# cannot find the path specified.' while certutil hashed the same file), so the test never ran
# there.  This VM boots VM 1's overlay (BootDsp = 1 and the topology persisted: the DSP boots
# with its child at the system boot) with a data disk that carries the exe under its long name
# and under the 8.3 name dsploop.exe; it probes the data disk by both names (dir, copy, the
# hash of the copy; the launch from the data disk by both names: E24's rows), then runs the
# apitest from the system disk under LIBERNT_APITEST_REQUIRED=1 (B5), the gate rule on its
# output, its driver lines (B6), the lists and the MMDevices registry (B4); the S5.
set -u
RUN="${RUN:-r5-plainboot-stream}"
OVERLAY="${OVERLAY:-p4c4c}"
. /tmp/qad-ev/p4c4c/tools/vmcommon.sh
log "boot5: $RUN on disk/$OVERLAY.qcow2 (VM 1's overlay)"
start_vm
waitre "dsppcm\.sys: endpoint .* registered as|The system has been stopped|topology: none selected" 900 || log "!! no registration line in 900 s"
sleep 10
log "the boot's driver lines:"
norm | grep -aE "intcdsp\.sys: (SelfTest|BootDsp = |boot ok|topology|ipc: link|firmware ready|DSP power down|audio child|loopback self-test)|dsppcm\.sys|clock stalled|interrupt storm|Work queue|Fatal|bugcheck" | grep -av "booting:" | cut -c1-420 | tee -a "$EV/driver.log"
waitre "Program Manager" 900 || log "!! the shell did not come up in 900 s"
sleep 20
g shot s1-desktop >/dev/null
console
pouchfind || { g shot s2-no-data-disk-letter >/dev/null; log "!! the data disk was not found: stopped here"; exit 1; }
alive boot || { g shot s3-console-silent >/dev/null; log "!! the console is silent: stopped here"; exit 1; }
# the data disk by its two names
cmd x-dir-D.txt "dir %POUCHDRV%:\\ /x" 30
cmd x-dir-lfn.txt "dir %POUCHDRV%:\\dsploop_apitest.exe" 30
cmd x-dir-short.txt "dir %POUCHDRV%:\\dsploop.exe" 30
cmd x-certutil-short.txt "certutil -hashfile %POUCHDRV%:\\dsploop.exe SHA256" 30
cmd x-copy-short.txt "copy %POUCHDRV%:\\dsploop.exe C:\\dsploop_apitest.exe" 40
cmd x-copy-lfn.txt "copy %POUCHDRV%:\\dsploop_apitest.exe C:\\x-lfn.exe" 40
cmd x-certutil.txt "certutil -hashfile C:\\dsploop_apitest.exe SHA256" 30
# E24: the launch from the data disk, by both names
cmd x-launch-pouch.txt "%POUCHDRV%:\\dsploop_apitest.exe" 240
cmd x-launch-short.txt "%POUCHDRV%:\\dsploop.exe" 240
# B5: the stream from the system disk under the required switch
n1=$(lines)
g type "set LIBERNT_APITEST_REQUIRED=1"; g key ret; sleep 3
log "typed: set LIBERNT_APITEST_REQUIRED=1 (serial line $n1)"
cmd dsploop-out.txt "C:\\dsploop_apitest.exe" 900
sleep 3
cmd dsploop-rc.txt "echo %ERRORLEVEL%" 30
pouch_text dsploop-out.txt > "$EV/dsploop-out.txt"
log "B5: the apitest's output as the guest wrote it (dsploop-out.txt, $(wc -l < "$EV/dsploop-out.txt") lines):"
cut -c1-330 "$EV/dsploop-out.txt" | tee -a "$EV/driver.log"
log "B5: the gate rule on it (apitest-gate.sh --required):"
bash <home>/libernt-build-logs/tools/apitest-gate.sh --required "$EV/dsploop-out.txt" 2>&1 | tee -a "$EV/driver.log"
log "gate rc=${PIPESTATUS[0]}"
log "B6: the apitest's driver lines (after serial line $n1):"
norm | tail -n +"$((n1 + 1))" | grep -aE "intcdsp\.sys: (endpoint|stream |pin )|dsppcm\.sys|latency|clock stalled|interrupt storm|Work queue|Fatal|bugcheck" | cut -c1-420 | tee -a "$EV/driver.log"
log "ace_audio lines of the VM so far: $(grep -ac '^ace_audio ' "$EV/qemu-dbg.log"); ace_unexpected: $(grep -ac ace_unexpected "$EV/qemu-dbg.log")"
g shot s4-after-dsploop >/dev/null
# B4: the device lists and the MMDevices registry, as the guest holds them
cmd enum-media.txt "pnputil /enum-devices /class Media /ids" 60
cmd enum-endpoint.txt "pnputil /enum-devices /class AudioEndpoint /ids" 60
cmd reg-mmdev.txt "reg query HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\MMDevices\\Audio /s" 90
log "B4: enum-media.txt: $(pouch_text enum-media.txt | grep -ci 'INTCDSP') INTCDSP lines; enum-endpoint.txt: $(pouch_text enum-endpoint.txt | grep -ci 'Loopback') Loopback lines; reg-mmdev.txt: $(pouch_text reg-mmdev.txt | grep -c 'Intel SST Loopback') 'Intel SST Loopback' lines"
log "stop lines in the whole log: $(norm | grep -ac 'The system has been stopped'); fatal lines: $(grep -acE 'Fatal System Error|bugcheck' "$EV/serial.log")"
s5
log "boot5 done"
exit 0
