#!/bin/bash
# E5-fixes prep checks (no VM). Read-only.
set -u
IMG=<home>/libernt-build-logs/test-audio-p5final-486b024c9b1
QAD=<project>
echo "=== image dir"; ls -la "$IMG" | head -12
echo "--- source-state / identity"; cat "$IMG/source-state.txt" 2>/dev/null | head -8
echo "--- VHD size (bytes) and footer's original size hint"; stat -c '%s' "$IMG/LiberNT.vhd"
echo
echo "=== qemu processes (count only): $(pgrep -c -x qemu-system-x86_64 || true)"
echo "=== E5 overlay sizes (for mkqcow2's size argument)"; ls -la "$QAD/disk/" | head -12
echo
echo "=== set-fault.sh: usage and the knob syntax (head 30)"; sed -n '1,30p' "$QAD/set-fault.sh"
echo
echo "=== E5 flow boot log: nwifi / wifi lines (if the evidence keeps a normalised serial log)"
ls "$QAD/evidence/2026-11-28-p5-e5/vm/flow/" | grep -i -e serial -e norm | head -5
for f in $(ls "$QAD/evidence/2026-11-28-p5-e5/vm/flow/"*serial* 2>/dev/null | head -2); do echo "--- $f"; tr -d '\r\0' < "$f" | sed 's/\x1b\[[0-9;]*[A-Za-z]//g' | grep -a -i -n -e 'nwifi' -e 'wifi\.sys' -e 'wlan' | head -10; done
echo
echo "=== query tools in the tree: driverquery / sc / netsh"
cd <home>/Projects/LiberNT && git ls-files | grep -i -E '^(base|shell)/.*(driverquery|/sc/|sc\.exe)' | head -5
grep -n -i -E 'driverquery|system32\\\\sc\.exe|netsh\.exe' image/data/componentfiles.txt | head -5
