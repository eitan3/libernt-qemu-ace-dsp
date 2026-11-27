#!/bin/bash
# c6.sh -- one small step of the C6 final pass on the running VM (the monitor serves one client
# at a time: every step goes through this script, nothing else touches the sockets).
# The rehearsal's c6.sh with EV made mandatory and one addition, `pw`:
#   c6.sh shot <name>          a PNG screenshot into the evidence dir (time-stamped in driver.log)
#   c6.sh key <chord> ...      one sendkey per chord (QEMU key names)
#   c6.sh type "<text>"        one sendkey per character
#   c6.sh pw                   types the rehearsal account's password, read from a file: the
#                              driver log records "<typed>", never the password
#   c6.sh mon "<hmp command>"  any human-monitor command
#   c6.sh wait <seconds>       a pause, time-stamped
set -u
QAD=<project>
EV="${EV:?EV=<vm evidence dir>}"
SOCK="$(cat "$EV/sock-dir.txt")/monitor.sock"
log() { printf '%s %s\n' "$(date -u +%T)" "$*" | tee -a "$EV/driver.log"; }
case "$1" in
    shot) shift; python3 "$QAD/tools/mon.py" "$SOCK" "screendump $EV/$1.png -f png" > /dev/null; log "shot $1.png $(stat -c %s "$EV/$1.png") bytes";;
    key)  shift; python3 "$QAD/tools/mon.py" "$SOCK" key "$@" > /dev/null; log "key $*";;
    type) shift; python3 "$QAD/tools/mon.py" "$SOCK" type "$@" > /dev/null; log "type $*";;
    pw)   python3 "$QAD/tools/mon.py" "$SOCK" type "$(cat /tmp/c6f/.pw)" > /dev/null; log "type <typed> (the account's password, not logged)";;
    mon)  shift; python3 "$QAD/tools/mon.py" "$SOCK" "$@"; log "mon $*";;
    wait) shift; sleep "$1"; log "waited $1";;
    *) echo "usage: c6.sh shot|key|type|pw|mon|wait ..." >&2; exit 2;;
esac
