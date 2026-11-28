#!/bin/bash
# E5c: cppcheck's findings of the backend by line, against the changed lines; then dsploop_apitest.exe (the gate).
set -u
L=/tmp/e5c
R=<home>/Projects/LiberNT
echo "== cppcheck backend findings (line: id) and the changed lines of the file"
grep -aE 'libernt_wdmaud\.c:[0-9]+:[0-9]+: ' "$L/cppcheck-backend.txt" | sed -E 's/.*libernt_wdmaud\.c:([0-9]+):[0-9]+: ([a-z]+): .*\[([A-Za-z]+)\]/\1 \3/' | sort -n | uniq | tr '\n' ';'
echo
echo "changed (new) line ranges:"; cd "$R" && git --no-optional-locks diff -U0 -- dll/win32/mmdevapi/libernt_wdmaud.c | grep -a -E '^@@' | sed -E 's/^@@ -[0-9,]+ \+([0-9]+)(,([0-9]+))? @@.*/\1 \3/' | tr '\n' ';'
echo
echo "== dsploop apitest"
mkdir -p "$L/dsploop"
date '+start %T'
python3 <home>/libernt-build-logs/tools/build-dsploop.py "$L/dsploop/dsploop_apitest.exe" > "$L/build-dsploop.txt" 2>&1
echo "build-dsploop.py rc=$?"
grep -a -i -E 'rc=|OK|warning|error|sha256|bytes' "$L/build-dsploop.txt" | head -12
ls -la "$L/dsploop/"
sha256sum "$L/dsploop/dsploop_apitest.exe" | cut -c1-16
date '+end %T'
