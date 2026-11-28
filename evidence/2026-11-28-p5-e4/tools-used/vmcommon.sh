#!/bin/bash
# vmcommon.sh -- the E4 round's: the E3 round's vmcommon.sh (evidence/2026-11-28-p5-e3/tools-used) with
# the live-log root, the tools directory and the data disk's path changed, and one fix (N13-10): norm() strips
# the CR as well as the NUL, so a pattern anchored at a line's end ($, as the self-test's `... ok$`) matches
# the serial log's CR LF lines; the E2 and E3 scripts counted such rows as 0.  Itself from the p4c4g regression
# round's (evidence/2026-11-27-fixg-regression-p4c4g/tools-used/vmcommon.sh).  A serial-line
# wait whose status means what it says (waitre); a typed command whose own text goes to the data
# disk (cmd); no text is read from a screenshot.  Everything the scripts do to the guest goes
# through tools/guest.sh (the monitor's sendkey) and the serial log.  The text the guest writes
# goes to the VM's data disk: a FAT16 partition made by make-pouch.sh that carries dsploop_apitest.exe
# in; the host reads it back with mtools while the VM runs and after it ended.  The monitor serves
# one client at a time: nothing else may use guest.sh while a step runs.
#   RUN      the run's name under /tmp/e4/ev/ (the live logs, on tmpfs)
#   OVERLAY  disk/<name>.qcow2 of the project (default p5e3)
#   IMG      the staged image directory (default: p5e3's; the E4 round names p5e4's)
set -u
QAD=<project>
IMG="${IMG:-<home>/libernt-build-logs/test-audio-intel-sst-p5e3-ae97c6a7a3e}"
T=/tmp/e4/tools
ID='CSAUDIO\ADSP&CTLR_VEN_8086&CTLR_DEV_7F50\4&aeefd634&0&1000000000'
KEY='HKLM\SYSTEM\CurrentControlSet\Services\intcdsp\Settings'
OVERLAY="${OVERLAY:-p5e3}"
EV=/tmp/e4/ev/$RUN
mkdir -p "$EV"
POUCH="${POUCH-/tmp/e4/pouch/$RUN.img}"
POUCHOFF=32256                 # the FAT16 partition's first byte (sector 63)
SOCK=""
LR=""
PDRV=""
log() { printf '%s %s\n' "$(date -u +%FT%TZ)" "$*" | tee -a "$EV/driver.log"; }
g() { (cd "$QAD" && tools/guest.sh "$EV" "$@"); }
norm() { sed "s/\x1b\[[0-9;]*[A-Za-z]//g" "$EV/serial.log" 2>/dev/null | tr -d "\0\r"; }
lines() { norm 2>/dev/null | wc -l; }
# the model's registers over qtest (reads only), as tools/cycle.sh prints them
st() { python3 "$QAD/tools/qtest.py" "$(cat "$EV/sock-dir.txt")/qtest.sock" adspcs dsp2cxctl inten irqsts hfhipcie hfipcxtdr hfipcxida hfipcxctl hfipcxtddy fsr | awk '{printf "%s=%s ", $NF, substr($4, 11, 8)}'; echo; }
pouch_text() { mtype -i "$POUCH@@$POUCHOFF" "::$1" 2>/dev/null | tr -d '\r'; }
pouch_ls() { mdir -i "$POUCH@@$POUCHOFF" ::/ 2>/dev/null; }
# the model's fault property and any other property of the device, over QMP (set-fault.sh)
setfault() { (cd "$QAD" && bash ./set-fault.sh "$EV" "$@" > "$EV/setfault-$1-${2:-}.out" 2>&1); }

