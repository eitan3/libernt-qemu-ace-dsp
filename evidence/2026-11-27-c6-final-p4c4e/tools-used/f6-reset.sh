#!/bin/bash
# f6-reset.sh -- the freeze case of the final pass (the rehearsal's s6b-early-reset.sh, timed from
# the screen): system_reset now (what the power button does to a running system), screenshots every
# 3 s; the second hard reset (the early one) 6 s after the kernel's text screen first shows -- the
# DSP's power-up is stamped at guest 3.5 s, the display driver starts at 5.2 s -- or at t+45 s if
# the text screen has not shown; then screenshots every 5 s for 150 s while the stick boots again.
set -u
EV="${EV:?EV=<vm evidence dir>}"
QAD=<project>
SOCK="$(cat "$EV/sock-dir.txt")/monitor.sock"
mon() { python3 "$QAD/tools/mon.py" "$SOCK" "$1" > /dev/null; }
shot() { mon "screendump $EV/$1.png -f png"; s=$(stat -c %s "$EV/$1.png" 2>/dev/null); printf '%s shot %s.png %s bytes (t+%ss)\n' "$(date -u +%T)" "$1" "$s" "$(( $(date +%s) - t0 ))" >> "$EV/driver.log"; echo "${s:-0}"; }
mon system_reset; t0=$(date +%s)
printf '%s SYSTEM_RESET #1 (the power button on the running system) at t+0\n' "$(date -u +%T)" | tee -a "$EV/driver.log"
T=""; tf=none; i=0
while :; do
    i=$((i+1)); printf -v n 'f6a-%02d' "$i"; s=$(shot "$n")
    now=$(( $(date +%s) - t0 ))
    if [ -z "$T" ] && [ "${s:-0}" -ge 50000 ]; then T=$(date +%s); tf=$(( T - t0 )); printf '%s the kernel text screen first shows at t+%ss\n' "$(date -u +%T)" "$tf" | tee -a "$EV/driver.log"; fi
    if [ -n "$T" ] && [ $(( $(date +%s) - T )) -ge 6 ]; then break; fi
    [ "$now" -ge 45 ] && break
    sleep 3
done
printf '%s SYSTEM_RESET #2 (the early one) at t+%ss; the text screen first showed at t+%ss\n' "$(date -u +%T)" "$(( $(date +%s) - t0 ))" "$tf" | tee -a "$EV/driver.log"
mon system_reset; t0=$(date +%s)
i=0
while [ $(( $(date +%s) - t0 )) -lt 150 ]; do
    i=$((i+1)); printf -v n 'f6b-%02d' "$i"; shot "$n" > /dev/null
    sleep 5
done
grep -E "f6|SYSTEM" "$EV/driver.log" | tail -50
echo "resets in qemu-dbg.log: $(grep -ac 'CPU Reset' "$EV/qemu-dbg.log")"
