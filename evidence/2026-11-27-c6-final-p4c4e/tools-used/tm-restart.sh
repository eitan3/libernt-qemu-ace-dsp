#!/bin/bash
# tm-restart.sh -- restart the guest by the run book's keyboard path (step 19):
# Win+R, taskmgr, Enter; in Task Manager: Alt (menu bar), Right x4 (Shut Down), Enter (opens the
# menu on Stand By), Down x3 (Restart), a screenshot for the record, Enter.
#   tm-restart.sh <shot-name> [menu item: restart|turnoff]   (turnoff = Down x2, step 31)
set -u
EV="${EV:?EV=<vm evidence dir>}"
QAD=<project>
SOCK="$(cat "$EV/sock-dir.txt")/monitor.sock"
k() { python3 "$QAD/tools/mon.py" "$SOCK" key "$1" > /dev/null; sleep "${2:-1}"; }
name="${1:?shot name}"; item="${2:-restart}"
k meta_l-r 4; k home 0; k shift-end 0
python3 "$QAD/tools/mon.py" "$SOCK" type "taskmgr" > /dev/null; sleep 1; k ret 12
k alt 1; k right; k right; k right; k right; k ret 2
if [ "$item" = turnoff ]; then k down; k down; else k down; k down; k down; fi
sleep 1
python3 "$QAD/tools/mon.py" "$SOCK" "screendump $EV/$name.png -f png" > /dev/null
printf '%s tm-restart: Task Manager > Shut Down > %s selected (shot %s.png); Enter\n' "$(date -u +%T)" "$item" "$name" | tee -a "$EV/driver.log"
k ret 0
