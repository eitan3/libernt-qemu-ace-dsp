#!/bin/bash
# boot1.sh -- VM 1 of the p3c3b round: the fresh overlay's first boot (stage 1,
# BootDsp = 0), the wizard closed by script, BootDsp = 1, Topology and
# SelfTest = 2 set in the console, then one disable/enable cycle of the DSP
# device read live (livecap.py stops the VM on each self-test run's first line
# and on its "stopped at" line): TESTING.md's runs 1b, 1 and 2; then the S5.
set -u
RUN=r1-firstboot-set-live
. /tmp/qad-ev/p3c3b/tools/vmcommon.sh
log "boot1: $RUN on disk/$OVERLAY.qcow2"
start_vm
waitfor "Storage expansion not offered" 900
sleep 5
g shot s1-desktop-before-wizard >/dev/null
wizard 15
g shot s2-after-wizard >/dev/null
console
g shot s3-console >/dev/null
regadd BootDsp REG_DWORD 1
regadd Topology REG_SZ sof-ipc4-loopback.tplg
regadd SelfTest REG_DWORD 2
g shot s4-reg-add >/dev/null
n0=$(lines)
g type "pnputil /disable-device \"$ID\""; g key ret
waitfor "Safe removal" 60 "$n0" || log "!! the disable was not seen"
sleep 3
log "reading the controller while the device is disabled (BAR0 from the config space)"
python3 "$T/livecap.py" "$SOCK" "$EV/serial.log" "$EV" "now-disabled=" > "$EV/livecap-disabled.out" 2>&1
log "livecap (disabled) rc=$?: $(grep -a '^== \|!!' "$EV/livecap-disabled.out" | cut -c1-300)"
g type "pnputil /enable-device \"$ID\""; g key ret
log "enable typed; stopping on each self-test run's first line"
python3 "$T/livecap.py" "$SOCK" "$EV/serial.log" "$EV" \
    "16=2 ch 16-bit, render stream" "16end=stopped at render position" \
    "24=2 ch 24-bit, render stream" "24end=stopped at render position" \
    "32=2 ch 32-bit, render stream" "32end=stopped at render position" \
    "wait=self-test: ran (" > "$EV/livecap.out" 2>&1
log "livecap rc=$?"
sleep 3
(cd "$QAD" && tools/qtest.py "$SOCK/qtest.sock" adspcs dsp2cxctl hfipcxida hfipcxtddy fsr) | tee -a "$EV/driver.log"
log "self-test lines:"
norm | tail -n +"$((n0 + 1))" | grep -aE "intcdsp\.sys" | grep -av "boot .*after" | cut -c1-400 | tee -a "$EV/driver.log"
g shot s5-after-selftest >/dev/null
s5
log "boot1 done"
