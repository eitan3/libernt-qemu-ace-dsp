#!/bin/bash
# e4-cd-d.sh -- row (d) on the same VM: a level kept by the applet survives an idle power-down.  Phase 1
# (after go2): unmute by the tray's key (the level -8 dB stays), a console, dsploop once -- the first open
# after the idle power-down boots the DSP and re-sends the kept level (the line), the stream runs at it
# (dsploop compares against the unscaled tone: its first differing sample carries the ratio).  Phase 2
# (after go3, the tray's keys having put the level back at unity): dsploop once more after the idle
# power-down: the line at unity, and the stream test exact.  Waits for "stop" are the start script's.
set -u
RUN="${RUN:-e4-cd}"
OVERLAY="${OVERLAY:-p5e3}"
. /tmp/e4/tools/vmcommon.sh
DRIVERLINES='intcdsp\.sys:|dsppcm\.sys:|hdaudbus\.sys:'
BOOTNOISE='intcdsp\.sys: (loaded for|controller|NHLT|reading BAR4|BAR4 \+|HFINTIPPTR|firmware .SystemRoot|interrupts before|subsystem powered|code-loader|ROM ready|firmware entered|FW_READY|firmware ready|ipc: link ready)'
RUNMAX=150
EXE='%POUCHDRV%:\dsploop_apitest.exe'

run() {
    local label="$1" n0 t0 i r
    n0=$(lines)
    mdel -i "$POUCH@@$POUCHOFF" "::$label.txt" >/dev/null 2>&1
    for i in $(seq 1 30); do [ -z "$(pouch_text "$label.txt")" ] && break; sleep 1; done
    t0=$(date +%s)
    g type "set LIBERNT_APITEST_REQUIRED=1&& $EXE > %POUCHDRV%:\\$label.txt 2>&1"; g key ret
    for i in $(seq 1 "$RUNMAX"); do
        [ -n "$(pouch_text "$label.txt" 2>/dev/null)" ] && { sleep 3; break; }
        sleep 1
    done
    if [ -z "$(pouch_text "$label.txt" 2>/dev/null)" ]; then r="!! NOT ended within $RUNMAX s"; else r="ended after about $(( $(date +%s) - t0 )) s"; fi
    log "$label: $r"
    log "$label: $(pouch_text "$label.txt" 2>/dev/null | grep -a -E 'depths compared|tests executed|frames compared|differing sample|was not captured' | tr '\n' ' ' | cut -c1-900)"
    norm | tail -n +"$((n0 + 1))" | grep -a -E "$DRIVERLINES" | grep -a -v -E "$BOOTNOISE" | grep -a -E "boot at stream open|gain: |idle power down|recovered|failed" | cut -c1-300 | sed 's/^/    /' | tee -a "$EV/driver.log"
}

waitfile() {
    local i
    for i in $(seq 1 900); do [ -f "$EV/$1" ] && return 0; sleep 2; done
    log "!! no $1 in 30 minutes"
    return 1
}

log "## row (d): waiting for $EV/go2"
waitfile go2 || exit 1
N0=$(lines)
g key audiomute >/dev/null
sleep 4
log "unmute by the tray's key (audiomute):"
norm | tail -n +"$((N0 + 1))" | grep -a -E "gain: " | cut -c1-300 | sed 's/^/    /' | tee -a "$EV/driver.log"
console 2
pouchfind || exit 1
alive d1 >/dev/null 2>&1 || log "!! the console does not answer before d1"
N0=$(lines)
log "## (d1) dsploop after the applet's level (-8 dB since the last key), the DSP down by idle since the boot"
run d1-level
IDLE1=$(norm | tail -n +"$((N0 + 1))" | grep -ac "idle power down after")
log "(d1) idle power-downs during the run: $IDLE1"

log "## waiting for $EV/go3 (the level back at unity by the tray's keys, then the idle power-down)"
waitfile go3 || exit 1
console 2
alive d2 >/dev/null 2>&1 || log "!! the console does not answer before d2"
N0=$(lines)
log "## (d2) dsploop at unity after the idle power-down"
run d2-unity
log "(d2) idle power-downs during the run: $(norm | tail -n +"$((N0 + 1))" | grep -ac "idle power down after")"
g shot 91-end >/dev/null
log "row (d) done; the start script ends the VM at $EV/stop"
