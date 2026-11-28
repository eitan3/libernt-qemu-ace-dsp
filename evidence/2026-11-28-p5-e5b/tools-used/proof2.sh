#!/bin/bash
# proof2.sh -- the E5b proof VM on the round's own image: a fresh first-boot overlay over the staged VHD (the tip's
# drivers and mmdevapi.dll with the node flag), the wizard, the settings (the loopback topology, SelfTest = 3,
# BootDsp = 1, DspIdleSec = 3), a reboot, then dsploop_apitest.exe at -8 dB set by the tray's keys, then at unity;
# a new console for each run, the drive letter typed explicit; the VM ended by the ACPI button.
#   env: RUN (proof2), DISKFILE (the overlay), IMG (the staged image dir), SRC (the directory holding the exe)
set -u
RUN="${RUN:-proof2}"
. /tmp/e5b/tools/vmcommon.sh
IDLESEC=3
DRIVERLINES='intcdsp\.sys:|dsppcm\.sys:|hdaudbus\.sys:'

counts() {
    local f="$1" t
    t() { norm | tail -n +"$((f + 1))" | grep -ac "$1"; }
    echo "booting $(t 'intcdsp.sys: booting:'), boot ok $(t 'intcdsp.sys: boot ok after'), boot at open ok $(t 'boot at stream open: ok after'), failed-boot $(t 'boot at stream open failed'), idle $(t 'idle power down after'), timeouts $(t 'reply timeout'), fault-during $(t 'fault during stream'), selftest runs $(t 'loopback self-test: [0-9]* runs'), gain lines $(t 'gain: '), fatal $(grep -acE 'Fatal System Error|bugcheck' "$EV/serial.log"), ace_unexpected $(grep -ac ace_unexpected "$EV/qemu-dbg.log")"
}

kdb() {
    if norm | grep -aq "kdb:>"; then
        log "!! KDBG: the guest is in its kernel debugger; the lines before the prompt:"
        norm | grep -an -B 40 "kdb:>" | head -45 | cut -c1-230 | sed "s/^/    /" | tee -a "$EV/driver.log"
        s5; exit 9
    fi
}

reboot() {
    local n0 i
    n0=$(lines)
    log "## reboot $(date -u +%FT%TZ) (serial line $n0): shutdown -r -t 0 typed"
    g type "shutdown -r -t 0"; g key ret
    if ! waitre "D0 entry: the DSP is not booted|intcdsp.sys: boot .*after|The system has been stopped" 600 "$n0"; then log "!! neither the D0 entry's line nor a boot's in 600 s after the reboot"; g shot 98-no-d0-after-reboot >/dev/null; s5; exit 1; fi
    if norm | tail -n +"$((n0 + 1))" | grep -aq "The system has been stopped"; then log "!! the reboot STOPPED"; s5; exit 1; fi
    sleep 45
    mdel -i "$POUCH@@$POUCHOFF" ::/drive.txt >/dev/null 2>&1
    for i in 1 2 3 4; do console 2; pouchfind && alive reboot && break; sleep 20; done
    RB_FROM=$((n0 + 1))
    log "after the reboot (from serial line $n0): $(counts "$n0")"
}

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
    norm | tail -n +"$((N0 + 1))" | head -n $((N1 - N0)) | grep -a -E "intcdsp\.sys: (gain:|boot at stream|endpoint 'Loopback' render: stream)|dsppcm\.sys: endpoint 'Loopback' render: pin created" | cut -c1-240 | sed 's/^/    /' | tee -a "$EV/driver.log" | head -12
}

# the tray's keys: Win+D, then the volume key N times; the driver's gain lines of the last 40 lines
keys() {
    local key=$1 n=$2 N0
    g key meta_l-d; sleep 3
    for i in $(seq 1 "$n"); do g key "$key"; sleep 3; done
    sleep 3
    N0=$(lines)
    log "## the tray's keys ($key x$n): $(norm | tail -n +"$((N0 - 40))" | grep -a 'gain: ' | tail -"$n" | cut -c1-120 | tr '\n' '|')"
}

log "proof2: $RUN on $DISKFILE, image $(basename "$IMG"), the exe $(sha256sum "$SRC/dsploop_apitest.exe" | cut -c1-16)"
start_vm
waitre "Storage expansion not offered|The system has been stopped|Program Manager" 900 || { log "!! neither the first-boot setup's line nor a stop line in 900 s"; g shot 00-no-setup-line >/dev/null; s5; exit 1; }
if norm | grep -aq "The system has been stopped"; then log "!! the first boot STOPPED"; s5; exit 1; fi
log "first boot: the desktop (or the setup) reached after $(lines) serial lines"
wizard 25
for i in 1 2 3; do console 3; pouchfind && alive first && break; sleep 15; done
kdb
regadd Topology REG_SZ "sof-ipc4-loopback.tplg"
regadd SelfTest REG_DWORD 3
regadd BootDsp REG_DWORD 1
regadd DspIdleSec REG_DWORD "$IDLESEC"
reboot
kdb
FROM=$RB_FROM
waitre "loopback self-test: [0-9]* runs" 300 "$FROM" || log "!! no self-test summary in 300 s after the reboot"
sleep 20
log "## the boot after the reboot (from serial line $((FROM - 1))): $(counts 0)"
norm | tail -n +"$FROM" | grep -a -E "SelfTest =|boot ok after|loopback self-test: [0-9]* runs|registered as" | cut -c1-240 | sed 's/^/    /' | tee -a "$EV/driver.log" | head -8
g shot 01-boot >/dev/null
# -8 dB by the tray's keys, as E4b did; once more if no gain line answered
keys volumedown 4
if ! norm | tail -n 60 | grep -aq 'gain: -8.00 dB'; then sleep 10; keys volumedown 4; fi
runexe dsploop-level.txt
g shot 30-level >/dev/null
# unity: Win+D, volumeup x4 (E4b: -8.00 to 0.00 dB)
keys volumeup 4
if ! norm | tail -n 60 | grep -aq 'gain: 0.00 dB'; then sleep 10; keys volumeup 4; fi
runexe dsploop-unity.txt
g shot 90-end >/dev/null
s5
log "done: $(counts 0)"
