#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# guest.sh — drive a running VM of lib-run.sh through its monitor socket.
#   guest.sh <evidence-dir> key ctrl-esc [chord ...]   one sendkey per chord
#   guest.sh <evidence-dir> type "text"                one sendkey per character
#   guest.sh <evidence-dir> shot [name]                PNG screenshot into the evidence dir
#   guest.sh <evidence-dir> mon 'hmp command'          any human-monitor command
#   guest.sh <evidence-dir> stop                       terminate the VM (SIGTERM)
# The key names are QEMU's (spc, ret, tab, ctrl-alt-delete, shift-semicolon ...).
# This work is licensed under the terms of the GNU GPL, version 2 or later.
# See the COPYING file in the top-level directory.
set -u
EV="${1:?usage: guest.sh <evidence-dir> key|type|shot|mon|stop ...}"
EV="$(cd "$EV" 2>/dev/null && pwd)" || { echo "guest.sh: no such evidence dir: $1" >&2; exit 2; }
shift
QAD="$(cd "$(dirname "$0")/.." && pwd)"
SOCK="$(cat "$EV/sock-dir.txt" 2>/dev/null)" || { echo "guest.sh: no sock-dir.txt in $EV" >&2; exit 2; }
case "$1" in
    key)  shift; python3 "$QAD/tools/mon.py" "$SOCK/monitor.sock" key "$@" ;;
    type) shift; python3 "$QAD/tools/mon.py" "$SOCK/monitor.sock" type "$@" ;;
    shot) shift; NAME="${1:-shot}"; python3 "$QAD/tools/mon.py" "$SOCK/monitor.sock" "screendump $EV/$NAME.png -f png" >/dev/null; ls -la "$EV/$NAME.png" ;;
    mon)  shift; python3 "$QAD/tools/mon.py" "$SOCK/monitor.sock" "$@" ;;
    stop) kill -TERM "$(cat "$SOCK/qemu.pid")" && echo "terminated $(cat "$SOCK/qemu.pid")" ;;
    *) echo "usage: guest.sh <evidence-dir> key|type|shot|mon|stop ..." >&2; exit 2 ;;
esac
