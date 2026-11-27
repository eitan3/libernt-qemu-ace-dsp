#!/bin/bash
# console.sh -- type console lines into the guest one by one (each line + Enter, a pause after
# each: keys sent back-to-back are dropped under TCG).  Lines come from a file, one per line.
#   console.sh <lines-file> [pause s after Enter, default 4]
set -u
EV="${EV:?EV=<vm evidence dir>}"
QAD=<project>
SOCK="$(cat "$EV/sock-dir.txt")/monitor.sock"
f="${1:?lines file}"; p="${2:-4}"
while IFS= read -r line; do
    [ -z "$line" ] && continue
    python3 "$QAD/tools/mon.py" "$SOCK" type "$line" > /dev/null; sleep 1
    python3 "$QAD/tools/mon.py" "$SOCK" key ret > /dev/null
    printf '%s typed: %s\n' "$(date -u +%T)" "$line" | tee -a "$EV/driver.log"
    sleep "$p"
done < "$f"
