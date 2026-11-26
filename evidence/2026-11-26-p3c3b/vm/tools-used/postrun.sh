#!/bin/bash
# postrun.sh -- the derived files of one finished run of the p3c3b round, made
# from its live directory under /tmp/qad-ev/p3c3b/<run> and copied into
# evidence/2026-11-26-p3c3b/vm/<run> (the raw trace kept gzipped, as in the
# earlier rounds).   postrun.sh <run>
set -u
QAD=<project>
R=/tmp/qad-ev/p3c3b/$1
D=$QAD/evidence/2026-11-26-p3c3b/vm/$1
cd "$R" || exit 2
strip() { sed 's/\x1b\[[0-9;]*[A-Za-z]//g' "$1" | tr -d "\0"; }
strip serial.log > serial.norm.log
grep -aE "hdaudbus\.sys|intcdsp\.sys" serial.norm.log > driver-lines.txt
grep -aE "^ace_|^intel_hda" qemu-dbg.log | grep -avE "^ace_reg_(read|write) " > ace-trace.txt
grep -a "^ace_audio " qemu-dbg.log > ace-audio-lines.txt
s=$(grep -an "intcdsp.sys: SelfTest = " serial.norm.log | head -1 | cut -d: -f1)
e=$(grep -an "loopback self-test: ran (" serial.norm.log | tail -1 | cut -d: -f1)
if [ -n "$s" ] && [ -n "$e" ] && [ "$e" -ge "$s" ]; then
    sed -n "${s},${e}p" serial.norm.log > selftest-lines.txt
fi
mkdir -p "$D"
cp -f *.txt *.log *.out *.bin *.png "$D"/ 2>/dev/null
rm -f "$D/serial.norm.log"
gzip -9n -c qemu-dbg.log > "$D/qemu-dbg.log.gz"
{
    echo "serial.log: $(wc -l < serial.norm.log) lines, $(wc -l < driver-lines.txt) driver lines; qemu-dbg.log: $(wc -l < qemu-dbg.log) lines, $(grep -ac '^ace_' qemu-dbg.log) ace_* of which $(grep -acE '^ace_reg_(read|write) ' qemu-dbg.log) register accesses (kept in the .gz only); ace-trace.txt: $(wc -l < ace-trace.txt) decoded lines, ace-audio-lines.txt: $(wc -l < ace-audio-lines.txt); livecap.out: $(wc -l < livecap.out 2>/dev/null || echo 0) lines"
    echo "serial lines end in CR LF in the logs; driver-lines.txt and selftest-lines.txt are quoted without the tail."
    echo "qemu exited: $(grep -a 'qemu exited' lib-run.out)"
    echo "fatal/storm/stall lines in serial.log: $(grep -ac 'Fatal System Error\|bugcheck' serial.log) fatal, $(grep -ac 'clock stalled' serial.norm.log) clock stalled, $(grep -ac 'interrupt storm' serial.norm.log) interrupt storm, $(grep -ac 'Work queue' serial.norm.log) work-queue; ace_unexpected in the trace: $(grep -ac 'ace_unexpected' qemu-dbg.log)"
    echo "bin files: the pages the descriptor lists named at each stop of livecap.py (pmemsave; one page more at each end of a window)."
} > "$D/contents.txt"
echo "$1 -> $D: $(head -1 "$D/contents.txt")"
