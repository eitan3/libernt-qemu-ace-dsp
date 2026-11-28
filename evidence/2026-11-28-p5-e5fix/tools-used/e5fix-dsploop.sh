#!/bin/bash
# E5-fixes dsploop gate: build-dsploop.py link rc, warnings, the binary's size and hash.
set -u
mkdir -p /tmp/e5fix/dsploop
L=/tmp/e5fix/dsploop/build.log
rm -f /tmp/e5fix/dsploop/dsploop_apitest.exe
python3 <home>/libernt-build-logs/tools/build-dsploop.py /tmp/e5fix/dsploop/dsploop_apitest.exe > "$L" 2>&1
rc=$?
echo "build-dsploop.py rc=$rc"
echo "warning lines: $(grep -c -i 'warning:' "$L")  error lines: $(grep -c -i 'error:' "$L")"
echo "--- tail"
tail -6 "$L"
echo "--- binary"
ls -la /tmp/e5fix/dsploop/dsploop_apitest.exe 2>/dev/null && sha256sum /tmp/e5fix/dsploop/dsploop_apitest.exe
