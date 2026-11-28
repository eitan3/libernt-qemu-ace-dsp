#!/bin/bash
# E5c: the mmdevapi host test, built and run in the E1a scratch (named target, named test).
# A failed build stops here: the test of a stale binary says nothing.
set -u
O=/tmp/ht-e1a
L=/tmp/e5c
mkdir -p "$L"
date '+start %T'
cd "$O" && ninja mmdevapi > "$L/host-build.txt" 2>&1
rc=$?
echo "ninja mmdevapi rc=$rc, warnings: $(grep -c -i 'warning' "$L/host-build.txt"), errors: $(grep -c -E 'error:' "$L/host-build.txt")"
grep -E 'warning|error:' "$L/host-build.txt" | head -20
[ "$rc" = 0 ] || { echo "!! build failed: the test is not run"; exit 1; }
ctest --test-dir "$O" -R mmdevapi.devenum --output-on-failure > "$L/mmdevapi.txt" 2>&1
rc2=$?
echo "ctest rc=$rc2"
grep -aE 'checks|FAIL|Passed|Failed' "$L/mmdevapi.txt" | head -12
date '+end %T'
