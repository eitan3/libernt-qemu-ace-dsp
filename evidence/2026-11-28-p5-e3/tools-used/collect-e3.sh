#!/bin/bash
# collect-e3.sh -- after the round: the evidence of the E3 round into the project's evidence tree.
# The VM: the raw serial log and a text copy, the driver log, the text the guest wrote to its data disk
# under pouch/ (the exe left out), rows.md, lib-run's output, the -d log gzipped, the screenshots; the
# host side: the qtest's TAP output, the model's mutation rows, the host test's and the gate's outputs.
# The tools as run under tools-used/.
set -u
Q=<project>
E=$Q/evidence/2026-11-28-p5-e3
T=/tmp/e3/tools
mkdir -p "$E/vm" "$E/tools-used" "$E/host"
cp -f "$T"/*.sh "$E/tools-used/"
run="${1:-e3-round}"
dst="$E/vm/$run"
mkdir -p "/tmp/e3/ev/$run/pouch"
if [ -f "/tmp/e3/pouch/$run.img" ]; then
    mcopy -n -i "/tmp/e3/pouch/$run.img@@32256" "::*" "/tmp/e3/ev/$run/pouch/" > "/tmp/e3/ev/$run/pouch-mcopy.out" 2>&1
fi
rm -f "/tmp/e3/ev/$run"/pouch/dsploop_apitest.exe
( cd "/tmp/e3/ev/$run/pouch" 2>/dev/null && sha256sum ./* 2>/dev/null | sed 's|\./||' > ../pouch-sha256.txt )
pngs=()
for f in "/tmp/e3/ev/$run"/0*.png "/tmp/e3/ev/$run"/9*.png; do [ -f "$f" ] && pngs+=("$(basename "$f" .png)"); done
bash "$T/collect.sh" "/tmp/e3/ev/$run" "$dst" "${pngs[@]}"
mkdir -p "$dst/pouch" && cp -f /tmp/e3/ev/$run/pouch/* "$dst/pouch/" 2>/dev/null; rm -f "$dst"/pouch/dsploop_apitest.exe
cp -f "/tmp/e3/ev/$run/rows.md" "/tmp/e3/ev/$run/rows-final.md" "/tmp/e3/ev/$run/pouch-sha256.txt" "$dst/" 2>/dev/null
cp -f "/tmp/e3/ev-e3-round.out" "$dst/round.out" 2>/dev/null
# the lines of the round, text, the boot noise left out
sed "s/\x1b\[[0-9;]*[A-Za-z]//g" "/tmp/e3/ev/$run/serial.log" 2>/dev/null | tr -d "\0" | grep -a -E "intcdsp\.sys:|dsppcm\.sys:" | grep -a -v -E "intcdsp\.sys: (loaded for|controller|NHLT|reading BAR4|BAR4 \+|HFINTIPPTR|interrupts before|subsystem powered|code-loader|ROM ready|firmware entered|FW_READY|firmware ready|ipc: link ready)" > "$dst/e3-lines.txt"
# the host side
cp -f /tmp/e3-qtest.txt "$E/host/qtest.tap"
cp -f /tmp/e3/mutation-check.md /tmp/e3/mutation-check-2.md "$E/host/" 2>/dev/null
cp -f /tmp/e3/mutations.txt /tmp/e3/mutations-2.txt "$E/host/" 2>/dev/null
cp -f /tmp/e3-sofipc.txt "$E/host/sofipc.txt" 2>/dev/null
cp -f /tmp/e3-sim-build.txt "$E/host/simulator-build.txt" 2>/dev/null
cp -f /tmp/e3/probe-gain.c "$E/host/probe-gain.c"
(cd /tmp/e3 && ./probe-gain > "$E/host/probe-gain.out" 2>&1)
echo "collected: $(find "$E/vm" -type f | wc -l) files under $E/vm, $(find "$E/host" -type f | wc -l) under $E/host"
