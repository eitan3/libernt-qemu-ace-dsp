#!/bin/bash
# collect-e1c.sh -- after the round: the evidence of the E1c VM into the project's evidence tree.
# Each VM: the raw serial log and a text copy, the driver log, the text the guest wrote to its
# data disk under pouch/ (the exe left out), rows.md, e1-lines.txt, the model's set-fault answers,
# lib-run's output, the -d log gzipped, the screenshots; the tools as run under tools-used/.
set -u
Q=<project>
E=$Q/evidence/2026-11-27-p5-e1c
T=/tmp/e1c/tools
mkdir -p "$E/vm" "$E/tools-used"
cp -f "$T"/*.sh "$E/tools-used/"
col() {  # col <run name> [png prefix ...]
    local run="$1" dst="$E/vm/$1"; shift
    mkdir -p "/tmp/e1c/ev/$run/pouch"
    [ -f "/tmp/e1c/pouch/$run.img" ] && mcopy -n -i "/tmp/e1c/pouch/$run.img@@32256" "::*" "/tmp/e1c/ev/$run/pouch/" > "/tmp/e1c/ev/$run/pouch-mcopy.out" 2>&1
    rm -f "/tmp/e1c/ev/$run"/pouch/dsploop_apitest.exe
    ( cd "/tmp/e1c/ev/$run/pouch" 2>/dev/null && sha256sum ./* 2>/dev/null | sed 's|\./||' > ../pouch-sha256.txt )
    local pngs=()
    for p in "$@"; do for f in "/tmp/e1c/ev/$run/$p"*.png; do [ -f "$f" ] && pngs+=("$(basename "$f" .png)"); done; done
    bash "$T/collect.sh" "/tmp/e1c/ev/$run" "$dst" "${pngs[@]}"
    cp -f "/tmp/e1c/ev/$run/rows.md" "/tmp/e1c/ev/$run/e1-lines.txt" "/tmp/e1c/ev/$run/pouch-sha256.txt" "/tmp/e1c/ev/$run.out" "$dst/" 2>/dev/null
}
for r in "$@"; do
    case "$r" in
        e1c-round) col e1c-round 0 ;;
        *) col "$r" dbg ;;
    esac
done
echo "collected: $(find "$E/vm" -type f | wc -l) files under $E/vm"
