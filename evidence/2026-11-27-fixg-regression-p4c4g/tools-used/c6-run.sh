#!/bin/bash
# c6-run.sh -- the VM launcher of the C6 first-session flow (p4c4g LiberNT.img on a raw virtual
# stick): the p4c4e final pass's launcher (evidence/2026-11-27-c6-final-p4c4e/tools-used/c6-run.sh)
# unchanged but for its name.
#   NO serial port (the loader must not add DEBUGPORT=COM1): the owner's configuration,
#   q35, pure TCG, -cpu max, -smp 1, 2 GB RAM, OVMF pflash, -nic none, -vga std, no display
#   (the screen is read through the monitor's screendump), the ACE HDA model + hda-duplex,
#   ICOUNT as every evidence run (tcg,thread=single + icount shift=auto: the guest clock and
#   the model's timers advance together), reboots reboot (no -no-reboot), no qtest, no trace.
#   env: EV=<vm evidence dir>  DISK=<raw stick image>  POUCH=<data disk image or empty>
# The VM is started in the background (its own session); the script returns at once; nothing polls.
set -u
QAD=<project>
BUILD="$QAD/build"
QEMU="$BUILD/qemu-system-x86_64"
FW="$QAD/firmware"
EV="${EV:?EV=<evidence dir>}"
DISK="${DISK:?DISK=<raw stick image>}"
POUCH="${POUCH:-}"
if pgrep -f "$QEMU -L $BUILD/pc-bios" > /dev/null; then
    echo "REFUSED: a qemu-system-x86_64 of this project is already running (one QEMU at a time)" >&2
    pgrep -af "$QEMU -L $BUILD/pc-bios" | cut -c1-120 >&2
    exit 3
fi
mkdir -p "$EV"; EV="$(cd "$EV" && pwd)"
SOCK=/tmp/qad-cvm.$$
rm -rf "$SOCK"; mkdir -p "$SOCK"
cp -f "$FW/OVMF_VARS.4m.fd" "$EV/OVMF_VARS.fd"
args=("$QEMU" -L "$BUILD/pc-bios"
      -machine q35 -cpu max -smp 1 -m 2048
      -drive if=pflash,format=raw,readonly=on,file="$FW/OVMF_CODE.4m.fd"
      -drive if=pflash,format=raw,file="$EV/OVMF_VARS.fd"
      -audiodev none,id=snd0 -display none -vga std -nic none
      -monitor "unix:$SOCK/monitor.sock,server,nowait"
      -qmp "unix:$SOCK/qmp.sock,server,nowait"
      -pidfile "$SOCK/qemu.pid"
      -d cpu_reset,guest_errors -D "$EV/qemu-dbg.log"
      -drive "file=$DISK,if=ide,index=0,media=disk,format=raw")
if [ -n "$POUCH" ]; then
    args+=(-drive "file=$POUCH,format=raw,if=ide,index=2,media=disk")
fi
args+=(-accel tcg,thread=single -icount shift=auto,align=off,sleep=off
       -device intel-hda-ace,bus=pcie.0,addr=1b.0,id=ace -device hda-duplex,audiodev=snd0)
date -u +%FT%TZ > "$EV/start.txt"
printf '%s\n' "${args[@]}" > "$EV/qemu-args.txt"
echo "$SOCK" > "$EV/sock-dir.txt"
{ echo "command:"; printf '%q ' "${args[@]}"; echo; } > "$EV/command.txt"
setsid nohup "${args[@]}" > "$EV/qemu.log" 2>&1 < /dev/null &
echo "started qemu pid $! at $(cat "$EV/start.txt"); sockets $SOCK; evidence $EV; serial=none"
