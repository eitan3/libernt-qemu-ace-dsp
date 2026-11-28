#!/bin/bash
# collect-e2.sh -- after the round: the evidence of the E2 VM into the project's evidence tree.
# Each VM: the raw serial log and a text copy, the driver log, the text the guest wrote to its
# data disk under pouch/ (the exe left out), rows.md, e2-lines.txt, the cycles' logs and the summary
# line, lib-run's output, the -d log gzipped, the screenshots; the tools as run under tools-used/.
set -u
Q=<project>
E=$Q/evidence/2026-11-28-p5-e2
T=/tmp/e3/tools
mkdir -p "$E/vm" "$E/tools-used"
cp -f "$T"/*.sh "$E/tools-used/"
col() {  # col <run name> [png prefix ...]
    local run="$1" dst="$E/vm/$1"; shift
    mkdir -p "/tmp/e3/ev/$run/pouch"
    [ -f "/tmp/e3/pouch/$run.img" ] && mcopy -n -i "/tmp/e3/pouch/$run.img@@32256" "::*" "/tmp/e3/ev/$run/pouch/" > "/tmp/e3/ev/$run/pouch-mcopy.out" 2>&1
    rm -f "/tmp/e3/ev/$run"/pouch/dsploop_apitest.exe
    ( cd "/tmp/e3/ev/$run/pouch" 2>/dev/null && sha256sum ./* 2>/dev/null | sed 's|\./||' > ../pouch-sha256.txt )
    local pngs=()
    for p in "$@"; do for f in "/tmp/e3/ev/$run/$p"*.png; do [ -f "$f" ] && pngs+=("$(basename "$f" .png)"); done; done
    bash "$T/collect.sh" "/tmp/e3/ev/$run" "$dst" "${pngs[@]}"
    mkdir -p "$dst/pouch" && cp -f /tmp/e3/ev/$run/pouch/* "$dst/pouch/" 2>/dev/null; rm -f "$dst"/pouch/dsploop_apitest.exe
    cp -f "/tmp/e3/ev/$run/rows.md" "/tmp/e3/ev/$run/e2-lines.txt" "/tmp/e3/ev/$run/pouch-sha256.txt" "/tmp/e3/ev/$run.out" "$dst/" 2>/dev/null
    cp -f "/tmp/e3/ev/$run/summary.txt" "/tmp/e3/ev/$run/cycles-summary.txt" "/tmp/e3/ev/$run/cycles-run.out" "/tmp/e3/ev/$run/cycle-a-1.from" "/tmp/e3/ev/$run/cycle-b-1.from" "$dst/" 2>/dev/null
}
for r in "$@"; do
    case "$r" in
        e2-round*|e2-round) col "$r" 0 ;;
        *) col "$r" dbg ;;
    esac
done
echo "collected: $(find "$E/vm" -type f | wc -l) files under $E/vm"
