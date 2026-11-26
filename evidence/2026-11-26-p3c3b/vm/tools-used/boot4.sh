#!/bin/bash
# boot4.sh -- VM 4 of the p3c3b round: a system boot with SelfTest = 0 and the topology
# kept (TESTING.md run 3 at a system boot: boot ok, ipc: link ready, the topology line
# and the modules line, no self-test line); then SelfTest = 2 in the console and one
# disable/enable cycle read live (livecap.py stops the VM on each self-test run's first
# line and on its "stopped at" line: TESTING.md's run 1b, the lists at the buffers);
# SelfTest = 0 again; the S5.
#
# VM 3 ended with SelfTest = 2 or 0 (its last command was typed into a paused VM), so
# the settings line of this boot is read first: with SelfTest = 0 this boot is the
# regression; otherwise SelfTest = 0 is set and the guest rebooted (REBOOT=1), and
# that boot is.
set -u
RUN=r4-plainboot-regression-and-live
REBOOT=1
. /tmp/qad-ev/p3c3b/tools/vmcommon.sh
log "boot4: $RUN on disk/$OVERLAY.qcow2"
start_vm
waitfor "topology 'sof-ipc4-loopback.tplg'|topology: none selected|clock stalled" 900
sleep 5
st=$(norm | grep -a "intcdsp.sys: SelfTest = " | head -1 | sed "s/.*SelfTest = \([0-9]*\).*/\1/")
log "this boot's settings line says SelfTest = $st"
if [ "$st" != "0" ]; then
    log "not the regression boot: SelfTest = 0 will be set and the guest rebooted"
    waitfor "Program Manager" 900
    sleep 20
    console
    regadd SelfTest REG_DWORD 0
    n=$(lines)
    g type "shutdown -r -t 0"; g key ret
    log "reboot typed at serial line $n"
    waitfor "SelfTest = 0, UseInterrupts" 600 "$n"
    waitfor "topology 'sof-ipc4-loopback.tplg'" 600 "$n"
    sleep 5
    log "the reboot's driver lines:"
    norm | tail -n +"$((n + 1))" | grep -aE "intcdsp\.sys" | grep -av "boot .*after" | cut -c1-300 | tee -a "$EV/driver.log"
    bootfrom=$n
else
    bootfrom=0
    log "the boot's driver lines:"
    norm | grep -aE "intcdsp\.sys" | grep -av "boot .*after" | cut -c1-300 | tee -a "$EV/driver.log"
fi
log "self-test lines of the regression boot (none expected): $(norm | tail -n +"$((bootfrom + 1))" | grep -ac "loopback self-test")"
waitfor "Program Manager" 900 "$([ "$bootfrom" -gt 0 ] && echo "$bootfrom" || echo 0)"
sleep 20
console
g shot s1-console >/dev/null
regadd SelfTest REG_DWORD 2
g shot s2-selftest2-set >/dev/null
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
log "boot4 done"
