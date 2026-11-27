#!/bin/bash
# clear-components.sh -- in the Components page of the first-boot wizard, with the list focused on
# item 1: clear every box by keyboard, one key per call with a pause (chords sent back-to-back
# are dropped under TCG).  <count> items: space, down ... (the last down at the list's end is harmless)
set -u
EV="${EV:-/tmp/c6/ev/vm1}"
QAD=<project>
SOCK="$(cat "$EV/sock-dir.txt")/monitor.sock"
n="${1:?count}"
for i in $(seq 1 "$n"); do
    python3 "$QAD/tools/mon.py" "$SOCK" key spc > /dev/null; sleep 1
    python3 "$QAD/tools/mon.py" "$SOCK" key down > /dev/null; sleep 1
done
printf '%s cleared %s boxes (spc,down x%s)\n' "$(date -u +%T)" "$n" "$n" | tee -a "$EV/driver.log"
