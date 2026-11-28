#!/bin/bash
# E5-fixes host-test gate: build mmdevapi in the E5 scratch (/tmp/ht-e1a) and run mmdevapi.devenum.
# Usage: bash /tmp/e5fix-host-gate.sh [logfile]   (default /tmp/e5fix-host-build.log)
set -u
HT=/tmp/ht-e1a
LOG=${1:-/tmp/e5fix-host-build.log}
ninja -C "$HT" mmdevapi > "$LOG" 2>&1
rc=$?
echo "ninja mmdevapi rc=$rc; steps: $(grep -c '^\[' "$LOG"); warning lines: $(grep -c -i 'warning:' "$LOG"); error lines: $(grep -c -i 'error:' "$LOG")"
grep -i -e 'warning:' -e 'error:' "$LOG" | head -10
ctest --test-dir "$HT" -R mmdevapi.devenum --output-on-failure 2>&1 | tail -8
