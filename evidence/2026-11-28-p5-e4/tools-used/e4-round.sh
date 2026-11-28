#!/bin/bash
# e4-round.sh -- the P5 E4 VM round on the image p5e4, one VM, bounded.  The E3 round's script (evidence/
# 2026-11-28-p5-e3/tools-used/e3-round.sh) through its reboot, with vmcommon.sh's norm() stripping the CR (N13-10),
# then the E4 rows:
#   (a) the boot after the reboot (SelfTest = 3, BootDsp = 1, DspIdleSec = 3, the loopback topology): the self-test's
#       six runs matched, its three gain rows at -6 dB counted by the script itself this time;
#   (b) the baseline: one dsploop run, 3 of 3 depths exact, after an idle power-down and a boot at open;
#   (c) the hold (N12-03): DSPLOOP_HOLD = 20 opens the render pin and holds it, initialized and not started;
#       no idle power-down while the pin is held, one after the release (the line's time against the release's);
#   (d) a dsploop run after it: 3 of 3 depths exact, the boot at open, no line of a fault.
#   env: RUN (e4-round), OVERLAY (p5e4), IMG (the staged image directory), IDLESEC (3), HOLD (20)
set -u
RUN="${RUN:-e4-round}"
OVERLAY="${OVERLAY:-p5e4}"
. /tmp/e4/tools/vmcommon.sh
RUNMAX="${RUNMAX:-150}"
IDLESEC="${IDLESEC:-3}"
HOLD="${HOLD:-20}"
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

# one typed run of the exe: the label's text back on the data disk; prints the serial line the run started at
run() {
    local label="$1" max="${2:-$RUNMAX}" cmd="$3" i r
    mdel -i "$POUCH@@$POUCHOFF" "::$label.txt" >/dev/null 2>&1
    for i in $(seq 1 30); do [ -z "$(pouch_text "$label.txt")" ] && break; sleep 1; done
    g type "$cmd"; g key ret
    for i in $(seq 1 "$max"); do
        [ -n "$(pouch_text "$label.txt" 2>/dev/null)" ] && { sleep 3; break; }
        sleep 1
    done
    if [ -z "$(pouch_text "$label.txt" 2>/dev/null)" ]; then r="!! NOT ended within $max s (the text file is still empty)"; else r="ended after about $i s"; fi
    alive "$label" > /dev/null 2>&1 && r="$r; the console answers" || r="$r; !! the console does not answer"
    log "$label: $r; $(pouch_text "$label.txt" 2>/dev/null | grep -a -E 'depths compared|tests executed|hold:|was not captured' | tr '\n' ' ' | cut -c1-400)"
}

linesof() { norm | tail -n +"$(($1 + 1))" | grep -a -E "$DRIVERLINES" | grep -a -v -E "$BOOTNOISE" | cut -c1-300 | sed 's/^/    /' | tee -a "$EV/driver.log"; }

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
log "e4-round: $RUN on disk/$OVERLAY.qcow2, image $(basename "$IMG") (IDLESEC $IDLESEC, HOLD $HOLD s)"
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
sleep 5
log "## (a) the self-test's lines of the boot (from serial line $((FROM - 1))):"
norm | tail -n +"$FROM" | grep -a -E "SelfTest =|boot ok after|loopback self-test: (the gain|[0-9]* runs)|gain: |idle power down|boot at stream open" | cut -c1-330 | sed 's/^/    /' | tee -a "$EV/driver.log"
A_RUNS=$(norm | tail -n +"$FROM" | grep -ac "loopback self-test: 6 runs, 6 matched, 0 failed")
A_GAIN=$(norm | tail -n +"$FROM" | grep -ac "gain 0x4026e73d.*ok$")
A_ERR=$(norm | tail -n +"$FROM" | grep -a "gain 0x4026e73d" | grep -a -c "max abs error 0,")
if [ "$A_RUNS" = 1 ] && [ "$A_GAIN" = 3 ] && [ "$A_ERR" = 3 ]; then A=PASS; else A=FAIL; fi
log "(a) SelfTest = 3: $A (summary rows $A_RUNS, gain rows ok $A_GAIN, max abs error 0 rows $A_ERR)"
printf '| (a) | SelfTest = 3 at a D0 entry: three depths at unity, three at -6 dB (gain 0x4026e73d) | %s (summary rows %s, gain rows ok %s, max abs error 0 rows %s) |\n' "$A" "$A_RUNS" "$A_GAIN" "$A_ERR" | tee -a "$ROWSMD"

# (b) the baseline after the idle power-down
sleep $((IDLESEC + 4))
N0=$(lines)
run e4-baseline "$RUNMAX" "set LIBERNT_APITEST_REQUIRED=1&& $EXE > %POUCHDRV%:\\e4-baseline.txt 2>&1"
linesof "$N0"
B_IDLE0=$(norm | tail -n +"$FROM" | head -n +"$((N0 + 1 - FROM))" | grep -ac "idle power down after $IDLESEC s")
B_BOOT=$(norm | tail -n +"$((N0 + 1))" | grep -ac "boot at stream open: ok after")
B_IDLE1=$(norm | tail -n +"$((N0 + 1))" | grep -ac "idle power down after $IDLESEC s")
if passed e4-baseline && [ "$B_BOOT" -ge 1 ]; then B=PASS; else B=FAIL; fi
log "(b) the baseline: $B (3 of 3: $(passed e4-baseline && echo yes || echo no), idle power-downs before the run $B_IDLE0, boots at open in the run $B_BOOT, idle power-downs in the run $B_IDLE1)"
printf '| (b) | the baseline: a dsploop run after the idle power-down | %s (3 of 3 depths %s, boots at open %s, idle power-downs in the run %s) |\n' "$B" "$(passed e4-baseline && echo exact || echo NOT exact)" "$B_BOOT" "$B_IDLE1" | tee -a "$ROWSMD"

