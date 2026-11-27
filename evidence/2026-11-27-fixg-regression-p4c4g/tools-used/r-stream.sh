#!/bin/bash
# r-stream.sh -- S4, S5 and S6 of the p4c4g round in one VM on the S2/S3 overlay (BootDsp = 1),
# with the loopback topology set in the guest and made live by one disable/enable cycle of the
# DSP device (the topology is read at the D0 entry).  The data disk carries THIS build's
# dsploop_apitest.exe; every run's text goes to it, read on the host with mtools.
#   S4  a fault while a stream is open (R5-01): dsploop started with LIBERNT_APITEST_REQUIRED=1;
#       the host watches the serial log for the render stream's first "opened" line (a 100 ms
#       poll: a stream is open for about 2 s of guest time) and injects the fault at once;
#       the run must end by itself (bounded at RUNMAX s), the driver must log the held buffer's
#       way back and the next run must pass.  Twice: never-reply, then crash-notification.
#   S5  ipc-status=5:18 (the delete-pipeline type) injected at the ninth open, as the run ends.
#   S6  the DSP's PCM child and the codec: one disable (stop) and one enable (start) each with no
#       stream open, as pnputil answers; a restart-device where the disable is refused; then one
#       disable/enable cycle of the DSP device (the devnode cycle: the child is removed and made
#       again); then dsploop must pass.
# The VM is left running at the end (S7 and S8 follow on it: r-final.sh ends it).
set -u
RUN="${RUN:-r-stream}"
OVERLAY="${OVERLAY:-p4c4g-nt}"
. /tmp/c6g/tools/vmcommon.sh
RUNMAX="${RUNMAX:-300}"
EXE='%POUCHDRV%:\dsploop_apitest.exe'
log "r-stream: $RUN on disk/$OVERLAY.qcow2"
start_vm
waitre "Program Manager" 600 || { log "!! the desktop did not come up"; s5; exit 1; }
sleep 10
console
pouchfind || { s5; exit 1; }
alive boot || { s5; exit 1; }
regadd Topology REG_SZ sof-ipc4-loopback.tplg
regadd SelfTest REG_DWORD 0
cmd settings.txt "reg query HKLM\\SYSTEM\\CurrentControlSet\\Services\\intcdsp\\Settings" 30
( cd "$QAD" && TIMEOUT=90 tools/cycle.sh "$EV" tp-1 > "$EV/cycle-tp-1.out" 2>&1 ); log "cycle tp-1 (the topology at the D0 entry): rc=$?"
log "after the cycle: boot ok lines: $(grep -ac 'intcdsp.sys: boot ok' "$EV/cycle-tp-1.out"); the topology line: $(grep -ac "topology 'sof-ipc4-loopback.tplg'" "$EV/cycle-tp-1.out"); registered-as lines: $(grep -ac 'registered as' "$EV/cycle-tp-1.out"); audio child lines: $(grep -ac 'audio child' "$EV/cycle-tp-1.out")"
cmd enum-endpoint.txt "pnputil /enum-devices /class AudioEndpoint /ids" 60
log "the endpoints the guest lists: $(pouch_text enum-endpoint.txt | grep -c 'Loopback') Loopback lines"

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

