#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# qemu-ace-dsp: guest.sh's companion -- wait (bounded) for a line of the serial log.
#   waitline.sh <evidence-dir> '<extended regex>' [timeout s, default 120] [from line N]
# Prints every matching line (ANSI escapes stripped, NULs removed) prefixed by
# the host time it was seen, then exits 0; on timeout prints "-- not seen in
# <timeout> s: <regex>" and exits 1. With "from line N" only lines after the
# Nth of the normalised log match (a second boot attempt in one VM must not be
# answered by the first attempt's lines). Never stops the VM.
# This work is licensed under the terms of the GNU GPL, version 2 or later.
# See the COPYING file in the top-level directory.
set -u
EV="${1:?usage: waitline.sh <evidence-dir> '<regex>' [timeout s] [from line N]}"
RE="${2:?regex missing}"
TO="${3:-120}"
FROM="${4:-0}"
EV="$(cd "$EV" 2>/dev/null && pwd)" || { echo "waitline: no such evidence dir: $1" >&2; exit 2; }
norm() { sed "s/\x1b\[[0-9;]*[A-Za-z]//g" "$EV/serial.log" 2>/dev/null | tr -d "\0"; }
t0=$(date +%s)
while :; do
    if [ -f "$EV/serial.log" ] && norm | tail -n +"$((FROM + 1))" | grep -aEq "$RE"; then
        norm | tail -n +"$((FROM + 1))" | grep -aE "$RE" | while IFS= read -r l; do printf '[%s] %s\n' "$(date +%H:%M:%S)" "$l"; done
        exit 0
    fi
    [ $(( $(date +%s) - t0 )) -ge "$TO" ] && break
    sleep 1
done
echo "-- not seen in $TO s (after line $FROM): $RE"
exit 1
