#!/bin/bash
# round.sh -- E5c's volume-level row in the VM on the owner's image (test-burnboot-leg1): a fresh
# first-boot overlay over the staged VHD (the baked settings boot the DSP by themselves), the wizard,
# the console, the data disk's setdef.cmd (two short typed lines: the drive, the command) setting
# DefaultOutput to the DSP's render endpoint, the slider by the tray's keys (Win+D, volumedown x4),
# dsploop at that level, mute and unmute by the tray's mute key, dsploop once more; the VM is ended by
# the ACPI button.  No long line is typed (N15-34: the guest drops characters of a typed line).
#   env: RUN (level)
set -u
RUN="${RUN:-level}"
. /tmp/e5c/tools/vmcommon.sh

counts() {
    local f="${1:-0}" t
    t() { norm | tail -n +"$((f + 1))" | grep -ac "$1"; }
    echo "booting $(t 'intcdsp.sys: booting:'), boot ok $(t 'intcdsp.sys: boot ok after'), boot at open ok $(t 'boot at stream open: ok after'), failed-boot $(t 'boot at stream open failed'), idle $(t 'idle power down after'), timeouts $(t 'reply timeout'), fault-during $(t 'fault during stream'), selftest runs $(t 'loopback self-test: [0-9]* runs'), gain lines $(t 'gain: '), fatal $(grep -acE 'Fatal System Error|bugcheck' "$EV/serial.log"), ace_unexpected $(grep -ac ace_unexpected "$EV/qemu-dbg.log")"
}

kdb() {
    if norm | grep -aq "kdb:>"; then
        log "!! KDBG: the guest is in its kernel debugger; the lines before the prompt:"
        norm | grep -an -B 40 "kdb:>" | head -45 | cut -c1-230 | sed "s/^/    /" | tee -a "$EV/driver.log"
        g shot 98-kdb >/dev/null; s5; exit 9
    fi
}

# a short typed line of the console and the file it makes on the data disk: the line, the file, the
# most seconds to wait, the text the file must hold, the seconds more after it came
typed() {
    local i
    mdel -i "$POUCH@@$POUCHOFF" "::$2" >/dev/null 2>&1
    g type "$1"; g key ret
    for i in $(seq 1 "${3:-90}"); do
        [ -n "$(pouch_text "$2" 2>/dev/null | grep -a "${4:-.}")" ] && { sleep "${5:-3}"; break; }
        sleep 1
    done
    log "## typed '$1': $2 after about $i s"
    pouch_text "$2" 2>/dev/null | tee "$EV/$2" | sed 's/^/    /' | tee -a "$EV/driver.log" | head -${6:-70}
}

# the driver's lines from a serial line: the gains, and the boot at a stream open
driver() {
    norm | tail -n +"$(($1 + 1))" | grep -a -E "intcdsp\.sys: (gain:|boot at stream)" | cut -c1-200
}

# a new console on the data disk: the drive letter typed, then a short line
onpouch() {
    console 3
    g type "${PDRV}:"; g key ret; sleep 2
}

log "e5c: $RUN on $QAD/disk/$OVERLAY.qcow2, image $(basename "$IMG"), the exe $(sha256sum /tmp/e5c/dsploop/dsploop_apitest.exe | cut -c1-16)"
start_vm
waitre "Storage expansion not offered|The system has been stopped|Program Manager" 900 || { log "!! neither the first-boot setup's line nor a stop line in 900 s"; g shot 00-no-setup-line >/dev/null; s5; exit 1; }
if norm | grep -aq "The system has been stopped"; then log "!! the first boot STOPPED"; s5; exit 1; fi
log "first boot: the desktop (or the setup) reached after $(lines) serial lines"
wizard 25
for i in 1 2 3; do console 3; pouchfind && alive first && break; sleep 15; done
kdb
waitre "loopback self-test: [0-9]* runs" 240 || log "!! no self-test summary in 240 s"
sleep 10
log "## the boot (the baked settings): $(counts 0)"
norm | grep -a -E "SelfTest =|boot ok after|loopback self-test: [0-9]* runs|registered as" | cut -c1-240 | sed 's/^/    /' | tee -a "$EV/driver.log" | head -10
g shot 01-boot >/dev/null

# the default device: the data disk's setdef.cmd (setdefault.exe finds the DSP's endpoint by name and
# writes DefaultOutput through MMDevSetDefaultEndpoint), after the drive letter (two short lines)
g type "${PDRV}:"; g key ret; sleep 2
typed "setdef" setdef.txt 150 "DefaultOutput set to" 3 60
if ! pouch_text setdef.txt | grep -aq 'DefaultOutput set to .*: error 0'; then log "!! DefaultOutput was not set (setdef.txt has no 'error 0')"; fi
g shot 10-setdef >/dev/null

# the slider by the tray's keys: Win+D, volumedown x4 (E4b: a gain line of 2 dB a key)
N1=$(lines)
g key meta_l-d; sleep 4
for i in 1 2 3 4; do g key volumedown; sleep 5; done
sleep 4
log "## the tray's keys (volumedown x4), the driver's lines from serial line $N1: $(driver "$N1" | tr '\n' '|')"
if ! driver "$N1" | grep -aq 'gain: -'; then
    sleep 15
    N1=$(lines)
    g key meta_l-d; sleep 4
    for i in 1 2 3 4; do g key volumedown; sleep 5; done
    sleep 4
    log "## once more (volumedown x4) from serial line $N1: $(driver "$N1" | tr '\n' '|')"
fi
g shot 20-level >/dev/null

# dsploop at the level the slider reached
N3=$(lines)
onpouch
typed "dl level" dl-level.txt 540 "tests executed" 5 40
log "## dsploop at the level: the driver's lines (serial $N3 to $(lines)): $(driver "$N3" | tr '\n' '|')"

# mute and unmute by the tray's mute key
N4=$(lines)
g key meta_l-d; sleep 4; g key mute; sleep 6; g shot 30-muted >/dev/null; g key mute; sleep 6
log "## the mute key twice (serial $N4 to $(lines)): $(driver "$N4" | tr '\n' '|')"

# the stream test once more, at the level, after mute and unmute
N5=$(lines)
onpouch
typed "dl after" dl-after.txt 540 "tests executed" 5 40
log "## dsploop after mute and unmute: the driver's lines (serial $N5 to $(lines)): $(driver "$N5" | tr '\n' '|')"
g shot 90-end >/dev/null
s5
log "done: $(counts 0)"
