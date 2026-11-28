#!/bin/bash
# Mutation run of the host gate: build + ctest, then the binary's own summary line.
set -u
bash /tmp/e5fix-host-gate.sh /tmp/e5fix-host-mutation.log
echo ---BINARY---
/tmp/ht-e1a/mmdevapi/mmdevapi
echo "binary rc=$?"
