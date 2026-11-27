#!/bin/bash
# wait-stable.sh <prefix> <start after s> <max s> [interval s, default 10] -- after a restart: a
# pause, then screenshots (each logged) every <interval> s until two in a row have almost the same
# size (within 150 bytes) and are under 40000 bytes -- the kernel's text screen is about 51 KB, the
# sign-in screen 20-25 KB and still -- or <max s> have passed since the first screenshot; prints
# the last two sizes.
set -u
EV="${EV:?EV=<vm evidence dir>}"
QAD=<project>
SOCK="$(cat "$EV/sock-dir.txt")/monitor.sock"
p="${1:?prefix}"; after="${2:?start after s}"; max="${3:?max s}"; iv="${4:-10}"
sleep "$after"
t0=$(date +%s); i=0; s=0; prev=0
while :; do
    i=$((i+1)); printf -v name '%s-%02d' "$p" "$i"
    python3 "$QAD/tools/mon.py" "$SOCK" "screendump $EV/$name.png -f png" > /dev/null
    prev=$s; s=$(stat -c %s "$EV/$name.png" 2>/dev/null || echo 0)
    d=$(( s > prev ? s - prev : prev - s ))
    printf '%s shot %s.png %s bytes (t+%ss)%s\n' "$(date -u +%T)" "$name" "$s" "$(( $(date +%s) - t0 ))" \
        "$([ "$i" -gt 1 ] && [ "$d" -lt 150 ] && [ "$s" -lt 40000 ] && echo ' -> still')" | tee -a "$EV/driver.log"
    [ "$i" -gt 1 ] && [ "$d" -lt 150 ] && [ "$s" -lt 40000 ] && break
    [ $(( $(date +%s) - t0 )) -ge "$max" ] && break
    sleep "$iv"
done
echo "$name $s (previous $prev)"
