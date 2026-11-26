#!/bin/bash
# preflight.sh -- the checks before the first VM run of the p4c4c round (the p4c4b2 round's
# preflight.sh with the image directory, the evidence directory, the extraction directory and
# the format of the staging record changed: gates/in-iso.txt of p4c4c is
# "EQUAL  <path> (<bytes>)  iso=<sha256>  build=<sha256>" or "EQUAL  <path>  iso=<sha256>",
# then "# unchanged payloads" lines "<sha256>  <path>"):
#   image-check.txt   the three images and the apitest against SHA256SUMS, the sizes, the
#                     staging record gates/in-iso.txt
#   in-iso.txt        the in-ISO files hashed from an independent extraction (bsdtar) against
#                     the staging directory's gates/in-iso.txt
#   vm/qtest-before-vm.txt   the model's qtest, run before the first VM run
set -u
QAD=<project>
IMG=$HOME/libernt-build-logs/test-audio-intel-sst-p4c4c-ec8ce887b1b
EV=$QAD/evidence/2026-11-26-p4c4c
X=/tmp/qad-ev/p4c4c/iso
mkdir -p "$EV/vm" "$X"
cd "$IMG" || exit 2

{
    echo "# image check $(date -u +%FT%TZ)"
    echo "## sha256sum -c SHA256SUMS (in the staging directory)"
    sha256sum -c SHA256SUMS; echo "rc=$?"
    echo "## sizes"
    ls -l LiberNT.iso LiberNT.vhd LiberNT.img dsploop_apitest.exe | awk '{print $5, $9}'
    echo "## the staging directory's PROVENANCE.txt (head)"
    sed -n 1,60p PROVENANCE.txt | cut -c1-200
    echo "## gates/in-iso.txt (the staging record)"
    cat gates/in-iso.txt
    echo "## gates/identity.txt"
    cat gates/identity.txt
    echo "## gates/source-state.txt"
    cat gates/source-state.txt
} > "$EV/image-check.txt"

# the files hashed from an independent extraction: the drivers and payloads under test, the
# user-mode binaries of the fix passes, and four tools of the guest (for the record)
FILES="Windows/system32/drivers/swenum.sys
Windows/system32/drivers/intcdsp.sys
Windows/system32/drivers/hdaudbus.sys
Windows/system32/drivers/dsppcm.sys
Windows/system32/drivers/hdaudio.sys
Windows/system32/drivers/wdmaud.sys
Windows/system32/mmdevapi.dll
Windows/system32/mmsys.cpl
Windows/explorer.exe
Windows/ImmersiveControlPanel/SystemSettings.exe
Windows/system32/stobject.dll
Windows/system32/ntoskrnl.exe
Windows/system32/drivers/intel/sof/sof-arl-s.ri
Windows/system32/drivers/intel/sof/sof-mtl.ri
Windows/system32/drivers/intel/sof-tplg/sof-ipc4-loopback.tplg
Windows/inf/dsppcm.inf
Windows/inf/intcdsp.inf
Windows/inf/hdaudbus.inf
Windows/system32/hal.dll
Windows/system32/cmd.exe
Windows/system32/certutil.exe
Windows/system32/pnputil.exe"

