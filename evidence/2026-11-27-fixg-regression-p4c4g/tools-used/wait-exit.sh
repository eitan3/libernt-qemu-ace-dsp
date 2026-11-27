#!/bin/bash
# wait-exit.sh [max s] -- wait until the VM of EV has exited (its pid is gone); log the result.
set -u
EV="${EV:?EV=<vm evidence dir>}"
max="${1:-150}"
PID=$(cat "$(cat "$EV/sock-dir.txt")/qemu.pid")
t0=$(date +%s)
while kill -0 "$PID" 2>/dev/null; do
    sleep 3
    [ $(( $(date +%s) - t0 )) -ge "$max" ] && break
done
if kill -0 "$PID" 2>/dev/null; then r="STILL RUNNING after $(( $(date +%s) - t0 )) s"; else r="EXITED, $(( $(date +%s) - t0 )) s after the wait began"; fi
date -u +%FT%TZ > "$EV/end.txt"
printf '%s qemu pid %s: %s\n' "$(date -u +%T)" "$PID" "$r" | tee -a "$EV/driver.log"
