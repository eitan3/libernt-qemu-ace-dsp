#!/bin/bash
# s6b-early-reset.sh -- the freeze case at the DSP's power-up: system_reset now; shots every few
# seconds; a second system_reset at about t+42 s (the kernel has just started: its text screen),
# then shots until t+110 s while the stick boots normally again.
set -u
QAD=<project>
EV=/tmp/c6/ev/vm2
SOCK="$(cat "$EV/sock-dir.txt")/monitor.sock"
shot() { printf -v n "$1"; python3 "$QAD/tools/mon.py" "$SOCK" "screendump $EV/$n.png -f png" > /dev/null; printf '%s shot %s.png %s bytes (t+%ss)\n' "$(date -u +%T)" "$n" "$(stat -c %s "$EV/$n.png" 2>/dev/null)" "$(( $(date +%s) - t0 ))" >> "$EV/driver.log"; }
python3 "$QAD/tools/mon.py" "$SOCK" system_reset > /dev/null; t0=$(date +%s)
printf '%s SYSTEM_RESET #2 (from the console) at t+0\n' "$(date -u +%T)" | tee -a "$EV/driver.log"
i=0
while [ $(( $(date +%s) - t0 )) -lt 42 ]; do
    i=$((i+1)); printf -v n 's6d-a-%02d' "$i"; shot "$n"; sleep 3
done
printf '%s SYSTEM_RESET #3 (the early one, t+%ss)\n' "$(date -u +%T)" "$(( $(date +%s) - t0 ))" | tee -a "$EV/driver.log"
python3 "$QAD/tools/mon.py" "$SOCK" system_reset > /dev/null
i=0
while [ $(( $(date +%s) - t0 )) -lt 150 ]; do
    i=$((i+1)); printf -v n 's6d-b-%02d' "$i"; shot "$n"; sleep 5
done
grep "s6d" "$EV/driver.log"
echo "resets in qemu-dbg.log: $(grep -ac 'CPU Reset' "$EV/qemu-dbg.log")"
