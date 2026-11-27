#!/bin/bash
# early-shots.sh -- screenshots at a fixed interval right after a (re)boot: what a machine
# without a serial port shows on its screen.  early-shots.sh <prefix> <count> <interval s>
set -u
EV="${EV:-/tmp/c6/ev/vm1}"
QAD=<project>
SOCK="$(cat "$EV/sock-dir.txt")/monitor.sock"
p="${1:?prefix}"; n="${2:?count}"; iv="${3:-2}"
t0=$(date +%s)
for i in $(seq 1 "$n"); do
    printf -v name '%s-early-%02d' "$p" "$i"
    python3 "$QAD/tools/mon.py" "$SOCK" "screendump $EV/$name.png -f png" > /dev/null
    printf '%s shot %s.png %s bytes (t+%ss)\n' "$(date -u +%T)" "$name" "$(stat -c %s "$EV/$name.png")" "$(( $(date +%s) - t0 ))" >> "$EV/driver.log"
    sleep "$iv"
done
tail -n "$n" "$EV/driver.log"
