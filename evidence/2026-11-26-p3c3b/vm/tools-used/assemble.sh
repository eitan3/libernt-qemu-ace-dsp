#!/bin/bash
# assemble.sh -- the derived files of the p3c3b round's evidence, from the live directories
# under /tmp/qad-ev/p3c3b and the tools in /tmp/qad-ev/p3c3b/tools.
set -u
L=/tmp/qad-ev/p3c3b
T=$L/tools
Q=<project>
E=$Q/evidence/2026-11-26-p3c3b
V=$E/vm
RUNS="r1-firstboot-set-live r2-plainboot-live-then-selftest0 r3-plainboot-selftest0-then-live r4-plainboot-regression-and-live"

bash "$T/measured.sh"
python3 "$T/expectcheck.py" "$V/measured-lines.txt" > "$V/expected-vs-measured.txt"
cat "$V/expected-vs-measured.txt"

# the live reads as compact tables, and their pages against the sine
{
    echo "# The live reads of the round (livecap.py / salvage.py outputs, read through livesum.py and pageverify.py)."
    echo "# ioc: the descriptor's fourth word, bit 0 (the upper dword's bit 31 was 0 in every descriptor)."
    for r in $RUNS; do
        for f in salvage-paused16 livecap-resume livecap; do
            [ -f "$L/$r/$f.out" ] || continue
            python3 "$T/livesum.py" "$L/$r/$f.out" | grep -v "^      0x[0-9a-f]*: frames\|window again"
        done
    done
} > "$V/live-reads.txt"
python3 "$T/pageverify.py" "$L/r3-plainboot-selftest0-then-live/salvage-paused16.out" \
    "$L/r3-plainboot-selftest0-then-live/livecap-resume.out" "$L/r4-plainboot-regression-and-live/livecap.out" \
    > "$V/live-reads-pages.txt"

# the rms of the driver's own sine, the driver's own arithmetic, and the trace of every VM
{
    echo "# The rms of the driver's sine (IntcDspSineQ31 at 1619498f85e) and of every ace_audio line of the round."
    echo
    echo "## rms-check.py: the sine's exact rms over a period's frames and over the whole buffer"
    python3 "$T/rms-check.py"
    echo
    echo "## driver-rms.py: the driver's own sum (each square divided by the count per sample) through IntcDspRms"
    python3 "$T/driver-rms.py"
    for r in $RUNS; do
        echo
        echo "## $r: ace-audio-check.py"
        python3 "$T/ace-audio-check.py" "$L/$r/qemu-dbg.log" "$L/$r/serial.log"
    done
} > "$V/rms-and-trace.txt"
tail -1 "$V/rms-and-trace.txt"

mkdir -p "$V/tools-used"
cp -f "$T"/*.py "$T"/*.sh "$V/tools-used/"
rm -rf "$V/tools-used/__pycache__"
ls "$V" "$V/tools-used"
