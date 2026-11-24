#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# set-fault.sh — inject a run-time fault into the ACE model of a running VM.
# usage: set-fault.sh <evidence-dir> <fault> [property=value ...]
#   e.g. set-fault.sh evidence/2026-11-24/run-120000-ace never-reply
#        set-fault.sh evidence/... halt-rom=43 x-delay-scale=1.6
# The first argument is the model's "fault" property (plan §4.2: none,
# never-power, never-ack, never-ready, never-enter, never-fwready, never-reply,
# drop-requests, halt-rom=<code>, halt-fw=<code>, crash-notification, abi=<n>,
# ipc-status=<n>, bad-tuples, truncated-reply, version-shift, window-read-fail);
# any further name=value pairs are set on the same device (/machine/peripheral/ace).
# Uses QMP over the socket lib-run.sh opens (its /tmp dir is recorded in the
# evidence directory's sock-dir.txt); the device is the one with id "ace".
# This work is licensed under the terms of the GNU GPL, version 2 or later.
# See the COPYING file in the top-level directory.
set -u
cd "$(dirname "$0")"
EV="${1:?usage: set-fault.sh <evidence-dir> <fault> [property=value ...]}"
FAULT="${2:?fault name missing}"
shift 2
EV="$(cd "$EV" && pwd)"
SOCK="$(cat "$EV/sock-dir.txt")"
q=()
for kv in "fault=$FAULT" "$@"; do
    q+=("qom-set" "/machine/peripheral/ace" "${kv%%=*}" "${kv#*=}")
done
python3 tools/qmp.py "$SOCK/qmp.sock" "${q[@]}"
