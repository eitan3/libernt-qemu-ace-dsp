#!/bin/bash
# e5fix-rows.sh -- E5-fixes' row VM on the new final image (486b024c9b1 = d8fbfe348da + the baked INF): a fresh
# first-boot overlay, the four rows of the brief in one boot: (1) setdefault.exe: the DSP endpoint's form factor
# (10 expected now), the codec's line out, the adapter path and the speakers; the capture endpoints' properties by
# the registry (cap.cmd); (4) the Wi-Fi service: the driver's lines at boot, sc query Nwifi (svc.cmd), no
# \\wifi.sys; (2) the stream test after the tray's mute key and unmute (endpointmute.exe as the fallback), the
# console re-opened by Win+R and asked (alive2) before anything is typed -- the N16-23 lesson; (3) crash-async=500
# set at a run's first open (E1c's 100 ms poll), the driver's fault lines, then the run after it (recovered: open ok)
# and the stream test exact.  ICOUNT=1 (lib-run.sh), one VM, no long line typed, ended by the ACPI button.
#   env: RUN (rows), OVERLAY (e5fix-firstboot), POUCH (/tmp/e5fix/pouch/rows.img), RUNMAX (300)
set -u
RUN="${RUN:-rows}"
OVERLAY="${OVERLAY:-e5fix-firstboot}"
POUCH="${POUCH-/tmp/e5fix/pouch/rows.img}"
RUNMAX="${RUNMAX:-300}"
. /tmp/e5fix/tools/vmcommon.sh
DRIVERLINES='intcdsp\.sys:|dsppcm\.sys:|hdaudbus\.sys:'
BOOTNOISE='intcdsp\.sys: (loaded for|controller|NHLT|reading BAR4|BAR4 \+|HFINTIPPTR|firmware .SystemRoot|SelfTest|BootDsp|booting:|interrupts before|subsystem powered|code-loader|ROM ready|firmware entered|FW_READY|firmware ready|ipc: link ready)'
KEYLINES="gain: |mute [01]|boot at stream|idle power down|recovered|firmware crash|fault during|released after|reply timeout|exception"

counts() {
    local f="$1" t
    t() { norm | tail -n +"$((f + 1))" | grep -ac "$1"; }
    echo "booting $(t 'intcdsp.sys: booting:'), boot ok $(t 'intcdsp.sys: boot ok after'), selftest ok $(t 'loopback self-test: ran (0x00000000)'), boot at open ok $(t 'boot at stream open: ok after'), recovered $(t 'recovered: open ok'), render opens $(t 'render: stream 1 opened'), gain lines $(t 'gain: '), mute lines $(t ', mute 1'), fault-during $(t 'fault during stream'), firmware crash $(t 'firmware crash'), timeouts $(t 'reply timeout'), stop lines $(norm | grep -ac 'The system has been stopped'), fatal $(grep -acE 'Fatal System Error|bugcheck' "$EV/serial.log"), ace_unexpected $(grep -ac ace_unexpected "$EV/qemu-dbg.log")"
}

kdb() {
    if norm | grep -aq "kdb:>"; then
        log "!! KDBG: the guest is in its kernel debugger; the lines before the prompt:"
        norm | grep -an -B 40 "kdb:>" | head -45 | cut -c1-230 | sed 's/^/    /' | tee -a "$EV/driver.log"
        g shot 98-kdbg >/dev/null 2>&1; s5; exit 9
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
    pouch_text "$2" 2>/dev/null | tee "$EV/$2" | sed 's/^/    /' | tee -a "$EV/driver.log" | head -${6:-40}
}

driverlines() { norm | tail -n +"$(($1 + 1))" | grep -a -E "$DRIVERLINES" | grep -a -v -E "$BOOTNOISE" | grep -a -E "$KEYLINES" | cut -c1-240; }

onpouch() {
    console 3
    g type "${PDRV}:"; g key ret; sleep 2
}

# the console asked in the console it is in (the pouch is the current directory after onpouch): a marker file
# on the pouch, counted on the host (vmcommon's alive() needs %POUCHDRV%, which a new console does not have)
alive2() {
    local n i
    n=$(pouch_ls | grep -c "alive")
    g type "echo alive>alive-$1.txt"; g key ret
    for i in $(seq 1 25); do
        [ "$(pouch_ls | grep -c "alive")" -gt "$n" ] && { log "console answering after $1 (alive-$1.txt, $i s)"; return 0; }
        sleep 1
    done
    log "!! the console did not answer after $1 (no alive-$1.txt in 25 s)"
    return 1
}

opens_after() { tail -n +"$(($1 + 1))" "$EV/serial.log" | grep -ac 'render: stream 1 opened'; }
# waitopen <from-line> <nth> <timeout s>: the guest seconds of the render stream's <nth> "opened" line; 1 on a timeout
waitopen() {
    local from="$1" nth="$2" to="$3" t0=$(date +%s)
    while [ "$(opens_after "$from")" -lt "$nth" ]; do
        [ $(( $(date +%s) - t0 )) -ge "$to" ] && return 1
        sleep 0.1
    done
    tail -n +"$((from + 1))" "$EV/serial.log" | grep -a 'render: stream 1 opened' | tail -n "$nth" | head -n 1 | grep -oE '\[ *[0-9.]+\]' | tr -d '[] '
}

