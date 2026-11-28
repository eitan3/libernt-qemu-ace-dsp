#!/bin/bash
# E5-fixes: the evidence of the round under the simulator's evidence/2026-11-28-p5-e5fix, then normalised (no local
# paths).   e5fix-collect.sh   after the row VM ended
set -u
Q=<project>
E=$Q/evidence/2026-11-28-p5-e5fix
IMG=<home>/libernt-build-logs/test-audio-p5final-486b024c9b1
if ps -eo comm | grep -qi "qemu-system"; then echo "!! a QEMU is running: the evidence of a round is collected after it ended"; exit 3; fi
mkdir -p "$E/vm/rows" "$E/host" "$E/tools-used"
# the row VM (the four rows in one boot)
for f in serial.log driver.log lib-run.out setdef.txt cap.txt svc-nwifi.txt dl-base.txt dl-muted.txt dl-crash.txt dl-a-crash-async.txt mute-1.txt mute-0.txt; do
    [ -f "/tmp/e5fix/ev/rows/$f" ] && cp "/tmp/e5fix/ev/rows/$f" "$E/vm/rows/"
done
cp /tmp/e5fix/ev/rows/*.png "$E/vm/rows/" 2>/dev/null
cp /tmp/e5fix/ev/rows/setfault-*.out "$E/vm/rows/" 2>/dev/null
cp /tmp/e5fix/rows.out "$E/vm/rows/rows.out" 2>/dev/null
# the host gates of phase 1
cp /tmp/e5fix/mmdevapi-dll-build.log "$E/host/mmdevapi-dll-build.txt" 2>/dev/null
cp /tmp/e5fix/dsploop/build.log "$E/host/build-dsploop.txt" 2>/dev/null
cp /tmp/e5fix/cppcheck-host.txt "$E/host/cppcheck-host.txt" 2>/dev/null
cp /tmp/e5fix/cppcheck-wdmaud.txt "$E/host/cppcheck-wdmaud.txt" 2>/dev/null
cp /tmp/e5fix-host-build.log "$E/host/mmdevapi-host-build.txt" 2>/dev/null
cp /tmp/e5fix-host-mutation.log "$E/host/mmdevapi-host-build-mutation-m54.txt" 2>/dev/null
cp /tmp/e5fix/host-mmdevapi-mutation-m54.txt "$E/host/mmdevapi-host-test-mutation-m54.txt" 2>/dev/null
(cd /tmp/e5fix/dsploop && sha256sum dsploop_apitest.exe; cd /tmp/e5fix/setdef && sha256sum setdefault.exe endpointmute.exe procinfo.exe) > "$E/host/SHA256SUMS"
cp "$IMG/PROVENANCE.txt" "$E/host/image-provenance.txt" 2>/dev/null
cp "$IMG/README.txt" "$E/host/image-readme.txt" 2>/dev/null
cp "$IMG/source-state.txt" "$E/host/image-source-state.txt" 2>/dev/null
(cd "$IMG" && sha256sum LiberNT.iso LiberNT.vhd LiberNT.img) > "$E/host/image-SHA256SUMS"
# the tools as they ran
cd /tmp/e5fix/tools && cp vmcommon.sh make-pouch.sh mkqcow2.py e5fix-rows.sh setdef.cmd dl.cmd mute.cmd cap.cmd svc.cmd "$E/tools-used/"
cp /tmp/e5fix-prep.sh /tmp/e5fix-prep-check.sh /tmp/e5fix-dll.sh /tmp/e5fix-host-gate.sh /tmp/e5fix-mutation-run.sh /tmp/e5fix-cppcheck.sh /tmp/e5fix-cppcheck-classify.sh /tmp/e5fix-dsploop.sh /tmp/t2-scan.sh /tmp/t2-followup.sh /tmp/t2-followup2.sh /tmp/t2-followup3.sh /tmp/t2-hive-diag.sh /tmp/t2-hive-flags.sh /tmp/t2-hive-facts.sh /tmp/t2-provenance.sh /tmp/t2-wifi-where.sh /tmp/t2-hive-utf16.sh /tmp/t2-wifi1.sh "$E/tools-used/" 2>/dev/null
cp /tmp/e5fix/tools/e5fix-collect.sh /tmp/e5fix/tools/verify.sh /tmp/e5fix/tools/scrub-dmi.sh "$E/tools-used/"
cp /tmp/build-dsploop.py "$E/tools-used/build-dsploop.py" 2>/dev/null
cd "$Q" && bash normalise-evidence.sh | tail -3
echo "files: $(find "$E" -type f | wc -l), $(du -sh "$E" | cut -f1)"
find "$E" -maxdepth 2 | sort | head -60
