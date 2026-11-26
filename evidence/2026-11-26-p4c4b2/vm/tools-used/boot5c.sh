#!/bin/bash
# boot5c.sh -- VM 5 of the p4c4b2 round after boot5b.sh was stopped: boot5b.sh had typed the
# apitest's command line from the system disk without Enter, but its livecap.py died on connect
# (the socket directory is set by start_vm, which a script that takes a running VM over does not
# call; its SOCK was empty), so the Enter was never sent and the line stands in the console.
# This script sets the socket directory from the run's sock-dir.txt, starts livecap.py (it sends
# the Enter and reads the streams at the first three latency lines), and takes the rest of
# boot5b.sh's flow: the apitest's output, the exit code, the Sound applet (screenshots for the
# record), the S5.
set -u
RUN=r5-firstboot-cycle-selftest2-dsploop-live
. /tmp/qad-ev/p4c4b2/tools/vmcommon.sh
LR=$(pgrep -f "^bash lib-run.sh$" | head -1)   # the launcher survived the stopped scripts
SOCK=$(cat "$EV/sock-dir.txt")
log "boot5c: the Enter of the line boot5b.sh typed (lib-run.sh pid $LR, sockets $SOCK)"
waitre() {   # waitre <regex> <seconds> <from line>
    local t0=$(date +%s)
    while :; do
        if norm | tail -n +"$(($3 + 1))" | grep -aEq "$1"; then return 0; fi
        [ $(( $(date +%s) - t0 )) -ge "$2" ] && return 1
        sleep 2
    done
}
cmd() {       # cmd <out file on the data disk> <command> [sleep s]
    g type "$2 > D:\\$1 2>&1"; g key ret; sleep "${3:-8}"
    log "$2: $(pouch_text "$1" 2>/dev/null | tr '\n' ' ' | cut -c1-600)"
}
LAUNCHRE="dsppcm\.sys: endpoint .* pin created|intcdsp\.sys: stream [0-9]+: latency|the DSP gives no stream|the pin.s format is refused"
n1=$(lines)
LIVECAP_SENDKEY=ret LIVECAP_TIMEOUT=240 python3 "$T/livecap.py" "$SOCK" "$EV/serial.log" "$EV" \
    "r16=: latency: fifo" "r24=: latency: fifo" "r32=: latency: fifo" > "$EV/livecap-4.out" 2>&1 &
LCP=$!
log "livecap.py started: it sends the Enter (serial line $n1)"
if waitre "$LAUNCHRE" 150 "$n1"; then
    log "the apitest launched from the system disk: its first driver line came"
else
    log "!! no driver line in 150 s after the Enter (the exe from the system disk)"
    g shot s6-launch-2-no-driver-line >/dev/null
    wait_livecap
    n1=$(lines)
    cmd x-d-alive.txt "echo alive-after-launch-2" 8
    log "the console after the launch: $(pouch_text x-d-alive.txt 2>/dev/null | tr '\n' ' ')"
    g shot s6b-console >/dev/null
fi
sleep 15
for i in $(seq 1 240); do
    if pouch_text dsploop-out.txt | grep -q "tests executed"; then
        log "the apitest ended its output after about $((15 + 2 * i)) s: $(pouch_text dsploop-out.txt | tail -1 | cut -c1-200)"
        break
    fi
    sleep 2
done
pouch_text dsploop-out.txt | grep -q "tests executed" || log "!! the apitest's output shows no 'tests executed' line in 495 s"
wait_livecap
sleep 3
cmd dsploop-rc.txt "echo %ERRORLEVEL%" 8
g shot s7-after-dsploop >/dev/null
log "run 2: the apitest's output as the guest wrote it (dsploop-out.txt):"
pouch_text dsploop-out.txt | cut -c1-330 | tee -a "$EV/driver.log"
log "run 2: driver lines of the apitest (after serial line $n1):"
norm | tail -n +"$((n1 + 1))" | grep -aE "intcdsp\.sys: (endpoint|stream )|dsppcm\.sys|latency|clock stalled|interrupt storm|Work queue|Fatal|bugcheck" | cut -c1-330 | tee -a "$EV/driver.log"
# the Sound applet for the record only (screenshots; nothing is read from them to decide anything)
g type "mmsys.cpl"; g key ret; sleep 30
g shot s8-sound-playback >/dev/null
g key ctrl-tab; sleep 6
g shot s9-sound-recording >/dev/null
g key esc; sleep 3
g shot s10-after-sound >/dev/null
s5
log "boot5c done"