# start the VM as every evidence run of the project: q35, TCG, -smp 1, ICOUNT=1, the installed
# system on the overlay (no cdrom), TRACE=1, QTESTSOCK=1, and the data disk of this VM on the
# next SATA port; the wall-clock cap is far above anything the script waits for (the script ends
# the VM itself, by the ACPI power button)
start_vm() {
    XD=""
    if [ -n "$POUCH" ]; then
        [ -f "$POUCH" ] || { mkdir -p "$(dirname "$POUCH")"; bash "$T/make-pouch.sh" "$POUCH" > "$EV/pouch-made.out" 2>&1 || { log "!! no data disk"; exit 2; }; }
        XD="file=$POUCH,format=raw,if=ide,index=2,media=disk"
    fi
    (cd "$QAD" && EVID="$EV" ISO="$IMG/LiberNT.iso" CDROM=none DISK="$QAD/disk/$OVERLAY.qcow2" \
        EXTRA_DRIVES="$XD" HDA=ace \
        ICOUNT=1 TRACE=1 QTESTSOCK=1 REBOOT=1 WAIT="${WAIT:-3600}" bash lib-run.sh > "$EV/lib-run.out" 2>&1) &
    LR=$!
    for i in $(seq 1 90); do
        [ -f "$EV/sock-dir.txt" ] && [ -S "$(cat "$EV/sock-dir.txt" 2>/dev/null)/monitor.sock" ] && break
        sleep 1
    done
    SOCK=$(cat "$EV/sock-dir.txt")
    log "VM $RUN started (lib-run pid $LR, sockets $SOCK, data disk $POUCH)"
}

# the first-boot Setup wizard's three pages (the storage page's Next, the account page's Skip,
# the component page's Cancel), closed by chords
wizard() {
    sleep "${1:-20}"
    g key tab tab ret; sleep 5
    g key ret; sleep 5
    g key tab tab tab ret; sleep 5
    log "wizard: tab tab ret, ret, tab tab tab ret sent"
}

# the console without the Start menu: the shell's Win+R hotkey opens the Run dialog; cmd.exe in it
console() {
    g key meta_l-r; sleep "${1:-4}"
    g key home shift-end
    g type "cmd.exe"; g key ret; sleep "${2:-10}"
    log "console: Win+R, cmd.exe"
}

regadd() { g type "reg add \"$KEY\" /v $1 /t $2 /d $3 /f"; g key ret; sleep "${4:-4}"; log "typed: reg add $1 = $3 ($2)"; }

# a serial-line wait whose status means what it says: waitre <regex> <seconds> [from line]
waitre() {
    local t0=$(date +%s) from=${3:-0}
    while :; do
        if norm | tail -n +"$((from + 1))" | grep -aEq "$1"; then
            norm | tail -n +"$((from + 1))" | grep -aE "$1" | head -3 | cut -c1-400 | while IFS= read -r l; do printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$l"; done | tee -a "$EV/driver.log"
            return 0
        fi
        [ $(( $(date +%s) - t0 )) -ge "$2" ] && { log "-- not seen in $2 s (after line $from): $1"; return 1; }
        sleep 2
    done
}

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

# a typed command whose text output goes to a file on the data disk, with the time from the
# Enter to the file's arrival (an earlier file of the name is deleted first): cmd <file> <command> [max wait s]
cmd() {
    local i
    mdel -i "$POUCH@@$POUCHOFF" "::$1" >/dev/null 2>&1
    g type "$2 > %POUCHDRV%:\\$1 2>&1"; g key ret
    for i in $(seq 1 "${3:-60}"); do
        [ -n "$(pouch_text "$1" 2>/dev/null)" ] && { sleep 1; break; }
        sleep 1
    done
    log "$2: output after about $i s: $(pouch_text "$1" 2>/dev/null | tr '\n' ' ' | cut -c1-700)"
}

# is the console answering?  a marker file is asked for and must show up on the host
alive() {
    local n i
    n=$(pouch_ls | grep -c "alive")
    g type "echo alive > %POUCHDRV%:\\alive-$1.txt"; g key ret
    for i in $(seq 1 25); do
        [ "$(pouch_ls | grep -c "alive")" -gt "$n" ] && { log "console answering after $1 (alive-$1.txt, $i s)"; return 0; }
        sleep 1
    done
    log "!! the console did not answer after $1 (no alive-$1.txt in 25 s)"
    return 1
}

# end the VM by the ACPI power button and wait for lib-run.sh
s5() {
    g mon system_powerdown >/dev/null
    wait $LR
    log "VM $RUN ended: $(grep -a 'qemu exited' "$EV/lib-run.out")"
}
