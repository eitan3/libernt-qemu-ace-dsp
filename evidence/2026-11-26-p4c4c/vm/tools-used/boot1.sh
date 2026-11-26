#!/bin/bash
# boot1.sh -- VM 1 of the p4c4c round: the fresh overlay's first boot WITH the data disk
# (TESTING.md A1 with the disk, A2: the desktop usable -- the console answers through the data
# disk); BootDsp = 1, Topology and SelfTest = 0 set; the guest rebooted: the system boot with
# the loopback topology (B4: the names; the boot's mailbox line of E17); then E24 (the exe
# launched from the data disk by its absolute path), the copy to the system disk with its hash,
# dsploop_apitest under LIBERNT_APITEST_REQUIRED=1 (B5: the stream at 16, 24-in-32 and 32 bits;
# B6: the FIFO constraint in the serial lines), the exit code, the device lists and the
# MMDevices registry (B4) to the data disk, the Sound applet (screenshots for the record);
# then SelfTest = 2 and a system boot (B7: the self-test once at a system boot), SelfTest = 0
# set back, the S5.
set -u
RUN="${RUN:-r1-firstboot-stream-selftest2boot}"
OVERLAY="${OVERLAY:-p4c4c}"
REBOOT=1
. /tmp/qad-ev/p4c4c/tools/vmcommon.sh
log "boot1: $RUN on disk/$OVERLAY.qcow2"
start_vm
waitre "Storage expansion not offered|The system has been stopped" 900 || log "!! neither the first-boot setup's line nor a stop line in 900 s"
if norm | grep -aq "The system has been stopped"; then
    log "!! the first boot STOPPED; its lines:"
    norm | grep -anE "KsCreateBusEnumObject|The system has been stopped|Stop code|Parameter [1-4]|^ *#[0-9][0-9] |RIP=" | cut -c1-300 | tee -a "$EV/driver.log"
    s5
    log "boot1: the first boot did not pass"
    exit 1
fi
log "A1 (with the data disk): the first boot's lines:"
norm | grep -aE "KsCreateBusEnumObject|Safe removal|First-boot setup|Storage expansion not offered|intcdsp\.sys: (BootDsp|SelfTest)|Program Manager" | cut -c1-300 | tee -a "$EV/driver.log"
log "stop lines in the boot's log: $(norm | grep -ac 'The system has been stopped'); ace_unexpected: $(grep -ac ace_unexpected "$EV/qemu-dbg.log")"
sleep 5
g shot s1-desktop-before-wizard >/dev/null
wizard 15
g shot s2-after-wizard >/dev/null
sleep 20
g shot s3-after-wizard-20s >/dev/null
console
g shot s4-console >/dev/null
if ! pouchfind; then
    g shot s4b-no-data-disk-letter >/dev/null
    log "!! the console did not find the data disk: stopped here for a look at s4b"
    exit 1
fi
alive firstboot || { g shot s4c-console-silent >/dev/null; log "!! the console is silent: stopped here"; exit 1; }
regadd BootDsp REG_DWORD 1
regadd Topology REG_SZ sof-ipc4-loopback.tplg
regadd SelfTest REG_DWORD 0
cmd exe-hash.txt "certutil -hashfile %POUCHDRV%:\\dsploop_apitest.exe SHA256" 30
g shot s5-reg-add >/dev/null
# the reboot: the DSP boots with the topology at this system boot
n0=$(lines)
g type "shutdown -r -t 0"; g key ret
log "reboot typed at serial line $n0"
waitre "intcdsp.sys: boot .*after|clock stalled|Work queue|Fatal|bugcheck" 600 "$n0" || log "!! no boot line in 600 s"
sleep 15
log "B4/E17: the system boot's driver lines (after serial line $n0):"
norm | tail -n +"$((n0 + 1))" | grep -aE "intcdsp\.sys: (SelfTest|BootDsp = |boot ok|topology|ipc: link|firmware ready|DSP power down|audio child|stream [0-9]+: latency)|dsppcm\.sys|Safe removal|clock stalled|interrupt storm|Work queue|Fatal|bugcheck" \
    | grep -av "firmware \\\\SystemRoot" | cut -c1-420 | tee -a "$EV/driver.log"
waitre "Program Manager" 900 "$n0" || log "!! the shell did not come up in 900 s"
sleep 20
g shot s6-desktop-after-reboot >/dev/null
console
pouchfind || { g shot s6b-no-data-disk-letter >/dev/null; log "!! the data disk was not found after the reboot: stopped here"; exit 1; }
alive after-reboot
# E24: the exe from the data disk by its absolute path (its own text to the data disk)
cmd x-launch-pouch.txt "%POUCHDRV%\\dsploop_apitest.exe" 180
# the copy on the system disk and its hash
cmd x-b-copy.txt "copy %POUCHDRV%\\dsploop_apitest.exe C:\\dsploop_apitest.exe" 40
cmd x-c-certutil.txt "certutil -hashfile C:\\dsploop_apitest.exe SHA256" 30
# B5: the stream through the audio stack, under the required switch
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
g shot s7-after-dsploop >/dev/null
# B4: the device lists and the MMDevices registry, as the guest holds them
cmd enum-media.txt "pnputil /enum-devices /class Media /ids" 60
cmd enum-endpoint.txt "pnputil /enum-devices /class AudioEndpoint /ids" 60
cmd reg-mmdev.txt "reg query HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\MMDevices\\Audio /s" 90
log "enum-media.txt: $(pouch_text enum-media.txt | grep -ci 'INTCDSP') INTCDSP lines; enum-endpoint.txt: $(pouch_text enum-endpoint.txt | grep -ci 'Loopback') Loopback lines; reg-mmdev.txt: $(pouch_text reg-mmdev.txt | grep -c 'Intel SST Loopback') 'Intel SST Loopback' lines"
# the Sound applet for the record (screenshots; nothing is read from them to decide anything)
g type "mmsys.cpl"; g key ret; sleep 30
g shot s8-sound-playback >/dev/null
g key ctrl-tab; sleep 6
g shot s9-sound-recording >/dev/null
g key esc; sleep 3
g shot s10-after-sound >/dev/null
# B7: SelfTest = 2 at a system boot
regadd SelfTest REG_DWORD 2
n2=$(lines)
g type "shutdown -r -t 0"; g key ret
log "reboot typed at serial line $n2 (SelfTest = 2)"
waitre "loopback self-test: ran \(|self-test: .* failed|not captured" 900 "$n2" || log "!! no 'ran (' line in 900 s"
sleep 10
log "B7: the self-test's lines at the system boot (after serial line $n2):"
norm | tail -n +"$((n2 + 1))" | grep -aE "loopback self-test|intcdsp\.sys: SelfTest|boot ok" | cut -c1-420 | tee -a "$EV/driver.log"
log "ace_audio lines of the VM: $(grep -ac '^ace_audio ' "$EV/qemu-dbg.log")"
waitre "Program Manager" 900 "$n2" || log "!! the shell did not come up in 900 s"
sleep 20
g shot s11-desktop-selftest2 >/dev/null
console
regadd SelfTest REG_DWORD 0
cmd x-selftest0.txt "reg query HKLM\\SYSTEM\\CurrentControlSet\\Services\\intcdsp\\Settings" 30
log "stop lines in the whole log: $(norm | grep -ac 'The system has been stopped'); fatal lines: $(grep -acE 'Fatal System Error|bugcheck' "$EV/serial.log")"
s5
log "boot1 done"
exit 0