# run <label> [max s]: a dsploop run by the pouch's dl.cmd (no fault of its own), its text kept on the host
run() {
    local label="$1" max="${2:-$RUNMAX}" n0 t0 i r
    n0=$(lines)
    mdel -i "$POUCH@@$POUCHOFF" "::dl-$label.txt" >/dev/null 2>&1
    for i in $(seq 1 30); do [ -z "$(pouch_text "dl-$label.txt" 2>/dev/null)" ] && break; sleep 1; done
    t0=$(date +%s)
    g type "dl $label"; g key ret
    for i in $(seq 1 "$max"); do
        [ -n "$(pouch_text "dl-$label.txt" 2>/dev/null)" ] && { sleep 3; break; }
        sleep 1
    done
    if [ -z "$(pouch_text "dl-$label.txt" 2>/dev/null)" ]; then r="!! NOT ended within $max s"; else r="ended after about $(( $(date +%s) - t0 )) s"; fi
    pouch_text "dl-$label.txt" > "$EV/dl-$label.txt" 2>/dev/null
    log "$label: $r; $(grep -a -E 'depths compared|tests executed' "$EV/dl-$label.txt" | tr '\n' ' ' | cut -c1-200)"
    log "$label: $(counts "$n0")"
    log "$label: the driver's lines after serial line $n0:"
    driverlines "$n0" | sed 's/^/    /' | tee -a "$EV/driver.log" | head -14
}

passed() { local t; t=$(cat "$EV/dl-$1.txt" 2>/dev/null); [ "$(echo "$t" | grep -ac '3 of 3 depths compared')" -ge 1 ] && [ "$(echo "$t" | grep -ac '0 failures), 0 skipped')" -ge 1 ]; }

# ----------------------------------------------------------------------------- the VM
log "e5fix rows: $RUN on $QAD/disk/$OVERLAY.qcow2, image $(basename "$IMG"), the exe $(sha256sum /tmp/e5fix/dsploop/dsploop_apitest.exe | cut -c1-16), pouch $POUCH"
start_vm
waitre "Storage expansion not offered|The system has been stopped|desktop ready" 900 || { log "!! neither the first-boot setup's line nor a stop line in 900 s"; g shot 00-no-setup-line >/dev/null; s5; exit 1; }
if norm | grep -aq "The system has been stopped"; then log "!! the first boot STOPPED"; norm | grep -anE "The system has been stopped|Stop code" | cut -c1-300 | tee -a "$EV/driver.log"; s5; exit 1; fi
log "first boot: the desktop (or the setup) reached after $(lines) serial lines"
wizard 25
for i in 1 2 3; do console 3; pouchfind && alive first && break; sleep 15; done
kdb
waitre "loopback self-test: [0-9]* runs" 240 || log "!! no self-test summary in 240 s"
sleep 10
log "## the boot (the DSP boots by itself): $(counts 0)"
norm | grep -a -E "intcdsp\.sys: (SelfTest =|boot ok after|firmware ready:|topology |audio child|loopback self-test: (the gain step|[0-9]+ runs|ran)|BootDsp =)|dsppcm\.sys: endpoint .*registered as" | cut -c1-260 | sed 's/^/    /' | tee -a "$EV/driver.log"
# row 4: the Wi-Fi service at boot -- the driver's own lines, the service by sc, no \\wifi.sys
log "## row 4, the Wi-Fi service at boot: the lines naming NWIFI / wlansvc / wifi.sys:"
norm | grep -a -i -E 'nwifi|wifi\.sys|wlansvc|wlan svc' | cut -c1-200 | sed 's/^/    /' | tee -a "$EV/driver.log" | head -12
log "## row 4: lines naming \\wifi.sys (the backslash form nwifi.sys cannot match): $(norm | grep -a -c -i '\\wifi\.sys'); lines with (not found|cannot find|failed to load) near wifi: $(norm | grep -a -i -c -E 'wifi\.sys[^|]*(not found|cannot find|failed)|((not found|cannot find|failed to load)[^|]*wifi\.sys)'); all 'not found' lines of the boot: $(norm | grep -a -i -c -E 'not found|cannot find')"
g shot 01-boot >/dev/null

# row 1: the endpoints in the Sound page, setdefault.exe, the capture endpoints by the registry
g type "${PDRV}:"; g key ret; sleep 2
g type "snd"; g key ret; sleep 15
g shot 02-sound-playback >/dev/null
g key ctrl-tab; sleep 4; g shot 03-sound-recording >/dev/null
g key ctrl-tab; sleep 3
onpouch
typed "setdef" setdef.txt 150 "DefaultOutput set to" 3 40
typed "cap" cap.txt 120 "." 2 90
g shot 10-setdef >/dev/null
typed "svc" svc-nwifi.txt 60 "." 2 14

