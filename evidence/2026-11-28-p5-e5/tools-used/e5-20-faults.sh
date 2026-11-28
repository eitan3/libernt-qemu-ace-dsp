#!/bin/bash
# E5 block 3: the 20 fault rows (the Fix G round's set) on the final image's matrix overlay (BootDsp = 1, SelfTest = 0,
# no topology: the overlay of the 22 cycles), the project's tools/fault-matrix.sh as the p4c4c/p4c4g rounds ran it
# (ICOUNT=1, TRACE=1, QTESTSOCK=1 by RECOVER=1, WINDOW=30, a recovery cycle per row, the rows collected as they
# finish), then tools/fm-check.sh over the collected rows.  FAULTS (space-separated) or N limit the run.
set -u
Q=<project>
IMG=<home>/libernt-build-logs/test-audio-p5final-9f023b460cc
E=$Q/evidence/2026-11-28-p5-e5
C="$E/vm/s3/fm"
mkdir -p "$E/vm" "$E/host" "$E/tools-used"
cd "$Q"
if ps -eo comm | grep -qi "qemu-system"; then echo "REFUSED: a QEMU is running" >&2; exit 3; fi
[ -e "$C" ] && { echo "REFUSED: $C exists" >&2; exit 3; }
mkdir -p "$C"
date -u +%FT%TZ > "$E/vm/s3-started.txt"
ALL=(FAULT=none halt-rom=43 halt-rom=44 halt-fw=51 crash-notification abi=2 window-read-fail never-power never-ack never-ready never-enter never-fwready never-reply drop-requests ipc-status=5 bad-tuples truncated-reply version-shift scale:1550 scale:0.001)
if [ -n "${FAULTS:-}" ]; then FA=($FAULTS); else FA=("${ALL[@]}"); fi
env DISK="$Q/disk/e5-firstboot.qcow2" ISO="$IMG/LiberNT.iso" EVROOT=/tmp/e5/fm WINDOW=30 \
    ICOUNT=1 RECOVER=1 COLLECT="$C" \
    bash tools/fault-matrix.sh "${FA[@]}" > "$E/vm/s3-fault-matrix.out" 2>&1
rc=$?
date -u +%FT%TZ > "$E/vm/s3-ended.txt"
echo "fault-matrix rc=$rc, rows: ${#FA[@]}"
cp -f /tmp/e5/fm/fault-matrix.md "$E/vm/s3-fault-matrix.rows.md" 2>/dev/null
bash tools/fm-check.sh "$C" >> "$E/vm/s3-fm-check.out" 2>&1
{ cat /tmp/e5/fm/fault-matrix.md; echo; cat "$C/fault-matrix.md"; } > "$E/vm/s3-fault-matrix.md" 2>/dev/null
tail -3 "$E/vm/s3-fm-check.out"
du -sh /tmp/e5/fm "$C" 2>/dev/null
