#!/bin/bash
# E5: the 20 fault rows (/tmp/e5-20-faults.sh) now, then the evidence collected and normalised (/tmp/e5-30-collect.sh).
set -u
ps -eo comm | grep -qi "qemu-system" && { echo "!! a QEMU is running"; exit 3; }
date '+fault rows start %T'
bash /tmp/e5-20-faults.sh
date '+fault rows end %T'
sleep 2
ps -eo comm | grep -qi qemu-system && { echo "!! a QEMU is still running: not collected"; exit 3; }
bash /tmp/e5-30-collect.sh | tail -8
