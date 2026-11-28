#!/bin/bash
# e2-round.sh -- E5's E1/E2 rows on the final image (the flow overlay after the row VM, its later boot), cloned
# from the E2 round's e2b-round.sh: (b), (c), (d) DspIdleSec = 3 made live by a reboot: RUNS dsploop runs, each
# three open -> run -> close cycles, the DSP powering down by idle after a run and booting at the next run's first
# open; (e), (f) BootAtStart = 1 and no topology (the 22-cycle matrix's configuration, the D0 veto S6/D4): a
# reboot, the D0 entry booting the DSP, CYCLES cycles by tools/cycle.sh; then E1's rows (C): `never-reply=19'
# at a run's first open and `crash-async=500' at a run's first open, each followed by a run that must pass
# (`recovered: open ok').  No long line typed (the pouch's dl.cmd; cycle.sh's own pnputil lines as ever).
#   env: RUN (e2), OVERLAY (e5-flow), RUNS (10), CYCLES (22), IDLESEC (3)
set -u
RUN="${RUN:-e2}"
OVERLAY="${OVERLAY:-e5-flow}"
RUNS="${RUNS:-10}"
CYCLES="${CYCLES:-22}"
IDLESEC="${IDLESEC:-3}"
. /tmp/e5/tools/vmcommon.sh
DRIVERLINES='intcdsp\.sys:|dsppcm\.sys:|hdaudbus\.sys:'
BOOTNOISE='intcdsp\.sys: (loaded for|controller|NHLT|reading BAR4|BAR4 \+|HFINTIPPTR|firmware .SystemRoot|SelfTest|BootDsp|booting:|interrupts before|subsystem powered|code-loader|ROM ready|firmware entered|FW_READY|firmware ready|ipc: link ready)'
RUNMAX="${RUNMAX:-300}"
ROWSMD="$EV/rows.md"
EXE='%POUCHDRV%:\dsploop_apitest.exe'

counts() {
    local f="$1" t
    t() { norm | tail -n +"$((f + 1))" | grep -ac "$1"; }
    echo "booting $(t 'intcdsp.sys: booting:'), boot ok $(t 'intcdsp.sys: boot ok after'), selftest ok $(t 'loopback self-test: ran (0x00000000)'), boot at open ok $(t 'boot at stream open: ok after'), failed-boot $(t 'boot at stream open failed'), D0 not booted $(t 'D0 entry: the DSP is not booted'), idle $(t 'idle power down after'), recovered $(t 'recovered: open ok'), render opens $(t 'render: stream 1 opened'), timeouts $(t 'reply timeout'), fault-during $(t 'fault during stream'), stop lines $(norm | grep -ac 'The system has been stopped'), fatal $(grep -acE 'Fatal System Error|bugcheck' "$EV/serial.log"), ace_unexpected $(grep -ac ace_unexpected "$EV/qemu-dbg.log")"
}

run() {
    local label="$1" max="${2:-$RUNMAX}" n0 t0 i r
    n0=$(lines)
    mdel -i "$POUCH@@$POUCHOFF" "::$label.txt" >/dev/null 2>&1
    for i in $(seq 1 30); do [ -z "$(pouch_text "$label.txt")" ] && break; sleep 1; done
    t0=$(date +%s)
    g type "dl $label"; g key ret
    for i in $(seq 1 "$max"); do
        [ -n "$(pouch_text "dl-$label.txt" 2>/dev/null)" ] && { sleep 3; break; }
        sleep 1
    done
    if [ -z "$(pouch_text "dl-$label.txt" 2>/dev/null)" ]; then r="!! NOT ended within $max s"; else r="ended after about $(( $(date +%s) - t0 )) s"; fi
    alive "$label" > /dev/null 2>&1 && r="$r; the console answers" || r="$r; !! the console does not answer"
    log "$label: $r; $(pouch_text "dl-$label.txt" 2>/dev/null | grep -a -E 'depths compared|tests executed' | tr '\n' ' ' | cut -c1-200)"
    log "$label: $(counts "$n0")"
    norm | tail -n +"$((n0 + 1))" | grep -a -E "$DRIVERLINES" | grep -a -v -E "$BOOTNOISE" | grep -a -E "boot at stream|idle power down|recovered|gain: |fault during|released after|firmware crash|reply timeout" | cut -c1-240 | sed 's/^/    /' | tee -a "$EV/driver.log" | head -14
}

