#!/bin/bash
# collect-e4.sh -- after the rounds: the evidence of the E4 rounds into the project's evidence tree.
# The VMs (e4-cd on p5e3, e4-round on p5e4): the raw serial log and a text copy, the driver log, the text the guest
# wrote to its data disk under pouch/ (the exe left out), rows.md, lib-run's output, the -d log gzipped, the
# screenshots; the host side: the gates' outputs and the mutation rows.  The tools as run under tools-used/.
set -u
Q=<project>
E=$Q/evidence/2026-11-28-p5-e4
T=/tmp/e4/tools
BOOTNOISE='intcdsp\.sys: (loaded for|controller|NHLT|reading BAR4|BAR4 \+|HFINTIPPTR|firmware .SystemRoot|interrupts before|subsystem powered|code-loader|ROM ready|firmware entered|FW_READY|firmware ready|ipc: link ready)'
mkdir -p "$E/vm" "$E/tools-used" "$E/host"
cp -f "$T"/*.sh "$T"/px.py "$E/tools-used/"
for run in e4-cd e4-round e4-round2; do
    [ -d "/tmp/e4/ev/$run" ] || continue
    dst="$E/vm/$run"
    mkdir -p "/tmp/e4/ev/$run/pouch"
    if [ -f "/tmp/e4/pouch/$run.img" ]; then
        mcopy -n -i "/tmp/e4/pouch/$run.img@@32256" "::*" "/tmp/e4/ev/$run/pouch/" > "/tmp/e4/ev/$run/pouch-mcopy.out" 2>&1
    fi
    rm -f "/tmp/e4/ev/$run"/pouch/dsploop_apitest.exe
    ( cd "/tmp/e4/ev/$run/pouch" 2>/dev/null && sha256sum ./* 2>/dev/null | sed 's|\./||' > ../pouch-sha256.txt )
    pngs=()
    for f in "/tmp/e4/ev/$run"/[0-9]*.png; do [ -f "$f" ] && pngs+=("$(basename "$f" .png)"); done
    bash "$T/collect.sh" "/tmp/e4/ev/$run" "$dst" "${pngs[@]}"
    mkdir -p "$dst/pouch" && cp -f /tmp/e4/ev/$run/pouch/* "$dst/pouch/" 2>/dev/null; rm -f "$dst"/pouch/dsploop_apitest.exe
    cp -f "/tmp/e4/ev/$run/rows.md" "/tmp/e4/ev/$run/rows-final.md" "/tmp/e4/ev/$run/pouch-sha256.txt" "$dst/" 2>/dev/null
    cp -f "/tmp/e4/ev-$run.out" "$dst/round.out" 2>/dev/null
    sed "s/\x1b\[[0-9;]*[A-Za-z]//g" "/tmp/e4/ev/$run/serial.log" 2>/dev/null | tr -d "\0\r" | grep -a -E "intcdsp\.sys:|dsppcm\.sys:" | grep -a -v -E "$BOOTNOISE" > "$dst/e4-lines.txt"
done
# the host side
cp -f /tmp/e4/gates/*.txt /tmp/e4/mutations.txt "$E/host/" 2>/dev/null
echo "collected: $(find "$E/vm" -type f | wc -l) files under $E/vm, $(find "$E/host" -type f | wc -l) under $E/host"