# runfault <label> <fault|none> <nth open, 0 = at once> <max s>
#   starts a dsploop run; when <fault> is not none, injects it at the <nth> open of the render
#   stream and clears it when the run has ended.  Records: the open line's guest time, the host
#   time of the injection, the first driver line after it, the run's own last lines, whether the
#   console answered again, and the lines of the release path (held / freed / tag).
runfault() {
    local label="$1" fault="$2" nth="$3" max="$4" n0 t_open="" t_set="" r
    n0=$(lines)
    mdel -i "$POUCH@@$POUCHOFF" "::$label.txt" >/dev/null 2>&1
    local i
    for i in $(seq 1 60); do [ -z "$(pouch_text "$label.txt")" ] && break; sleep 1; done
    g type "set LIBERNT_APITEST_REQUIRED=1 && $EXE > %POUCHDRV%:\\$label.txt 2>&1"; g key ret
    log "$label: dsploop started (fault $fault at open $nth, bounded at $max s)"
    if [ "$fault" != none ] && [ "$nth" -gt 0 ]; then
        if t_open=$(waitopen "$n0" "$nth" 400); then
            ( cd "$QAD" && bash ./set-fault.sh "$EV" "$fault" > "$EV/$label.setfault.out" 2>&1 )
            t_set=$(date -u +%T)
            log "$label: open #$nth at guest $t_open s; fault '$fault' injected at $t_set (host), the model answered: $(tr '\n' ' ' < "$EV/$label.setfault.out" | cut -c1-80)"
        else
            log "$label: !! open #$nth not seen in 400 s; the fault was not injected"
        fi
    elif [ "$fault" != none ]; then
        ( cd "$QAD" && bash ./set-fault.sh "$EV" "$fault" > "$EV/$label.setfault.out" 2>&1 )
        log "$label: fault '$fault' set before any open ($(date -u +%T))"
    fi
    # the run's end: its text on the data disk
    local t0=$(date +%s) i
    for i in $(seq 1 "$max"); do
        [ -n "$(pouch_text "$label.txt" 2>/dev/null)" ] && { sleep 3; break; }
        sleep 1
    done
    r="ended after about $i s"
    [ -z "$(pouch_text "$label.txt" 2>/dev/null)" ] && r="!! NOT ended within $max s (the text file is still empty)"
    if [ "$fault" != none ]; then
        ( cd "$QAD" && bash ./set-fault.sh "$EV" none > "$EV/$label.setfault-none.out" 2>&1 )
        log "$label: fault cleared ($(date -u +%T))"
    fi
    sleep 2
    alive "$label" > /dev/null 2>&1 && r="$r; the console answers" || r="$r; !! the console does not answer"
    log "$label: $r"
    log "$label: the run's own lines (compared / preconditions / tests executed / errors):"
    pouch_text "$label.txt" | grep -a -E 'compared|preconditions|tests executed|fail|error|Error|timed out|unhandled|Access' | cut -c1-200 | sed 's/^/    /' | tee -a "$EV/driver.log"
    log "$label: the driver's lines from the open on (ipc / stream / held / freed / tag / power), after serial line $n0:"
    norm | tail -n +"$((n0 + 1))" | grep -a -E "intcdsp\.sys:|dsppcm\.sys:|hdaudbus\.sys:" | grep -a -v -E "intcdsp\.sys: (loaded for|controller|NHLT|reading BAR4|BAR4 \+|HFINTIPPTR|firmware .SystemRoot|SelfTest|BootDsp|booting:|interrupts before|subsystem powered|code-loader|ROM ready|firmware entered|FW_READY|firmware ready|ipc: link ready)" | cut -c1-330 | sed 's/^/    /' | tee -a "$EV/driver.log"
    log "$label: held-buffer lines: $(norm | tail -n +"$((n0 + 1))" | grep -ac -E 'held|stays with the stream|still held'); freed-under lines: $(norm | tail -n +"$((n0 + 1))" | grep -ac 'freed under'); tag lines: $(norm | tail -n +"$((n0 + 1))" | grep -ac 'tag'); ipc lines: $(norm | tail -n +"$((n0 + 1))" | grep -ac 'intcdsp.sys: ipc:'); stop lines: $(norm | grep -ac 'The system has been stopped'); fatal: $(grep -acE 'Fatal System Error|bugcheck' "$EV/serial.log"); ace_unexpected: $(grep -ac ace_unexpected "$EV/qemu-dbg.log")"
}

# mustpass <label>: a dsploop run with no fault; if it does not pass, one disable/enable cycle of
# the DSP device and a second run (<label>-after-cycle) -- whether the device needed the cycle is
# the record.
mustpass() {
    local label="$1" p
    runfault "$label" none 0 "$RUNMAX"
    p=$(pouch_text "$label.txt" 2>/dev/null | grep -ac '0 failures), 0 skipped')
    if [ "$p" -ge 1 ] && [ "$(pouch_text "$label.txt" | grep -ac '3 of 3 depths compared')" -ge 1 ]; then
        log "$label: PASS (3 of 3 depths compared, 0 failures): recovered: open ok"
        return 0
    fi
    log "$label: !! the run after the fault did not pass (compared lines: $(pouch_text "$label.txt" | grep -ac 'compared within'); failures line: $(pouch_text "$label.txt" | grep -a 'tests executed' | head -1))"
    ( cd "$QAD" && TIMEOUT=90 tools/cycle.sh "$EV" "rec-$label" > "$EV/cycle-rec-$label.out" 2>&1 ); log "cycle rec-$label: rc=$?; boot ok: $(grep -ac 'intcdsp.sys: boot ok' "$EV/cycle-rec-$label.out")"
    runfault "$label-after-cycle" none 0 "$RUNMAX"
    p=$(pouch_text "$label-after-cycle.txt" 2>/dev/null | grep -ac '0 failures), 0 skipped')
    [ "$p" -ge 1 ] && log "$label-after-cycle: PASS after the device cycle" || log "$label-after-cycle: !! still not passing after the device cycle"
}

