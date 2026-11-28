#!/bin/bash
# E5c prep (no VM): the tools of the E5b round copied and re-pointed at this round, the data disk with the
# apitest and the two short .cmd files, a fresh first-boot overlay over the owner's VHD (mkqcow2.py).
set -eu
E5B=<project>/evidence/2026-11-28-p5-e5b/tools-used
T=/tmp/e5c/tools
QAD=<project>
VHD=<home>/libernt-build-logs/test-burnboot-leg1-909633bdde3/LiberNT.vhd
mkdir -p "$T" /tmp/e5c/pouch /tmp/e5c/ev
cp "$E5B/mkqcow2.py" "$T/"
cp "$E5B/vmcommon.sh" "$T/vmcommon.sh"
sed -i -e 's|^QAD=<project>$|QAD=<project>|' \
       -e 's|^IMG="\${IMG:-<home>/libernt-build-logs/test-audio-intel-sst-p5e4b-82d9cf754e9}"$|IMG="${IMG:-<home>/libernt-build-logs/test-burnboot-leg1-909633bdde3}"|' \
       -e 's|^T=/tmp/e5b/tools$|T=/tmp/e5c/tools|' \
       -e 's|^OVERLAY="\${OVERLAY:-p5e3}"$|OVERLAY="${OVERLAY:-e5c-firstboot}"|' \
       -e 's|^EV=/tmp/e5b/ev/\$RUN$|EV=/tmp/e5c/ev/$RUN|' \
       -e 's|POUCH="\${POUCH-/tmp/e5b/pouch/\$RUN.img}"|POUCH="${POUCH-/tmp/e5c/pouch/$RUN.img}"|' \
       "$T/vmcommon.sh"
grep -n -E '^QAD=|^IMG=|^T=|^OVERLAY=|^EV=|^POUCH=' "$T/vmcommon.sh"
cp "$E5B/make-pouch.sh" "$T/make-pouch.sh"
sed -i 's|^mcopy -i "\$W/part.img" "\$W/pouch.tag" ::/$|&\nmcopy -i "$W/part.img" /tmp/e5c/tools/setdef.cmd ::/\nmcopy -i "$W/part.img" /tmp/e5c/tools/dl.cmd ::/|' "$T/make-pouch.sh"
grep -c 'setdef.cmd' "$T/make-pouch.sh"
# the batch files as cmd.exe reads them: CR LF
sed -i 's/$/\r/' "$T/setdef.cmd" "$T/dl.cmd"
file "$T/setdef.cmd" "$T/dl.cmd"
# the data disk
SRC=/tmp/e5c/dsploop bash "$T/make-pouch.sh" /tmp/e5c/pouch/level.img
# a fresh first-boot overlay over the owner's VHD: 80 GiB as the VHD's footer says
python3 "$T/mkqcow2.py" "$QAD/disk/e5c-firstboot.qcow2" "$VHD" 85899345920
ls -la "$QAD/disk/e5c-firstboot.qcow2"
# nothing else on the VM: names and counts only
echo "qemu processes: $(pgrep -c -x qemu-system-x86_64 || true)"
for m in mtype mdir mdel mcopy mkfs.vfat sfdisk truncate fsck.fat; do printf '%s: ' "$m"; command -v "$m" || echo MISSING; done
