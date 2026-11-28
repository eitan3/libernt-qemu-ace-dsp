#!/bin/bash
# roundmute.sh -- E5c's mute row on the installed overlay of round 3 (the same data disk): mute and
# unmute of the DSP's endpoint through IAudioEndpointVolume (endpointmute.exe: the call the tray's
# button and the Volume tab make; the tray takes no mute key, round 3), dsploop once more after the
# unmute; the VM is ended by the ACPI button.  No long line is typed.
#   env: RUN (mute), OVERLAY (e5c-firstboot3)
set -u
RUN="${RUN:-mute}"
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
    norm | tail -n +"$(($1 + 1))" | grep -a -E "intcdsp\.sys: (gain:|boot at stream)" | cut -c1-200
}

onpouch() {
    console 3
    g type "${PDRV}:"; g key ret; sleep 2
}

log "e5c mute row: $RUN on $QAD/disk/$OVERLAY.qcow2, image $(basename "$IMG"), the exes $(sha256sum /tmp/e5c/dsploop/dsploop_apitest.exe | cut -c1-16) $(sha256sum /tmp/e5c/setdef/endpointmute.exe | cut -c1-16)"
start_vm
waitre "loopback self-test: [0-9]* runs|The system has been stopped" 600 || { log "!! neither the self-test's line nor a stop line in 600 s"; g shot 00-no-selftest >/dev/null; s5; exit 1; }
if norm | grep -aq "The system has been stopped"; then log "!! the boot STOPPED"; s5; exit 1; fi
kdb
sleep 60
log "## the boot: $(counts 0)"
log "## the driver's gain lines of the boot: $(driver 0 | cut -c1-90 | tr '\n' '|')"
for i in 1 2 3; do console 3; pouchfind && alive boot && break; sleep 15; done
kdb
g shot 01-boot >/dev/null

# mute through the endpoint volume, then unmute
g type "${PDRV}:"; g key ret; sleep 2
N1=$(lines)
typed "mute 1" mute-1.txt 120 "after: mute" 5 20
log "## mute: the driver's lines (serial $N1 to $(lines)): $(driver "$N1" | tr '\n' '|')"
onpouch
N2=$(lines)
typed "mute 0" mute-0.txt 120 "after: mute" 5 20
log "## unmute: the driver's lines (serial $N2 to $(lines)): $(driver "$N2" | tr '\n' '|')"
g shot 30-after-unmute >/dev/null

# the stream test once more, after mute and unmute
onpouch
N3=$(lines)
typed "dl unmuted" dl-unmuted.txt 540 "tests executed" 5 40
log "## dsploop after mute and unmute: the driver's lines (serial $N3 to $(lines)): $(driver "$N3" | tr '\n' '|')"
g shot 90-end >/dev/null
s5
log "done: $(counts 0)"