# --- S4a: never-reply while a stream is open
runfault s4a-never-reply never-reply 1 "$RUNMAX"
g shot s4a-after >/dev/null
# --- the next run must pass
mustpass s4a-recovered
# --- S4b: crash-notification while a stream is open
runfault s4b-crash-notification crash-notification 1 "$RUNMAX"
g shot s4b-after >/dev/null
mustpass s4b-recovered
# --- S5: a status on the delete-pipeline type as the run ends (the ninth open)
runfault s5-status-18 ipc-status=5:18 9 "$RUNMAX"
g shot s5-after >/dev/null
mustpass s5-recovered

# --- S6: the PCM child and the codec, no stream open
n0=$(lines)
cmd s6-1-child-disable.txt "pnputil /disable-device \"$CHILD\"" 60
cmd s6-2-child-enable.txt "pnputil /enable-device \"$CHILD\"" 60
cmd s6-3-child-restart.txt "pnputil /restart-device \"$CHILD\"" 60
cmd s6-4-codec-disable.txt "pnputil /disable-device \"$CODEC\"" 60
cmd s6-5-codec-enable.txt "pnputil /enable-device \"$CODEC\"" 60
cmd s6-6-codec-restart.txt "pnputil /restart-device \"$CODEC\"" 60
cmd s6-7-enum-media.txt "pnputil /enum-devices /class Media /ids" 60
cmd s6-8-enum-system.txt "pnputil /enum-devices /class System /ids" 60
sleep 3
log "S6: the driver's lines during the six commands (after serial line $n0):"
norm | tail -n +"$((n0 + 1))" | grep -a -E "intcdsp\.sys:|dsppcm\.sys:|hdaudbus\.sys:|Safe removal|RestartDevice|DisableDevice|EnableDevice|QueryRemove|Surprise|clock stalled|interrupt storm|Work queue|Fatal|bugcheck|The system has been stopped" | grep -a -v -E "booting:|interrupts before|subsystem powered|code-loader|ROM ready|firmware entered|FW_READY|loaded for|controller 8086|NHLT|reading BAR4|BAR4 \+|HFINTIPPTR" | cut -c1-300 | sed 's/^/    /' | tee -a "$EV/driver.log"
log "S6: the child's lines in enum-media.txt: $(pouch_text s6-7-enum-media.txt | grep -ci 'INTCDSP'); the codec's Status line: $(pouch_text s6-7-enum-media.txt | grep -a -A1 'HDAUDIO' | grep -a -i 'Status' | head -1 | tr -s ' ')"
( cd "$QAD" && TIMEOUT=90 tools/cycle.sh "$EV" s6-dsp > "$EV/cycle-s6-dsp.out" 2>&1 ); log "cycle s6-dsp (the DSP device: the devnode cycle): rc=$?; boot ok: $(grep -ac 'intcdsp.sys: boot ok' "$EV/cycle-s6-dsp.out"); registered as: $(grep -ac 'registered as' "$EV/cycle-s6-dsp.out")"
mustpass s6-recovered
cmd s6-9-enum-media-after.txt "pnputil /enum-devices /class Media /ids" 60
log "S6: the child after the cycle: $(pouch_text s6-9-enum-media-after.txt | grep -c 'INTCDSP') INTCDSP lines; stop lines: $(norm | grep -ac 'The system has been stopped'); fatal: $(grep -acE 'Fatal System Error|bugcheck' "$EV/serial.log"); ace_unexpected: $(grep -ac ace_unexpected "$EV/qemu-dbg.log")"
log "r-stream: done; the VM is left running for S7 and S8 (lib-run pid $LR, sockets $SOCK)"
echo "$LR" > "$EV/lib-run.pid"
