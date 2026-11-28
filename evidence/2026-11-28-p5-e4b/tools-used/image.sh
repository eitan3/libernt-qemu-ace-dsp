#!/bin/bash
# e4b-image.sh -- the image p5e4b as E4 built p5e4 (N14-03: rebuild_cache, buildstamp, the three images), then
# staged under libernt-build-logs/test-audio-intel-sst-p5e4b-<tip>/ with the gates, the apitest, SHA256SUMS and the
# identity check (bsdtar -x of the ISO against the build tree).  No VM up; explicit ninja targets only.
set -u
R=<home>/Projects/LiberNT
O=$R/output-Clang-amd64-debug
G=/tmp/e4b/gates
T=<home>/libernt-build-logs/tools
UP=$(pgrep -c qemu-system || true)
[ "${UP:-0}" = 0 ] || { echo "!! a VM is up: not built"; exit 2; }
cd "$R" || exit 1
TIP=$(git rev-parse --short=11 HEAD)
D=<home>/libernt-build-logs/test-audio-intel-sst-p5e4b-$TIP
mkdir -p "$D/gates" /tmp/e4b/iso
{
    echo "branch $(git rev-parse --abbrev-ref HEAD) HEAD $(git rev-parse HEAD)"
    echo "dirty $(git status --porcelain | wc -l)"
    echo "== start $(date '+%F %T %z')"
    echo "== rebuild_cache"
    cd "$O" && ninja rebuild_cache > /tmp/e4b/rebuild-cache.txt 2>&1; RC=$?
    grep -E "Re-checking|Running CMake|ninja:" /tmp/e4b/rebuild-cache.txt | head -3; echo "rebuild_cache rc=$RC"
    [ $RC -eq 0 ] || exit 3
    echo "== buildstamp"
    ninja buildstamp > /tmp/e4b/buildstamp.txt 2>&1; RC=$?
    tail -1 /tmp/e4b/buildstamp.txt; echo "buildstamp rc=$RC"
    [ $RC -eq 0 ] || exit 3
    echo "== images"
    CCACHE_DISABLE=1 ninja liberntiso liberntvhd liberntimg > /tmp/e4b/images.txt 2>&1; RC=$?
    grep -E "Linking C shared module drivers/wdm/audio|Linking CXX shared module drivers/wdm/audio|warning:|error:|FAILED|ninja:" /tmp/e4b/images.txt | tail -12
    echo "steps $(grep -c -E '^\[[0-9]+/[0-9]+\]' /tmp/e4b/images.txt), warnings $(grep -c 'warning:' /tmp/e4b/images.txt); images rc=$RC"
    echo "== end $(date +%T)"
    echo "exit $RC"
    [ $RC -eq 0 ] || exit 3
} > "$G/images-build.txt" 2>&1
cat "$G/images-build.txt"
[ "$(tail -1 "$G/images-build.txt")" = "exit 0" ] || exit 3
# the apitest beside the image, built at the tip (the record of its own)
cd /tmp && python3 "$T/build-dsploop.py" /tmp/e4b/dsploop/dsploop_apitest.exe > "$G/build-dsploop.txt" 2>&1
echo "build-dsploop rc=$? $(sha256sum /tmp/e4b/dsploop/dsploop_apitest.exe | cut -c1-16)"
# staged
cp -f "$O/LiberNT.iso" "$O/LiberNT.vhd" "$O/LiberNT.img" "$D/"
cp -f /tmp/e4b/dsploop/dsploop_apitest.exe "$D/"
cp -f "$G"/*.txt "$G"/qtest.tap "$D/gates/"
cp -f /tmp/e4b/mut/mut-m36.txt /tmp/e4b/mut/mut-m37.txt /tmp/e4b/mut/mut-m38.txt /tmp/e4b/mut/mut-m39.txt "$D/gates/"
rm -f "$D/gates/images-build.txt"; cp -f "$G/images-build.txt" "$D/gates/"
( cd "$D" && sha256sum LiberNT.iso LiberNT.vhd LiberNT.img dsploop_apitest.exe > SHA256SUMS && cat SHA256SUMS )
# the identity: ntoskrnl.exe's string, the in-ISO binaries against the build tree's
cd /tmp/e4b/iso && rm -rf Windows && bsdtar -x -f "$D/LiberNT.iso" Windows/system32/ntoskrnl.exe Windows/system32/drivers/intcdsp.sys Windows/system32/drivers/dsppcm.sys Windows/system32/drivers/hdaudbus.sys Windows/system32/drivers/hdaudio.sys Windows/system32/mmdevapi.dll Windows/system32/mmsys.cpl 2>&1 | head -3
{
    echo "ntoskrnl.exe identity string (unique):"
    strings -e l Windows/system32/ntoskrnl.exe | grep -a -m1 '\.libernt'
    echo "the version resources (UTF-16) of the drivers:"
    for f in intcdsp dsppcm hdaudbus hdaudio; do printf '  %s: ' "$f"; ( strings -e l Windows/system32/drivers/$f.sys | grep -a -m1 'libernt' || echo "(no string)" ); done
    echo
    echo "--- in-ISO vs the build tree"
    n=0; ok=0
    for pair in "Windows/system32/drivers/intcdsp.sys:$O/drivers/wdm/audio/intcdsp/intcdsp.sys" \
                "Windows/system32/drivers/dsppcm.sys:$O/drivers/wdm/audio/drivers/dsppcm/dsppcm.sys" \
                "Windows/system32/drivers/hdaudbus.sys:$O/drivers/wdm/audio/hdaudbus/hdaudbus.sys" \
                "Windows/system32/drivers/hdaudio.sys:$O/drivers/wdm/audio/drivers/hdaudio/hdaudio.sys" \
                "Windows/system32/mmdevapi.dll:$O/dll/win32/mmdevapi/mmdevapi.dll" \
                "Windows/system32/mmsys.cpl:$O/dll/cpl/mmsys/mmsys.cpl"; do
        a=${pair%%:*}; b=${pair##*:}; n=$((n+1))
        if cmp -s "$a" "$b"; then ok=$((ok+1)); echo "$a: identical to the build tree ($(stat -c %s "$a") bytes)"; else echo "$a: DIFFERS from $b"; fi
    done
    echo "method: bsdtar -x of the ISO; $ok of $n identical; the count in the identity string is the branch's absolute commit count"
} > "$G/identity.txt" 2>&1
cat "$G/identity.txt"
cp -f "$G/identity.txt" "$D/gates/"
cd "$R" && { echo "branch $(git rev-parse --abbrev-ref HEAD) HEAD $(git rev-parse HEAD)"; echo "over master: $(git rev-list --count master..HEAD) commits; master $(git rev-parse --short=11 master)"; echo "tracked modifications in the source tree at build time: tip $(git rev-parse --short=11 HEAD) dirty $(git status --porcelain | wc -l)"; echo "stashes: $(git stash list | wc -l) (untouched)"; } > "$D/gates/source-state.txt"
echo "staged: $D"
ls -la "$D" | awk '{print $5, $9}' | tail -n +2
