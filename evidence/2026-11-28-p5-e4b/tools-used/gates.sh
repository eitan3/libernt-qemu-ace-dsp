#!/bin/bash
# e4b-gates.sh -- the E4b gates as E4's (gates/*.txt): no VM up, explicit ninja targets only (gate-commands.md).
#   drivers (0 warnings), kmtest 17/17, the apitest compile check, the audio host-test list 14/14 with the three
#   units' own counts, the simulator build and its qtest 18/18.  Outputs under /tmp/e4b/gates/.
set -u
R=<home>/Projects/LiberNT
O=$R/output-Clang-amd64-debug
S=/tmp/ht-e1a
T=<home>/libernt-build-logs/tools
Q=<project>
G=/tmp/e4b/gates
mkdir -p "$G" /tmp/e4b/kmtest
UP=$(pgrep -c qemu-system || true)
echo "== $(date +%FT%T%z) VMs up: ${UP:-0}"
[ "${UP:-0}" = 0 ] || { echo "!! a VM is up: the compiles are not run"; exit 2; }
cd "$R" && echo "branch $(git rev-parse --abbrev-ref HEAD) HEAD $(git rev-parse HEAD) dirty $(git status --porcelain | wc -l)"
echo "== drivers $(date +%T)"
cd "$O" && CCACHE_DISABLE=1 ninja intcdsp.sys hdaudbus.sys dsppcm.sys hdaudio.sys mmdevapi.dll dll/cpl/mmsys/mmsys.cpl > "$G/drivers.txt" 2>&1
echo "drivers rc=$? warnings: $(grep -c 'warning:' "$G/drivers.txt")"
echo "== kmtest $(date +%T)"
bash "$T/kmtest-compilecheck.sh" /tmp/e4b/kmtest > "$G/kmtest.txt" 2>&1
echo "kmtest rc=$? $(tail -1 "$G/kmtest.txt")"
echo "== apitest compile $(date +%T)"
if [ -f <home>/libernt-build-logs/apitest-compile.sh ]; then
    bash <home>/libernt-build-logs/apitest-compile.sh modules/rostests/apitests/dsploop/dsploop.c modules/rostests/apitests/dsploop/compare.c modules/rostests/apitests/dsploop/testlist.c modules/rostests/apitests/mmdevapi/micprivacy.c > "$G/apitest-compile.txt" 2>&1
    echo "apitest-compile rc=$? $(grep -c '^OK' "$G/apitest-compile.txt") OK, $(grep -c 'warning' "$G/apitest-compile.txt") warning lines"
else
    echo "apitest-compile.sh not found (the run book's path): not run"
fi
echo "== host list $(date +%T)"
cd "$S" && ninja apitest/apitest audiofmt/audiofmt dspidentity/dspidentity dsploop/dsploop dspparsers/disco dspparsers/sofipc4 dspparsers/softplg dsppath/dsppath dsppcm/dsppcm fwload/fwload hdaudio/hdaudio ipc/sofipc mmdevapi/mmdevapi pcmsample/pcmsample > "$G/host-build.txt" 2>&1
echo "host build rc=$? warnings: $(grep -c 'warning:' "$G/host-build.txt")"
ctest --output-on-failure > "$G/host-audio-list.txt" 2>&1
echo "ctest rc=$? $(grep -a 'tests passed' "$G/host-audio-list.txt")"
./ipc/sofipc > "$G/sofipc.txt" 2>&1; echo "sofipc: $(tail -1 "$G/sofipc.txt")"
./dsppcm/dsppcm > "$G/dsppcm.txt" 2>&1; echo "dsppcm: $(tail -1 "$G/dsppcm.txt")"
./dsploop/dsploop > "$G/dsploop.txt" 2>&1; echo "dsploop: $(tail -1 "$G/dsploop.txt")"
./mmdevapi/mmdevapi > "$G/mmdevapi.txt" 2>&1; echo "mmdevapi: $(tail -1 "$G/mmdevapi.txt")"
echo "== simulator $(date +%T)"
cd "$Q" && bash build.sh > "$G/simulator-build.txt" 2>&1
echo "simulator build rc=$? $(tail -1 "$G/simulator-build.txt")"
( cd "$Q/build" && QTEST_QEMU_BINARY=./qemu-system-x86_64 timeout 400 ./tests/qtest/intel-hda-ace-test > "$G/qtest.tap" 2>&1 )
echo "qtest rc=$? ok $(grep -c '^ok' "$G/qtest.tap") not ok $(grep -c '^not ok' "$G/qtest.tap") plan $(grep '^1\.\.' "$G/qtest.tap")"
echo "== end $(date +%T)"
