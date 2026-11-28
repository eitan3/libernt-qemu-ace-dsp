#!/bin/bash
# E5c: mmdevapi.dll and the four drivers of the gate, named targets, warnings counted.
set -u
O=<home>/Projects/LiberNT/output-Clang-amd64-debug
L=/tmp/e5c
mkdir -p "$L"
date '+start %T'
cd "$O" && CCACHE_DISABLE=1 ninja mmdevapi.dll > "$L/mmdevapi-build.txt" 2>&1
rc=$?
echo "mmdevapi.dll rc=$rc, warnings: $(grep -c -E 'warning:' "$L/mmdevapi-build.txt"), errors: $(grep -c -E 'error:' "$L/mmdevapi-build.txt"), steps: $(grep -c -E '^\[[0-9]+/[0-9]+\]' "$L/mmdevapi-build.txt")"
grep -E 'warning:|error:' "$L/mmdevapi-build.txt" | head -20
cd "$O" && CCACHE_DISABLE=1 ninja intcdsp.sys hdaudbus.sys dsppcm.sys hdaudio.sys > "$L/drivers-build.txt" 2>&1
rc=$?
echo "drivers rc=$rc, warnings: $(grep -c -E 'warning:' "$L/drivers-build.txt"), errors: $(grep -c -E 'error:' "$L/drivers-build.txt"), steps: $(grep -c -E '^\[[0-9]+/[0-9]+\]' "$L/drivers-build.txt")"
grep -E 'warning:|error:' "$L/drivers-build.txt" | head -20
ls -la "$O/dll/win32/mmdevapi/mmdevapi.dll"
date '+end %T'
