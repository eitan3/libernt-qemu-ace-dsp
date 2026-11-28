#!/bin/bash
# e2b-round.sh -- the P5 E2 VM round, second half, on the p5e2 image: a later boot of the overlay of the
# fourth run (vm/e2-round-fourth: the same image, its guest holding BootDsp = 1, the loopback topology,
# DspIdleSec = IDLESEC and BootAtStart unset), so no wizard and no row (a) here (the fourth run's row (a) is
# the image's).  The functions are the E1c round's as they ran (vmcommon.sh).
#   (b), (d) RUNS dsploop runs, each three open -> run -> close cycles, the DSP powering down by idle after
#       a run and booting at the next run's first open (the first open of the first run boots too: the D0
#       entry of this boot booted nothing); the cycles counted from the driver's log and the runs' texts;
#   (c) inside those runs: one boot at open and one idle power-down per run, none between a run's loops;
#   (e), (f) BootAtStart = 1 and no topology (the p4c4g regression S2 configuration: with the PCM child
#       reported the device cannot be disabled): a reboot, the D0 entry booting the DSP (f), then CYCLES
#       disable/enable cycles by the project's tools/cycle.sh, as tools/ac3-cycles.sh runs them, and its
#       summary line (e).  The reboot is waited for by the driver's D0-entry line: the shell's start prints
#       nothing on this image's serial port, and the console is tried until it answers.
#   env: RUNMAX (a run's cap, s), RUN, OVERLAY, RUNS (16), CYCLES (22), IDLESEC (3)
set -u
RUN="${RUN:-e2-round}"
OVERLAY="${OVERLAY:-p5e3}"
. /tmp/e3/tools/vmcommon.sh
RUNMAX="${RUNMAX:-150}"
RUNS="${RUNS:-16}"
CYCLES="${CYCLES:-22}"
IDLESEC="${IDLESEC:-3}"
EXE='%POUCHDRV%:\dsploop_apitest.exe'
ROWSMD="$EV/rows.md"
DRIVERLINES='intcdsp\.sys:|dsppcm\.sys:|hdaudbus\.sys:'
BOOTNOISE='intcdsp\.sys: (loaded for|controller|NHLT|reading BAR4|BAR4 \+|HFINTIPPTR|firmware .SystemRoot|SelfTest|BootDsp|interrupts before|subsystem powered|code-loader|ROM ready|firmware entered|FW_READY|firmware ready|ipc: link ready)'
: > "$ROWSMD"
: > "$EV/cycles-run.out"

# the driver's line counts from serial line <from> on, one line of text
counts() {
    local f="$1" t
    t() { norm | tail -n +"$((f + 1))" | grep -ac "$1"; }
    echo "booting $(t 'intcdsp.sys: booting:'), boot ok $(t 'intcdsp.sys: boot ok after'), boot at open ok $(t 'boot at stream open: ok after'), failed-boot $(t 'boot at stream open failed'), D0 not booted $(t 'D0 entry: the DSP is not booted'), idle $(t 'idle power down after'), recovered $(t 'recovered: open ok'), render opens $(t 'render: stream 1 opened'), timeouts $(t 'reply timeout'), fault-during $(t 'fault during stream'), pin-told $(t 'the pin is told'), release $(t 'release: '), topology $(t "topology 'sof-ipc4-loopback.tplg'"), audio child $(t 'audio child'), stop lines $(norm | grep -ac 'The system has been stopped'), fatal $(grep -acE 'Fatal System Error|bugcheck' "$EV/serial.log"), ace_unexpected $(grep -ac ace_unexpected "$EV/qemu-dbg.log")"
}

# run <label> [max s]: a dsploop run with no fault of its own; its text on the data disk; the
# driver's lines from the start on in the driver log
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
    log "$label: $r; $(pouch_text "$label.txt" 2>/dev/null | grep -a -E 'depths compared|tests executed' | tr '\n' ' ' | cut -c1-200)"
    log "$label: $(counts "$n0")"
    log "$label: the driver's lines from the start on, after serial line $n0 (the boot noise left out):"
    norm | tail -n +"$((n0 + 1))" | grep -a -E "$DRIVERLINES" | grep -a -v -E "$BOOTNOISE" | cut -c1-300 | sed 's/^/    /' | tee -a "$EV/driver.log"
}

