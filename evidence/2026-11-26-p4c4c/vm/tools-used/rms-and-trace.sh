#!/bin/bash
# rms-and-trace.sh -- the model's trace of the p4c4c round against the driver's own lines and the
# apitest's, into vm/rms-and-trace.txt: ace-audio-check.py (the p3c3b round's checker, unchanged)
# on every VM that has a self-test, and the ace_audio lines of the apitest's stream runs counted
# (the tone's periods against the silence's, every pair identical).
set -u
QAD=<project>
EV=$QAD/evidence/2026-11-26-p4c4c
T=/tmp/qad-ev/p4c4c/tools
{
    echo "# The model's trace of the p4c4c round: ace-audio-check.py (the p3c3b round's checker, unchanged) on the VMs with a self-test, and the"
    echo "# apitest's stream runs counted.  The trace line is \"ace_audio <tag> <bytes> rms <r> peak <p> first <8 samples>\"; the checker pairs the"
    echo "# render's line with the capture's for each period and holds the samples and the rms against the driver's own sine (IntcDspSineQ31)."
    echo "# $(date -u +%FT%TZ)"
    for d in "$EV"/vm/r*; do
        r=$(basename "$d")
        [ -f "$d/qemu-dbg.log.gz" ] || continue
        na=$(zcat "$d/qemu-dbg.log.gz" | grep -ac '^ace_audio')
        echo
        echo "## $r: ace_audio lines $na; self-test lines of the driver $(grep -ac 'loopback self-test' "$d/serial.txt"); pin-created lines $(grep -ac 'pin created' "$d/serial.txt"); latency lines $(grep -ac 'latency: fifo' "$d/serial.txt")"
        if [ "$na" = 0 ]; then
            echo "(no ace_audio line in this VM: no stream ran through the model)"
            continue
        fi
        if [ "$(grep -ac 'loopback self-test: .* frames captured after' "$d/serial.txt")" -gt 0 ]; then
            # the checker reads the plain log; its last sentence about the driver's 16-bit figure is reworded (this image prints the exact value)
            zcat "$d/qemu-dbg.log.gz" > "/tmp/qad-ev/p4c4c/$r.qemu-dbg.log"
            python3 "$T/ace-audio-check.py" "/tmp/qad-ev/p4c4c/$r.qemu-dbg.log" "$d/serial.txt" 2>/dev/null \
                | sed "s/(its per-sample truncating sum: see driver-rms.py)/(the sine's exact value to a thousandth on this image)/" | cut -c1-300
            echo "checker rc=${PIPESTATUS[0]}"
            rm -f "/tmp/qad-ev/p4c4c/$r.qemu-dbg.log"
        fi
        if [ "$(grep -ac 'pin created' "$d/serial.txt")" -gt 0 ]; then
        # the apitest's stream: the tone's periods (every one the same line) against the silence's
        nz=$(grep -avc "rms 0.000 " "$d/ace-audio-lines.txt")
        z=$(grep -ac "rms 0.000 " "$d/ace-audio-lines.txt")
        echo "the apitest's stream (pin-created lines $(grep -ac 'pin created' "$d/serial.txt")): $nz periods with the tone, $z of silence; distinct tone lines: $(grep -av "rms 0.000 " "$d/ace-audio-lines.txt" | sort -u | wc -l); tone lines with an odd multiplicity (each render period should have its identical capture line): $(grep -av "rms 0.000 " "$d/ace-audio-lines.txt" | sort | uniq -c | awk '$1 % 2 == 1' | wc -l)"
        grep -av "rms 0.000 " "$d/ace-audio-lines.txt" | sort -u | head -3 | cut -c1-200 | sed 's/^/   /'
        echo "   the tone's samples: every 'first' value a multiple of 65536 (16-bit steps in the 32-bit container): $(grep -av "rms 0.000 " "$d/ace-audio-lines.txt" | sort -u | head -1 | awk '{ok=1; for (i=9; i<=16; i++) if ($i % 65536 != 0) ok=0; print ok ? "yes" : "no"}'); its peak $(grep -av "rms 0.000 " "$d/ace-audio-lines.txt" | sort -u | head -1 | awk '{print $8}') (2^30: half of full scale)"
        fi
    done
} > "$EV/vm/rms-and-trace.txt"
echo "rms-and-trace.txt: $(wc -l < "$EV/vm/rms-and-trace.txt") lines"
exit 0
