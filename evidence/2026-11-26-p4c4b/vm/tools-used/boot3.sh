#!/bin/bash
# boot3.sh -- VM 3 of the p4c4b round: a plain boot with the endpoint registered, the apitest once
# more (no live read: the measurement a second time), then TESTING.md run 3 (ii), the disable
# attribution against this master's PnP semantics, scripted and one command at a time, each read
# from the serial log and from a marker file the console is asked for (the next typed command
# answered):
#   (a) the PCM child alone, then its enable; (b) the codec, then its enable; (c) the DSP device
#   with the child present.  A disable that stalls ends the sequence (the PnP manager is then
# busy for good); the exact last lines are recorded and the S5 is attempted.
set -u
RUN=r3-plainboot-attribution
. /tmp/qad-ev/p4c4b/tools/vmcommon.sh
log "boot3: $RUN on disk/$OVERLAY.qcow2"
start_vm
waitfor "topology 'sof-ipc4-loopback.tplg'|topology: none selected|clock stalled" 900
sleep 5
log "the boot's driver lines:"
norm | grep -aE "intcdsp\.sys: (SelfTest|BootDsp = |boot ok|topology: modules|audio child)|dsppcm\.sys: endpoint .* registered as|clock stalled|interrupt storm|Work queue|Fatal|bugcheck" | cut -c1-330 | tee -a "$EV/driver.log"
waitfor "Program Manager" 900
sleep 20
console
pouchfind || true
# the apitest a second time, without the live read
n1=$(lines)
totext dsploop-out.txt "%POUCHDRV%\\dsploop_apitest.exe"
for i in $(seq 1 240); do
    if pouch_text dsploop-out.txt | grep -q "tests executed"; then
        log "the apitest ended its output after about $((2 * i)) s: $(pouch_text dsploop-out.txt | tail -1)"
        break
    fi
    sleep 2
done
totext dsploop-rc.txt "echo %ERRORLEVEL%"
log "the apitest's output as the guest wrote it (dsploop-out.txt):"
pouch_text dsploop-out.txt | cut -c1-330 | tee -a "$EV/driver.log"
log "exit code line (dsploop-rc.txt): $(pouch_text dsploop-rc.txt | tr '\n' ' ')"
log "driver lines of the apitest (after serial line $n1):"
norm | tail -n +"$((n1 + 1))" | grep -aE "intcdsp\.sys: endpoint|intcdsp\.sys: stream |dsppcm\.sys|latency|clock stalled|interrupt storm|Work queue|Fatal|bugcheck" | cut -c1-330 | tee -a "$EV/driver.log"
g shot s1-after-dsploop >/dev/null

# one pnputil command and what the guest says of it
pnpline() {
    n=$(lines)
    g type "pnputil /$1-device \"$2\""; g key ret
    if waitfor "$3" "$4" "$n"; then r="completes (its line came)"; else r="STALLS (no such line in $4 s)"; fi
    log "$1 $5: $r"
    norm | tail -n +"$((n + 1))" | grep -aE "PNP_Disable|DisableDevice|Safe removal|dsppcm\.sys|intcdsp\.sys|umpnpmgr|kmixer|sysaudio|wdmaud|portcls|HDAUDIO|hdaudbus|err:|ERR:|Assertion|clock stalled|Work queue|Fatal|bugcheck" \
        | grep -av "boot .*after" | cut -c1-330 | tee -a "$EV/driver.log"
    sleep 3
    if alive "$5"; then log "console after $1 $5: answering"; else log "console after $1 $5: NOT answering"; fi
    g shot "s-attrib-after-$5" >/dev/null
    [ "$r" = "completes (its line came)" ]
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
# the S5: attempted, and bounded (a stalled PnP operation may keep the guest from shutting down)
g mon system_powerdown >/dev/null
if waitfor "Entering sleep state S5" 120; then
    wait $LR
    log "VM $RUN ended: $(grep -a 'qemu exited' "$EV/lib-run.out")"
else
    log "!! no S5 in 120 s after the power button; the VM is terminated"
    g stop
    wait $LR
    log "VM $RUN ended: $(grep -a 'qemu exited' "$EV/lib-run.out")"
fi
log "boot3 done"
