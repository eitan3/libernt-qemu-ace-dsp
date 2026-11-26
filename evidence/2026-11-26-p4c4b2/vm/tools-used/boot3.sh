#!/bin/bash
# boot3.sh -- VM 3 of the p4c4b2 round: a plain boot with the endpoint registered, the apitest once
# more (no live read: the measurement a second time; its launch read from the serial log, with
# one typed retry), then TESTING.md run 3 (ii), the disable attribution against this master's
# PnP semantics, scripted and one command at a time:
#   (a) the PCM child alone, then its enable; (b) the codec, then its enable; (c) the DSP device
#   with the child present.
# What the p4c4b round's boot3.sh did, with two changes for what VM 1 showed: every pnputil
# command's own text goes to the data disk (> file 2>&1), so the guest's verdict ('Device
# disabled successfully' or 'Failed to disable device: ...') and the time the command returned
# are read from the disk, not from a screenshot; and a command that does not return in its
# bounded wait ends the sequence (the console is then busy for good), with its last serial
# lines recorded and the S5 attempted (bounded).
# The codec's instance id is as this guest lists it (vmcommon.sh: 4&AEEFD634&0&0001).
set -u
RUN="${RUN:-r3-plainboot-attribution}"
OVERLAY="${OVERLAY:-p4c4b2-st2}"
. /tmp/qad-ev/p4c4b2/tools/vmcommon.sh
# a serial-line wait whose status means what it says: vmcommon.sh's waitfor is a pipeline that
# ends in tee, so its status is always 0 (its '|| log' callers never log)
waitre() {   # waitre <regex> <seconds> <from line>
    local t0=$(date +%s)
    while :; do
        if norm | tail -n +"$(($3 + 1))" | grep -aEq "$1"; then return 0; fi
        [ $(( $(date +%s) - t0 )) -ge "$2" ] && return 1
        sleep 2
    done
}
log "boot3: $RUN on disk/$OVERLAY.qcow2"
start_vm
waitfor "topology 'sof-ipc4-loopback.tplg'|topology: none selected|clock stalled|The system has been stopped" 900
sleep 5
log "the boot's driver lines:"
norm | grep -aE "intcdsp\.sys: (SelfTest|BootDsp = |boot ok|topology: modules|audio child)|dsppcm\.sys: endpoint .* registered as|clock stalled|interrupt storm|Work queue|Fatal|bugcheck|The system has been stopped" | cut -c1-330 | tee -a "$EV/driver.log"
waitfor "Program Manager" 900
sleep 20
console
pouchfind || true
cmd() {       # cmd <out file on the data disk> <command> [sleep s]
    g type "$2 > %POUCHDRV%:\\$1 2>&1"; g key ret; sleep "${3:-8}"
    log "$2: $(pouch_text "$1" 2>/dev/null | tr '\n' ' ' | cut -c1-600)"
}
# the apitest a second time, without the live read.  The p4c4b round's typed line (the exe from the
# data disk) first, its own text to the disk: on this image cmd.exe answers it with 'The system cannot
# find the path specified.' (VM 1 and VM 5); the exe from the system disk (copied there in VM 5) is
# the launch of record, with a launch check read from the serial log.
LAUNCHRE="dsppcm\.sys: endpoint .* pin created|intcdsp\.sys: stream [0-9]+: latency|the DSP gives no stream|the pin.s format is refused"
cmd x-launch-D.txt "D:\\dsploop_apitest.exe" 30
cmd x-dir-C.txt "dir C:\\dsploop_apitest.exe" 8
if ! pouch_text x-dir-C.txt | grep -q "dsploop"; then
    log "C:\\dsploop_apitest.exe is not there (VM 5's copy not on this overlay): copied again"
    cmd x-copy.txt "copy %POUCHDRV%:\\dsploop_apitest.exe C:\\dsploop_apitest.exe" 20
fi
n1=$(lines)
g type "C:\\dsploop_apitest.exe > %POUCHDRV%:\\dsploop-out.txt"; g key ret
log "typed the apitest from the system disk with Enter (serial line $n1)"
waitre "$LAUNCHRE" 150 "$n1" && log "a driver line of the apitest came" || { log "no driver line of the apitest in 150 s (its output below says why)"; g shot s0-launch-no-driver-line >/dev/null; }
for i in $(seq 1 240); do
    if pouch_text dsploop-out.txt | grep -q "tests executed"; then
        log "the apitest ended its output after about $((2 * i)) s: $(pouch_text dsploop-out.txt | tail -1 | cut -c1-200)"
        break
    fi
    sleep 2
