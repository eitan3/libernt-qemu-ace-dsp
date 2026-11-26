#!/bin/bash
# vmcommon.sh -- sourced by the four boot scripts of the p3c3b round (throwaway;
# kept under evidence/<date>/vm/tools-used for the record).  Everything the
# scripts do to the guest goes through tools/guest.sh (the monitor's sendkey)
# and the serial log; no screenshot is read to decide anything.
#   RUN      the run's name under /tmp/qad-ev/p3c3b/ (the live logs, on tmpfs)
#   OVERLAY  disk/<name>.qcow2 of the project (default p3c3b)
set -u
QAD=<project>
IMG=$HOME/libernt-build-logs/test-audio-intel-sst-p3c3b-d8f3a5bc81e
T=/tmp/qad-ev/p3c3b/tools
ID='CSAUDIO\ADSP&CTLR_VEN_8086&CTLR_DEV_7F50\4&aeefd634&0&1000000000'
KEY='HKLM\SYSTEM\CurrentControlSet\Services\intcdsp\Settings'
OVERLAY="${OVERLAY:-p3c3b}"
EV=/tmp/qad-ev/p3c3b/$RUN
mkdir -p "$EV"
SOCK=""
LR=""
log() { printf '%s %s\n' "$(date -u +%FT%TZ)" "$*" | tee -a "$EV/driver.log"; }
g() { (cd "$QAD" && tools/guest.sh "$EV" "$@"); }
norm() { sed "s/\x1b\[[0-9;]*[A-Za-z]//g" "$EV/serial.log" 2>/dev/null | tr -d "\0"; }
lines() { norm 2>/dev/null | wc -l; }

# start the VM exactly as every evidence run of the project: q35, TCG, -smp 1,
# ICOUNT=1, the installed system on the overlay (no cdrom), TRACE=1, QTESTSOCK=1;
# the wall-clock cap is far above anything the script waits for (the script ends
# the VM itself, by the ACPI power button)
start_vm() {
    (cd "$QAD" && EVID="$EV" ISO="$IMG/LiberNT.iso" CDROM=none DISK="$QAD/disk/$OVERLAY.qcow2" \
        ICOUNT=1 TRACE=1 QTESTSOCK=1 REBOOT="${REBOOT:-0}" WAIT="${WAIT:-3600}" bash lib-run.sh > "$EV/lib-run.out" 2>&1) &
    LR=$!
    for i in $(seq 1 90); do
        [ -f "$EV/sock-dir.txt" ] && [ -S "$(cat "$EV/sock-dir.txt" 2>/dev/null)/monitor.sock" ] && break
        sleep 1
    done
    SOCK=$(cat "$EV/sock-dir.txt")
    log "VM $RUN started (lib-run pid $LR, sockets $SOCK)"
}

# the first-boot Setup wizard's three pages (README: language and keyboard,
# the account page's Skip, the component page's Cancel), closed by chords
wizard() {
    sleep "${1:-20}"
    g key tab tab ret; sleep 5
    g key ret; sleep 5
    g key tab tab tab ret; sleep 5
    log "wizard: tab tab ret, ret, tab tab tab ret sent"
}

# the console without the Start menu: the shell's Win+R hotkey (IDHK_RUN) opens
# the Run dialog; cmd.exe in it; the field is cleared first (home, shift-end)
console() {
    g key meta_l-r; sleep 4
    g key home shift-end
    g type "cmd.exe"; g key ret; sleep 10
    log "console: Win+R, cmd.exe"
}

regadd() { g type "reg add \"$KEY\" /v $1 /t $2 /d $3 /f"; g key ret; sleep "${4:-4}"; log "typed: reg add $1 = $3 ($2)"; }
regdel() { g type "reg delete \"$KEY\" /v $1 /f"; g key ret; sleep "${2:-4}"; log "typed: reg delete $1"; }

# wait for a serial line (bounded); prints it with the host time
waitfor() { "$QAD/tools/waitline.sh" "$EV" "$1" "${2:-600}" "${3:-0}" | cut -c1-400 | tee -a "$EV/driver.log"; }

# end the VM by the ACPI power button and wait for lib-run.sh
s5() {
    g mon system_powerdown >/dev/null
    wait $LR
    log "VM $RUN ended: $(grep -a 'qemu exited' "$EV/lib-run.out")"
}
