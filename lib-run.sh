#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# qemu-ace-dsp: the shared VM launcher of run.sh and run-control.sh.
#
# The LiberNT P2b image under the self-built QEMU: q35, pure TCG (no KVM on
# this VM), -cpu max, -smp 1 (the -smp 2 TLB bugcheck is tracked separately and
# a run with another SMP value is never evidence), 2 GB RAM, OVMF pflash. The
# ISO's boot entry already logs to COM1 at 115200, so the serial console is
# captured to a file; the monitor (HMP) and a QMP socket are unix sockets in
# the evidence directory for snapshot.sh / set-fault.sh. The VM is time-boxed
# and writes only under the evidence directory (plus the qcow2 overlay it is
# given, which is the guest's to write).
#
# This work is licensed under the terms of the GNU GPL, version 2 or later.
# See the COPYING file in the top-level directory.
#
# Variables (environment):
#   EVID       evidence directory (default evidence/<date>/run-<time>)
#   ISO        the live ISO (default: the P2b bootcd.iso of the build logs)
#   DISK       optional disk image attached as the first hard disk (qcow2 overlay)
#   BOOT       d (cdrom, default) or c (disk)
#   HDA        ace | ich9 | none      (which HDA controller the VM gets)
#   FAULT      boot-time fault of the ACE model (-device intel-hda-ace,fault=...)
#   ACE_ARGS   more -device intel-hda-ace arguments, comma separated
#   TRACE      1 -> -trace 'ace_*' into qemu.log
#   WAIT       wall-clock cap in seconds (default 300)
#   STOP_ON    optional extended regex; the VM is stopped SETTLE seconds after a
#              serial line matches (the acceptance line of the stage under test)
#   SETTLE     seconds to keep running after STOP_ON matched (default 20)
#   REBOOT     1 -> drop -no-reboot (a guest reboot reboots; default: QEMU exits)
#   SMP        fixed at 1 (refuses any other value: never evidence)
set -u

QAD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD="$QAD/build"
QEMU="${QEMU:-$BUILD/qemu-system-x86_64}"
BIOSDIR="${BIOSDIR:-$BUILD/pc-bios}"
FW="$QAD/firmware"
ISO="${ISO:-/home/megan/libernt-build-logs/test-audio-intel-sst-p2b-51f9711a/bootcd.iso}"
SMP="${SMP:-1}"
HDA="${HDA:-ace}"
WAIT="${WAIT:-300}"
SETTLE="${SETTLE:-20}"

case "$SMP" in 1) ;; *) echo "run: SMP=$SMP refused: every evidence run pins -smp 1 (see plan §2(a), the 0x1DB bugcheck)" >&2; exit 2;; esac
[ -x "$QEMU" ] || { echo "run: no $QEMU -- run build.sh first" >&2; exit 2; }
[ -r "$ISO" ] || { echo "run: ISO not readable: $ISO" >&2; exit 2; }

EV="${EVID:-$QAD/evidence/$(date -u +%F)/run-$(date -u +%H%M%S)-$HDA}"
mkdir -p "$EV"
EV="$(cd "$EV" && pwd)"
# unix sockets are limited to 108 bytes of path: keep them in a short /tmp dir
SOCK=/tmp/qad-vm.$$
rm -rf "$SOCK"; mkdir -p "$SOCK"
cp -f "$FW/OVMF_VARS.4m.fd" "$EV/OVMF_VARS.fd"
trap 'rm -rf "$SOCK"' EXIT

args=("$QEMU" -L "$BIOSDIR"
      -machine q35 -accel tcg,thread=multi -cpu max -smp 1 -m 2048
      -drive if=pflash,format=raw,readonly=on,file="$FW/OVMF_CODE.4m.fd"
      -drive if=pflash,format=raw,file="$EV/OVMF_VARS.fd"
      -audiodev none,id=snd0 -display none -vga std -nic none
      -serial "file:$EV/serial.log"
      -monitor "unix:$SOCK/monitor.sock,server,nowait"
      -qmp "unix:$SOCK/qmp.sock,server,nowait"
      -pidfile "$SOCK/qemu.pid"
      -d cpu_reset,guest_errors -D "$EV/qemu-dbg.log")