# runfault <label> <fault>: the fault set before the run (a boot-time fault set here is cleared at the run's end),
# the run, the fault cleared, the console asked; then the driver's lines
runfault() {
    local label="$1" fault="$2" n0 r
    n0=$(lines)
    ( cd "$QAD" && bash ./set-fault.sh "$EV" "$fault" > "$EV/$label.setfault.out" 2>&1 )
    log "$label: fault '$fault' set ($(date -u +%T)): $(tr '\n' ' ' < "$EV/$label.setfault.out" | cut -c1-80)"
    run "$label"
    ( cd "$QAD" && bash ./set-fault.sh "$EV" none > "$EV/$label.setfault-none.out" 2>&1 )
    log "$label: fault cleared"
}

passed() { local t; t=$(pouch_text "dl-$1.txt" 2>/dev/null); [ "$(echo "$t" | grep -ac '3 of 3 depths compared')" -ge 1 ] && [ "$(echo "$t" | grep -ac '0 failures), 0 skipped')" -ge 1 ]; }

kdb() {
    if norm | grep -aq "kdb:>"; then
        log "!! KDBG: the guest is in its kernel debugger; the lines before the prompt:"
        norm | grep -an -B 40 "kdb:>" | head -45 | cut -c1-230 | sed "s/^/    /" | tee -a "$EV/driver.log"
        g shot 99-kdbg >/dev/null 2>&1; s5; exit 9
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
        console 3
        pouchfind && alive reboot && break
        sleep 20
    done
    g type "${PDRV}:"; g key ret; sleep 2
    RB_FROM=$((n0 + 1))
    log "after the reboot (from serial line $n0): $(counts "$n0")"
    norm | tail -n +"$((n0 + 1))" | grep -a -E "intcdsp\.sys: (SelfTest|BootDsp|boot ok after|topology |loopback self-test: [0-9]+ runs|ran \(|D0 entry|audio child)" | cut -c1-200 | sed 's/^/    /' | tee -a "$EV/driver.log" | head -10
}

# ----------------------------------------------------------------------------- the VM
log "e2-round: $RUN on disk/$OVERLAY.qcow2, a later boot (RUNS $RUNS, CYCLES $CYCLES, IDLESEC $IDLESEC), image $(basename "$IMG")"
start_vm
waitre "D0 entry: the DSP is not booted|intcdsp.sys: boot .*after|The system has been stopped" 900 || { log "!! neither the D0 entry's line nor a stop line in 900 s"; g shot 00-no-d0-line >/dev/null; s5; exit 1; }
if norm | grep -aq "The system has been stopped"; then log "!! the boot STOPPED"; norm | grep -anE "The system has been stopped|Stop code" | cut -c1-300 | tee -a "$EV/driver.log"; s5; exit 1; fi
log "the boot: $(counts 0)"
sleep 45
for i in 1 2 3 4; do
    console 3
    pouchfind && alive boot && break
    sleep 20
done
g type "${PDRV}:"; g key ret; sleep 2
cmd settings-before.txt "reg query $KEY" 30
printf '\n| row | the setting | what the log shows | the run | the counts |\n|---|---|---|---|---|\n' >> "$ROWSMD"

