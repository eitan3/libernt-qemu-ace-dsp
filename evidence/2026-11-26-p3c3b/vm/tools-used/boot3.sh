#!/bin/bash
# boot3.sh -- VM 3 of the p3c3b round: a plain boot with SelfTest = 0 and no
# Topology value (TESTING.md run 3 at a system boot: the none-selected line and
# the power-down line, no self-test line); then, in the console, the topology
# and SelfTest = 2 set again and one disable/enable cycle read live (livecap.py
# stops the VM on each self-test run's first line and on its "stopped at" line:
# TESTING.md's run 1b, the lists at the buffers); then SelfTest = 0 again for
# VM 4; the S5.
set -u
RUN=r3-plainboot-selftest0-then-live
. /tmp/qad-ev/p3c3b/tools/vmcommon.sh
log "boot3: $RUN on disk/$OVERLAY.qcow2"
start_vm
waitfor "DSP power down from state ready|topology: none selected|loopback self-test|clock stalled" 900
sleep 5
waitfor "Program Manager" 900
sleep 20
console
g shot s1-console >/dev/null
regadd Topology REG_SZ sof-ipc4-loopback.tplg
regadd SelfTest REG_DWORD 2
g shot s2-set >/dev/null
n0=$(lines)
g type "pnputil /disable-device \"$ID\""; g key ret
waitfor "Safe removal" 60 "$n0" || log "!! the disable was not seen"
sleep 3
log "reading the controller while the device is disabled (BAR0 from the monitor's info pci)"
python3 "$T/livecap.py" "$SOCK" "$EV/serial.log" "$EV" "now-disabled=" > "$EV/livecap-disabled.out" 2>&1
log "livecap (disabled) rc=$?: $(grep -a '^   BAR0\|!!' "$EV/livecap-disabled.out" | cut -c1-300)"
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
log "the cycle's self-test lines:"
norm | tail -n +"$((n0 + 1))" | grep -aE "loopback self-test" | cut -c1-300 | tee -a "$EV/driver.log"
g shot s3-after-live-cycle >/dev/null
regadd SelfTest REG_DWORD 0
g shot s4-selftest0-again >/dev/null
s5
log "boot3 done"