if [ -n "${DISK:-}" ]; then
    args+=(-drive "file=$DISK,if=ide,index=0,media=disk,format=qcow2")
fi
if [ "${CDROM:-$ISO}" != none ]; then
    args+=(-cdrom "${CDROM:-$ISO}" -boot "order=${BOOT:-d}")
fi
case "$HDA" in
    ace)
        dev="intel-hda-ace,bus=pcie.0,addr=1b.0,id=ace"
        [ -n "${FAULT:-}" ] && dev+=",fault=$FAULT"
        [ -n "${ACE_ARGS:-}" ] && dev+=",$ACE_ARGS"
        args+=(-device "$dev" -device hda-duplex,audiodev=snd0)
        ;;
    ich9) args+=(-device ich9-intel-hda,bus=pcie.0,addr=1b.0,id=hda0 -device hda-duplex,audiodev=snd0) ;;
    none) ;;
    *) echo "run: HDA must be ace, ich9 or none" >&2; exit 2 ;;
esac
[ "${TRACE:-0}" = 1 ] && args+=(-trace 'ace_*')
[ "${REBOOT:-0}" = 1 ] || args+=(-no-reboot)

date -u +%FT%TZ > "$EV/start.txt"
printf '%s\n' "${args[@]}" > "$EV/qemu-args.txt"
echo "evidence: $EV"
echo "$SOCK" > "$EV/sock-dir.txt"
echo "command:  $(printf '%q ' "${args[@]}")" > "$EV/command.txt"

"${args[@]}" > "$EV/qemu.log" 2>&1 &
qpid=$!
t0=$(date +%s)
stopped_by=none
# Poll until QEMU exits by itself (a guest reboot under -no-reboot), until the
# STOP_ON line shows up in the serial log, or until the wall-clock cap.
while kill -0 "$qpid" 2>/dev/null; do
    if [ $(( $(date +%s) - t0 )) -ge "$WAIT" ]; then
        stopped_by=cap
        break
    fi
    if [ -n "${STOP_ON:-}" ] && grep -Eq "$STOP_ON" "$EV/serial.log" 2>/dev/null; then
        sleep "$SETTLE"
        stopped_by=marker
        break
    fi
    sleep 2
done
[ "$stopped_by" = none ] || {
    # a screenshot before the VM goes away, when asked to (SNAP=1)
    if [ "${SNAP:-0}" = 1 ] && [ -S "$SOCK/monitor.sock" ]; then
        python3 "$QAD/tools/mon.py" "$SOCK/monitor.sock" "screendump $EV/desktop.png -f png" > /dev/null 2>&1
    fi
    kill -TERM "$qpid" 2>/dev/null
}
wait "$qpid"
rc=$?
date -u +%FT%TZ > "$EV/end.txt"
echo "qemu exited rc=$rc ($stopped_by) at $(cat "$EV/end.txt"); wall $(( $(date +%s) - t0 )) s"
echo "--- serial lines of the drivers under test (hdaudbus.sys / intcdsp.sys):"
grep -aE "hdaudbus\.sys|intcdsp\.sys" "$EV/serial.log" | sed 's/\x1b\[[0-9;]*[A-Za-z]//g' | head -60
echo "--- device trace: $(grep -ac 'ace_' "$EV/qemu-dbg.log" 2>/dev/null || echo 0) ace_* lines, $(grep -ac 'ace_unexpected' "$EV/qemu-dbg.log" "$EV/qemu.log" 2>/dev/null | awk -F: '{s+=$2} END {print s+0}') ace_unexpected (in $EV/qemu-dbg.log, the -D log), $(grep -ac 'Fatal System Error\|bugcheck' "$EV/serial.log" 2>/dev/null || echo 0) fatal lines in serial.log"
exit "$rc"
