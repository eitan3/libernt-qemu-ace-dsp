#!/bin/bash
# e1c-round.sh -- the P5 E1c VM round on the p5e1c image, one VM, every step bounded (the E1b round's
# scripts as they ran: evidence/2026-11-27-p5-e1b/tools-used/, their functions unchanged, the flow E1c's):
#   the first boot of a fresh overlay (the Setup wizard's chords), BootDsp = 1 and the loopback topology
#     set in the guest, made live by one disable/enable cycle of the DSP device, a baseline dsploop run
#     that must pass;
#   (b) never-reply-running=19, (c) crash-during-stream=1 and =2, and the asynchronous exception
#     crash-async=500, each set at the render stream's first open of a run: the run must end by itself
#     with its error, and a second run must pass with a recovered line and no reboot;
#   (d) one bounded attempt at a D0 cycle in session (the guest's sleep, then the DSP device's disable);
#   (e) the driver's and the engine's lines, from the serial log and the runs' texts.
# The text the guest writes goes to the data disk (read on the host with mtools); the model's fault is
# set over QMP (set-fault.sh) at the render stream's first "opened" line (a 100 ms poll).
#   env: RUNMAX (a run's cap, s), RUN, OVERLAY
set -u
RUN="${RUN:-e1c-round}"
OVERLAY="${OVERLAY:-p5e1c}"
. /tmp/e1c/tools/vmcommon.sh
RUNMAX="${RUNMAX:-150}"
EXE='%POUCHDRV%:\dsploop_apitest.exe'
ROWS="${ROWS:-halt-rom=43 halt-rom=44 halt-fw=51 crash-notification abi=2 window-read-fail never-power never-ack never-ready never-enter never-fwready never-reply drop-requests ipc-status=5 bad-tuples truncated-reply version-shift scale:1550 scale:0.001 none}"
ROWSMD="$EV/rows.md"
DRIVERLINES='intcdsp\.sys:|dsppcm\.sys:|hdaudbus\.sys:'
BOOTNOISE='intcdsp\.sys: (loaded for|controller|NHLT|reading BAR4|BAR4 \+|HFINTIPPTR|firmware .SystemRoot|SelfTest|BootDsp|booting:|interrupts before|subsystem powered|code-loader|ROM ready|firmware entered|FW_READY|firmware ready|ipc: link ready)'
: > "$ROWSMD"

# the guest timestamp of the render stream's <nth> "opened" line after serial line <from>
opens_after() { tail -n +"$(($1 + 1))" "$EV/serial.log" | grep -ac 'render: stream 1 opened'; }
# waitopen <from-line> <nth> <timeout s>: prints the open line's guest seconds; 1 on a timeout
waitopen() {
    local from="$1" nth="$2" to="$3" t0=$(date +%s)
    while [ "$(opens_after "$from")" -lt "$nth" ]; do
        [ $(( $(date +%s) - t0 )) -ge "$to" ] && return 1
        sleep 0.1
    done
    tail -n +"$((from + 1))" "$EV/serial.log" | grep -a 'render: stream 1 opened' | tail -n "$nth" | head -n 1 | grep -oE '\[ *[0-9.]+\]' | tr -d '[] '
}

# run <label> [max s]: a dsploop run with no fault of its own; its text on the data disk; the
# driver's lines from the start on in the driver log; prints nothing
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
    log "$label: opens $(norm | tail -n +"$((n0 + 1))" | grep -ac 'render: stream 1 opened'), recovered lines $(norm | tail -n +"$((n0 + 1))" | grep -ac 'recovered: open ok'), failed-boot lines $(norm | tail -n +"$((n0 + 1))" | grep -ac 'boot at stream open failed'), fault-during lines $(norm | tail -n +"$((n0 + 1))" | grep -ac 'fault during stream'), pin-told lines $(norm | tail -n +"$((n0 + 1))" | grep -ac 'the pin is told'), release lines $(norm | tail -n +"$((n0 + 1))" | grep -ac 'release: '), pin-free lines $(norm | tail -n +"$((n0 + 1))" | grep -ac "its pin's free returned"), freed-under lines $(norm | tail -n +"$((n0 + 1))" | grep -ac 'freed under'), stop lines $(norm | grep -ac 'The system has been stopped'), fatal $(grep -acE 'Fatal System Error|bugcheck' "$EV/serial.log"), ace_unexpected $(grep -ac ace_unexpected "$EV/qemu-dbg.log")"
    log "$label: the driver's lines from the start on, after serial line $n0:"
    norm | tail -n +"$((n0 + 1))" | grep -a -E "$DRIVERLINES" | grep -a -v -E "$BOOTNOISE" | cut -c1-330 | sed 's/^/    /' | tee -a "$EV/driver.log"
}

