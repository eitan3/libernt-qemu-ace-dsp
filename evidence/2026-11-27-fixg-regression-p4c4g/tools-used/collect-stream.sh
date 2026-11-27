#!/bin/bash
# collect-stream.sh -- after r-final.sh: the evidence of the S4-S8 VMs into the tree.  Each VM
# with the text the guest wrote to its data disk under pouch/ (the exe left out), the screenshots
# named; the S5 and S6 files again under logs/s5/ and logs/s6/ (their VM is one).
set -u
Q=<project>
E=$Q/evidence/2026-11-27-fixg-regression-p4c4g
T=/tmp/c6g/tools
col() {  # col <run name> <dest dir> [png prefix ...]
    local run="$1" dst="$2"; shift 2
    mkdir -p "/tmp/c6g/ev/$run/pouch"
    [ -f "/tmp/c6g/pouch/$run.img" ] && mcopy -n -i "/tmp/c6g/pouch/$run.img@@32256" "::*" "/tmp/c6g/ev/$run/pouch/" > "/tmp/c6g/ev/$run/pouch-mcopy.out" 2>&1
    rm -f "/tmp/c6g/ev/$run"/pouch/dsploop_apitest.exe "/tmp/c6g/ev/$run"/pouch/dsploop.exe
    ( cd "/tmp/c6g/ev/$run/pouch" 2>/dev/null && sha256sum ./* 2>/dev/null | sed 's|\./||' > ../pouch-sha256.txt )
    local pngs=()
    for p in "$@"; do for f in "/tmp/c6g/ev/$run/$p"*.png; do [ -f "$f" ] && pngs+=("$(basename "$f" .png)"); done; done
    bash "$T/collect.sh" "/tmp/c6g/ev/$run" "$dst" "${pngs[@]}"
}
col r-stream "$E/logs/s4/r-stream" s4a-after
col r-s4b "$E/logs/s4/r-s4b" s4b-after
col r-s6 "$E/logs/s6/r-s6" s5-after s7-
mkdir -p "$E/logs/s5" "$E/logs/s7"
cp -f /tmp/c6g/ev/r-s6/s5-*.txt /tmp/c6g/ev/r-s6/driver.log /tmp/c6g/ev/r-s6/cycle-rec-s5-*.out "$E/logs/s5/" 2>/dev/null
cp -f /tmp/c6g/ev/r-s6/s7-*.png "$E/logs/s7/" 2>/dev/null
grep -a "S7" /tmp/c6g/ev/r-s6/driver.log > "$E/logs/s7/driver-S7.log" 2>/dev/null
mkdir -p "$E/logs/s8"
col r-final "$E/logs/s8/r-final" s8b-desktop-after-boot
grep -a "S8" /tmp/c6g/ev/r-s6/driver.log > "$E/logs/s8/driver-S8.log" 2>/dev/null
echo "collected: $(find "$E/logs/s4" "$E/logs/s5" "$E/logs/s6" "$E/logs/s7" "$E/logs/s8" -type f | wc -l) files"
