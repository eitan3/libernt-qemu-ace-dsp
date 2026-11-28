#!/bin/bash
# E5-fixes prep (no VM): the E5 tools re-pointed at this round and the new image, two more .cmd files on the
# pouch (cap.cmd: the Capture endpoints' registry; svc.cmd: sc query Nwifi), the apitest built at the tip,
# the helper exes of E5c, a fresh first-boot overlay over the new VHD (mkqcow2.py: no qemu-img on the host).
set -eu
QAD=<project>
IMG=<home>/libernt-build-logs/test-audio-p5final-486b024c9b1
VHD=$IMG/LiberNT.vhd
T=/tmp/e5fix/tools
S=/tmp/e5/tools
mkdir -p "$T" /tmp/e5fix/pouch /tmp/e5fix/ev /tmp/e5fix/setdef

echo "== qemu processes by name: $(ps -eo comm | grep -c '^qemu-system' || true)"
echo "== the VHD footer: original / current size"
python3 - "$VHD" <<'EOF'
import struct, sys
f = open(sys.argv[1], 'rb'); f.seek(-512, 2); t = f.read(512)
print('cookie', t[:8], 'original', struct.unpack('>Q', t[40:48])[0], 'current', struct.unpack('>Q', t[48:56])[0])
EOF

cp "$S/mkqcow2.py" "$T/"
cp "$S/vmcommon.sh" "$T/vmcommon.sh"
sed -i -e 's|^T=/tmp/e5/tools$|T=/tmp/e5fix/tools|' \
       -e 's|^IMG="\${IMG:-<home>/libernt-build-logs/test-audio-p5final-9f023b460cc}"$|IMG="${IMG:-'"$IMG"'"}|' \
       -e 's|^OVERLAY="\${OVERLAY:-e5-firstboot}"$|OVERLAY="${OVERLAY:-e5fix-firstboot}"|' \
       -e 's|^EV=/tmp/e5/ev/\$RUN$|EV=/tmp/e5fix/ev/$RUN|' \
       -e 's|POUCH="\${POUCH-/tmp/e5/pouch/\$RUN.img}"|POUCH="${POUCH-/tmp/e5fix/pouch/$RUN.img}"|' \
       -e 's|/tmp/e5/ev/ (the live logs, on tmpfs)|/tmp/e5fix/ev/ (the live logs, on tmpfs)|' \
       "$T/vmcommon.sh"
echo "== vmcommon.sh re-pointed:"; grep -n -E '^QAD=|^IMG=|^T=|^OVERLAY=|^EV=|^POUCH=' "$T/vmcommon.sh"

cp "$S/make-pouch.sh" "$T/make-pouch.sh"
sed -i -e 's|^SRC="\${SRC:-/tmp/e5/dsploop}"$|SRC="${SRC:-/tmp/e5fix/dsploop}"|' \
       -e 's|W=\$(mktemp -d /tmp/e5/pouch.XXXXXX)|W=$(mktemp -d /tmp/e5fix/pouch.XXXXXX)|' \
       -e 's|/tmp/e5/tools/|/tmp/e5fix/tools/|g' \
       -e 's|/tmp/e5/setdef/|/tmp/e5fix/setdef/|g' \
       -e 's|-n P5E5 |-n P5E5F |' \
       -e 's|printf "e5 pouch: the data disk of this VM\\n"|printf "e5fix pouch: the data disk of this VM\\n"|' \
       -e 's|^\[ "\$(mdir -i|mcopy -i "$W/part.img" /tmp/e5fix/tools/cap.cmd /tmp/e5fix/tools/svc.cmd ::/\n[ "$(mdir -i|' \
       "$T/make-pouch.sh"
echo "== make-pouch.sh re-pointed:"; grep -n -E 'SRC=|^W=|mcopy|P5E5|pouch:' "$T/make-pouch.sh" | cut -c1-160

# the batch files as cmd.exe reads them (CR LF); the two new ones written here
cp "$S/setdef.cmd" "$S/dl.cmd" "$S/mute.cmd" "$S/hc.cmd" "$T/"
cp /tmp/e5/setdef/setdefault.exe /tmp/e5/setdef/endpointmute.exe /tmp/e5/setdef/procinfo.exe /tmp/e5fix/setdef/ 2>/dev/null || true
printf '@echo off\r\ncd /d %%~d0\\\r\nreg query "HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\MMDevices\\Audio\\Capture" /s > %%~d0\\cap.txt 2>&1\r\n' > "$T/cap.cmd"
printf '@echo off\r\ncd /d %%~d0\\\r\nsc query Nwifi > %%~d0\\svc-nwifi.txt 2>&1\r\n' > "$T/svc.cmd"
file "$T/cap.cmd" "$T/svc.cmd"; cat -A "$T/cap.cmd" | head -4

# the data disk with all the tools (start_vm makes one if missing; this one is inspected)
rm -f /tmp/e5fix/pouch/rows.img
bash "$T/make-pouch.sh" /tmp/e5fix/pouch/rows.img 2>&1 | tail -14

# a fresh first-boot overlay over the new VHD: 80 GiB as the VHD's footer says
rm -f "$QAD/disk/e5fix-firstboot.qcow2"
python3 "$T/mkqcow2.py" "$QAD/disk/e5fix-firstboot.qcow2" "$VHD" 85899345920
ls -la "$QAD/disk/e5fix-firstboot.qcow2"
cd "$QAD" && (git check-ignore -q disk/e5fix-firstboot.qcow2 && echo "disk/e5fix-firstboot.qcow2 is ignored by git" || echo "!! the overlay is NOT ignored")
git -C "$QAD" status --short | head -5
echo "== the exe on the pouch vs the build: $(sha256sum /tmp/e5fix/dsploop/dsploop_apitest.exe | cut -c1-16)"
echo "== image identity:"; cat "$IMG/PROVENANCE.txt" | head -12