done
pouch_text dsploop-out.txt | grep -q "tests executed" || log "!! the apitest's output shows no 'tests executed' line in 495 s"
cmd dsploop-rc.txt "echo %ERRORLEVEL%" 8
log "the apitest's output as the guest wrote it (dsploop-out.txt):"
pouch_text dsploop-out.txt | cut -c1-330 | tee -a "$EV/driver.log"
log "driver lines of the apitest (after serial line $n1):"
norm | tail -n +"$((n1 + 1))" | grep -aE "intcdsp\.sys: (endpoint|stream )|dsppcm\.sys|latency|clock stalled|interrupt storm|Work queue|Fatal|bugcheck" | cut -c1-330 | tee -a "$EV/driver.log"
g shot s1-after-dsploop >/dev/null
# the MMDevice enumerator's own registry (read only): which render and capture endpoints it holds, with their states
cmd reg-mmdev-render.txt "reg query HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\MMDevices\\Audio\\Render /s" 20
cmd reg-mmdev-capture.txt "reg query HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\MMDevices\\Audio\\Capture /s" 20
log "MMDevices\\\\Audio\\\\Render: $(pouch_text reg-mmdev-render.txt | wc -l) lines, $(pouch_text reg-mmdev-render.txt | grep -c '^HKEY') keys, DeviceState values: $(pouch_text reg-mmdev-render.txt | grep -a DeviceState | tr -s ' ' | tr '\n' ';')"
log "MMDevices\\\\Audio\\\\Capture: $(pouch_text reg-mmdev-capture.txt | wc -l) lines, $(pouch_text reg-mmdev-capture.txt | grep -c '^HKEY') keys, DeviceState values: $(pouch_text reg-mmdev-capture.txt | grep -a DeviceState | tr -s ' ' | tr '\n' ';')"

# one pnputil command: its text to the data disk, the serial lines, whether and when it returned
#   pnpline <disable|enable> <instance id> <expected serial regex> <wait for it s> <label>
pnpline() {
    f="attrib-$5.txt"
    n=$(lines); t0=$(date +%s)
    g type "pnputil /$1-device \"$2\" > %POUCHDRV%:\\$f 2>&1"; g key ret
    # the expected serial line or the command's own text, whichever comes first (bounded by the wait)
    r=""
    for i in $(seq 1 $(( $4 / 2 ))); do
        if norm | tail -n +"$((n + 1))" | grep -aEq "$3"; then r="its line came"; break; fi
        [ -n "$(pouch_text "$f")" ] && break
        sleep 2
    done
    [ -n "$r" ] || r="no such line in $4 s"
    for i in $(seq 1 120); do
        [ -n "$(pouch_text "$f")" ] && break
        sleep 2
    done
    t1=$(( $(date +%s) - t0 ))
    if [ -n "$(pouch_text "$f")" ]; then
        e="the command returned: $(pouch_text "$f" | tr '\n' ' ' | cut -c1-280)"
    else
        e="the command did NOT return in about $t1 s (no text on the data disk)"
    fi
    log "$1 $5: $r; about $t1 s after Enter: $e"
    norm | tail -n +"$((n + 1))" | grep -aE "PNP_Disable|DisableDevice|Safe removal|dsppcm\.sys|intcdsp\.sys|umpnpmgr|kmixer|sysaudio|wdmaud|portcls|HDAUDIO|hdaudbus|err:|ERR:|Assertion|clock stalled|Work queue|Fatal|bugcheck" \
        | grep -av "boot .*after" | cut -c1-330 | tee -a "$EV/driver.log"
    sleep 3
    g shot "s-attrib-after-$5" >/dev/null
    [ -n "$(pouch_text "$f")" ]
}

log "== the attribution, TESTING.md run 3 (ii)"
if pnpline disable "$CHILD" "Safe removal: INTCDSP" 60 child-disable; then
    if pnpline enable "$CHILD" "dsppcm\.sys: endpoint .* registered as" 120 child-enable; then
        sleep 10
        if pnpline disable "$CODEC" "Safe removal: HDAUDIO" 60 codec-disable; then
            if pnpline enable "$CODEC" "HDAUDIO: codec 0 vendor" 120 codec-enable; then
                sleep 5
                if pnpline disable "$ID" "Safe removal: CSAUDIO" 60 dsp-disable; then
                    sleep 5
                    alive dsp-disabled && log "console after the DSP device's disable: answering"
                    g shot s-attrib-end >/dev/null
                fi
            fi
        fi
    fi
fi
log "== the last 25 serial lines of the attribution:"
norm | tail -25 | cut -c1-260 | tee -a "$EV/driver.log"
log "== the commands' own texts (the data disk):"
for x in child-disable child-enable codec-disable codec-enable dsp-disable; do
    [ -n "$(pouch_text "attrib-$x.txt")" ] && { log "attrib-$x.txt: $(pouch_text "attrib-$x.txt" | tr '\n' ' ' | cut -c1-280)"; }
done
# the S5: attempted, and bounded
g mon system_powerdown >/dev/null
if waitre "Entering sleep state S5" 120 0; then
    wait $LR
    log "VM $RUN ended: $(grep -a 'qemu exited' "$EV/lib-run.out")"
else
    log "!! no S5 in 120 s after the power button; the VM is terminated"
    g stop
    wait $LR
    log "VM $RUN ended: $(grep -a 'qemu exited' "$EV/lib-run.out")"
fi
log "boot3 done"
