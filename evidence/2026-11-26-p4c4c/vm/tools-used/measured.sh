#!/bin/bash
# measured.sh -- the measured lines of the p4c4c round, cut from each VM's serial.txt (ANSI
# escapes, NULs and CRs removed; the timestamps are the guest's own) with the round's counts,
# into vm/measured-lines.txt.  Re-runnable; a VM whose serial.txt is not there yet is skipped.
set -u
QAD=<project>
EV=$QAD/evidence/2026-11-26-p4c4c
cd "$EV/vm" || exit 2
out=$EV/vm/measured-lines.txt
LINES="KsCreateBusEnumObject|Safe removal|Storage expansion not offered|Storport: a request|hibernated|Gina|intcdsp\.sys: (SelfTest|BootDsp = |boot ok|topology|ipc: link|audio child|loopback self-test|firmware ready|stream [0-9]+: latency|DSP power down|streams: released)|dsppcm\.sys:|PNP_DisableDevInst|DisableDeviceInstance|EnableDeviceInstance|RestartDevice|The system has been stopped|Stop code|Entering sleep state S5|clock stalled|interrupt storm"
{
    echo "# The measured lines of the p4c4c round, cut from each VM's serial.txt (ANSI escapes, NULs and CRs removed; the timestamps are the guest's)."
    echo "# Long lines are cut at 400 characters; the whole line is in the VM's serial.txt."
    echo "# $(date -u +%FT%TZ)"
    for r in $(ls -d r* fm-* 2>/dev/null | grep -v '^r[0-9]*\.' ); do
        [ -f "$r/serial.txt" ] || continue
        echo
        echo "=== $r  (serial.txt $(wc -l < "$r/serial.txt") lines; start $(cat "$r/start.txt" 2>/dev/null); end $(cat "$r/end.txt" 2>/dev/null); $(grep -a 'qemu exited' "$r/lib-run.out" 2>/dev/null | cut -c1-110))"
        echo "--- counts: settings lines $(grep -ac 'intcdsp.sys: SelfTest = ' "$r/serial.txt"); boot ok $(grep -ac 'boot ok after' "$r/serial.txt") (with '0 DSP interrupts' on $(grep -a 'boot ok after' "$r/serial.txt" | grep -ac '0 DSP interrupts')); self-test runs captured $(grep -ac 'loopback self-test: .* frames captured after' "$r/serial.txt"); pins created $(grep -ac 'pin created' "$r/serial.txt"); 'Safe removal' $(grep -ac 'Safe removal' "$r/serial.txt"); stopped $(grep -ac 'The system has been stopped' "$r/serial.txt"); storport timeouts $(grep -ac 'Storport: a request' "$r/serial.txt"); clock stalled $(grep -ac 'clock stalled' "$r/serial.txt"); interrupt storm $(grep -ac 'interrupt storm' "$r/serial.txt"); 'Entering sleep state S5' $(grep -ac 'Entering sleep state S5' "$r/serial.txt")"
        if [ -f "$r/qemu-dbg.log.gz" ]; then
            echo "--- the model's trace (qemu-dbg.log): $(zcat "$r/qemu-dbg.log.gz" | grep -ac '^ace_') ace_* lines, $(zcat "$r/qemu-dbg.log.gz" | grep -ac 'ace_unexpected') ace_unexpected, $(zcat "$r/qemu-dbg.log.gz" | grep -ac '^ace_audio') ace_audio"
        fi
        echo "--- the lines:"
        grep -aE "$LINES" "$r/serial.txt" | cut -c1-400
    done
} > "$out"
echo "measured-lines.txt: $(wc -l < "$out") lines"
exit 0
