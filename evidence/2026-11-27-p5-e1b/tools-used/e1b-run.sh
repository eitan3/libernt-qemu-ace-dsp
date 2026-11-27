#!/bin/bash
# e1b-run.sh -- launch the P5 E1b VM micro round: the overlay over the p5e1b LiberNT.vhd, the
# round script under a cap, the evidence collected into the project's evidence tree.
#   env: RUN (default e1b-round), ROWS (the rows of (a)), CAP (the whole round's cap, s, 4500)
set -u
Q=<project>
IMG=<home>/libernt-build-logs/test-audio-intel-sst-p5e1b-7664a41eeb7
T=/tmp/e1b/tools
RUN="${RUN:-e1b-round}"
CAP="${CAP:-4500}"
OVERLAY=p5e1b-b
mkdir -p /tmp/e1b/ev
if pgrep -f "qemu-system-x86_64 -L $Q/build/pc-bios" > /dev/null; then echo "REFUSED: a QEMU of this project is running" >&2; exit 3; fi
cd "$Q" || exit 1
if [ ! -e disk/$OVERLAY.qcow2 ]; then
    VHD=<home>/libernt-build-logs/test-audio-intel-sst-p5e1b-d0bb1c7cec9/LiberNT.vhd bash make-overlay.sh $OVERLAY > /tmp/e1b/ev/overlay-made.txt 2>&1
    cat /tmp/e1b/ev/overlay-made.txt
fi
date -u +%FT%TZ > /tmp/e1b/ev/$RUN.start.txt 2>/dev/null || true
RUN="$RUN" OVERLAY="$OVERLAY" timeout "$CAP" bash "$T/e1b-round.sh" > /tmp/e1b/ev/$RUN.out 2>&1
rc=$?
echo "e1b-round.sh rc=$rc (124 = the cap)"
tail -8 /tmp/e1b/ev/$RUN.out
pgrep -f "qemu-system-x86_64 -L $Q/build/pc-bios" > /dev/null && { echo "a QEMU is still running: stopping it"; pkill -TERM -f "qemu-system-x86_64 -L $Q/build/pc-bios"; sleep 5; }
exit $rc