{
    echo "# in-ISO hashes, independent extraction (bsdtar -x -f LiberNT.iso -C /tmp/..., the named members only) $(date -u +%FT%TZ)"
    echo "# expected: gates/in-iso.txt of the staging directory (image-check.txt): its iso= value, or the payload line"
    for f in $FILES; do
        if bsdtar -x -f LiberNT.iso -C "$X" "$f" 2>/dev/null; then
            h=$(sha256sum "$X/$f" | cut -d" " -f1)
            s=$(stat -c %s "$X/$f")
            e=$(grep -aE "^(EQUAL|DIFFERENT) +$f( |$)" gates/in-iso.txt | head -1 | grep -oE "iso=[0-9a-f]{64}" | cut -d= -f2)
            [ -z "$e" ] && e=$(grep -aE "^[0-9a-f]{64} +$f\$" gates/in-iso.txt | head -1 | awk '{print $1}')
            es=$(grep -aE "^(EQUAL|DIFFERENT) +$f \(" gates/in-iso.txt | head -1 | grep -oE "\([0-9]+ bytes\)" | grep -oE "[0-9]+")
            if [ -z "$e" ]; then v="(no record in gates/in-iso.txt)"
            elif [ "$h" = "$e" ] && { [ -z "$es" ] || [ "$s" = "$es" ]; }; then v="equal (hash$( [ -n "$es" ] && echo " and size"))"
            elif [ "$h" = "$e" ]; then v="hash equal, size DIFFERENT from $es"
            else v="DIFFERENT from $e"; fi
            printf '%s  %9d  %s  %s\n' "$h" "$s" "$f" "$v"
        else
            echo "(not in the ISO: $f)"
        fi
    done
    echo
    echo "## the identity string of the ISO's ntoskrnl.exe (grep -a)"
    grep -aoE "20261126-[0-9a-f]{6}" "$X/Windows/system32/ntoskrnl.exe" | sort | uniq -c
    echo "## dsppcm.inf's FriendlyNames (the ISO's copy)"
    grep -aE "FriendlyName|LoopbackRenderName|LoopbackCaptureName" "$X/Windows/inf/dsppcm.inf" | tr -d '\r' | cut -c1-200
    echo "## the format strings of this checkpoint in the copies extracted from the ISO (grep -a)"
    for s in "the DSP is booted at the next D0 entry with" "topology: none selected" "topology: modules" "audio child" "loopback self-test: %u runs" "stream %u: latency: fifo" "pin created" "registered as" "mailbox" "released" "generation"; do
        for d in intcdsp.sys dsppcm.sys; do
            if grep -aqF "$s" "$X/Windows/system32/drivers/$d"; then r=present; else r=absent; fi
            printf '  %-8s %-12s %s\n' "$r" "$d" "$s"
        done
    done
    echo "## the lines around 'latency', 'pin created', 'released' in dsppcm.sys and intcdsp.sys (strings -a, 6 wide)"
    for d in intcdsp.sys dsppcm.sys; do
        echo "--- $d"
        strings -a -n 6 "$X/Windows/system32/drivers/$d" | grep -aE "latency|pin created|released|freed|generation|stale" | cut -c1-200 | head -40
    done
    echo "## swenum.sys of this image (upstream's fix): its size and the strings of its remove path's neighbours (for the record)"
    strings -a -n 6 "$X/Windows/system32/drivers/swenum.sys" | grep -aiE "detach|remove|delete" | cut -c1-200 | head -10
} > "$EV/in-iso.txt"

echo "--- image-check.txt: $(grep -c . "$EV/image-check.txt") lines; $(grep -E ': (OK|FAILED)' "$EV/image-check.txt" | tr '\n' ' ')"
echo "--- in-iso.txt: $(grep -c '  equal (hash' "$EV/in-iso.txt") equal, $(grep -c 'DIFFERENT from' "$EV/in-iso.txt") different, $(grep -c 'no record in' "$EV/in-iso.txt") without a record, $(grep -c 'not in the ISO' "$EV/in-iso.txt") not found"
grep -E "DIFFERENT|not in the ISO|no record" "$EV/in-iso.txt"

# the model's qtest, before the first VM run
cd "$QAD/build" || exit 2
QTEST_QEMU_BINARY=./qemu-system-x86_64 timeout 400 ./tests/qtest/intel-hda-ace-test > "$EV/vm/qtest-before-vm.txt" 2>&1
rc=$?
{
    echo "# qtest before the first VM run: $(date -u +%FT%TZ), rc=$rc, QTEST_QEMU_BINARY=./qemu-system-x86_64 (build/)"
    echo "# qemu-system-x86_64 sha256 $(sha256sum ./qemu-system-x86_64 | cut -d' ' -f1); intel-hda-ace-test sha256 $(sha256sum ./tests/qtest/intel-hda-ace-test | cut -d' ' -f1)"
    echo "# ok: $(grep -c '^ok ' "$EV/vm/qtest-before-vm.txt"), not ok: $(grep -c '^not ok' "$EV/vm/qtest-before-vm.txt")"
} > "$EV/vm/qtest-before-vm.head.txt"
cat "$EV/vm/qtest-before-vm.head.txt"
tail -3 "$EV/vm/qtest-before-vm.txt" | cut -c1-200
exit 0
