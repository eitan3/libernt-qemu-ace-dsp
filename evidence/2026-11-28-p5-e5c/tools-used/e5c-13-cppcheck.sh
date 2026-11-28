#!/bin/bash
# E5c: cppcheck of the two touched C files (the build's compdb for the DLL's unit, the scratch's for the host unit).
set -u
T=<home>/libernt-build-logs/tools
L=/tmp/e5c
cd <home>/Projects/LiberNT
echo "== kernel: dll/win32/mmdevapi/libernt_wdmaud.c"
HT=/tmp/ht-e1a W=/tmp/cppcheck-gate bash "$T/cppcheck-gate.sh" kernel dll/win32/mmdevapi/libernt_wdmaud.c > "$L/cppcheck-backend.txt" 2>&1
echo "rc=$?"; tail -15 "$L/cppcheck-backend.txt" | cut -c1-300
echo "== host: submodules/host-tests/mmdevapi/t_mmdevapi.c"
HT=/tmp/ht-e1a W=/tmp/cppcheck-gate bash "$T/cppcheck-gate.sh" host submodules/host-tests/mmdevapi/t_mmdevapi.c > "$L/cppcheck-host.txt" 2>&1
echo "rc=$?"; tail -15 "$L/cppcheck-host.txt" | cut -c1-300
date '+%T'