# ----------------------------------------------------------------------------- (b), (d), (c) DspIdleSec = 3, live by a reboot
log "## DspIdleSec = $IDLESEC by the registry, then a reboot (N12-09)"
regadd DspIdleSec REG_DWORD "$IDLESEC" 4
reboot
cmd settings-idle.txt "reg query $KEY" 30
BF=$RB_FROM
log "(b) from serial line $BF (the setting read at the reboot's D0 entry): $(counts "$BF")"
printf '\n| run | the run | boot at open | idle after the run | recovered | render opens | timeouts |\n|---|---|---|---|---|---|---|\n' >> "$ROWSMD"
okruns=0; idleseen=0
for i in $(seq 1 "$RUNS"); do
    label=$(printf 'r%02d' "$i")
    r0=$(lines)
    run "$label"
    if passed "$label"; then p="PASS"; okruns=$((okruns + 1)); else p="**not a pass**"; fi
    if waitre "idle power down after" $((IDLESEC + 15)) "$r0"; then idleseen=$((idleseen + 1)); else log "$label: !! no idle power-down line in $((IDLESEC + 15)) s after the run"; fi
    bo=$(norm | tail -n +"$((r0 + 1))" | grep -ac 'boot at stream open: ok after')
    id=$(norm | tail -n +"$((r0 + 1))" | grep -ac 'idle power down after')
    rc=$(norm | tail -n +"$((r0 + 1))" | grep -ac 'recovered: open ok')
    op=$(norm | tail -n +"$((r0 + 1))" | grep -ac 'render: stream 1 opened')
    to=$(norm | tail -n +"$((r0 + 1))" | grep -ac 'reply timeout')
    printf '| %s | %s | %s | %s | %s | %s | %s |\n' "$label" "$p" "$bo" "$id" "$rc" "$op" "$to" | tee -a "$ROWSMD"
    kdb
done
g shot 06-after-idle
CB=$(counts "$BF")
log "(b), (d), (c) from serial line $BF: $CB; runs passed: $okruns of $RUNS; idle lines seen by the waits: $idleseen"
printf '\n| (b) | DspIdleSec = %s | %s | %s of %s runs passed | idle power-downs %s; boots at open %s; recovered %s; render opens %s |\n' "$IDLESEC" "$CB" "$okruns" "$RUNS" "$(norm | tail -n +"$((BF + 1))" | grep -ac 'idle power down after')" "$(norm | tail -n +"$((BF + 1))" | grep -ac 'boot at stream open: ok after')" "$(norm | tail -n +"$((BF + 1))" | grep -ac 'recovered: open ok')" "$(norm | tail -n +"$((BF + 1))" | grep -ac 'render: stream 1 opened')" | tee -a "$ROWSMD"

# ----------------------------------------------------------------------------- E1's rows: a fault with a stream open, then a run that must pass
log "## E1: never-reply=19 at a run's first open, then a run after it"
F1=$(lines)
runfault f-never-reply never-reply=19
norm | tail -n +"$((F1 + 1))" | grep -a -E "fault during|released after the fault|reply timeout" | cut -c1-200 | sed 's/^/    /' | tee -a "$EV/driver.log" | head -4
run a-never-reply
if passed a-never-reply; then log "a-never-reply: PASS after the fault: $(norm | tail -n +"$((F1 + 1))" | grep -a 'recovered: open ok' | head -1 | cut -c1-120)"; else log "a-never-reply: !! the run after the fault did not pass"; fi
printf '| E1 never-reply=19 | %s | %s | %s |\n' "$(norm | tail -n +"$((F1 + 1))" | grep -ac 'fault during stream')" "$(norm | tail -n +"$((F1 + 1))" | grep -ac 'recovered: open ok')" "$(passed a-never-reply && echo PASS || echo 'not a pass')" | tee -a "$ROWSMD"
log "## E1: crash-async=500 at a run's first open (the asynchronous exception, read at a stream's period), then a run after it"
F2=$(lines)
runfault f-crash-async crash-async=500
norm | tail -n +"$((F2 + 1))" | grep -a -E "firmware crash|fault during|released after the fault" | cut -c1-200 | sed 's/^/    /' | tee -a "$EV/driver.log" | head -4
run a-crash-async
if passed a-crash-async; then log "a-crash-async: PASS after the crash: $(norm | tail -n +"$((F2 + 1))" | grep -a 'recovered: open ok' | head -1 | cut -c1-120)"; else log "a-crash-async: !! the run after the crash did not pass"; fi
printf '| E1 crash-async=500 | %s | %s | %s |\n' "$(norm | tail -n +"$((F2 + 1))" | grep -ac 'firmware crash')" "$(norm | tail -n +"$((F2 + 1))" | grep -ac 'recovered: open ok')" "$(passed a-crash-async && echo PASS || echo 'not a pass')" | tee -a "$ROWSMD"
kdb

