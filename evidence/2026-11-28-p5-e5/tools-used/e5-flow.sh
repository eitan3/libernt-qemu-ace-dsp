#!/bin/bash
# e5-flow.sh -- E5's row VM on the final image: the first-session run book flow end to end (boot -> the DSP boots
# by itself -> the self-test -> the endpoints in Sound -> a stream through the DSP -> shutdown), E3's rows (the
# self-test's gain step in the boot's lines, the slider by the tray's keys, the mute key `audiomute`, the pointer
# path by hand between two go files, dsploop after mute/unmute exact), E5c's properties in the registry
# (setdefault.exe), LEG-1's no-jack rows (the boot's HDAUDIO lines, the Sound page's listing, the jack description
# line once per endpoint, the watcher's 10 minutes by the handle count of every process, procinfo.exe at the
# baseline and 10 minutes on), D12 d / D13 / D14 by screenshots.  A fresh first-boot overlay over the final VHD;
# no long typed line; the VM is ended by the guest's own shutdown (the flow's last step).
#   env: RUN (flow), OVERLAY (e5-flow), POUCH (/tmp/e5/pouch/flow.img, made with all the tools)
set -u
RUN="${RUN:-flow}"
OVERLAY="${OVERLAY:-e5-flow}"
POUCH="${POUCH-/tmp/e5/pouch/flow.img}"
. /tmp/e5/tools/vmcommon.sh

counts() {
    local f="${1:-0}" t
    t() { norm | tail -n +"$((f + 1))" | grep -ac "$1"; }
    echo "booting $(t 'intcdsp.sys: booting:'), boot ok $(t 'intcdsp.sys: boot ok after'), selftest ok $(t 'loopback self-test: ran (0x00000000)'), gain lines $(t 'gain: '), mute lines $(t 'mute 1'), fatal $(grep -acE 'Fatal System Error|bugcheck' "$EV/serial.log"), ace_unexpected $(grep -ac ace_unexpected "$EV/qemu-dbg.log" 2>/dev/null), mmdevapi ERR/WARN $(t 'mmdevapi.*\(ERR\|WARN\)'):"
}

kdb() {
    if norm | grep -aq "kdb:>"; then
        log "!! KDBG: the guest is in its kernel debugger"; norm | grep -an -B 40 "kdb:>" | head -45 | cut -c1-230 | tee -a "$EV/driver.log"; g shot 98-kdb >/dev/null; s5; exit 9
    fi
}

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

driver() {
    norm | tail -n +"$(($1 + 1))" | grep -a -E "intcdsp\.sys: (gain:|boot at stream|stream [0-9]+: latency)" | cut -c1-200
}

onpouch() {
    console 3
    g type "${PDRV}:"; g key ret; sleep 2
}

waitfile() {
    local i
    for i in $(seq 1 "${2:-450}"); do [ -f "$EV/$1" ] && { log "## go: $1"; return 0; }; sleep 2; done
    log "!! no $1 in $(( ${2:-450} * 2 )) s"
    return 1
}

log "e5 flow: $RUN on $QAD/disk/$OVERLAY.qcow2, image $(basename "$IMG"), the exe $(sha256sum /tmp/e5/dsploop/dsploop_apitest.exe | cut -c1-16)"
start_vm
waitre "Storage expansion not offered|The system has been stopped|Program Manager" 900 || { log "!! neither the first-boot setup's line nor a stop line in 900 s"; g shot 00-no-setup-line >/dev/null; s5; exit 1; }
if norm | grep -aq "The system has been stopped"; then log "!! the first boot STOPPED"; s5; exit 1; fi
log "first boot: the desktop (or the setup) reached after $(lines) serial lines"
wizard 25
for i in 1 2 3; do console 3; pouchfind && alive first && break; sleep 15; done
kdb
waitre "loopback self-test: [0-9]* runs" 240 || log "!! no self-test summary in 240 s"
sleep 10
log "## the boot (the DSP boots by itself): $(counts 0)"
norm | grep -a -E "intcdsp\.sys: (SelfTest =|boot ok after|firmware ready:|topology |audio child|loopback self-test: (the gain step|[0-9]+ runs|ran)|BootDsp =)|dsppcm\.sys: endpoint .*registered as|HDAUDIO: (pin [0-9] cfg|SubdeviceName|jack description)" | cut -c1-260 | sed 's/^/    /' | tee -a "$EV/driver.log"
g shot 01-boot >/dev/null

