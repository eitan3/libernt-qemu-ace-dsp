#!/bin/bash
# e4-cd-start.sh -- the E4 step 0 VM on the unchanged image p5e3 (rows (c) and (d), the E3 round's N13-09):
# starts the VM, waits for the boot's self-test (the overlay's registry has SelfTest = 3, BootDsp = 1,
# DspIdleSec = 3 and the loopback topology from the E3 round), takes a screenshot, and waits for the file
# "go1"; then opens the console, finds the data disk and waits for the file "stop", and ends the VM by the
# ACPI power button.  Meanwhile the applet's steps are driven by hand through tools/guest.sh (the monitor
# serves one client at a time: this script touches it only at its start and at its end).
#   env: RUN (e4-cd), OVERLAY (p5e3)
set -u
RUN="${RUN:-e4-cd}"
OVERLAY="${OVERLAY:-p5e3}"
. /tmp/e4/tools/vmcommon.sh
DRIVERLINES='intcdsp\.sys:|dsppcm\.sys:|hdaudbus\.sys:'
BOOTNOISE='intcdsp\.sys: (loaded for|controller|NHLT|reading BAR4|BAR4 \+|HFINTIPPTR|firmware .SystemRoot|interrupts before|subsystem powered|code-loader|ROM ready|firmware entered|FW_READY|firmware ready|ipc: link ready)'

log "e4-cd: $RUN on disk/$OVERLAY.qcow2, image $(basename "$IMG")"
start_vm || exit 2
if ! waitre "loopback self-test: [0-9]* runs|The system has been stopped|kdb:>" 600; then
    log "!! no self-test summary in 600 s"
    g shot 00-no-selftest >/dev/null
fi
if norm | grep -aq "The system has been stopped\|kdb:>"; then
    log "!! the boot stopped or sits in the debugger"
    s5
    exit 1
fi
IDLE0=$(norm | grep -ac "idle power down after")
log "the boot: self-test summary lines $(norm | grep -ac 'loopback self-test: [0-9]* runs'), matched rows $(norm | grep -ac 'loopback self-test: 6 runs, 6 matched, 0 failed'), gain rows ok $(norm | grep -ac 'gain 0x4026e73d.*ok$'), idle power-downs so far $IDLE0"
norm | grep -a -E "SelfTest =|boot ok after|loopback self-test|gain: |idle power down" | cut -c1-330 | sed 's/^/    /' | tee -a "$EV/driver.log"
sleep 60
g shot 01-boot >/dev/null
log "screenshot 01-boot; waiting for $EV/go1"
for i in $(seq 1 600); do [ -f "$EV/go1" ] && break; sleep 2; done
[ -f "$EV/go1" ] || { log "!! no go1 in 20 minutes; ending the VM"; s5; exit 1; }
for i in 1 2 3; do console 3; pouchfind && alive first && break; sleep 15; done
log "the console and the data disk are ready; waiting for $EV/stop"
while [ ! -f "$EV/stop" ]; do sleep 3; done
g shot 90-end >/dev/null
s5
log "done"
