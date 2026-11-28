#!/bin/bash
# E5c final state: mmdevapi.dll and the drivers gate once more on the committed tree (named targets), warnings counted.
set -u
O=<home>/Projects/LiberNT/output-Clang-amd64-debug
L=/tmp/e5c
date '+start %T'
cd "$O" && CCACHE_DISABLE=1 ninja mmdevapi.dll > "$L/mmdevapi-build-final.txt" 2>&1
rc=$?
echo "mmdevapi.dll (final tree) rc=$rc, warnings: $(grep -c -E 'warning:' "$L/mmdevapi-build-final.txt"), errors: $(grep -c -E 'error:' "$L/mmdevapi-build-final.txt"), steps: $(grep -c -E '^\[[0-9]+/[0-9]+\]' "$L/mmdevapi-build-final.txt")"
grep -E 'warning:|error:' "$L/mmdevapi-build-final.txt" | head
cd "$O" && CCACHE_DISABLE=1 ninja intcdsp.sys hdaudbus.sys dsppcm.sys hdaudio.sys > "$L/drivers-build-final.txt" 2>&1
rc=$?
echo "drivers (final tree) rc=$rc, warnings: $(grep -c -E 'warning:' "$L/drivers-build-final.txt"), errors: $(grep -c -E 'error:' "$L/drivers-build-final.txt"), steps: $(grep -c -E '^\[[0-9]+/[0-9]+\]' "$L/drivers-build-final.txt")"
grep -E 'warning:|error:' "$L/drivers-build-final.txt" | head
ls -la --time-style=+%T "$O/dll/win32/mmdevapi/mmdevapi.dll" | awk '{print $6, $7, $5}'
date '+end %T'
