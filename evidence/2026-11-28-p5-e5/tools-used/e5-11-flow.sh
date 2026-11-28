#!/bin/bash
# E5: after the 22-cycle run ends, the host gate (the mmdevapi host test on the final tip, built and run in the E1a
# scratch: no QEMU runs then), then the row VM (tools/e5-flow.sh) under ICOUNT=1.  No compile may run while it runs.
set -u
for i in $(seq 1 480); do grep -q "ac3-cycles.sh rc=" /tmp/e5/cycles.out 2>/dev/null && break; sleep 5; done
grep -q "ac3-cycles.sh rc=" /tmp/e5/cycles.out 2>/dev/null || { echo "!! the cycles' launcher did not end in 40 min"; exit 3; }
sleep 5
ps -eo comm | grep -qi "qemu-system" && { echo "!! a QEMU is still running after the cycles"; exit 3; }
date '+host gate %T'
bash /tmp/e5-40-host.sh
date '+flow start %T'
RUN=flow OVERLAY=e5-flow bash /tmp/e5/tools/e5-flow.sh > /tmp/e5/flow.out 2>&1
rc=$?
echo "e5-flow.sh rc=$rc"
date '+flow end %T'
grep -a -E "##|!!|done|VM " /tmp/e5/flow.out | cut -c1-300 | tail -40