# (c) the hold (N12-03): the DSP is down by idle since the baseline; the hold's first open boots it, the pin is held HOLD s, no idle power-down meanwhile, one after the release
sleep $((IDLESEC + 4))
N0=$(lines)
T0=$(date +%s)
run e4-hold "$((HOLD + 90))" "set LIBERNT_APITEST_REQUIRED=1&& set DSPLOOP_HOLD=$HOLD&& $EXE > %POUCHDRV%:\\e4-hold.txt 2>&1"
T1=$(date +%s)
sleep $((IDLESEC + 8))
linesof "$N0"
H_TEXT=$(pouch_text e4-hold.txt 2>/dev/null | grep -a -E "hold:" | tr '\n' ' ' | cut -c1-400)
H_BOOT=$(norm | tail -n +"$((N0 + 1))" | grep -ac "boot at stream open: ok after")
H_GAIN=$(norm | tail -n +"$((N0 + 1))" | grep -ac "gain: ")
H_IDLE_LINES=$(norm | tail -n +"$((N0 + 1))" | grep -a "idle power down after" | cut -c1-60)
H_IDLE_N=$(echo "$H_IDLE_LINES" | grep -ac "idle power down after")
# the idle power-down's guest time against the hold's: the release line's guest time is the hold text's "released after N ms" after the boot at open
H_REL=$(pouch_text e4-hold.txt 2>/dev/null | grep -a -o "released after [0-9]* ms ([a-z ]*)" | head -1)
H_BOOT_T=$(norm | tail -n +"$((N0 + 1))" | grep -a -m1 "boot at stream open: ok after" | sed 's/^\[ *//; s/\..*//' | tr -d ' ')
H_IDLE_T=$(echo "$H_IDLE_LINES" | head -1 | sed 's/^\[ *//; s/\..*//' | tr -d ' ')
H_OK=NO
if [ "$H_BOOT" -ge 1 ] && [ "$H_IDLE_N" = 1 ] && [ -n "$H_BOOT_T" ] && [ -n "$H_IDLE_T" ] && echo "$H_REL" | grep -q "released after"; then
    H_DELTA=$(( H_IDLE_T - H_BOOT_T ))
    log "(c) the hold: the boot at open at guest $H_BOOT_T s, $H_REL, the idle power-down at guest $H_IDLE_T s ($H_DELTA s after the boot at open; the hold asks $HOLD s and the idle time $IDLESEC s)"
    if [ "$H_DELTA" -ge "$HOLD" ] && [ "$H_DELTA" -le "$((HOLD + IDLESEC + 25))" ]; then H_OK=YES; fi
fi
if [ "$H_OK" = YES ]; then C=PASS; else C=FAIL; fi
log "(c) the hold: $C (boots at open $H_BOOT, gain lines $H_GAIN, idle power-downs $H_IDLE_N; $H_TEXT)"
printf '| (c) | the hold (N12-03): DSPLOOP_HOLD = %s s, the render pin open and not started | %s (idle power-downs during the hold %s in all, the one at guest %s s, %s after the boot at open; %s) |\n' "$HOLD" "$C" "$H_IDLE_N" "$H_IDLE_T" "$([ -n "$H_BOOT_T" ] && [ -n "$H_IDLE_T" ] && echo $((H_IDLE_T - H_BOOT_T)) s || echo "?")" "$H_REL" | tee -a "$ROWSMD"

# (d) a dsploop run after the hold's idle power-down
sleep $((IDLESEC + 4))
N0=$(lines)
run e4-after "$RUNMAX" "set LIBERNT_APITEST_REQUIRED=1&& $EXE > %POUCHDRV%:\\e4-after.txt 2>&1"
linesof "$N0"
D_BOOT=$(norm | tail -n +"$((N0 + 1))" | grep -ac "boot at stream open: ok after")
if passed e4-after && [ "$D_BOOT" -ge 1 ]; then D=PASS; else D=FAIL; fi
log "(d) dsploop after the hold: $D ($(passed e4-after && echo '3 of 3 depths exact' || echo 'NOT exact'), boots at open $D_BOOT); $(counts 0)"
printf '| (d) | a dsploop run after the hold'"'"'s idle power-down | %s (3 of 3 depths %s, boots at open %s) |\n' "$D" "$(passed e4-after && echo exact || echo NOT exact)" "$D_BOOT" | tee -a "$ROWSMD"
g shot 90-end >/dev/null
s5
cp -f "$ROWSMD" "$EV/rows-final.md"
log "done: (a) $A, (b) $B, (c) $C, (d) $D"
