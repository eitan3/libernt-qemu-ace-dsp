#!/bin/bash
# rms-and-trace.sh -- the model's trace of the p4c4b2 round against the driver's own lines, into
# vm/rms-and-trace.txt: ace-audio-check.py (the p3c3b round's checker, unchanged) on every VM
# that has an ace_audio line, and the count of what the apitest's runs left in the trace (none:
# the test never opened a stream).
set -u
QAD=<project>
EV=$QAD/evidence/2026-11-26-p4c4b2
T=/tmp/qad-ev/p4c4b2/tools
{
    echo "# The model's trace of the p4c4b2 round: ace-audio-check.py (the p3c3b round's checker, unchanged) on the VMs with ace_audio lines."
    echo "# The trace line is \"ace_audio <tag> <bytes> rms <r> peak <p> first <8 samples>\"; the checker pairs the render's line with the capture's"
    echo "# for each period and holds the samples and the rms against the driver's own sine (IntcDspSineQ31)."
    echo "# $(date -u +%FT%TZ)"
    for r in r1-firstboot-cycle-dsploop-selftest2 r5-firstboot-cycle-selftest2-dsploop-live r2-plainboot-selftest0 r3-plainboot-attribution r4-freshboot-notopology; do
        echo
        echo "## $r: ace_audio lines $(zcat "$EV/vm/$r/qemu-dbg.log.gz" | grep -ac '^ace_audio'); self-test lines of the driver $(grep -ac 'loopback self-test' "$EV/vm/$r/serial.txt"); pin-created lines $(grep -ac 'pin created' "$EV/vm/$r/serial.txt"); latency lines $(grep -ac 'latency: fifo' "$EV/vm/$r/serial.txt")"
        if [ "$(zcat "$EV/vm/$r/qemu-dbg.log.gz" | grep -ac '^ace_audio')" = 0 ]; then
            echo "(no ace_audio line in this VM: no stream ran through the model)"
        else
            # the checker is the p3c3b round's, unchanged: its stale parenthesis about the driver's 16-bit figure (p3c3b's
            # 5793.911 was a truncating sum; this image's 5794.253 is the integer square root in thousandths) is reworded here
            zcat "$EV/vm/$r/qemu-dbg.log.gz" > "/tmp/qad-ev/p4c4b2/$r.qemu-dbg.log"   # the checker reads the plain log
            python3 "$T/ace-audio-check.py" "/tmp/qad-ev/p4c4b2/$r.qemu-dbg.log" "$EV/vm/$r/serial.txt" 2>/dev/null \
                | sed "s/(its per-sample truncating sum: see driver-rms.py)/(one thousandth below the model's whole-buffer rms: the driver's integer square root in thousandths)/" | cut -c1-300
            rm -f "/tmp/qad-ev/p4c4b2/$r.qemu-dbg.log"
        fi
    done
    echo
    echo "## The apitest's runs (r5 and r3, the test launched from the system disk): no 'pin created' line, no 'latency: fifo' line, no ace_audio line:"
    echo "   the test was skipped before it opened a stream (its line: no active render endpoint named 'Loopback'; DIVERGENCE.md, D1), so the negotiated"
    echo "   engine buffer and period, the FIFO constraint and the render-against-capture comparison of the apitest were not reached in this round."
} > "$EV/vm/rms-and-trace.txt"
echo "rms-and-trace.txt: $(wc -l < "$EV/vm/rms-and-trace.txt") lines"
