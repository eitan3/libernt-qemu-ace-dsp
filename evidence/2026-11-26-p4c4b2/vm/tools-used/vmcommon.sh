#!/bin/bash
# vmcommon.sh -- sourced by the boot scripts of the p4c4b round, as the p4c4b2 round runs it: the image
# directory, the log paths and the default overlay changed, nothing else (throwaway; kept under
# evidence/2026-11-26-p4c4b2/vm/tools-used for the record).  Everything the scripts do to
# the guest goes through tools/guest.sh (the monitor's sendkey) and the serial log; no
# screenshot is read to decide anything.  The text the guest writes -- the device lists,
# the hash of the apitest, the apitest's own lines -- goes to the VM's data disk: a FAT16
# partition made by make-pouch.sh that carries dsploop_apitest.exe in; the host reads it
# back with mtools while the VM runs and after it ended.
#   RUN      the run's name under /tmp/qad-ev/p4c4b2/ (the live logs, on tmpfs)
#   OVERLAY  disk/<name>.qcow2 of the project (default p4c4b2)
set -u
QAD=<project>
IMG=$HOME/libernt-build-logs/test-audio-intel-sst-p4c4b2-a81cf9e65cf
T=/tmp/qad-ev/p4c4b2/tools
ID='CSAUDIO\ADSP&CTLR_VEN_8086&CTLR_DEV_7F50\4&aeefd634&0&1000000000'
CHILD='INTCDSP\PCM&CTLR_VEN_8086&CTLR_DEV_7F50\5&4D9FAD45&0&00'
CODEC='HDAUDIO\FUNC_01&VEN_1AF4&DEV_0022&SUBSYS_1AF40022&REV_1001\4&AEEFD634&0&0001'   # as the guest lists it (enum-media.txt of r1); p4c4b's TESTING.md and the script had AEFFD634
KEY='HKLM\SYSTEM\CurrentControlSet\Services\intcdsp\Settings'
OVERLAY="${OVERLAY:-p4c4b2}"
EV=/tmp/qad-ev/p4c4b2/$RUN
mkdir -p "$EV"
POUCH="${POUCH-/tmp/qad-ev/p4c4b2/pouch/$RUN.img}"   # POUCH= (set, empty): no data disk; XDRIVE: a -drive spec in place of the pouch
POUCHOFF=32256                 # the FAT16 partition's first byte (sector 63)
SOCK=""
LR=""
LCP=""
PDRV=""
log() { printf '%s %s\n' "$(date -u +%FT%TZ)" "$*" | tee -a "$EV/driver.log"; }
g() { (cd "$QAD" && tools/guest.sh "$EV" "$@"); }
norm() { sed "s/\x1b\[[0-9;]*[A-Za-z]//g" "$EV/serial.log" 2>/dev/null | tr -d "\0"; }
lines() { norm 2>/dev/null | wc -l; }
pouch_text() { mtype -i "$POUCH@@$POUCHOFF" "::$1" 2>/dev/null | tr -d '\r'; }
pouch_ls() { mdir -i "$POUCH@@$POUCHOFF" ::/ 2>/dev/null; }

# start the VM as every evidence run of the project: q35, TCG, -smp 1, ICOUNT=1, the installed
# system on the overlay (no cdrom), TRACE=1, QTESTSOCK=1, and the data disk of this VM on the
# next SATA port; the wall-clock cap is far above anything the script waits for (the script ends
# the VM itself, by the ACPI power button)
start_vm() {
    XD=""
    if [ -n "${XDRIVE:-}" ]; then XD="$XDRIVE"
    elif [ -n "$POUCH" ]; then
        [ -f "$POUCH" ] || bash "$T/make-pouch.sh" "$POUCH" > "$EV/pouch-made.out" 2>&1 || { log "!! no data disk"; exit 2; }
        XD="file=$POUCH,format=raw,if=ide,index=2,media=disk"
    fi
    (cd "$QAD" && EVID="$EV" ISO="$IMG/LiberNT.iso" CDROM=none DISK="$QAD/disk/$OVERLAY.qcow2" \
        EXTRA_DRIVES="$XD" HDA="${HDA:-ace}" \
        ICOUNT=1 TRACE=1 QTESTSOCK=1 REBOOT="${REBOOT:-0}" WAIT="${WAIT:-3600}" bash lib-run.sh > "$EV/lib-run.out" 2>&1) &
    LR=$!
    for i in $(seq 1 90); do
        [ -f "$EV/sock-dir.txt" ] && [ -S "$(cat "$EV/sock-dir.txt" 2>/dev/null)/monitor.sock" ] && break
        sleep 1
    done
    SOCK=$(cat "$EV/sock-dir.txt")
    log "VM $RUN started (lib-run pid $LR, sockets $SOCK, data disk ${XDRIVE:-${POUCH:-none}})"
}

