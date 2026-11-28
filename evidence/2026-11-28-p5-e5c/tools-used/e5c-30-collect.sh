#!/bin/bash
# E5c: the evidence of the round under the simulator's evidence/2026-11-28-p5-e5c, then normalised (no local paths).
#   e5c-30-collect.sh <round>   the round (level3) whose VM files are the row
set -u
Q=<project>
E=$Q/evidence/2026-11-28-p5-e5c
R="${1:-level3}"
[ "$(pgrep -c qemu || true)" = 0 ] || { echo "!! a QEMU is running: the evidence of a round is collected after it ended"; exit 3; }
mkdir -p "$E/vm/$R" "$E/vm/level-cmd-script" "$E/host" "$E/tools-used"
# the row
for f in serial.log driver.log lib-run.out setdef.txt; do [ -f "/tmp/e5c/ev/$R/$f" ] && cp "/tmp/e5c/ev/$R/$f" "$E/vm/$R/"; done
cp /tmp/e5c/ev/$R/dl-*.txt "$E/vm/$R/" 2>/dev/null
cp /tmp/e5c/ev/$R/*.png "$E/vm/$R/" 2>/dev/null
cp "/tmp/e5c/round3.out" "$E/vm/$R/round.out" 2>/dev/null
# the first attempt (the batch script the guest's cmd could not expand): what it wrote
cp /tmp/e5c/ev/level/setdef.txt "$E/vm/level-cmd-script/setdef.txt" 2>/dev/null
cp /tmp/e5c/ev/level/driver.log "$E/vm/level-cmd-script/driver.log" 2>/dev/null
cp /tmp/e5c/round.out "$E/vm/level-cmd-script/round.out" 2>/dev/null
# host
cp /tmp/e5c/mmdevapi.txt /tmp/e5c/mutations.txt /tmp/e5c/mut-m4?.txt /tmp/e5c/mut-m5?.txt \
   /tmp/e5c/host-build.txt /tmp/e5c/mmdevapi-build.txt /tmp/e5c/mmdevapi-build-final.txt \
   /tmp/e5c/drivers-build.txt /tmp/e5c/drivers-build-final.txt \
   /tmp/e5c/cppcheck-backend.txt /tmp/e5c/cppcheck-host.txt \
   /tmp/e5c/build-dsploop.txt /tmp/e5c/build-setdefault.txt "$E/host/"
cp /tmp/e5c/hdaudio-build.txt /tmp/e5c/cppcheck-prophnd.txt "$E/host/" 2>/dev/null
(cd /tmp/e5c/dsploop && sha256sum dsploop_apitest.exe) > "$E/host/SHA256SUMS"
(cd /tmp/e5c/setdef && sha256sum setdefault.exe) >> "$E/host/SHA256SUMS"
# tools as they ran
cd /tmp/e5c/tools && cp vmcommon.sh make-pouch.sh mkqcow2.py round.sh dl.cmd setdef.cmd build-setdefault.py "$E/tools-used/"
cp /tmp/e5c/setdef-src/setdefault.c "$E/tools-used/"
cp /tmp/e5c/e5c-1[0-5]*.sh /tmp/e5c/e5c-2[0-3]*.sh /tmp/e5c/e5c-30-collect.sh "$E/tools-used/"
# the first attempt's batch script, as it was written (replaced on the tools directory by the second attempt)
cat > "$E/tools-used/setdef-cmd-first-attempt.cmd" <<'EOF'
@echo off
setlocal
set GUID=
for /f "delims=" %%k in ('reg query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render') do (
  echo %%k | findstr /c:"{" | findstr /c:"}" >nul && reg query "%%k\Properties" /v "{a45c254e-df1c-4efd-8020-67d146a850e0},14" 2>nul | findstr /i "Loopback" >nul && set GUID=%%~nk
)
set GUID=%GUID:~0,38%
echo GUID=%GUID% > %~d0\setdef.txt
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render\%GUID%\Properties" >> %~d0\setdef.txt 2>&1
reg add HKCU\Software\Wine\Drivers\wdmaud.drv /v DefaultOutput /t REG_SZ /d "{0.0.0.00000000}.%GUID%" /f >> %~d0\setdef.txt 2>&1
reg query HKCU\Software\Wine\Drivers\wdmaud.drv /v DefaultOutput >> %~d0\setdef.txt 2>&1
EOF
(cd "$Q" && bash normalise-evidence.sh | tail -3)
echo "files: $(find "$E" -type f | wc -l), $(du -sh "$E" | cut -f1)"
find "$E" -maxdepth 2 | sort | head -40
