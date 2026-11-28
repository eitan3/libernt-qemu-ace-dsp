#!/bin/bash
# E5c prep 2 (no VM): setdef.cmd runs the helper exe; the data disk carries it too; a second fresh
# first-boot overlay over the owner's VHD; then round 2 under ICOUNT=1 (no compile while it runs).
set -eu
T=/tmp/e5c/tools
QAD=<project>
VHD=<home>/libernt-build-logs/test-burnboot-leg1-909633bdde3/LiberNT.vhd
printf '@echo off\r\ncd /d %%~d0\\\r\nsetdefault.exe > %%~d0\\setdef.txt 2>&1\r\n' > "$T/setdef.cmd"
cat -A "$T/setdef.cmd" | head -5
grep -q 'setdefault.exe' "$T/make-pouch.sh" || sed -i 's|^mcopy -i "\$W/part.img" /tmp/e5c/tools/setdef.cmd ::/$|&\nmcopy -i "$W/part.img" /tmp/e5c/setdef/setdefault.exe ::/|' "$T/make-pouch.sh"
grep -n 'mcopy' "$T/make-pouch.sh" | cut -c1-120
SRC=/tmp/e5c/dsploop bash "$T/make-pouch.sh" /tmp/e5c/pouch/level2.img | tail -11
python3 "$T/mkqcow2.py" "$QAD/disk/e5c-firstboot2.qcow2" "$VHD" 85899345920
echo "qemu processes: $(pgrep -c qemu || true)"
date '+start %T'
RUN=level2 OVERLAY=e5c-firstboot2 bash "$T/round.sh" > /tmp/e5c/round2.out 2>&1
echo "round.sh rc=$?"
date '+end %T'
