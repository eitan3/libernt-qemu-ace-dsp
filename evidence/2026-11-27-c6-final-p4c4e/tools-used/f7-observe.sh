#!/bin/bash
# f7-observe.sh <count> <interval s> -- after `shutdown -r -t 0`: a screenshot, the CPU reset count
# of qemu-dbg.log and the serial log's line count at each step, to see whether the machine
# restarts (a new reset, the serial log growing again) or stays on the desktop.
set -u
EV="${EV:?EV=<vm evidence dir>}"
n="${1:?count}"; iv="${2:?interval}"
SOCK="$(cat "$EV/sock-dir.txt")/monitor.sock"
t0=$(date +%s)
for i in $(seq 1 "$n"); do
    sleep "$iv"
    printf -v name 'f7-after-shutdown-%02d' "$i"
    python3 <project>/tools/mon.py "$SOCK" "screendump $EV/$name.png -f png" > /dev/null
    printf '%s shot %s.png %s bytes (t+%ss); CPU resets %s; serial lines %s; serial tail: %s\n' "$(date -u +%T)" "$name" \
        "$(stat -c %s "$EV/$name.png")" "$(( $(date +%s) - t0 ))" "$(grep -ac 'CPU Reset' "$EV/qemu-dbg.log")" \
        "$(grep -ac '' "$EV/serial.log")" "$(tr -d '\r' < "$EV/serial.log" | tail -n 1 | cut -c1-110)" | tee -a "$EV/driver.log"
done