# ----------------------------------------------------------------------------- (e), (f) BootAtStart = 1, no topology: the cycles (CYCLES = 0 skips them)
if [ "$CYCLES" -gt 0 ]; then
log "## (e), (f) BootAtStart = 1 and no topology: $CYCLES cycles by tools/cycle.sh, each D0 entry booting the DSP"
g type "reg delete \"$KEY\" /v Topology /f"; g key ret; sleep 3
regadd BootAtStart REG_DWORD 1 4
reboot
EF=$RB_FROM
log "(f) the first D0 entry with BootAtStart = 1 and no topology (from serial line $EF): $(counts "$EF")"
printf '| (f) | BootAtStart = 1, no topology | the D0 entry boots: %s | - | - |\n' "$(norm | tail -n +"$((EF + 1))" | grep -a 'intcdsp.sys: boot ok after' | head -1 | sed 's/^\[ *[0-9.]*\] //' | cut -c1-100)" | tee -a "$ROWSMD"
for i in $(seq 1 "$CYCLES"); do
    echo "=== cycle c$i $(date -u +%FT%TZ)" >> "$EV/cycles-run.out"
    ( cd "$QAD" && TIMEOUT=90 tools/cycle.sh "$EV" "c$i" >> "$EV/cycles-run.out" 2>&1 )
    kdb
done
ok=$(awk '/^## cycle c[0-9]+ /{f=1; next} /^## cycle/{f=0} f && /intcdsp.sys: boot ok after/{n++} END{print n+0}' "$EV/cycles.log")
to=$(awk '/^## cycle c[0-9]+ /{f=1; next} /^## cycle/{f=0} f && /intcdsp.sys: boot .*timeout after/{n++} END{print n+0}' "$EV/cycles.log")
other=$(awk '/^## cycle c[0-9]+ /{f=1; next} /^## cycle/{f=0} f && /intcdsp.sys: boot/ && !/booting:/ && !/boot ok after/ && !/timeout after/{n++} END{print n+0}' "$EV/cycles.log")
none=$(grep -ac "not seen" "$EV/cycles.log")
stall=$(grep -ac "clock stalled" "$EV/serial.log")
printf 'AC3 cycles: %d run, %d boot ok, %d bounded timeouts, %d other outcomes, %d waits not seen, clock stalled lines: %d (%s; BootAtStart = 1, no topology, in the E2 round VM)\n' \
    "$CYCLES" "$ok" "$to" "$other" "$none" "$stall" "$(date -u +%FT%TZ)" | tee "$EV/summary.txt" | tee -a "$ROWSMD"
log "(e) the cycles from serial line $EF: $(counts "$EF")"
g shot 07-after-cycles
kdb
fi

# ----------------------------------------------------------------------------- the lines
{
    echo "# the lines of this round (from the serial log, ANSI and NULs removed)"
    echo "## the settings as the driver read them"; norm | grep -a 'SelfTest = ' | cut -c1-200
    echo "## the D0 entries"; norm | grep -a -E "D0 entry: the DSP is not booted|intcdsp.sys: boot ok after" | cut -c1-200
    echo "## boot at stream open: ok"; norm | grep -a 'boot at stream open: ok' | cut -c1-200 | head -30
    echo "## idle power down";        norm | grep -a 'idle power down after' | cut -c1-200
    echo "## recovered";               norm | grep -a 'recovered: open ok' | cut -c1-200
    echo "## faults with a stream open"; norm | grep -a -E "fault during stream|released after the fault|firmware crash|reply timeout" | cut -c1-200 | head -20
    echo "## counts"; echo "stop lines: $(norm | grep -ac 'The system has been stopped'); fatal lines: $(grep -acE 'Fatal System Error|bugcheck' "$EV/serial.log"); ace_unexpected: $(grep -ac ace_unexpected "$EV/qemu-dbg.log"); kdb prompts: $(norm | grep -ac 'kdb:>')"
} > "$EV/e5-e1e2-lines.txt"
s5
log "e2-round done: $(counts 0)"
exit 0
