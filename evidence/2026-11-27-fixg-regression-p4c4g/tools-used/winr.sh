#!/bin/bash
# winr.sh <text> [pause s after Enter, default 12] -- the run book's step 14: hold the Windows
# key and press R, type <text>, Enter.  (home, shift-end clear whatever the Run box holds.)
set -u
EV="${EV:?EV=<vm evidence dir>}"
QAD=<project>
SOCK="$(cat "$EV/sock-dir.txt")/monitor.sock"
k() { python3 "$QAD/tools/mon.py" "$SOCK" key "$1" > /dev/null; sleep "${2:-0}"; }
text="${1:?text}"; p="${2:-12}"
k meta_l-r 4; k home 0; k shift-end 0
python3 "$QAD/tools/mon.py" "$SOCK" type "$text" > /dev/null
printf '%s winr: meta_l-r, typed %s\n' "$(date -u +%T)" "$text" >> "$EV/driver.log"
sleep 1; k ret "$p"
