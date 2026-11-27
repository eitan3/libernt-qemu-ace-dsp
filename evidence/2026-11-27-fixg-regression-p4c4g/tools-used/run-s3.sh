#!/bin/bash
# run-s3.sh -- S3 of the p4c4g round: the 20 fault rows on the S2 overlay (BootDsp = 1, no
# topology), the project's tools/fault-matrix.sh as the p4c4c round ran it (fault-matrix-p4c4g.sh:
# ICOUNT=1, TRACE=1, QTESTSOCK=1, a recovery cycle per row, the rows collected as they finish),
# then tools/fm-check.sh over the collected rows.  The live rows run under /tmp/c6g/fm (tmpfs);
# the collected copies (serial log, command line, screenshot, the trace excerpt + gzipped) go to
# the evidence tree.
set -u
Q=<project>
E=$Q/evidence/2026-11-27-fixg-regression-p4c4g
IMG=<home>/libernt-build-logs/test-audio-intel-sst-p4c4g-6bdaaa5e920
T=/tmp/c6g/tools
C="$E/logs/s3/fm"
cd "$Q"
if pgrep -f "qemu-system-x86_64 -L $Q/build/pc-bios" > /dev/null; then echo "REFUSED: a QEMU of this project is running" >&2; exit 3; fi
[ -e "$C" ] && { echo "REFUSED: $C exists" >&2; exit 3; }
mkdir -p "$C"
date -u +%FT%TZ > "$E/logs/s3/started.txt"
env DISK="$Q/disk/p4c4g-nt.qcow2" ISO="$IMG/LiberNT.iso" EVROOT=/tmp/c6g/fm WINDOW=30 \
    ICOUNT=1 RECOVER=1 COLLECT="$C" \
    bash "$T/fault-matrix-p4c4g.sh" halt-rom=43 halt-rom=44 halt-fw=51 crash-notification abi=2 window-read-fail \
    never-power never-ack never-ready never-enter never-fwready never-reply drop-requests ipc-status=5 bad-tuples \
    truncated-reply version-shift scale:1550 scale:0.001 FAULT=none > "$E/logs/s3/fault-matrix.out" 2>&1
rc=$?
date -u +%FT%TZ > "$E/logs/s3/ended.txt"
echo "fault-matrix rc=$rc"
# the rows' table is the script's own summary under EVROOT; fm-check.sh appends its table to a
# fault-matrix.md inside the collected dir: the two are joined here
cp -f /tmp/c6g/fm/fault-matrix.md "$E/logs/s3/fault-matrix.rows.md"
bash tools/fm-check.sh "$C" >> "$E/logs/s3/fm-check.out" 2>&1
{ cat /tmp/c6g/fm/fault-matrix.md; echo; cat "$C/fault-matrix.md"; } > "$E/logs/s3/fault-matrix.md"
tail -3 "$E/logs/s3/fm-check.out"
# the live rows' raw -d logs are the collected .gz copies' sources: drop them to keep /tmp/c6g small
rm -f /tmp/c6g/fm/*/qemu-dbg.log
du -sh /tmp/c6g/fm "$C"
