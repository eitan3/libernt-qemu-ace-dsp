#!/bin/bash
# E5c: the VM round of the volume-level row (tools/round.sh) under ICOUNT=1, one at a time; its output to /tmp/e5c/round.out.
# No compile may run while this job runs.
set -u
pgrep -c qemu >/dev/null 2>&1 && { echo "!! a QEMU is already running: this round does not start"; exit 3; }
date '+start %T'
RUN=level bash /tmp/e5c/tools/round.sh > /tmp/e5c/round.out 2>&1
rc=$?
echo "round.sh rc=$rc"
date '+end %T'
tail -5 /tmp/e5c/round.out | cut -c1-300
