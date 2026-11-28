#!/bin/bash
# E5: the mmdevapi host test on the final tip, built and run in the E1a scratch (named target, named test), between
# two VMs (no compile while a QEMU runs).  A failed build stops here.
set -u
O=/tmp/ht-e1a
L=/tmp/e5
ps -eo comm | grep -qi "qemu-system" && { echo "!! a QEMU is running: no build"; exit 3; }
date '+start %T'
cd <home>/Projects/LiberNT && git rev-parse --short=11 HEAD && git status --short | wc -l
cd "$O" && ninja mmdevapi > "$L/host-build.txt" 2>&1
rc=$?
echo "ninja mmdevapi rc=$rc, warnings: $(grep -c -i 'warning' "$L/host-build.txt"), errors: $(grep -c -E 'error:' "$L/host-build.txt"), steps: $(grep -c -E '^\[[0-9]+/[0-9]+\]' "$L/host-build.txt")"
grep -E 'warning|error:' "$L/host-build.txt" | head -10
[ "$rc" = 0 ] || { echo "!! build failed: the test is not run"; exit 1; }
ctest --test-dir "$O" -R mmdevapi.devenum --output-on-failure > "$L/mmdevapi.txt" 2>&1
rc2=$?
echo "ctest rc=$rc2"
grep -aE 'checks|FAIL|Passed|Failed|tests passed' "$L/mmdevapi.txt" | head -8
date '+end %T'