# (1) the endpoints in the Sound page (mmsys.cpl): the flow's step; the page stays open (its client is the watcher's)
g type "${PDRV}:"; g key ret; sleep 2
g type "snd"; g key ret; sleep 15
g shot 02-sound-playback >/dev/null
g key ctrl-tab; sleep 4; g shot 03-sound-recording >/dev/null
g key ctrl-tab; sleep 3
# the baseline of the handle counts: every process (procinfo.exe, hc.cmd)
onpouch
typed "hc .exe" hc-t0.txt 60 "processes matching" 2 40
HC0=$(date +%s)

# (2) E5c's properties in the VM's registry, and the default device: setdefault.exe
typed "setdef" setdef.txt 150 "DefaultOutput set to" 3 40
if ! pouch_text setdef.txt | grep -aq 'DefaultOutput set to .*: error 0'; then log "!! DefaultOutput was not set"; fi
g shot 10-setdef >/dev/null

# (3) E3: the slider by the tray's keys (Win+D, volumedown x4)
N1=$(lines)
g key meta_l-d; sleep 4
for i in 1 2 3 4; do g key volumedown; sleep 5; done
sleep 4
log "## the tray's keys (volumedown x4): the driver's lines from serial $N1: $(driver "$N1" | tr '\n' '|')"
g shot 20-level >/dev/null

# (4) a stream through the DSP at that level (the flow's step): dsploop
N3=$(lines)
onpouch
typed "dl level" dl-level.txt 540 "tests executed" 5 40
log "## dsploop at the level: the driver's lines (serial $N3 to $(lines)): $(driver "$N3" | tr '\n' '|')"

# (5) E3: the mute key, audiomute x2 (the tray's VK_VOLUME_MUTE; E5c's `mute` was QEMU's mic-mute key, N15-42)
N4=$(lines)
g key meta_l-d; sleep 4; g key audiomute; sleep 6; g shot 30-muted >/dev/null; g key audiomute; sleep 6
log "## the mute key twice (audiomute; serial $N4 to $(lines)): $(driver "$N4" | tr '\n' '|')"

# (6) the pointer path, by hand: a drag in the tray's flyout (go-ptr-1), then in the Settings' Volume tab (go-ptr-2)
N5=$(lines)
waitfile go-ptr-1 600 || true
log "## the pointer path, the tray's flyout (serial $N5 to $(lines)): $(driver "$N5" | tr '\n' '|')"
g shot 40-ptr-tray >/dev/null
N6=$(lines)
waitfile go-ptr-2 600 || true
log "## the pointer path, the Volume tab (serial $N6 to $(lines)): $(driver "$N6" | tr '\n' '|')"
g shot 41-ptr-volume >/dev/null

# (7) the stream test once more after mute/unmute and the pointer's level: exact
N7=$(lines)
onpouch
typed "dl after" dl-after.txt 540 "tests executed" 5 40
log "## dsploop after: the driver's lines (serial $N7 to $(lines)): $(driver "$N7" | tr '\n' '|')"

# (8) LEG-1's watcher: the handle counts 10 minutes after the baseline (the Sound page open all along)
while [ $(( $(date +%s) - HC0 )) -lt 600 ]; do sleep 10; done
onpouch
typed "hc .exe" hc-t10.txt 60 "processes matching" 2 40
log "## the Sound page after 10 minutes: the jack-description lines $(norm | grep -ac 'HDAUDIO: jack description'), the watcher's TRACE lines $(norm | grep -ac 'jack change told'), mmdevapi ERR/WARN lines $(norm | grep -ac 'mmdevapi.*\(ERR\|WARN\)'):"
g key meta_l-d; sleep 3; g shot 50-sound-10min >/dev/null

# (9) the flow's last step: the guest's own shutdown
console 3
g type "shutdown -s -t 0"; g key ret
wait $LR
log "VM $RUN ended by the guest's shutdown: $(grep -a 'qemu exited' "$EV/lib-run.out")"
log "done: $(counts 0)"
