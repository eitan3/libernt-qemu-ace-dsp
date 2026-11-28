#!/bin/bash
# e2-run.sh -- launch the P5 E2 VM round: the overlay over the p5e2 LiberNT.vhd, the round script under a
# cap, nothing collected here (collect-e2.sh after).
#   env: RUN (default e2-round), CAP (the whole round's cap, s, 3300)
# One QEMU at a time: refused while any QEMU of this project's build is up (another agent's VM included; it is
# never touched).  The VM this script started is the only one it may stop at its end: it is told by its own
# overlay's name.
set -u
Q=<project>
IMG=<home>/libernt-build-logs/test-audio-intel-sst-p5e2-b32d338494d
T=/tmp/e2/tools
RUN="${RUN:-e2b-round}"
CAP="${CAP:-3300}"
OVERLAY=p5e2
mkdir -p /tmp/e2/ev
if pgrep -f "qemu-system-x86_64 -L $Q/build/pc-bios" > /dev/null; then echo "REFUSED: a QEMU of this project is running" >&2; exit 3; fi
cd "$Q" || exit 1
if [ ! -e disk/$OVERLAY.qcow2 ]; then
    VHD="$IMG/LiberNT.vhd" bash make-overlay.sh $OVERLAY > /tmp/e2/ev/overlay-made.txt 2>&1
    cat /tmp/e2/ev/overlay-made.txt
fi
date -u +%FT%TZ > /tmp/e2/ev/$RUN.start.txt 2>/dev/null || true
RUN="$RUN" OVERLAY="$OVERLAY" timeout "$CAP" bash "$T/e2b-round.sh" > /tmp/e2/ev/$RUN.out 2>&1
rc=$?
echo "e2b-round.sh rc=$rc (124 = the cap)"
tail -8 /tmp/e2/ev/$RUN.out | cut -c1-300
pgrep -f "qemu-system-x86_64.*disk/$OVERLAY.qcow2" > /dev/null && { echo "this round's QEMU is still running: stopping it"; pkill -TERM -f "qemu-system-x86_64.*disk/$OVERLAY.qcow2"; sleep 5; }
exit $rc
