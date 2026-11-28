#!/bin/bash
# e3-round.sh -- the P5 E3 VM round on the p5e3 image (93f11c644b0), one VM, bounded.  The functions are the E2
# round's as they ran (tools/vmcommon.sh).  Everything the script does to the guest goes through tools/guest.sh
# and the serial log; the guest's own text comes back on the data disk.
#   (a) SelfTest = 3 with BootDsp = 1 and DspIdleSec = 3, made live by a reboot: the D0 entry boots the DSP and
#       runs the loopback self-test at the three depths, then at -6 dB through the gain module: the lines
#       "loopback self-test: the gain step" and "6 runs, 6 matched, 0 failed", the three "gain 0x4026e73d" rows
#       with their max abs error and capture rms;
#   (b) the stream test (dsploop) after it, with DspIdleSec = 3: the DSP powers down by idle after each run and
#       boots at the next run's first open; each run compares 3 of 3 depths exactly (the level is unity again).
#   env: RUN, OVERLAY (p5e3), RUNS (4), IDLESEC (3)
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

# ----------------------------------------------------------------------------- the VM
log "e3-round: $RUN on disk/$OVERLAY.qcow2 (RUNS $RUNS, IDLESEC $IDLESEC)"
start_vm
waitre "Storage expansion not offered|The system has been stopped|Program Manager" 900 || { log "!! neither the first-boot setup's line nor a stop line in 900 s"; g shot 00-no-setup-line >/dev/null; s5; exit 1; }
if norm | grep -aq "The system has been stopped"; then log "!! the first boot STOPPED"; s5; exit 1; fi
log "first boot: the desktop (or the setup) reached after $(lines) serial lines"
wizard 25
for i in 1 2 3; do console 3; pouchfind && alive first && break; sleep 15; done
kdb

# (a) the settings live: the loopback topology, SelfTest = 3, BootDsp = 1, DspIdleSec = 3; a reboot makes them live
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
norm | tail -n +"$FROM" | grep -a -E "SelfTest =|boot ok after|loopback self-test|gain: |idle power down|boot at stream open" | cut -c1-330 | sed 's/^/    /' | tee -a "$EV/driver.log"
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
