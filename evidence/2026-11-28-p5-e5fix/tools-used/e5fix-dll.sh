#!/bin/bash
# E5-fixes DLL gate: build mmdevapi.dll (named target) with CCACHE_DISABLE=1, log, count warnings.
set -u
O=<home>/Projects/LiberNT/output-Clang-amd64-debug
L=/tmp/e5fix/mmdevapi-dll-build.log
mkdir -p /tmp/e5fix
cd "$O" || exit 1
CCACHE_DISABLE=1 ninja mmdevapi.dll > "$L" 2>&1
rc=$?
echo "ninja mmdevapi.dll rc=$rc"
echo "steps done: $(grep -c '^\[' "$L")  warning lines: $(grep -c -i 'warning:' "$L")  error lines: $(grep -c -i 'error:' "$L")"
echo "--- tail"
tail -3 "$L"
echo "--- warnings (if any)"
grep -i 'warning:' "$L" | head -10
echo "--- the steps that compiled the touched unit"
grep -E 'libernt_wdmaud|devenum' "$L" | head -5
