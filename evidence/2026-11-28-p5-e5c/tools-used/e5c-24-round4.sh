#!/bin/bash
# E5c prep 4 (no VM): endpointmute.exe built as the helper is; the data disk of round 3 copied and the
# tool with its .cmd added; then the mute row on the installed overlay of round 3 under ICOUNT=1.
set -eu
T=/tmp/e5c/tools
QAD=<project>
L=/tmp/e5c
[ "$(pgrep -c qemu || true)" = 0 ] || { echo "!! a QEMU is running: not started"; exit 3; }
sed -e 's|SOURCES = \["setdefault.c"\]|SOURCES = ["endpointmute.c"]|' \
    -e 's|OBJDIR = "/tmp/e5c/setdef-obj"|OBJDIR = "/tmp/e5c/mute-obj"|' \
    -e 's|TARGET = sys.argv\[1\] if len(sys.argv) > 1 else "/tmp/e5c/setdef/setdefault.exe"|TARGET = sys.argv[1] if len(sys.argv) > 1 else "/tmp/e5c/setdef/endpointmute.exe"|' \
    "$T/build-setdefault.py" > "$T/build-endpointmute.py"
grep -n -E 'SOURCES|OBJDIR|TARGET' "$T/build-endpointmute.py" | head -4
python3 "$T/build-endpointmute.py" "$L/setdef/endpointmute.exe" > "$L/build-endpointmute.txt" 2>&1
echo "build rc=$? $(grep -E '^OK|^FAIL|rc=' "$L/build-endpointmute.txt" | tr '\n' ' ')"
grep -E 'error:|warning:' "$L/build-endpointmute.txt" | head -8
sha256sum "$L/setdef/endpointmute.exe" | cut -c1-16
printf '@echo off\r\ncd /d %%~d0\\\r\nendpointmute.exe %%1 > %%~d0\\mute-%%1.txt 2>&1\r\n' > "$T/mute.cmd"
cp "$L/pouch/level3.img" "$L/pouch/mute.img"
mcopy -i "$L/pouch/mute.img@@32256" "$L/setdef/endpointmute.exe" ::/
mcopy -i "$L/pouch/mute.img@@32256" "$T/mute.cmd" ::/
mdir -i "$L/pouch/mute.img@@32256" ::/ | grep -E 'exe|cmd|tag'
date '+start %T'
RUN=mute OVERLAY=e5c-firstboot3 bash "$T/roundmute.sh" > "$L/round4.out" 2>&1
echo "roundmute.sh rc=$?"
date '+end %T'
