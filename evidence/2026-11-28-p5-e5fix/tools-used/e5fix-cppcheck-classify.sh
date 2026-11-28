#!/bin/bash
# Classify the 24 cppcheck notes of libernt_wdmaud.c: by message, by file, and whether any is in a changed line.
set -u
T=/tmp/cppcheck-gate/kernel-dll_win32_mmdevapi_libernt_wdmaud.c.txt
echo "--- by message"
grep -E ':[0-9]+:[0-9]+: ' "$T" | grep -v ': note:' | sed -E 's/.*\[([A-Za-z]+)\]$/\1/' | sort | uniq -c
echo "--- by file"
grep -E ':[0-9]+:[0-9]+: ' "$T" | grep -v ': note:' | sed -E 's/^([^:]+):[0-9]+:[0-9]+: .*/\1/' | sort | uniq -c
echo "--- any in endpoint_props.h at all?"
grep -c 'endpoint_props\.h:' "$T"
echo "--- any severity other than portability?"
grep -E ':[0-9]+:[0-9]+: ' "$T" | grep -v ': note:' | grep -v -c ': portability:'
echo "--- the lines of libernt_wdmaud.c the branch's diff touches (should be none: the file is unchanged)"
cd <home>/Projects/LiberNT && git diff --stat -- dll/win32/mmdevapi/libernt_wdmaud.c | tail -1; echo "(empty = unchanged)"
