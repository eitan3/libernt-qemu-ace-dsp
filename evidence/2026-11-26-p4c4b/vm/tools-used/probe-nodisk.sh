#!/bin/bash
# probe-nodisk.sh -- attribute r0a's first-boot bugcheck: the same first boot (a fresh
# overlay) with no data disk attached.  The monitor's read primitive (HMP x) is checked
# while the VM stands stopped shortly after autochk's line; the VM is stopped again the
# moment the bugcheck's register line reaches the serial log (bugpause.py) and the faulting
# thread's memory is read (bugread.py); the guest is then let continue (REBOOT=1: after its
# dump and reset, the next boot is watched for the same crash or for the lines past it).
# Nothing is typed into the guest: the first boot decides by its own serial lines.
set -u
RUN="${RUN:-r0b-firstboot-nodisk}"
OVERLAY="${OVERLAY:-p4c4b-probe}"
REBOOT=1; POUCH=; WAIT=2400
. /tmp/qad-ev/p4c4b/tools/vmcommon.sh
NTK=/tmp/qad-ev/p4c4b/nt/Windows/system32

end_vm() {
    g mon system_powerdown >/dev/null 2>&1
    for i in $(seq 1 90); do [ -f "$EV/end.txt" ] && break; sleep 1; done
    [ -f "$EV/end.txt" ] || { log "the guest did not power off in 90 s: the monitor's quit"; g mon quit >/dev/null 2>&1; }
    wait $LR 2>/dev/null
    log "VM $RUN ended: $(grep -a 'qemu exited' "$EV/lib-run.out")"
}

log "probe: $RUN on disk/$OVERLAY.qcow2, REBOOT=$REBOOT, no data disk"
start_vm
CHECK="$NTK/ntoskrnl.exe:$NTK/hal.dll" python3 "$T/bugpause.py" "$SOCK" "$EV/serial.log" "AUTOCHK: Checking" 600 > "$EV/bugpause-check.out" 2>&1
log "the read primitive's check (rc=$?): $(grep -a 'CHECK\|!!\|KPCR\|image base\|stopped' "$EV/bugpause-check.out" | tr '\n' ' ' | cut -c1-900)"
g mon cont >/dev/null
python3 "$T/bugpause.py" "$SOCK" "$EV/serial.log" "RIP=" 1800 > "$EV/bugpause-crash.out" 2>&1 &
BP=$!
n0=$(lines)
i=0
while ! norm | tail -n +"$((n0 + 1))" | grep -aq "RIP=\|First-boot setup lists"; do
    sleep 5; i=$((i + 1)); [ $i -gt 200 ] && break
done
sleep 2
new() { norm | tail -n +"$((n0 + 1))"; }
if new | grep -aq "RIP="; then
    for i in $(seq 1 30); do grep -aq "stopped\|not seen" "$EV/bugpause-crash.out" && break; sleep 1; done
    wait $BP; log "the bugcheck's register line: $(tr '\n' ' ' < "$EV/bugpause-crash.out" | cut -c1-300)"
    RSP=$(new | grep -a "RIP=" | tail -1 | sed -n 's/.*RIP=[0-9a-f]* RSP=\([0-9a-f]*\).*/\1/p')
    python3 "$T/bugread.py" "$SOCK" "$RSP" "$EV/bugread.txt" > "$EV/bugread.out" 2>&1
    log "bugread at the first boot's bugcheck (RSP $RSP): rc=$?, $(wc -l < "$EV/bugread.txt" 2>/dev/null) lines to bugread.txt"
    g mon cont >/dev/null
    n1=$(lines)
    sleep 20
    # the next boot: stopped at its bugcheck too and read, if it comes to that
    python3 "$T/bugpause.py" "$SOCK" "$EV/serial.log" "RIP=" 1200 > "$EV/bugpause-crash2.out" 2>&1 &
    BP=$!
    for i in $(seq 1 240); do
        new | tail -n +"$((n1 + 1))" | grep -aq "RIP=\|First-boot setup lists" && break
        sleep 5
    done
    sleep 2
    if new | tail -n +"$((n1 + 1))" | grep -aq "RIP="; then
        for i in $(seq 1 30); do grep -aq "stopped\|not seen" "$EV/bugpause-crash2.out" && break; sleep 1; done
        wait $BP
        RSP2=$(new | grep -a "RIP=" | tail -1 | sed -n 's/.*RIP=[0-9a-f]* RSP=\([0-9a-f]*\).*/\1/p')
        python3 "$T/bugread.py" "$SOCK" "$RSP2" "$EV/bugread-2.txt" > "$EV/bugread-2.out" 2>&1
        log "the next boot bugchecked too (RSP $RSP2): bugread rc=$?"
        g mon cont >/dev/null
    else
        kill $BP 2>/dev/null; wait $BP 2>/dev/null
        log "the next boot: $(new | tail -n +"$((n1 + 1))" | grep -a 'First-boot setup lists\|Storage expansion' | cut -c1-200 | tr '\n' '|')"
    fi
else
    kill $BP 2>/dev/null; wait $BP 2>/dev/null
    log "no bugcheck before the first-boot setup's component list (the crash point of r0a, serial line ~125, is past): waiting for the storage-expansion line"
    waitfor "Storage expansion not offered" 900 "$n0"
fi
sleep 5
log "the serial lines after the crash point of r0a (KsCreateBusEnumObject onward, kernel lines only):"
new | grep -a "^\[ *[0-9]" | grep -a -A60 "KsCreateBusEnumObject" | cut -c1-240 | head -70 | tee -a "$EV/driver.log"
end_vm
log "probe done"
