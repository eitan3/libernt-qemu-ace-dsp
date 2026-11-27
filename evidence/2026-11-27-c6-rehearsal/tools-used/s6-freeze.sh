#!/bin/bash
# s6-freeze.sh -- the freeze case of the C6 rehearsal: a cold boot of the stick (BootDsp = 1,
# topology, SelfTest = 0), screenshots every 2 s, a hard reset (the monitor's system_reset, what
# the owner's power button does) at about t+36 s, then screenshots every 3 s while it boots again.
set -u
QAD=<project>
EV=/tmp/c6/ev/vm2
STICK=$QAD/disk/c6-stick-p4c4d.img
POUCH=/tmp/qad-ev/c6/pouch/c6.img
rm -rf "$EV"; mkdir -p "$EV"
EV="$EV" DISK="$STICK" POUCH="$POUCH" bash /tmp/c6/tools/c6-run.sh | tee "$EV/../s6-vm-start.txt"
t0=$(date +%s)
SOCK="$(cat "$EV/sock-dir.txt")/monitor.sock"
for i in $(seq 1 18); do
    printf -v n 's6-a-%02d' "$i"
    python3 "$QAD/tools/mon.py" "$SOCK" "screendump $EV/$n.png -f png" > /dev/null
    printf '%s shot %s.png %s bytes (t+%ss)\n' "$(date -u +%T)" "$n" "$(stat -c %s "$EV/$n.png")" "$(( $(date +%s) - t0 ))" >> "$EV/driver.log"
    sleep 2
done
printf '%s SYSTEM_RESET (hard reset, the power button) at t+%ss\n' "$(date -u +%T)" "$(( $(date +%s) - t0 ))" | tee -a "$EV/driver.log"
python3 "$QAD/tools/mon.py" "$SOCK" system_reset > /dev/null
sleep 1
for i in $(seq 1 16); do
    printf -v n 's6-b-%02d' "$i"
    python3 "$QAD/tools/mon.py" "$SOCK" "screendump $EV/$n.png -f png" > /dev/null
    printf '%s shot %s.png %s bytes (t+%ss)\n' "$(date -u +%T)" "$n" "$(stat -c %s "$EV/$n.png")" "$(( $(date +%s) - t0 ))" >> "$EV/driver.log"
    sleep 3
done
cat "$EV/driver.log"
