#!/bin/bash
# e3-round2.sh -- the E3 round attached to the VM the first script started (its first wait was for a D0-entry
# line the first boot does not print without a topology: the script was stopped, the VM kept).  The rest is
# e3-round.sh's: the wizard, a console, the settings live by a reboot, row (a) SelfTest = 3, row (b) dsploop.
set -u
RUN="${RUN:-e3-round}"
OVERLAY="${OVERLAY:-p5e3}"
. /tmp/e3/tools/vmcommon.sh
RUNMAX="${RUNMAX:-150}"
RUNS="${RUNS:-4}"
IDLESEC="${IDLESEC:-3}"
EXE='%POUCHDRV%:\dsploop_apitest.exe'
ROWSMD="$EV/rows.md"
DRIVERLINES='intcdsp\.sys:|dsppcm\.sys:|hdaudbus\.sys:'
BOOTNOISE='intcdsp\.sys: (loaded for|controller|NHLT|reading BAR4|BAR4 \+|HFINTIPPTR|firmware .SystemRoot|interrupts before|subsystem powered|code-loader|ROM ready|firmware entered|FW_READY|firmware ready|ipc: link ready)'
: > "$ROWSMD"

# the VM is up: its evidence directory and sockets exist; the launcher is not this script's child, so the
# end waits for the emulator's process instead of lib-run's
attach_vm() {
    SOCK=$(cat "$EV/sock-dir.txt")
    log "attached to the running VM $RUN (sockets $SOCK)"
}
s5() {
    local i
    g mon system_powerdown >/dev/null
    for i in $(seq 1 120); do pgrep -f "[q]emu-system-x86_64.*disk/$OVERLAY" > /dev/null || break; sleep 2; done
    log "VM $RUN ended: $(grep -a 'qemu exited' "$EV/lib-run.out" 2>/dev/null; pgrep -f "[q]emu-system-x86_64.*disk/$OVERLAY" > /dev/null && echo 'still running' || echo 'the emulator is gone')"
}

counts() {
    local f="$1" t
    t() { norm | tail -n +"$((f + 1))" | grep -ac "$1"; }
    echo "booting $(t 'intcdsp.sys: booting:'), boot ok $(t 'intcdsp.sys: boot ok after'), boot at open ok $(t 'boot at stream open: ok after'), failed-boot $(t 'boot at stream open failed'), D0 not booted $(t 'D0 entry: the DSP is not booted'), idle $(t 'idle power down after'), recovered $(t 'recovered: open ok'), timeouts $(t 'reply timeout'), fault-during $(t 'fault during stream'), release $(t 'release: '), selftest runs $(t 'loopback self-test: [0-9]* runs'), gain lines $(t 'gain: '), fatal $(grep -acE 'Fatal System Error|bugcheck' "$EV/serial.log"), ace_unexpected $(grep -ac ace_unexpected "$EV/qemu-dbg.log")"
}

run() {
    local label="$1" max="${2:-$RUNMAX}" n0 t0 i r
    n0=$(lines)
    mdel -i "$POUCH@@$POUCHOFF" "::$label.txt" >/dev/null 2>&1
    for i in $(seq 1 30); do [ -z "$(pouch_text "$label.txt")" ] && break; sleep 1; done
    t0=$(date +%s)
    g type "set LIBERNT_APITEST_REQUIRED=1&& $EXE > %POUCHDRV%:\\$label.txt 2>&1"; g key ret
    for i in $(seq 1 "$max"); do
        [ -n "$(pouch_text "$label.txt" 2>/dev/null)" ] && { sleep 3; break; }
        sleep 1
    done
    if [ -z "$(pouch_text "$label.txt" 2>/dev/null)" ]; then r="!! NOT ended within $max s (the text file is still empty)"; else r="ended after about $(( $(date +%s) - t0 )) s"; fi
    alive "$label" > /dev/null 2>&1 && r="$r; the console answers" || r="$r; !! the console does not answer"
    log "$label: $r; $(pouch_text "$label.txt" 2>/dev/null | grep -a -E 'depths compared|tests executed|mismatch|gain' | tr '\n' ' ' | cut -c1-300)"
    log "$label: $(counts "$n0")"
    norm | tail -n +"$((n0 + 1))" | grep -a -E "$DRIVERLINES" | grep -a -v -E "$BOOTNOISE" | cut -c1-300 | sed 's/^/    /' | tee -a "$EV/driver.log"
}