# runfault <label> <fault> <nth open> [max s]: a run with the fault injected at the render
# stream's <nth> open, cleared when the run has ended
runfault() {
    local label="$1" fault="$2" nth="$3" n0 t_open t_set
    n0=$(lines)
    log "$label: dsploop with fault $fault at open $nth (from serial line $n0)"
    # the run is started by run(), which counts the lines from its own start: the injection
    # must watch the same lines, so the run is started here and waited for by hand
    mdel -i "$POUCH@@$POUCHOFF" "::$label.txt" >/dev/null 2>&1
    g type "set LIBERNT_APITEST_REQUIRED=1&& $EXE > %POUCHDRV%:\\$label.txt 2>&1"; g key ret
    if t_open=$(waitopen "$n0" "$nth" 150); then
        setfault "$fault" x-delay-scale=1
        t_set=$(date -u +%T)
        log "$label: open #$nth at guest $t_open s; fault '$fault' set at $t_set (host)"
    else
        log "$label: !! open #$nth not seen in 150 s; the fault was not set"
    fi
    local t0=$(date +%s) i r
    for i in $(seq 1 "$RUNMAX"); do
        [ -n "$(pouch_text "$label.txt" 2>/dev/null)" ] && { sleep 3; break; }
        sleep 1
    done
    if [ -z "$(pouch_text "$label.txt" 2>/dev/null)" ]; then r="!! NOT ended within $RUNMAX s (the text file is still empty)"; else r="ended after about $(( $(date +%s) - t0 )) s"; fi
    setfault none x-delay-scale=1
    log "$label: fault cleared ($(date -u +%T))"
    sleep 2
    alive "$label" > /dev/null 2>&1 && r="$r; the console answers" || r="$r; !! the console does not answer"
    log "$label: $r; $(pouch_text "$label.txt" 2>/dev/null | grep -a -E 'depths compared|tests executed' | tr '\n' ' ' | cut -c1-200)"
    log "$label: opens $(norm | tail -n +"$((n0 + 1))" | grep -ac 'render: stream 1 opened'), recovered lines $(norm | tail -n +"$((n0 + 1))" | grep -ac 'recovered: open ok'), failed-boot lines $(norm | tail -n +"$((n0 + 1))" | grep -ac 'boot at stream open failed'), fault-during lines $(norm | tail -n +"$((n0 + 1))" | grep -ac 'fault during stream'), pin-told lines $(norm | tail -n +"$((n0 + 1))" | grep -ac 'the pin is told'), release lines $(norm | tail -n +"$((n0 + 1))" | grep -ac 'release: '), pin-free lines $(norm | tail -n +"$((n0 + 1))" | grep -ac "its pin's free returned"), freed-under lines $(norm | tail -n +"$((n0 + 1))" | grep -ac 'freed under'), stop lines $(norm | grep -ac 'The system has been stopped'), fatal $(grep -acE 'Fatal System Error|bugcheck' "$EV/serial.log"), ace_unexpected $(grep -ac ace_unexpected "$EV/qemu-dbg.log")"
    log "$label: the run's own lines (errors and the summary):"
    pouch_text "$label.txt" 2>/dev/null | grep -a -i -E 'fail|error|invalidated|0x8|tests executed|compared' | cut -c1-220 | sed 's/^/    /' | tee -a "$EV/driver.log"
    log "$label: the driver's lines from the start on, after serial line $n0:"
    norm | tail -n +"$((n0 + 1))" | grep -a -E "$DRIVERLINES" | grep -a -v -E "$BOOTNOISE" | cut -c1-330 | sed 's/^/    /' | tee -a "$EV/driver.log"
}

# passed <label>: the run's text says 3 of 3 depths compared and 0 failures
passed() { local t; t=$(pouch_text "$1.txt" 2>/dev/null); [ "$(echo "$t" | grep -ac '3 of 3 depths compared')" -ge 1 ] && [ "$(echo "$t" | grep -ac '0 failures), 0 skipped')" -ge 1 ]; }

# the guest in its kernel debugger (a kernel exception caught on the serial port): the round
# stops at the first prompt, the lines before it in the driver log, and nothing more is typed
kdb() {
    if norm | grep -aq "kdb:>"; then
        log "!! KDBG: the guest is in its kernel debugger; the lines before the prompt:"
        norm | grep -an -B 40 "kdb:>" | head -45 | cut -c1-230 | sed "s/^/    /" | tee -a "$EV/driver.log"
        printf "| KDBG | the guest in its kernel debugger at this step (the lines in driver.log) | - | - | CRASH |\n" | tee -a "$ROWSMD"
        g shot 99-kdbg >/dev/null 2>&1
        s5
        exit 9
    fi
}

