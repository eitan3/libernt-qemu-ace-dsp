#!/bin/bash
# E5c: the mute row's files and tools added to the evidence; the exact lines of both rounds printed for the report.
set -u
Q=<project>
E=$Q/evidence/2026-11-28-p5-e5c
[ "$(pgrep -c qemu || true)" = 0 ] || { echo "!! a QEMU is running"; exit 3; }
mkdir -p "$E/vm/mute"
for f in serial.log driver.log lib-run.out mute-1.txt mute-0.txt dl-unmuted.txt; do [ -f "/tmp/e5c/ev/mute/$f" ] && cp "/tmp/e5c/ev/mute/$f" "$E/vm/mute/"; done
cp /tmp/e5c/ev/mute/*.png "$E/vm/mute/" 2>/dev/null
cp /tmp/e5c/round4.out "$E/vm/mute/round.out"
cd /tmp/e5c/tools && cp roundmute.sh mute.cmd build-endpointmute.py "$E/tools-used/"
cp /tmp/e5c/setdef-src/endpointmute.c /tmp/e5c/e5c-24-round4.sh /tmp/e5c/e5c-31-hdaudio.sh /tmp/e5c/e5c-32-collect-mute.sh "$E/tools-used/"
cp /tmp/e5c/build-endpointmute.txt "$E/host/"
(cd /tmp/e5c/setdef && sha256sum endpointmute.exe setdefault.exe) >> "$E/host/SHA256SUMS"
echo "== the mute round's exact lines (serial)"; sed "s/\x1b\[[0-9;]*[A-Za-z]//g" "$E/vm/mute/serial.log" | tr -d '\0\r' | grep -a -E 'intcdsp\.sys: gain: ' | cut -c1-140
echo "== mute-1.txt / mute-0.txt"; tr -d '\r' < "$E/vm/mute/mute-1.txt" | head -6; echo --; tr -d '\r' < "$E/vm/mute/mute-0.txt" | head -6
echo "== the first round's (the batch script) setdef.txt"; tr -d '\r' < "$E/vm/level-cmd-script/setdef.txt" | head -8
echo "== dl-unmuted.txt"; tr -d '\r' < "$E/vm/mute/dl-unmuted.txt" | grep -a -E 'volume node|frames compared|depths compared|tests executed' | cut -c1-230
(cd "$Q" && bash normalise-evidence.sh | tail -3)
echo "files: $(find "$E" -type f | wc -l), $(du -sh "$E" | cut -f1)"
