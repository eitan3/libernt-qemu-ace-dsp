#!/bin/bash
# E5: after the E1/E2 rows' VM ends (its driver.log's last line), the 20 fault rows (/tmp/e5-20-faults.sh), then the
# evidence collected and normalised (/tmp/e5-30-collect.sh).  One VM at a time.
set -u
for i in $(seq 1 300); do grep -q "e2-round done" /tmp/e5/ev/e2/driver.log 2>/dev/null && ! ps -eo comm | grep -qi qemu-system && break; sleep 10; done
grep -q "e2-round done" /tmp/e5/ev/e2/driver.log 2>/dev/null || { echo "!! the E1/E2 VM did not end in 50 min"; exit 3; }
sleep 3
date '+fault rows start %T'
bash /tmp/e5-20-faults.sh
date '+fault rows end %T'
ps -eo comm | grep -qi qemu-system && { echo "!! a QEMU is still running: not collected"; exit 3; }
bash /tmp/e5-30-collect.sh | tail -8
