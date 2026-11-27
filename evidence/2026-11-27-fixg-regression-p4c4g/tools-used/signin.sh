#!/bin/bash
# signin.sh -- the run book's step 19 sign-in: on the "Press any key or click to sign in" screen
# press Enter (the account's tile is shown), type the password (not logged), Enter.
#   signin.sh <shot name of the tile> [pause s after the last Enter, default 30]
set -u
EV="${EV:?EV=<vm evidence dir>}"
QAD=<project>
SOCK="$(cat "$EV/sock-dir.txt")/monitor.sock"
k() { python3 "$QAD/tools/mon.py" "$SOCK" key "$1" > /dev/null; sleep "${2:-0}"; }
name="${1:?shot name}"; p="${2:-30}"
k ret 5
python3 "$QAD/tools/mon.py" "$SOCK" "screendump $EV/$name.png -f png" > /dev/null
printf '%s signin: Enter on the lock screen, shot %s.png (the tile); typing the password (<typed>)\n' "$(date -u +%T)" "$name" | tee -a "$EV/driver.log"
python3 "$QAD/tools/mon.py" "$SOCK" type "$(cat /tmp/c6g/.pw)" > /dev/null
sleep 1; k ret "$p"
