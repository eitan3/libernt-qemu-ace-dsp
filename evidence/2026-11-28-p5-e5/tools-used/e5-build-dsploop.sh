#!/bin/bash
# E5: build-dsploop -- the tree's dsploop_apitest target (a named target) on the final tip, pefixup, into /tmp/e5/dsploop.
# No VM may run while this builds.
set -u
O=<home>/Projects/LiberNT/output-Clang-amd64-debug
L=/tmp/e5
mkdir -p "$L/dsploop"
pgrep -x qemu-system-x86_64 >/dev/null 2>&1 && { echo "!! a QEMU is running: no build"; exit 3; }
date '+start %T'
cd "$O" && CCACHE_DISABLE=1 ninja dsploop_apitest > "$L/build-dsploop.txt" 2>&1
rc=$?
echo "ninja dsploop_apitest rc=$rc, warnings: $(grep -c -E 'warning:' "$L/build-dsploop.txt"), errors: $(grep -c -E 'error:' "$L/build-dsploop.txt"), steps: $(grep -c -E '^\[[0-9]+/[0-9]+\]' "$L/build-dsploop.txt")" | tee -a "$L/build-dsploop.txt"
grep -E 'warning:|error:' "$L/build-dsploop.txt" | head -10
E="$O/modules/rostests/apitests/dsploop/dsploop_apitest.exe"
ls -la "$E" | cut -c1-120
if [ $rc -eq 0 ]; then
    "$O/host-tools/bin/pefixup" --checksum "$E" >> "$L/build-dsploop.txt" 2>&1; echo "pefixup rc=$?" | tee -a "$L/build-dsploop.txt"
    cp "$E" "$L/dsploop/dsploop_apitest.exe"
    sha256sum "$L/dsploop/dsploop_apitest.exe" | tee -a "$L/build-dsploop.txt"
    cd <home>/Projects/LiberNT && git rev-parse --short=11 HEAD | tee -a "$L/build-dsploop.txt"
fi
date '+end %T'
