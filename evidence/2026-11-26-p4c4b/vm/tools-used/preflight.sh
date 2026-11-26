#!/bin/bash
# preflight.sh -- the checks before the first VM run of the p4c4b round:
#   image-check.txt   the three images and the apitest against SHA256SUMS, the sizes,
#                     the format strings of the drivers under test (grep -a of the
#                     copies extracted from the ISO)
#   in-iso.txt        the in-ISO files hashed from an independent extraction (bsdtar)
#                     against the staging directory's gates/in-iso.txt
#   vm/qtest-before-vm.txt   the model's qtest, run before the first VM run
set -u
QAD=<project>
IMG=$HOME/libernt-build-logs/test-audio-intel-sst-p4c4b-a81cf9e65cf
EV=$QAD/evidence/2026-11-26-p4c4b
X=/tmp/qad-ev/p4c4b/iso
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
} > "$EV/image-check.txt"

FILES="Windows/system32/drivers/intcdsp.sys
Windows/system32/drivers/hdaudbus.sys
Windows/system32/drivers/dsppcm.sys
Windows/system32/drivers/hdaudio.sys
Windows/inf/dsppcm.inf
Windows/inf/intcdsp.inf
Windows/inf/hdaudbus.inf
Windows/system32/drivers/intel/sof/sof-arl-s.ri
Windows/system32/drivers/intel/sof/sof-mtl.ri
Windows/system32/drivers/intel/sof/LICENCE.Intel
Windows/system32/drivers/intel/sof-tplg/sof-ipc4-loopback.tplg
Windows/system32/drivers/intel/sof-tplg/LICENCE.Intel
Windows/system32/drivers/intel/sof-tplg/NOTICE
Windows/system32/ntoskrnl.exe
Windows/system32/cmd.exe
Windows/system32/certutil.exe
Windows/system32/pnputil.exe"

{
    echo "# in-ISO hashes, independent extraction (bsdtar -x -f LiberNT.iso -C /tmp/..., the named members only) $(date -u +%FT%TZ)"
    echo "# expected: gates/in-iso.txt of the staging directory (image-check.txt)"
    for f in $FILES; do
        if bsdtar -x -f LiberNT.iso -C "$X" "$f" 2>/dev/null; then
            h=$(sha256sum "$X/$f" | cut -d" " -f1)
            s=$(stat -c %s "$X/$f")
            e=$(grep -a " $f (" gates/in-iso.txt | head -1 | cut -d" " -f1)
            if [ -z "$e" ]; then v="(not in gates/in-iso.txt)"
            elif [ "$h" = "$e" ]; then v="equal"
            else v="DIFFERENT from $e"; fi
            printf '%s  %9d  %s  %s\n' "$h" "$s" "$f" "$v"
        else
            echo "(not in the ISO: $f)"
        fi
    done
    echo
    echo "## the format strings of this checkpoint in the copies extracted from the ISO (grep -a)"
    for s in "the DSP is booted at the next D0 entry with" "topology: none selected" "topology: modules" "audio child" "loopback self-test: %u runs" "stream %u: latency: fifo" "pin created" "registered as" "3 formats in 2 data ranges" "GetClockRegister" "clock" ; do
        for d in intcdsp.sys dsppcm.sys; do
            if grep -aqF "$s" "$X/Windows/system32/drivers/$d"; then r=present; else r=absent; fi
            printf '  %-8s %-8s %s\n' "$r" "$d" "$s"
        done
    done
    echo "## the lines around 'latency' and 'pin created' in dsppcm.sys and intcdsp.sys (strings -a, 6 wide)"
    for d in intcdsp.sys dsppcm.sys; do
        echo "--- $d"
        strings -a -n 6 "$X/Windows/system32/drivers/$d" | grep -aE "latency|pin created|stream %u|period|buffer" | cut -c1-200 | head -40
    done
    echo "## cmd.exe's version string"
    strings -a -n 8 "$X/Windows/system32/cmd.exe" | grep -aE "0\.4\.17|10\.0\.[0-9]+\.[0-9]+ " | head -3
} > "$EV/in-iso.txt"

echo "--- image-check.txt: $(grep -c . "$EV/image-check.txt") lines; $(grep -E ': (OK|FAILED)' "$EV/image-check.txt" | tr '\n' ' ')"
echo "--- in-iso.txt: $(grep -c ' equal$' "$EV/in-iso.txt") equal, $(grep -c 'DIFFERENT' "$EV/in-iso.txt") different, $(grep -c 'not in' "$EV/in-iso.txt") not found"
grep -E "DIFFERENT|not in" "$EV/in-iso.txt"

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