passed() { local t; t=$(pouch_text "$1.txt" 2>/dev/null); [ "$(echo "$t" | grep -ac '3 of 3 depths compared')" -ge 1 ] && [ "$(echo "$t" | grep -ac '0 failures), 0 skipped')" -ge 1 ]; }

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

# ----------------------------------------------------------------------------- the VM (already up)
log "e3-round2: attached to the VM of disk/$OVERLAY.qcow2 (RUNS $RUNS, IDLESEC $IDLESEC)"
attach_vm
g shot 01-first-boot >/dev/null
wizard 10
for i in 1 2 3; do console 3; pouchfind && alive first && break; sleep 15; done
kdb
n0=$(lines)
log "first boot, the driver's lines (from the start): $(counts 0)"
norm | tail -n +"$((n0 + 1))" > /dev/null

# (a) the settings live: SelfTest = 3, BootDsp = 1, the loopback topology, DspIdleSec = 3; a reboot makes them live
regadd Topology REG_SZ "sof-ipc4-loopback.tplg"
regadd SelfTest REG_DWORD 3
regadd BootDsp REG_DWORD 1
regadd DspIdleSec REG_DWORD "$IDLESEC"
reboot
kdb
FROM=$RB_FROM
waitre "loopback self-test: [0-9]* runs" 300 "$FROM" || log "!! no self-test summary in 300 s after the reboot"
sleep 5
log "## (a) the self-test's lines of the boot (from serial line $((FROM - 1))):"
norm | tail -n +"$FROM" | grep -a -E "SelfTest =|topology '|boot ok after|loopback self-test|gain: |idle power down|boot at stream open" | cut -c1-330 | sed 's/^/    /' | tee -a "$EV/driver.log"
A_RUNS=$(norm | tail -n +"$FROM" | grep -ac "loopback self-test: 6 runs, 6 matched, 0 failed")
A_GAIN=$(norm | tail -n +"$FROM" | grep -ac "gain 0x4026e73d.*ok$")
A_ERR=$(norm | tail -n +"$FROM" | grep -a "gain 0x4026e73d" | grep -a -c "max abs error 0,")
if [ "$A_RUNS" = 1 ] && [ "$A_GAIN" = 3 ] && [ "$A_ERR" = 3 ]; then A=PASS; else A=FAIL; fi
log "(a) SelfTest = 3: $A (summary rows $A_RUNS, gain rows ok $A_GAIN, max abs error 0 rows $A_ERR)"
printf '| (a) | SelfTest = 3 at a D0 entry: three depths at unity, three at -6 dB (gain 0x4026e73d) | %s (summary rows %s, gain rows ok %s, max abs error 0 rows %s) |\n' "$A" "$A_RUNS" "$A_GAIN" "$A_ERR" | tee -a "$ROWSMD"

# (b) the stream test after the self-test, with the idle power-down between the runs
B_OK=0
for i in $(seq 1 "$RUNS"); do
    sleep $((IDLESEC + 4))
    run "e3-run-$i"
    passed "e3-run-$i" && B_OK=$((B_OK + 1))
    kdb
done
B_IDLE=$(norm | tail -n +"$FROM" | grep -ac "idle power down after $IDLESEC s")
B_BOOT=$(norm | tail -n +"$FROM" | grep -ac "boot at stream open: ok after")
if [ "$B_OK" = "$RUNS" ] && [ "$B_IDLE" -ge "$RUNS" ] && [ "$B_BOOT" -ge "$RUNS" ]; then B=PASS; else B=FAIL; fi
log "(b) dsploop after the self-test with DspIdleSec = $IDLESEC: $B ($B_OK of $RUNS runs 3 of 3, $B_IDLE idle power-downs, $B_BOOT boots at open)"
printf '| (b) | the stream test after it, DspIdleSec = %s: each run 3 of 3 depths exact, an idle power-down and a boot at open per run | %s (%s of %s runs, %s idle power-downs, %s boots at open) |\n' "$IDLESEC" "$B" "$B_OK" "$RUNS" "$B_IDLE" "$B_BOOT" | tee -a "$ROWSMD"
g shot 90-end >/dev/null
s5
cp -f "$ROWSMD" "$EV/rows-final.md"
log "done: (a) $A, (b) $B"
