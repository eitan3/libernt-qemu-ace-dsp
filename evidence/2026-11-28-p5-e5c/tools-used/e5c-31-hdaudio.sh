#!/bin/bash
# E5c: the drivers gate after the jack line's change (hdaudio.sys rebuilt), warnings counted; cppcheck of prophnd.cpp.
set -u
O=<home>/Projects/LiberNT/output-Clang-amd64-debug
T=<home>/libernt-build-logs/tools
L=/tmp/e5c
date '+start %T'
cd "$O" && CCACHE_DISABLE=1 ninja intcdsp.sys hdaudbus.sys dsppcm.sys hdaudio.sys > "$L/hdaudio-build.txt" 2>&1
rc=$?
echo "drivers (with the jack line's change) rc=$rc, warnings: $(grep -c -E 'warning:' "$L/hdaudio-build.txt"), errors: $(grep -c -E 'error:' "$L/hdaudio-build.txt"), steps: $(grep -c -E '^\[[0-9]+/[0-9]+\]' "$L/hdaudio-build.txt")"
grep -E 'warning:|error:' "$L/hdaudio-build.txt" | head -10
cd <home>/Projects/LiberNT && HT=/tmp/ht-e1a W=/tmp/cppcheck-gate bash "$T/cppcheck-gate.sh" kernel drivers/wdm/audio/drivers/hdaudio/prophnd.cpp > "$L/cppcheck-prophnd.txt" 2>&1
echo "cppcheck prophnd.cpp rc=$?: $(grep -aE 'findings in the file|cppcheck errors' "$L/cppcheck-prophnd.txt" | tr '\n' ' ')"
grep -aE 'prophnd\.cpp:[0-9]+:[0-9]+: ' "$L/cppcheck-prophnd.txt" | cut -c1-200 | head -10
date '+end %T'