# ----------------------------------------------------------------------------- the VM
# The flow of the E1c round: the first boot of a fresh overlay (the wizard, the settings, the topology
# live, a baseline run that must pass), then one row per knob -- (b) never-reply-running, (c)
# crash-during-stream =1 and =2, and the asynchronous exception crash-async -- each one dsploop run with
# the knob set at the render stream's first open, which must end by itself with its error, then a
# second run that must pass with a recovered line and no reboot; then (d) one bounded attempt at a D0
# cycle in session, and (e) the lines.  The 20 boot-phase fault rows are not repeated (E1b's (a)).
log "e1c-round: $RUN on disk/$OVERLAY.qcow2"
start_vm
waitre "Storage expansion not offered|The system has been stopped|Program Manager" 900 || { log "!! neither the first-boot setup's line nor a stop line in 900 s"; g shot 00-no-setup-line >/dev/null; s5; exit 1; }
if norm | grep -aq "The system has been stopped"; then
    log "!! the first boot STOPPED; its lines:"
    norm | grep -anE "KsCreateBusEnumObject|The system has been stopped|Stop code|Parameter [1-4]|RIP=" | cut -c1-300 | tee -a "$EV/driver.log"
    s5; exit 1
fi
log "the first boot: $(norm | grep -aE 'First-boot setup|Storage expansion|intcdsp\.sys: (BootDsp|boot ok|topology|DSP power down)' | cut -c1-160 | tr '\n' ';' | cut -c1-900)"
log "stop lines in the boot's log: $(norm | grep -ac 'The system has been stopped'); ace_unexpected: $(grep -ac ace_unexpected "$EV/qemu-dbg.log")"
sleep 5
if norm | grep -aq "Storage expansion\|First-boot setup"; then
    g shot 01-desktop-before-wizard >/dev/null
    wizard 15
    g shot 02-after-wizard >/dev/null
    sleep 20
else
    log "a later boot of the overlay (no first-boot setup line): no wizard chords"
fi
console
pouchfind || { g shot 03-no-data-disk-letter >/dev/null; s5; exit 1; }
alive boot || { g shot 04-console-silent >/dev/null; s5; exit 1; }
regadd BootDsp REG_DWORD 1
regadd Topology REG_SZ sof-ipc4-loopback.tplg
regadd SelfTest REG_DWORD 0
cmd settings.txt "reg query $KEY" 30
# the topology live: at this boot's D0 entry already, or by one disable/enable cycle of the DSP device
if [ "$(norm | grep -ac "topology 'sof-ipc4-loopback.tplg'")" -gt 0 ]; then
    log "the topology at this boot's D0 entry: boot ok $(norm | grep -ac 'intcdsp.sys: boot ok'); topology line $(norm | grep -ac "topology 'sof-ipc4-loopback.tplg'"); audio child $(norm | grep -ac 'audio child')"
else
    ( cd "$QAD" && TIMEOUT=90 tools/cycle.sh "$EV" tp-1 > "$EV/cycle-tp-1.out" 2>&1 ); log "cycle tp-1 (the topology at the D0 entry): rc=$?"
    log "after the cycle: boot ok $(grep -ac 'intcdsp.sys: boot ok' "$EV/cycle-tp-1.out"); the topology line $(grep -ac "topology 'sof-ipc4-loopback.tplg'" "$EV/cycle-tp-1.out"); registered as $(grep -ac 'registered as' "$EV/cycle-tp-1.out")"
fi
cmd enum-endpoint.txt "pnputil /enum-devices /class AudioEndpoint /ids" 60
log "the endpoints the guest lists: $(pouch_text enum-endpoint.txt | grep -c 'Loopback') Loopback lines"
run baseline
passed baseline && log "baseline: PASS" || log "baseline: !! the run with no fault did not pass"
g shot 05-after-baseline
kdb