# a baseline run before the mute: the stream exact at all three depths
run base

# row 2: the tray's mute key twice (mute, unmute), then the stream test; endpointmute.exe if the key does not reach
N4=$(lines)
g key meta_l-d; sleep 4; g key audiomute; sleep 6; g key audiomute; sleep 6
M1=$(norm | tail -n +"$((N4 + 1))" | grep -a -c ', mute 1'); M0=$(norm | tail -n +"$((N4 + 1))" | grep -a -c ', mute 0')
log "## row 2, the mute key twice (audiomute; serial $N4 to $(lines)): mute 1 lines $M1, mute 0 lines $M0: $(norm | tail -n +"$((N4 + 1))" | grep -a -E 'intcdsp\.sys: (gain:|mute )' | cut -c1-120 | tr '\n' '|')"
if [ "$M1" -lt 1 ] || [ "$M0" -lt 1 ]; then
    log "## the tray's key did not reach the driver (mute 1 / mute 0 lines $M1 / $M0): endpointmute.exe instead"
    onpouch
    N4=$(lines)
    typed "mute 1" mute-1.txt 120 "after: mute" 5 20
    typed "mute 0" mute-0.txt 120 "after: mute" 5 20
    log "## endpointmute: the driver's lines (serial $N4 to $(lines)): $(norm | tail -n +"$((N4 + 1))" | grep -a -E 'intcdsp\.sys: gain: .*mute [01]' | cut -c1-120 | tr '\n' '|')"
fi
g shot 20-after-mute >/dev/null
# the console re-opened the proven way (Win+R, cmd.exe, the pouch) and asked before anything is typed
okc=0
for i in 1 2 3; do
    onpouch
    if alive2 after-mute; then okc=1; break; fi
    g key esc; sleep 2; g key esc; sleep 2
done
if [ "$okc" = 1 ]; then
    N7=$(lines)
    typed "dl muted" dl-muted.txt 540 "tests executed" 5 40
    log "## row 2: dsploop after the mute/unmute: $(passed muted && echo PASS || echo 'not a pass'); the driver's lines (serial $N7 to $(lines)): $(driverlines "$N7" | tr '\n' '|')"
else
    log "!! row 2: the console did not answer after the mute (3 tries): the stream test after the mute/unmute is not typed"
fi
g shot 21-after-muted >/dev/null
kdb

# row 3: crash-async=500 at a run's first open (the poll of E1c), the driver's fault lines, then a run that must pass
F2=$(lines)
log "## row 3: crash-async=500 at a run's first open, then a run after it"
mdel -i "$POUCH@@$POUCHOFF" "::dl-crash.txt" >/dev/null 2>&1
g type "dl crash"; g key ret
if t_open=$(waitopen "$F2" 1 150); then
    setfault crash-async=500 x-delay-scale=1
    log "crash: open #1 at guest $t_open s; crash-async=500 set at $(date -u +%T) (host)"
else
    log "crash: !! open #1 not seen in 150 s; the fault was not set"
fi
t0=$(date +%s); r=""
for i in $(seq 1 "$RUNMAX"); do [ -n "$(pouch_text "dl-crash.txt" 2>/dev/null)" ] && { sleep 3; break; }; sleep 1; done
[ -z "$(pouch_text "dl-crash.txt" 2>/dev/null)" ] && r="!! NOT ended within $RUNMAX s" || r="ended after about $(( $(date +%s) - t0 )) s"
setfault none x-delay-scale=1
log "crash: $r; fault cleared ($(date -u +%T))"
pouch_text dl-crash.txt > "$EV/dl-crash.txt" 2>/dev/null
log "crash: the run's own lines (errors and the summary):"
grep -a -i -E 'fail|error|invalidated|0x8|tests executed|compared' "$EV/dl-crash.txt" | cut -c1-220 | sed 's/^/    /' | tee -a "$EV/driver.log" | head -10
log "crash: the driver's fault lines after serial line $F2:"
norm | tail -n +"$((F2 + 1))" | grep -a -E "firmware crash|fault during stream|released after the fault|recovered|exception|crash" | cut -c1-240 | sed 's/^/    /' | tee -a "$EV/driver.log" | head -14
log "crash: $(counts "$F2")"
okc=0
for i in 1 2 3; do onpouch; alive2 after-crash && { okc=1; break; }; g key esc; sleep 2; done
if [ "$okc" = 1 ]; then
    run a-crash-async
    if passed a-crash-async; then log "## row 3: PASS after the crash: $(norm | tail -n +"$((F2 + 1))" | grep -a 'recovered: open ok' | head -1 | cut -c1-140)"; else log "!! row 3: the run after the crash did not pass"; fi
else
    log "!! row 3: the console did not answer after the crash run (3 tries): the run after the crash is not typed"
fi
g shot 30-after-crash >/dev/null
kdb

s5
log "done: $(counts 0)"
exit 0
