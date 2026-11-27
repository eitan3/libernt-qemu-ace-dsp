#!/bin/bash
# r2-common.sh -- sourced by s4b.sh and s6.sh (the second attempt at S4-S6 after the first VM's
# lesson: after a fault with a stream open the DSP stays down until the device is started again,
# and the PnP disable of the DSP device did not complete, so each fault gets its own boot).
# The functions are r-stream.sh's (runfault, mustpass) with the recovery cycle's waits shortened,
# and the switch's value typed without a trailing space (`=1&&`: cmd.exe keeps the space).
set -u
. /tmp/c6g/tools/vmcommon.sh
RUNMAX="${RUNMAX:-300}"
EXE='%POUCHDRV%:\dsploop_apitest.exe'

session() {
    start_vm
    waitre "Program Manager" 600 || { log "!! the desktop did not come up"; s5; exit 1; }
    sleep 10
    console
    pouchfind || { s5; exit 1; }
    alive boot || { s5; exit 1; }
    log "the boot: AUTOCHK lines $(norm | grep -ac 'AUTOCHK'); boot ok lines $(norm | grep -ac 'intcdsp.sys: boot ok'); the topology line $(norm | grep -ac "topology 'sof-ipc4-loopback.tplg'"); registered-as lines $(norm | grep -ac 'registered as'); audio child $(norm | grep -ac 'audio child'); stop lines $(norm | grep -ac 'The system has been stopped')"
}

opens_after() { tail -n +"$(($1 + 1))" "$EV/serial.log" | grep -ac 'render: stream 1 opened'; }
waitopen() {
    local from="$1" nth="$2" to="$3" t0=$(date +%s)
    while [ "$(opens_after "$from")" -lt "$nth" ]; do
        [ $(( $(date +%s) - t0 )) -ge "$to" ] && return 1
        sleep 0.1
    done
    tail -n +"$((from + 1))" "$EV/serial.log" | grep -a 'render: stream 1 opened' | tail -n "$nth" | head -n 1 | grep -oE '\[ *[0-9.]+\]' | tr -d '[] '
}

runfault() {
    local label="$1" fault="$2" nth="$3" max="$4" n0 t_open="" t_set="" r
    n0=$(lines)
    mdel -i "$POUCH@@$POUCHOFF" "::$label.txt" >/dev/null 2>&1
    g type "set LIBERNT_APITEST_REQUIRED=1&& $EXE > %POUCHDRV%:\\$label.txt 2>&1"; g key ret
    log "$label: dsploop started (fault $fault at open $nth, bounded at $max s)"
    if [ "$fault" != none ] && [ "$nth" -gt 0 ]; then
        if t_open=$(waitopen "$n0" "$nth" 400); then
            ( cd "$QAD" && bash ./set-fault.sh "$EV" "$fault" > "$EV/$label.setfault.out" 2>&1 )
            t_set=$(date -u +%T)
            log "$label: open #$nth at guest $t_open s; fault '$fault' injected at $t_set (host): $(tr '\n' ' ' < "$EV/$label.setfault.out" | cut -c1-60)"
        else
            log "$label: !! open #$nth not seen in 400 s; the fault was not injected"
        fi
    fi
    local t0=$(date +%s) i
    for i in $(seq 1 "$max"); do
        [ -n "$(pouch_text "$label.txt" 2>/dev/null)" ] && { sleep 3; break; }
        sleep 1
    done
    r="ended after about $i s"
    [ -z "$(pouch_text "$label.txt" 2>/dev/null)" ] && r="!! NOT ended within $max s"
    if [ "$fault" != none ]; then
        ( cd "$QAD" && bash ./set-fault.sh "$EV" none > "$EV/$label.setfault-none.out" 2>&1 )
        log "$label: fault cleared ($(date -u +%T))"
    fi
    sleep 2
    alive "$label" > /dev/null 2>&1 && r="$r; the console answers" || r="$r; !! the console does not answer"
    log "$label: $r"
    pouch_text "$label.txt" | grep -a -E 'compared|preconditions|tests executed|Test failed' | cut -c1-200 | sed 's/^/    /' | tee -a "$EV/driver.log"
    log "$label: the driver's lines from the start on, after serial line $n0:"
    norm | tail -n +"$((n0 + 1))" | grep -a -E "intcdsp\.sys:|dsppcm\.sys:|hdaudbus\.sys:" | grep -a -v -E "intcdsp\.sys: (loaded for|controller|NHLT|reading BAR4|BAR4 \+|HFINTIPPTR|firmware .SystemRoot|SelfTest|BootDsp|booting:|interrupts before|subsystem powered|code-loader|ROM ready|firmware entered|FW_READY|firmware ready|ipc: link ready)" | cut -c1-330 | sed 's/^/    /' | tee -a "$EV/driver.log"
    log "$label: held-buffer lines: $(norm | tail -n +"$((n0 + 1))" | grep -ac -E 'held|stays with the stream|still held'); freed-under lines: $(norm | tail -n +"$((n0 + 1))" | grep -ac 'freed under'); tag lines: $(norm | tail -n +"$((n0 + 1))" | grep -ac 'tag'); ipc lines: $(norm | tail -n +"$((n0 + 1))" | grep -ac 'intcdsp.sys: ipc:'); stop lines: $(norm | grep -ac 'The system has been stopped'); fatal: $(grep -acE 'Fatal System Error|bugcheck' "$EV/serial.log"); ace_unexpected: $(grep -ac ace_unexpected "$EV/qemu-dbg.log")"
}

mustpass() {
    local label="$1" p n0
    runfault "$label" none 0 "$RUNMAX"
    p=$(pouch_text "$label.txt" 2>/dev/null | grep -ac '0 failures), 0 skipped')
    if [ "$p" -ge 1 ] && [ "$(pouch_text "$label.txt" | grep -ac '3 of 3 depths compared')" -ge 1 ]; then
        log "$label: PASS (3 of 3 depths compared, 0 failures): recovered: open ok"
        return 0
    fi
    log "$label: !! the run after the fault did not pass (compared lines: $(pouch_text "$label.txt" | grep -ac 'compared within'); failures line: $(pouch_text "$label.txt" | grep -a 'tests executed' | head -1))"
    n0=$(lines)
    ( cd "$QAD" && TIMEOUT=30 tools/cycle.sh "$EV" "rec-$label" > "$EV/cycle-rec-$label.out" 2>&1 ); log "cycle rec-$label: rc=$?; boot ok: $(grep -ac 'intcdsp.sys: boot ok' "$EV/cycle-rec-$label.out"); the PnP lines of it: $(norm | tail -n +"$((n0 + 1))" | grep -a -c -E 'PNP_|Safe removal|QueryRemove|RemoveDevice')"
    runfault "$label-after-cycle" none 0 "$RUNMAX"
    p=$(pouch_text "$label-after-cycle.txt" 2>/dev/null | grep -ac '0 failures), 0 skipped')
    [ "$p" -ge 1 ] && log "$label-after-cycle: PASS after the device cycle" || log "$label-after-cycle: !! still not passing after the device cycle"
}
