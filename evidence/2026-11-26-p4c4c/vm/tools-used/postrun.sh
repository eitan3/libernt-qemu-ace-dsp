#!/bin/bash
# postrun.sh -- the derived files of one finished VM of the p4c4c round, made from its live
# directory under /tmp/qad-ev/p4c4c/<run> and copied into evidence/2026-11-26-p4c4c/vm/<run>
# (the p4c4b2 round's postrun.sh with the paths changed; the raw trace kept gzipped).
#   postrun.sh <run> [<overlay>]
# The text the guest wrote to its data disk is read back with mtools into the run directory
# first (every .txt and .log file of the disk's root).  Re-runnable: a run is copied again each time.
set -u
QAD=<project>
R=/tmp/qad-ev/p4c4c/$1
D=$QAD/evidence/2026-11-26-p4c4c/vm/$1
cd "$R" || exit 2
if [ -n "${2:-}" ] && [ -f "$2" ]; then
    mcopy -o -i "$2@@32256" ::/*.txt . >/dev/null 2>&1
    mcopy -o -i "$2@@32256" ::/*.log . >/dev/null 2>&1
    mdir -i "$2@@32256" ::/ > pouch-listing.txt 2>&1
fi
strip() { sed 's/\x1b\[[0-9;]*[A-Za-z]//g' "$1" | tr -d "\0"; }
strip serial.log | tr -d "\r" > serial.txt
grep -aE "hdaudbus\.sys|intcdsp\.sys|dsppcm\.sys" serial.txt > driver-lines.txt
grep -a "^ace_" qemu-dbg.log | grep -avE "^ace_reg_(read|write) " > ace-trace.txt
grep -a "^ace_audio " qemu-dbg.log > ace-audio-lines.txt
rm -f contents.txt
mkdir -p "$D"
cp -f *.txt *.log *.out *.bin *.png "$D"/ 2>/dev/null
cp -f serial.log "$D"/
rm -f "$D/qemu-dbg.log" "$D/sock-dir.txt" "$D/contents.txt"
gzip -9n -c qemu-dbg.log > "$D/qemu-dbg.log.gz"
{
    echo "serial.txt: $(wc -l < serial.txt) lines (ANSI escapes, NULs and CRs removed), $(wc -l < driver-lines.txt) driver lines (hdaudbus.sys, intcdsp.sys, dsppcm.sys); serial.log: as the guest wrote it"
    echo "qemu-dbg.log: $(wc -l < qemu-dbg.log) lines, $(grep -ac '^ace_' qemu-dbg.log) ace_* of which $(grep -acE '^ace_reg_(read|write) ' qemu-dbg.log) register accesses (kept in the .gz only); ace-trace.txt: $(wc -l < ace-trace.txt) decoded lines; ace-audio-lines.txt: $(wc -l < ace-audio-lines.txt) lines"
    echo "livecap: $(ls livecap*.out 2>/dev/null | tr '\n' ' ') $(cat livecap*.out 2>/dev/null | wc -l) lines"
    echo "qemu exited: $(grep -a 'qemu exited' lib-run.out)"
    echo "stop/fatal/stall lines in serial.log: $(grep -ac 'The system has been stopped' serial.log) stopped, $(grep -ac 'Stop code' serial.log) stop code, $(grep -ac 'Fatal System Error\|bugcheck' serial.log) fatal, $(grep -ac 'clock stalled' serial.txt) clock stalled, $(grep -ac 'interrupt storm' serial.txt) interrupt storm, $(grep -ac 'Work queue' serial.txt) work-queue; ace_unexpected in the trace: $(grep -ac 'ace_unexpected' qemu-dbg.log)"
    echo "the data disk's text: $(ls *.txt 2>/dev/null | grep -c .) .txt files in this directory (pouch-listing.txt: the disk's listing)"
    echo "bin files: the pages the descriptor lists named at each stop of livecap.py (pmemsave), where a run made them."
} > "$D/contents.txt"
echo "$1 -> $D: $(ls "$D" | wc -l) files, $(du -sk "$D" | cut -f1) KiB"
exit 0
