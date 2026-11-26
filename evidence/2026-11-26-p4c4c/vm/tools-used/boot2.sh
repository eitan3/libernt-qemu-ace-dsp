#!/bin/bash
# boot2.sh -- VM 2 of the p4c4c round: a fresh overlay's first boot with the data disk
# (TESTING.md A1/A2 once more, in this configuration); BootDsp = 1 and NO Topology value; then
#   C8  -- one disable/enable cycle with no topology: the none-selected line and the power-down,
#          no child, no endpoint; the device lists to the data disk;
#   C9  -- the DSP device alone: two more cycles;
#   the regression of the plan -- 22 disable/enable cycles (tools/cycle.sh, the model's registers
#          read over qtest before and after each boot; the same count as the p3c1 round's
#          ac3-cycles run), the summary line as ac3-cycles.sh writes it;
# then the S5.  The overlay keeps BootDsp = 1 without a topology for the fault rows.
set -u
RUN="${RUN:-r2-notopology-cycles}"
OVERLAY="${OVERLAY:-p4c4c-nt}"
. /tmp/qad-ev/p4c4c/tools/vmcommon.sh
log "boot2: $RUN on disk/$OVERLAY.qcow2"
start_vm
waitre "Storage expansion not offered|The system has been stopped" 900 || log "!! neither the first-boot setup's line nor a stop line in 900 s"
if norm | grep -aq "The system has been stopped"; then
    log "!! the first boot STOPPED; its lines:"
    norm | grep -anE "KsCreateBusEnumObject|The system has been stopped|Stop code|Parameter [1-4]|^ *#[0-9][0-9] |RIP=" | cut -c1-300 | tee -a "$EV/driver.log"
    s5
    exit 1
fi
log "A1: the first boot's lines:"
norm | grep -aE "KsCreateBusEnumObject|Safe removal|First-boot setup|Storage expansion not offered|intcdsp\.sys: (BootDsp|SelfTest)|Program Manager" | cut -c1-300 | tee -a "$EV/driver.log"
log "stop lines in the boot's log: $(norm | grep -ac 'The system has been stopped'); storport timeouts: $(norm | grep -ac 'Storport: a request'); ace_unexpected: $(grep -ac ace_unexpected "$EV/qemu-dbg.log")"
sleep 5
g shot s1-desktop-before-wizard >/dev/null
wizard 15
g shot s2-after-wizard >/dev/null
sleep 20
g shot s3-after-wizard-20s >/dev/null
console
if ! pouchfind; then g shot s4-no-data-disk-letter >/dev/null; log "!! the console did not find the data disk: stopped here"; exit 1; fi
alive firstboot || { g shot s4b-console-silent >/dev/null; log "!! the console is silent: stopped here"; exit 1; }
regadd BootDsp REG_DWORD 1
cmd settings.txt "reg query HKLM\\SYSTEM\\CurrentControlSet\\Services\\intcdsp\\Settings" 30
# C8: the first cycle, no topology
n0=$(lines)
( cd "$QAD" && TIMEOUT=90 tools/cycle.sh "$EV" c8-none > "$EV/cycle-c8.out" 2>&1 ); log "cycle c8-none: rc=$?"
sleep 10
log "C8: the driver lines of the cycle (after serial line $n0):"
norm | tail -n +"$((n0 + 1))" | grep -aE "intcdsp\.sys: (SelfTest|BootDsp = |boot ok|topology|ipc: link|DSP power down|audio child)|dsppcm\.sys|Safe removal|clock stalled|interrupt storm|Work queue|Fatal|bugcheck" \
    | grep -av "booting:" | cut -c1-420 | tee -a "$EV/driver.log"
log "C8: audio child lines of the cycle: $(norm | tail -n +"$((n0 + 1))" | grep -ac "audio child"); dsppcm.sys lines of the VM: $(norm | grep -ac "dsppcm\.sys")"
cmd enum-media.txt "pnputil /enum-devices /class Media /ids" 60
cmd enum-endpoint.txt "pnputil /enum-devices /class AudioEndpoint /ids" 60
log "C8: enum-media.txt: $(pouch_text enum-media.txt | grep -ci 'INTCDSP') INTCDSP lines; enum-endpoint.txt: $(pouch_text enum-endpoint.txt | grep -ci 'Loopback') Loopback lines"
# C9: the DSP device alone, two more cycles
for c in c9a-alone c9b-alone; do
    ( cd "$QAD" && TIMEOUT=90 tools/cycle.sh "$EV" "$c" > "$EV/cycle-$c.out" 2>&1 ); log "cycle $c: rc=$?"
done
# the regression of the plan: 22 cycles
for i in $(seq 1 22); do
    ( cd "$QAD" && TIMEOUT=90 tools/cycle.sh "$EV" "ac3-$i" > "$EV/cycle-ac3-$i.out" 2>&1 ); log "cycle ac3-$i: rc=$?"
done
ok=$(awk '/^## cycle ac3-[0-9]+ /{f=1; next} /^## cycle/{f=0} f && /intcdsp.sys: boot ok after/{n++} END{print n+0}' "$EV/cycles.log")
to=$(awk '/^## cycle ac3-[0-9]+ /{f=1; next} /^## cycle/{f=0} f && /intcdsp.sys: boot .*timeout after/{n++} END{print n+0}' "$EV/cycles.log")
other=$(awk '/^## cycle ac3-[0-9]+ /{f=1; next} /^## cycle/{f=0} f && /intcdsp.sys: boot/ && !/booting:/ && !/boot ok after/ && !/timeout after/{n++} END{print n+0}' "$EV/cycles.log")
none=$(grep -ac "not seen" "$EV/cycles.log")
stall=$(grep -ac "clock stalled" "$EV/serial.log")
printf 'AC3 cycles: 22 run, %s boot ok, %s bounded timeouts, %s other outcomes, %s waits not seen, clock stalled lines: %s (%s; icount=1)\n' \
    "$ok" "$to" "$other" "$none" "$stall" "$(date -u +%FT%TZ)" | tee "$EV/summary.txt" | tee -a "$EV/driver.log"
log "the model's readings before the 22 cycles (distinct): $(awk '/^## cycle ac3-[0-9]+ /{f=1; next} /^## cycle/{f=0} f && /^model \(disabled\)/{print} ' "$EV/cycles.log" | sort -u | wc -l); after (distinct): $(awk '/^## cycle ac3-[0-9]+ /{f=1; next} /^## cycle/{f=0} f && /^model \(D0\)/{print} ' "$EV/cycles.log" | sort -u | wc -l)"
log "all cycles of the VM: $(grep -ac '^## cycle' "$EV/cycles.log"); Safe removal lines: $(norm | grep -ac 'Safe removal: CSAUDIO'); none-selected lines: $(norm | grep -ac 'topology: none selected'); power-down lines: $(norm | grep -ac 'DSP power down from state ready')"
log "stop lines in the whole log: $(norm | grep -ac 'The system has been stopped'); fatal lines: $(grep -acE 'Fatal System Error|bugcheck' "$EV/serial.log"); ace_unexpected: $(grep -ac ace_unexpected "$EV/qemu-dbg.log")"
s5
log "boot2 done"
exit 0
