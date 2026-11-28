#!/bin/bash
# ptr.sh -- the hand-driven pointer steps of the flow VM while tools/e5-flow.sh waits for a go file (the monitor
# serves one client at a time: the script is idle in its wait)
#   ptr.sh shot <name>     a screenshot into /tmp/e5/ev/flow/<name>.png
#   ptr.sh mv <dx> <dy>    a relative pointer move (HMP mouse_move: the PS/2 mouse)
#   ptr.sh btn <0|1>       the left button up / down (HMP mouse_button: the button mask)
#   ptr.sh click           down, up
#   ptr.sh type "<text>"   typed (short lines)
#   ptr.sh key <chord>     a key chord (QEMU names)
#   ptr.sh go <name>       the go file the script waits for
set -u
QAD=<project>
EV=/tmp/e5/ev/flow
case "$1" in
    shot) python3 "$QAD/tools/mon.py" "$(cat "$EV/sock-dir.txt")/monitor.sock" "screendump $EV/$2.png -f png" >/dev/null; ls -la "$EV/$2.png" | cut -c1-100;;
    mv)   python3 "$QAD/tools/mon.py" "$(cat "$EV/sock-dir.txt")/monitor.sock" "mouse_move $2 $3";;
    btn)  python3 "$QAD/tools/mon.py" "$(cat "$EV/sock-dir.txt")/monitor.sock" "mouse_button $2";;
    click) python3 "$QAD/tools/mon.py" "$(cat "$EV/sock-dir.txt")/monitor.sock" "mouse_button 1"; sleep 0.3; python3 "$QAD/tools/mon.py" "$(cat "$EV/sock-dir.txt")/monitor.sock" "mouse_button 0";;
    type) shift; (cd "$QAD" && tools/guest.sh "$EV" type "$@");;
    key)  shift; (cd "$QAD" && tools/guest.sh "$EV" key "$@");;
    go)   touch "$EV/$2"; echo "go: $2 at $(date +%T)";;
    *) echo "usage: ptr.sh shot|mv|btn|click|type|key|go ..." >&2; exit 2;;
esac
