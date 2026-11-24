#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# reproduce.sh — AC5: reproduce AC2 (VM stage 1) and the qtest from a clean
# checkout of this project in one command.  Clones the repository into
# .clean/ (not committed), fetches the pinned QEMU (the downloaded tarball is
# reused when dl/ has it), builds, runs the qtest, the regression control and
# the stage-1 VM, and compares the drivers' serial lines with the stored
# evidence.  Env: ISO=<the live ISO> (default disk/bootcd.iso), WAIT=<cap>.
# This work is licensed under the terms of the GNU GPL, version 2 or later.
# See the COPYING file in the top-level directory.
set -u
Q="$(cd "$(dirname "$0")" && pwd)"
C="$Q/.clean/qemu-ace-dsp"
export ISO="${ISO:-$Q/disk/bootcd.iso}"
WAIT="${WAIT:-600}"
rm -rf "$Q/.clean"
mkdir -p "$Q/.clean"
git clone -q "$Q" "$C" || { echo "clone failed"; exit 1; }
mkdir -p "$C/dl"; cp -f "$Q"/dl/*.tar.xz "$C/dl/" 2>/dev/null
cd "$C"
echo "== fetch";  bash fetch.sh | tail -1
echo "== build";  bash build.sh 2>&1 | grep -E 'build ok|FAILED|QEMU emulator'
echo "== qtest";  (cd build && QTEST_QEMU_BINARY=./qemu-system-x86_64 timeout 400 ./tests/qtest/intel-hda-ace-test 2>&1 | grep -E '^(ok|not ok)' | tr '\n' ' '); echo
echo "== control (ich9)"; EVID="$C/evidence/clean-control" WAIT=$WAIT STOP_ON='audio path LegacyHdaOnly' SETTLE=5 bash run-control.sh ich9 | grep -E 'qemu exited|not created on PCI 8086:293e|LegacyHdaOnly' | cut -c1-150
echo "== stage 1 (ace)";     EVID="$C/evidence/clean-stage1" TRACE=1 WAIT=$WAIT STOP_ON='BootDsp = 0' SETTLE=5 bash run.sh | grep -E 'qemu exited|ADSP child created|BootDsp =|device trace' | cut -c1-150
echo "== stored evidence";   grep -aE 'ADSP child created|BootDsp = 0' "$Q"/evidence/*/c2-stage1-run1/serial.log | cut -c1-150
echo "== diff of the driver lines (clean vs stored)"
diff <(grep -aE 'hdaudbus\.sys|intcdsp\.sys' "$C/evidence/clean-stage1/serial.log" | sed 's/^\[ *[0-9.]*\] //') \
     <(grep -aE 'hdaudbus\.sys|intcdsp\.sys' "$Q"/evidence/*/c2-stage1-run1/serial.log | sed 's/^\[ *[0-9.]*\] //') \
     && echo "IDENTICAL (timestamps aside)"