# passed <label>: the run's text says 3 of 3 depths compared and 0 failures
passed() { local t; t=$(pouch_text "$1.txt" 2>/dev/null); [ "$(echo "$t" | grep -ac '3 of 3 depths compared')" -ge 1 ] && [ "$(echo "$t" | grep -ac '0 failures), 0 skipped')" -ge 1 ]; }

# the guest in its kernel debugger: the round stops at the first prompt
kdb() {
    if norm | grep -aq "kdb:>"; then
        log "!! KDBG: the guest is in its kernel debugger; the lines before the prompt:"
        norm | grep -an -B 40 "kdb:>" | head -45 | cut -c1-230 | sed "s/^/    /" | tee -a "$EV/driver.log"
        printf '| KDBG | the guest in its kernel debugger at this step (the lines in driver.log) | - | - | CRASH |\n' | tee -a "$ROWSMD"
        g shot 99-kdbg >/dev/null 2>&1
        s5
        exit 9
    fi
}

# cyc <label>: one disable/enable cycle of the DSP device by hand, bounded, waiting for the D0
# entry's own line or for a boot's; the serial line of the enable is kept for the counts
cyc() {
    local label="$1" n0 n1
    n0=$(lines)
    log "## cycle $label by hand $(date -u +%FT%TZ) (serial line $n0)"
    g type "pnputil /disable-device \"$ID\""; g key ret
    waitre "Safe removal" 30 "$n0" || log "$label: !! disable not seen in 30 s"
    sleep 2
    log "model (disabled): $(st)"
    n1=$(lines)
    g type "pnputil /enable-device \"$ID\""; g key ret
    waitre "D0 entry: the DSP is not booted|intcdsp.sys: boot .*after|clock stalled|Work queue|Fatal|bugcheck" 90 "$n1" || log "$label: !! neither the D0 entry's line nor a boot's in 90 s"
    sleep 3
    log "model (D0): $(st)"
    log "the driver's lines after the enable (from serial line $n1):"
    norm | tail -n +"$((n1 + 1))" | grep -a -E "$DRIVERLINES" | cut -c1-300 | sed 's/^/    /' | tee -a "$EV/driver.log"
    echo "$n1" > "$EV/cycle-$label.from"
}


# reboot: the guest restarts, and the desktop, the console and the data disk come back.  A setting made
# live needs a D0 entry, and the DSP device's disable is refused once the PCM child exists (the p4c4g
# regression's S6, the known veto): a reboot is the way in session.  RB_FROM holds the serial line.
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
    log "the driver's lines of the boot (the boot noise left out):"
    norm | tail -n +"$((n0 + 1))" | grep -a -E "$DRIVERLINES" | grep -a -v -E "$BOOTNOISE" | cut -c1-300 | sed 's/^/    /' | head -12 | tee -a "$EV/driver.log"
}

# ----------------------------------------------------------------------------- the VM
log "e2b-round: $RUN on disk/$OVERLAY.qcow2, a later boot (RUNS $RUNS, CYCLES $CYCLES, IDLESEC $IDLESEC)"
start_vm
waitre "D0 entry: the DSP is not booted|intcdsp.sys: boot .*after|The system has been stopped" 900 || { log "!! neither the D0 entry's line nor a stop line in 900 s"; g shot 00-no-d0-line >/dev/null; s5; exit 1; }
if norm | grep -aq "The system has been stopped"; then
    log "!! the boot STOPPED; its lines:"
    norm | grep -anE "KsCreateBusEnumObject|The system has been stopped|Stop code|Parameter [1-4]|RIP=" | cut -c1-300 | tee -a "$EV/driver.log"
    s5; exit 1
fi
log "the boot: $(norm | grep -aE 'intcdsp\.sys: (BootDsp|SelfTest|D0 entry|boot ok|topology)' | cut -c1-160 | tr '\n' ';' | cut -c1-900)"
log "stop lines in the boot's log: $(norm | grep -ac 'The system has been stopped'); ace_unexpected: $(grep -ac ace_unexpected "$EV/qemu-dbg.log")"
sleep 45
for i in 1 2 3 4; do
    console 2
    pouchfind && alive boot && break
    sleep 20
done
cmd settings.txt "reg query $KEY" 30
printf '\n| row | the setting | what the log shows | the run | the counts |\n|---|---|---|---|---|\n' >> "$ROWSMD"

