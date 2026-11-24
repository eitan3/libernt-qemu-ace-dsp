#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# snapshot.sh — a PNG screenshot of the VM's display through the monitor socket.
# usage: snapshot.sh <evidence-dir> [name]   -> <evidence-dir>/<name>.png (default: desktop)
# This work is licensed under the terms of the GNU GPL, version 2 or later.
# See the COPYING file in the top-level directory.
set -u
cd "$(dirname "$0")"
EV="${1:?usage: snapshot.sh <evidence-dir> [name]}"
NAME="${2:-desktop}"
EV="$(cd "$EV" && pwd)"
python3 tools/mon.py "$EV/monitor.sock" "screendump $EV/$NAME.png format=png" | sed -n '1,3p'
ls -la "$EV/$NAME.png"
