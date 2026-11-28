#!/bin/bash
# E5-fixes cppcheck gate on the touched C units (the header is reached through each), plus the --probe proof.
set -u
T=<home>/libernt-build-logs/tools
R=<home>/Projects/LiberNT
mkdir -p /tmp/e5fix
cd "$R" || exit 1
echo "=== probe: is the analysis live with -D__cdecl= ?"
W=/tmp/cppcheck-gate bash "$T/cppcheck-gate.sh" --probe 2>&1 | head -6
echo
echo "=== host unit: submodules/host-tests/mmdevapi/t_mmdevapi.c (scratch build's compdb)"
W=/tmp/cppcheck-gate HT=/tmp/ht-e1a bash "$T/cppcheck-gate.sh" host submodules/host-tests/mmdevapi/t_mmdevapi.c 2>&1 | tee /tmp/e5fix/cppcheck-host.txt
echo "gate rc=${PIPESTATUS[0]}"
echo
echo "=== DLL unit: dll/win32/mmdevapi/libernt_wdmaud.c (the build's compdb, its own rule)"
W=/tmp/cppcheck-gate bash "$T/cppcheck-gate.sh" kernel dll/win32/mmdevapi/libernt_wdmaud.c 2>&1 | tee /tmp/e5fix/cppcheck-wdmaud.txt
echo "gate rc=${PIPESTATUS[0]}"
echo
echo "=== findings in the changed lines of the header (95-120) or the test's NT block (1165-1195), if any"
grep -E 'endpoint_props\.h:(9[5-9]|1[01][0-9]|120):' /tmp/cppcheck-gate/kernel-dll_win32_mmdevapi_libernt_wdmaud.c.txt | head -5
grep -E 't_mmdevapi\.c:(116[5-9]|11[78][0-9]|119[0-5]):' /tmp/cppcheck-gate/host-submodules_host-tests_mmdevapi_t_mmdevapi.c.txt | head -5
echo "(end)"
