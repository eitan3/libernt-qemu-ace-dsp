#!/bin/bash
# E5c prep 3 (no VM): the helper rebuilt (the id's suffix cut fixed), the data disk 3, a third fresh
# first-boot overlay over the owner's VHD; then round 3 under ICOUNT=1 (no compile while it runs).
set -eu
T=/tmp/e5c/tools
QAD=<project>
VHD=<home>/libernt-build-logs/test-burnboot-leg1-909633bdde3/LiberNT.vhd
[ "$(pgrep -c qemu || true)" = 0 ] || { echo "!! a QEMU is running: not started"; exit 3; }
python3 "$T/build-setdefault.py" /tmp/e5c/setdef/setdefault.exe > /tmp/e5c/build-setdefault.txt 2>&1
echo "build rc=$? $(grep -E '^OK|^FAIL|rc=' /tmp/e5c/build-setdefault.txt | tr '\n' ' ')"
sha256sum /tmp/e5c/setdef/setdefault.exe | cut -c1-16
SRC=/tmp/e5c/dsploop bash "$T/make-pouch.sh" /tmp/e5c/pouch/level3.img | grep -E 'exe|cmd|files' | head -8
python3 "$T/mkqcow2.py" "$QAD/disk/e5c-firstboot3.qcow2" "$VHD" 85899345920 | cut -c1-120
echo "qemu processes: $(pgrep -c qemu || true)"
date '+start %T'
RUN=level3 OVERLAY=e5c-firstboot3 bash "$T/round.sh" > /tmp/e5c/round3.out 2>&1
echo "round.sh rc=$?"
date '+end %T'
