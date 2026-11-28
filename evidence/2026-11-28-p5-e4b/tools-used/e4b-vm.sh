#!/bin/bash
# e4b-vm.sh -- the E4b VM (evidence/2026-11-28-p5-e4b): the first boot of the overlay p5e4b (the wizard), the
# settings (the loopback topology, SelfTest = 3, BootDsp = 1, DspIdleSec = 3), a reboot, then the holder: go1 when
# the console answers after the reboot, the VM ended by the ACPI button when the file stop appears.  The rows (the
# Volume tab, D12 d, D13, D14, dsploop at the kept level) are driven by hand through tools/guest.sh meanwhile.
#   The body from e4-round.sh (evidence/2026-11-28-p5-e4/tools-used) through its reboot.
#   env: RUN (e4b), OVERLAY (p5e4b), IMG (the staged image directory), IDLESEC (3)
set -u
RUN="${RUN:-e4b}"
OVERLAY="${OVERLAY:-p5e4b}"
. /tmp/e4b/tools/vmcommon.sh
IDLESEC="${IDLESEC:-3}"
DRIVERLINES='intcdsp\.sys:|dsppcm\.sys:|hdaudbus\.sys:'
BOOTNOISE='intcdsp\.sys: (loaded for|controller|NHLT|reading BAR4|BAR4 \+|HFINTIPPTR|firmware .SystemRoot|interrupts before|subsystem powered|code-loader|ROM ready|firmware entered|FW_READY|firmware ready|ipc: link ready)'

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
    for i in 1 2 3 4; do
        console 2
        pouchfind && alive reboot && break
        sleep 20
    done
    RB_FROM=$((n0 + 1))
    log "after the reboot (from serial line $n0): $(counts "$n0")"
}

# ----------------------------------------------------------------------------- the VM
log "e4b: $RUN on disk/$OVERLAY.qcow2, image $(basename "$IMG") (IDLESEC $IDLESEC): the first boot, the wizard, the settings, a reboot; then the holder"
start_vm
waitre "Storage expansion not offered|The system has been stopped|Program Manager" 900 || { log "!! neither the first-boot setup's line nor a stop line in 900 s"; g shot 00-no-setup-line >/dev/null; s5; exit 1; }
if norm | grep -aq "The system has been stopped"; then log "!! the first boot STOPPED"; s5; exit 1; fi
log "first boot: the desktop (or the setup) reached after $(lines) serial lines"
wizard 25
for i in 1 2 3; do console 3; pouchfind && alive first && break; sleep 15; done
kdb

# the settings live: the loopback topology, SelfTest = 3, BootDsp = 1, DspIdleSec = 3; a reboot makes them live
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
norm | tail -n +"$FROM" | grep -a -E "SelfTest =|boot ok after|loopback self-test: [0-9]* runs|gain: |idle power down|registered as|endpoint '" | cut -c1-300 | sed 's/^/    /' | tee -a "$EV/driver.log" | head -30
g shot 01-boot >/dev/null
: > "$EV/go1"
log "## ready: the console answers after the reboot (go1 written); the rows by hand; waiting for $EV/stop"
while [ ! -f "$EV/stop" ]; do sleep 3; kdb; done
g shot 90-end >/dev/null
s5
log "done: $(counts 0)"