# the first-boot Setup wizard's three pages (README: language and keyboard, the account
# page's Skip, the component page's Cancel), closed by chords
wizard() {
    sleep "${1:-20}"
    g key tab tab ret; sleep 5
    g key ret; sleep 5
    g key tab tab tab ret; sleep 5
    log "wizard: tab tab ret, ret, tab tab tab ret sent"
}

# the console without the Start menu: the shell's Win+R hotkey (IDHK_RUN) opens the Run
# dialog; cmd.exe in it; the field is cleared first (home, shift-end)
console() {
    g key meta_l-r; sleep 4
    g key home shift-end
    g type "cmd.exe"; g key ret; sleep 10
    log "console: Win+R, cmd.exe"
}

regadd() { g type "reg add \"$KEY\" /v $1 /t $2 /d $3 /f"; g key ret; sleep "${4:-4}"; log "typed: reg add $1 = $3 ($2)"; }

# wait for a serial line (bounded); prints it with the host time
waitfor() { "$QAD/tools/waitline.sh" "$EV" "$1" "${2:-600}" "${3:-0}" | cut -c1-400 | tee -a "$EV/driver.log"; }

# which drive letter the guest gave the data disk: the console looks for the marker file on
# every letter and writes the one it found to the disk itself; PDRV holds it on the host
pouchfind() {
    g type "for %d in (C D E F G H I J) do @if exist %d:\pouch.tag set POUCHDRV=%d"; g key ret; sleep 3
    g type "echo %POUCHDRV% > %POUCHDRV%:\\drive.txt"; g key ret
    for i in $(seq 1 40); do
        PDRV=$(pouch_text drive.txt | tr -d ' \n')
        [ -n "$PDRV" ] && break
        sleep 1
    done
    if [ -n "$PDRV" ]; then log "data disk: drive $PDRV: in the guest ($(pouch_ls | grep -c 'pouch    tag') marker)"; return 0; fi
    log "!! the data disk got no drive letter the console could find (no drive.txt in 40 s)"
    return 1
}

# a typed command whose text output goes to a file on the data disk: totext <file> <command>
totext() { g type "$2 > %POUCHDRV%:\\$1"; g key ret; log "typed: $2 > $PDRV:\\$1"; }

# is the console answering?  a marker file is asked for and must show up on the host
alive() {
    n=$(pouch_ls | grep -c "alive")
    g type "echo alive > %POUCHDRV%:\\alive-$1.txt"; g key ret
    for i in $(seq 1 25); do
        [ "$(pouch_ls | grep -c "alive")" -gt "$n" ] && { log "console answering after $1 (alive-$1.txt, $i s)"; return 0; }
        sleep 1
    done
    log "!! the console did not answer after $1 (no alive-$1.txt in 25 s)"
    return 1
}

# the monitor is one connection at a time: while livecap.py runs (it holds it from before
# the Enter it sends itself), nothing else may use guest.sh
wait_livecap() { wait "$LCP"; log "livecap rc=$?"; LCP=""; }

# end the VM by the ACPI power button and wait for lib-run.sh
s5() {
    [ -n "$LCP" ] && wait_livecap
    g mon system_powerdown >/dev/null
    wait $LR
    log "VM $RUN ended: $(grep -a 'qemu exited' "$EV/lib-run.out")"
}