# ----------------------------------------------------------------------------- (b), (c), the async row
# each knob: one dsploop run with the knob set at the render stream's first open (cleared when the
# run has ended), which must end by itself with its error, then a second run that must pass with a
# recovered line and no reboot.  The counts are of the first run's lines.
printf '\n| knob | at open | fault during stream | the pin told | release | the pin'"'"'s free | the run | the second run |\n|---|---|---|---|---|---|---|---|\n' >> "$ROWSMD"
knob() {
    local label="$1" fault="$2" n0 f p rl pf r1 r2 npr ex
    n0=$(lines)
    runfault "$label" "$fault" 1
    f=$(norm | tail -n +"$((n0 + 1))" | grep -a 'fault during stream' | head -1 | sed 's/^\[ *[0-9.]*\] intcdsp.sys: //' | cut -c1-120)
    p=$(norm | tail -n +"$((n0 + 1))" | grep -ac 'the pin is told')
    rl=$(norm | tail -n +"$((n0 + 1))" | grep -a 'release: ' | head -1 | sed 's/^\[ *[0-9.]*\] intcdsp.sys: //' | cut -c1-120)
    pf=$(norm | tail -n +"$((n0 + 1))" | grep -ac "its pin's free returned")
    r1=$(pouch_text "$label.txt" 2>/dev/null | grep -a 'tests executed' | head -1 | cut -c1-110)
    npr=$(norm | tail -n +"$((n0 + 1))" | grep -ac 'read at a stream')
    ex=$(grep -ac 'exception caught with no request outstanding' "$EV/qemu-dbg.log" 2>/dev/null)
    log "$label: the poll point's lines in this run: $npr; the model's asynchronous exceptions so far (its -d log): $ex"
    run "$label-second"
    passed "$label-second" && r2="PASS" || r2="**not a pass**"
    printf '| %s | 1 | %s | %s | %s | %s | %s | %s |\n' "$fault" "${f:-**none**}" "$p" "${rl:-**none**}" "$pf" "${r1:-**no summary**}" "$r2" | tee -a "$ROWSMD"
    kdb
}
knob b never-reply-running=19
knob c1 crash-during-stream=1
knob c2 crash-during-stream=2
knob async crash-async=500
g shot 06-after-knobs

# ----------------------------------------------------------------------------- (d) a D0 cycle in session
log "## (d) a D0 cycle in session: the guest's sleep states, one bounded sleep attempt, one bounded disable attempt"
cmd d-powercfg.txt "powercfg /a" 30
log "d-powercfg: $(pouch_text d-powercfg.txt 2>/dev/null | tr '\n' ' ' | cut -c1-300)"
n0=$(lines)
log "d-sleep: rundll32 powrprof.dll,SetSuspendState 0,1,0 typed (bounded at 90 s)"
g type "rundll32 powrprof.dll,SetSuspendState 0,1,0"; g key ret
if waitre "Entering sleep state|Sleep: Sending|sleep state S[1-4]" 90 "$n0"; then
    sleep 8
    g mon system_wakeup >/dev/null; log "d-sleep: system_wakeup sent"
    waitre "Program Manager|Resuming|resume" 300 "$n0" && log "d-sleep: the desktop is back" || log "d-sleep: !! no desktop in 300 s after the wake"
    run d-after-resume
else
    log "d-sleep: no sleep line in 90 s: the guest did not sleep (E1b's README: no S3 in the VM)"
fi
g shot 07-after-sleep-attempt >/dev/null
alive after-sleep >/dev/null 2>&1 && log "d-sleep: the console answers" || log "d-sleep: !! the console does not answer"
# the DSP device's disable: refused with the topology loaded (C10/C11), one bounded attempt
n0=$(lines)
cmd d-disable.txt "pnputil /disable-device \"$ID\"" 30
log "d-disable: the guest's answer: $(pouch_text d-disable.txt 2>/dev/null | tr '\n' ' ' | cut -c1-300); D0 lines after it: $(norm | tail -n +"$((n0 + 1))" | grep -ac 'intcdsp.sys: DSP power down')"
alive after-disable >/dev/null 2>&1 && log "d-disable: the console answers" || log "d-disable: !! the console does not answer"
run d-after-disable
kdb

# ----------------------------------------------------------------------------- (e) the lines
{
    echo "# the lines of this round (from the serial log, ANSI and NULs removed)"
    echo "## fault during stream";   norm | grep -a 'fault during stream' | cut -c1-200
    echo "## the poll point (read at a stream's period)"; norm | grep -a 'read at a stream' | cut -c1-220
    echo "## the pin told";          norm | grep -a 'the pin is told' | cut -c1-200
    echo "## release";               norm | grep -a 'release: ' | cut -c1-200
    echo "## the pin's free";        norm | grep -a "its pin's free returned" | cut -c1-200
    echo "## recovered";             norm | grep -a 'recovered: open ok' | cut -c1-200
    echo "## boot at stream open failed"; norm | grep -a 'boot at stream open failed' | cut -c1-200
    echo "## dsppcm.sys lines";      norm | grep -a 'dsppcm\.sys:' | cut -c1-200
    echo "## counts"; echo "stop lines: $(norm | grep -ac 'The system has been stopped'); fatal lines: $(grep -acE 'Fatal System Error|bugcheck' "$EV/serial.log"); ace_unexpected: $(grep -ac ace_unexpected "$EV/qemu-dbg.log"); freed-under lines: $(norm | grep -ac 'freed under'); kdb prompts: $(norm | grep -ac 'kdb:>')"
} > "$EV/e1-lines.txt"
log "the round's lines: $(grep -c . "$EV/e1-lines.txt") in e1-lines.txt; stop lines: $(norm | grep -ac 'The system has been stopped')"
s5
log "e1c-round done"
exit 0
