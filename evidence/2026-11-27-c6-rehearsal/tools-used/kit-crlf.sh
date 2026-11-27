#!/bin/bash
# kit-crlf.sh -- CRLF line endings for the kit's .cmd files (cmd.exe reads them) and KIT-SHA256SUMS
set -euo pipefail
K=<home>/Projects/LiberNT-IntelDSP-plan/refs/c6/kit
cd "$K"
for f in *.cmd; do sed -i 's/\r$//; s/$/\r/' "$f"; done
rm -f KIT-SHA256SUMS
sha256sum savelog.cmd stage1.cmd stage2.cmd stage3.cmd restart.cmd shutdown.cmd run-dsploop.cmd dsploop_apitest.exe > KIT-SHA256SUMS
cat KIT-SHA256SUMS
echo "--- line endings (file):"
file *.cmd | sed 's/, with very long lines ([0-9]*)//'