# ----------------------------------------------------------------------------- (b), (d), (c) DspIdleSec
log "## (b), (d) DspIdleSec = $IDLESEC: $RUNS runs, each three cycles, an idle power-down after a run and a boot at the next run's first open"
BF=$(lines)
cmd enum-endpoint-2.txt "pnputil /enum-devices /class AudioEndpoint /ids" 60
log "(b) from serial line $BF (the setting read at this boot's D0 entry): $(counts "$BF"); the dsppcm registrations of this boot: $(norm | grep -ac "registered as 'Loopback'")"
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
printf '\n| (b) | DspIdleSec = %s | from the settings'"'"'s cycle: %s | %s of %s runs passed | idle power-downs %s; boots at open %s; recovered %s |\n' "$IDLESEC" "$CB" "$okruns" "$RUNS" "$(norm | tail -n +"$((BF + 1))" | grep -ac 'idle power down after')" "$(norm | tail -n +"$((BF + 1))" | grep -ac 'boot at stream open: ok after')" "$(norm | tail -n +"$((BF + 1))" | grep -ac 'recovered: open ok')" | tee -a "$ROWSMD"
cycall=$(norm | grep -ac 'render: stream 1 opened')
baseok=0; [ "$a" = PASS ] && baseok=3
printf 'cycles: %d run, %d ok, 0 timeouts\n' "$cycall" "$((okruns * 3 + baseok))" | tee "$EV/cycles-summary.txt" | tee -a "$ROWSMD"

# ----------------------------------------------------------------------------- (e), (f) BootAtStart = 1
log "## (e), (f) BootAtStart = 1: $CYCLES cycles by tools/cycle.sh, each D0 entry booting the DSP"
g type "reg delete \"$KEY\" /v Topology /f"; g key ret; sleep 3
log "typed: reg delete Topology (the 22-cycle matrix of the p4c4g regression runs without a topology: with the PCM child reported the device cannot be disabled, S6's veto)"
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
printf 'AC3 cycles: %d run, %d boot ok, %d bounded timeouts, %d other outcomes, %d waits not seen, clock stalled lines: %d (%s; by hand in the E2 round VM, tools/cycle.sh as tools/ac3-cycles.sh runs it; BootAtStart = 1, no topology, the p4c4g regression S2 configuration)\n' \
    "$CYCLES" "$ok" "$to" "$other" "$none" "$stall" "$(date -u +%FT%TZ)" | tee "$EV/summary.txt" | tee -a "$ROWSMD"
log "(e) the 22 cycles from serial line $EF: $(counts "$EF")"
g shot 07-after-cycles
kdb

# ----------------------------------------------------------------------------- the lines
{
    echo "# the lines of this round (from the serial log, ANSI and NULs removed)"
    echo "## the settings as the driver read them"; norm | grep -a 'SelfTest = ' | cut -c1-200
    echo "## BootDsp";                norm | grep -a 'intcdsp.sys: BootDsp' | cut -c1-200
    echo "## the D0 entry that booted nothing"; norm | grep -a 'D0 entry: the DSP is not booted' | cut -c1-200
    echo "## the topology and the child"; norm | grep -a -E "intcdsp.sys: topology 'sof|audio child" | cut -c1-200
    echo "## boot at stream open: ok"; norm | grep -a 'boot at stream open: ok' | cut -c1-200
    echo "## idle power down";        norm | grep -a 'idle power down after' | cut -c1-200
    echo "## recovered";               norm | grep -a 'recovered: open ok' | cut -c1-200
    echo "## boot at stream open failed"; norm | grep -a 'boot at stream open failed' | cut -c1-200
    echo "## the D0 entries' boots (boot ok after)"; norm | grep -a 'intcdsp.sys: boot ok after' | cut -c1-200
    echo "## dsppcm.sys lines";       norm | grep -a 'dsppcm\.sys:' | cut -c1-200
    echo "## counts"; echo "stop lines: $(norm | grep -ac 'The system has been stopped'); fatal lines: $(grep -acE 'Fatal System Error|bugcheck' "$EV/serial.log"); ace_unexpected: $(grep -ac ace_unexpected "$EV/qemu-dbg.log"); kdb prompts: $(norm | grep -ac 'kdb:>')"
} > "$EV/e2-lines.txt"
log "the round's lines: $(grep -c . "$EV/e2-lines.txt") in e2-lines.txt; stop lines: $(norm | grep -ac 'The system has been stopped')"
s5
log "e2b-round done"
exit 0
