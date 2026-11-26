#!/bin/bash
# boot2.sh -- VM 2 of the p3c3b round: a plain boot with SelfTest = 2 and the
# topology persisted (TESTING.md run 1's three runs and run 2's T1 line at a
# system boot); then, still with SelfTest = 2, one disable/enable cycle read
# live (livecap.py stops the VM on each self-test run's first line and on its
# "stopped at" line: TESTING.md's run 1b, the lists at the buffers); then
# SelfTest = 0 in the console and the device cycled with the topology kept and,
# after its value is deleted, without it (TESTING.md run 3 at a disable/enable
# cycle, both states); the S5.
set -u
RUN=r2-plainboot-live-then-selftest0
. /tmp/qad-ev/p3c3b/tools/vmcommon.sh
log "boot2: $RUN on disk/$OVERLAY.qcow2"
start_vm
waitfor "self-test: ran \(|not captured|mismatch at frame|self-test: .* failed" 900
sleep 3
waitfor "Program Manager" 900
sleep 20
console
g shot s1-console >/dev/null
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
log "the cycle's driver lines:"
norm | tail -n +"$((n0 + 1))" | grep -aE "intcdsp\.sys" | grep -av "boot .*after" | cut -c1-400 | tee -a "$EV/driver.log"
g shot s2-after-live-cycle >/dev/null
regadd SelfTest REG_DWORD 0
g shot s3-selftest0-set >/dev/null
(cd "$QAD" && TIMEOUT=120 tools/cycle.sh "$EV" selftest0-topology) > "$EV/cycle-selftest0-topology.out" 2>&1
log "cycle selftest0-topology rc=$?: $(grep -a 'boot ok\|!!\|not seen' "$EV/cycle-selftest0-topology.out" | cut -c1-200)"
regdel Topology
(cd "$QAD" && TIMEOUT=120 tools/cycle.sh "$EV" selftest0-notopology) > "$EV/cycle-selftest0-notopology.out" 2>&1
log "cycle selftest0-notopology rc=$?: $(grep -a 'boot ok\|!!\|not seen\|none selected' "$EV/cycle-selftest0-notopology.out" | cut -c1-200)"
g shot s4-after-cycles >/dev/null
s5
log "boot2 done"
