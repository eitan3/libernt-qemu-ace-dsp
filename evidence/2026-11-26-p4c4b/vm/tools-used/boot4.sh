#!/bin/bash
# boot4.sh -- VM 4 of the p4c4b round: the second fresh overlay's first boot (the wizard closed
# by chords), BootDsp = 1 and no Topology value, one disable/enable cycle: TESTING.md run 3 (i),
# no topology -> no child, no endpoint, from a fresh boot (the brief's run 3a); the device lists
# to the data disk; the S5.
set -u
RUN=r4-freshboot-notopology
OVERLAY=p4c4b-fresh
. /tmp/qad-ev/p4c4b/tools/vmcommon.sh
log "boot4: $RUN on disk/$OVERLAY.qcow2"
start_vm
waitfor "Storage expansion not offered" 900
sleep 5
g shot s1-desktop-before-wizard >/dev/null
wizard 15
g shot s2-after-wizard >/dev/null
console
g shot s3-console >/dev/null
regadd BootDsp REG_DWORD 1
pouchfind || true
n0=$(lines)
g type "pnputil /disable-device \"$ID\""; g key ret
waitfor "Safe removal" 60 "$n0" || log "!! the disable was not seen"
sleep 3
g type "pnputil /enable-device \"$ID\""; g key ret
waitfor "topology: none selected" 120 "$n0" || log "!! the none-selected line did not come in 120 s"
sleep 15
log "run 3 (i): driver lines after the disable (serial line $n0):"
norm | tail -n +"$((n0 + 1))" | grep -aE "intcdsp\.sys|dsppcm\.sys|Safe removal|PNP_DisableDevInst|clock stalled|interrupt storm|Work queue|Fatal|bugcheck" \
    | grep -av "firmware \|BAR4\|NHLT\|reading BAR4\|HFINTIPPTR\|interrupts before\|subsystem powered\|code-loader\|ROM ready\|firmware entered\|FW_READY" \
    | cut -c1-330 | tee -a "$EV/driver.log"
log "audio child lines after the enable: $(norm | tail -n +"$((n0 + 1))" | grep -ac "audio child"); dsppcm.sys lines of the whole boot: $(norm | grep -ac "dsppcm\.sys")"
totext enum-media.txt "pnputil /enum-devices /class Media /ids"
sleep 8
totext enum-endpoint.txt "pnputil /enum-devices /class AudioEndpoint /ids"
sleep 8
log "enum-media.txt: $(pouch_text enum-media.txt | wc -l) lines, $(pouch_text enum-media.txt | grep -ci 'INTCDSP') INTCDSP lines; enum-endpoint.txt: $(pouch_text enum-endpoint.txt | wc -l) lines, $(pouch_text enum-endpoint.txt | grep -ci 'Loopback') Loopback lines"
log "enum-media.txt as the guest wrote it:"
pouch_text enum-media.txt | cut -c1-200 | tee -a "$EV/driver.log"
g shot s4-lists >/dev/null
s5
log "boot4 done"
