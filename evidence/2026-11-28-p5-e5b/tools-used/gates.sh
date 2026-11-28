#!/bin/bash
# e5b-gates.sh -- the E5b gates as E4b's (gates/*.txt): no VM up, explicit ninja targets only.
#   drivers (0 warnings), the audio host-test list with the units' own counts, the apitest.  Outputs under /tmp/e5b/gates/.
set -u
R=<home>/Projects/LiberNT
O=$R/output-Clang-amd64-debug
S=/tmp/ht-e1a
G=/tmp/e5b/gates
mkdir -p "$G"
UP=$(ps -eo comm | grep -c qemu-system || true)
echo "== $(date +%FT%T%z) VMs up: ${UP:-0}"
[ "${UP:-0}" = 0 ] || { echo "!! a VM is up: the compiles are not run"; exit 2; }
cd "$R" && echo "branch $(git rev-parse --abbrev-ref HEAD) HEAD $(git rev-parse HEAD) dirty $(git status --porcelain | wc -l)"
echo "== drivers $(date +%T)"
cd "$O" && CCCACHE_DISABLE=1 ninja mmdevapi.dll intcdsp.sys hdaudbus.sys dsppcm.sys hdaudio.sys > "$G/drivers.txt" 2>&1
echo "drivers rc=$? warnings: $(grep -c 'warning:' "$G/drivers.txt")"
echo "== host list $(date +%T)"
cd "$S" && ninja mmdevapi/mmdevapi dsploop/dsploop dsppcm/dsppcm > "$G/host-build.txt" 2>&1
echo "host build rc=$? warnings: $(grep -c 'warning:' "$G/host-build.txt")"
ctest --test-dir "$S" --output-on-failure -R 'mmdevapi|dsploop|dsppcm' > "$G/host-ctest.txt" 2>&1
echo "ctest rc=$? $(grep -a 'tests passed' "$G/host-ctest.txt")"
./mmdevapi/mmdevapi > "$G/mmdevapi.txt" 2>&1; echo "mmdevapi: $(tail -1 "$G/mmdevapi.txt")"
./dsploop/dsploop > "$G/dsploop.txt" 2>&1; echo "dsploop: $(tail -1 "$G/dsploop.txt")"
./dsppcm/dsppcm > "$G/dsppcm.txt" 2>&1; echo "dsppcm: $(tail -1 "$G/dsppcm.txt")"
echo "== end $(date +%T)"
