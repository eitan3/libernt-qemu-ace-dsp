#!/bin/bash
# E5 prep (no VM): the E5c round's tools re-pointed at this round and the final image, the data disk with the
# apitest built at the final tip and the helper exes / short .cmd files, a fresh first-boot overlay over the
# final image's VHD (mkqcow2.py: no qemu-img on the host; the VHD stays on disk).
set -eu
E5C=<project>/evidence/2026-11-28-p5-e5c/tools-used
T=/tmp/e5/tools
QAD=<project>
IMG=<home>/libernt-build-logs/test-audio-p5final-9f023b460cc
VHD=$IMG/LiberNT.vhd
mkdir -p "$T" /tmp/e5/pouch /tmp/e5/ev /tmp/e5/setdef
cp "$E5C/mkqcow2.py" "$T/"
cp "$E5C/vmcommon.sh" "$T/vmcommon.sh"
sed -i -e 's|^QAD=<project>$|QAD='"$QAD"'|' \
       -e 's|^T=/tmp/e5c/tools$|T=/tmp/e5/tools|' \
       -e 's|^IMG="\${IMG:-<home>/libernt-build-logs/test-burnboot-leg1-909633bdde3}"$|IMG="${IMG:-'"$IMG"'"}|' \
       -e 's|^OVERLAY="\${OVERLAY:-e5c-firstboot}"$|OVERLAY="${OVERLAY:-e5-firstboot}"|' \
       -e 's|^EV=/tmp/e5c/ev/\$RUN$|EV=/tmp/e5/ev/$RUN|' \
       -e 's|POUCH="\${POUCH-/tmp/e5c/pouch/\$RUN.img}"|POUCH="${POUCH-/tmp/e5/pouch/$RUN.img}"|' \
       -e 's|#   RUN      the run.s name under /tmp/e5b/ev/ (the live logs, on tmpfs)|#   RUN      the run'"'"'s name under /tmp/e5/ev/ (the live logs, on tmpfs)|' \
       "$T/vmcommon.sh"
grep -n -E '^QAD=|^IMG=|^T=|^OVERLAY=|^EV=|^POUCH=' "$T/vmcommon.sh"
cp "$E5C/make-pouch.sh" "$T/make-pouch.sh"
sed -i -e 's|^SRC="\${SRC:-<home>/libernt-build-logs/test-audio-intel-sst-p5e4b-82d9cf754e9}"$|SRC="${SRC:-/tmp/e5/dsploop}"|' \
       -e 's|^W=\$(mktemp -d /tmp/e5b/pouch.XXXXXX)$|W=$(mktemp -d /tmp/e5/pouch.XXXXXX)|' \
       -e 's|/tmp/e5c/tools/setdef.cmd|/tmp/e5/tools/setdef.cmd|' \
       -e 's|/tmp/e5c/setdef/setdefault.exe|/tmp/e5/setdef/setdefault.exe|' \
       -e 's|/tmp/e5c/tools/dl.cmd|/tmp/e5/tools/dl.cmd|' \
       -e 's|^printf .p5e4 pouch: the data disk of this VM\\n. > "\$W/pouch.tag"$|printf "e5 pouch: the data disk of this VM\\n" > "$W/pouch.tag"|' \
       -e 's|-n P5E4B |-n P5E5 |' \
       "$T/make-pouch.sh"
# the helper exes of E5c (standalone tools, built at 39e4bc940a5 by build-setdefault.py / build-endpointmute.py) and the batch files as cmd.exe reads them (CR LF)
cp /tmp/e5c/setdef/setdefault.exe /tmp/e5c/setdef/endpointmute.exe /tmp/e5/setdef/
cp "$E5C/setdef.cmd" "$E5C/dl.cmd" "$E5C/mute.cmd" "$T/"
sed -i 's/$/\r/' "$T/setdef.cmd" "$T/dl.cmd" "$T/mute.cmd"
file "$T/setdef.cmd" "$T/dl.cmd" "$T/mute.cmd"
# the data disk of the cycles VM (the exe only is needed there; the others go into the row VM's pouch)
SRC=/tmp/e5/dsploop bash "$T/make-pouch.sh" /tmp/e5/pouch/cycles.img
# a fresh first-boot overlay over the final image's VHD: 80 GiB as the VHD's footer says
python3 "$T/mkqcow2.py" "$QAD/disk/e5-firstboot.qcow2" "$VHD" 85899345920
ls -la "$QAD/disk/e5-firstboot.qcow2"
cat "$IMG/source-state.txt"; cat "$IMG/SHA256SUMS"
echo "qemu processes: $(pgrep -c -x qemu-system-x86_64 || true)"
