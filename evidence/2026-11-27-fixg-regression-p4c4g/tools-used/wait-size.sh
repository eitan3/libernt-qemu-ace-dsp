#!/bin/bash
# wait-size.sh <prefix> <min bytes> <max s> [interval s, default 5] -- screenshots (each logged)
# until one is at least <min bytes> (the sign-in screen of these images is 20-25 KB, the kernel's
# text screen 14-52 KB, the wizard pages and the desktop more than 750 KB) or <max s> have
# passed; prints the last screenshot's name and size.
set -u
EV="${EV:?EV=<vm evidence dir>}"
QAD=<project>
SOCK="$(cat "$EV/sock-dir.txt")/monitor.sock"
p="${1:?prefix}"; min="${2:?min bytes}"; max="${3:?max s}"; iv="${4:-5}"
t0=$(date +%s); i=0; s=0
while [ $(( $(date +%s) - t0 )) -lt "$max" ]; do
    i=$((i+1)); printf -v name '%s-%02d' "$p" "$i"
    python3 "$QAD/tools/mon.py" "$SOCK" "screendump $EV/$name.png -f png" > /dev/null
    s=$(stat -c %s "$EV/$name.png" 2>/dev/null || echo 0)
    printf '%s shot %s.png %s bytes (t+%ss)%s\n' "$(date -u +%T)" "$name" "$s" "$(( $(date +%s) - t0 ))" "$([ "$s" -ge "$min" ] && echo ' -> reached')" | tee -a "$EV/driver.log"
    [ "$s" -ge "$min" ] && break
    sleep "$iv"
done
echo "$name $s"
