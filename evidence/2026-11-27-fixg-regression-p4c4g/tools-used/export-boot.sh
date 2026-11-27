#!/bin/bash
# export-boot.sh -- the export boot of the two sticks (the run book's step 32 fallback): wait for
# the lock screen (a still frame under 40 KB, as the kernel's text screen is about 51 KB), sign in,
# open a console, type the lines of lines-x.txt (copy /y C:\logs\*.* D:\, dir C:\logs, dir D:\,
# exit), a screenshot, then Task Manager > Shut Down > Turn Off so the FAT write is flushed;
# waits for QEMU to exit.  env: EV, DISK, POUCH (as c6-run.sh)
set -u
T=/tmp/c6g/tools
: "${EV:?}" "${DISK:?}" "${POUCH:?}"
export EV DISK POUCH
$T/c6-run.sh
$T/wait-stable.sh x1w 95 150 10 > "$EV/.x1w" 2>&1; cat "$EV/.x1w"; rm -f "$EV/.x1w"
s=$(tail -n 1 "$EV/driver.log" | awk '{print $4}')
if [ "${s:-0}" -lt 15000 ]; then
    echo "export-boot: the still frame is $s bytes (not the lock screen); waiting once more" >&2
    $T/wait-stable.sh x1w 20 120 10
    s=$(tail -n 1 "$EV/driver.log" | awk '{print $4}')
fi
last=$(tail -n 1 "$EV/driver.log" | awk '{print $3}' | sed 's/\.png//')
printf '%s %s = the lock screen (still frame of %s bytes, read by size)\n' "$(date -u +%T)" "$last" "$s" >> "$EV/driver.log"
$T/signin.sh x1-02-signin-tile 30
$T/winr.sh cmd.exe 15
GUEST_TYPE_DELAY=0.2 $T/console.sh $T/lines-x1.txt 6
$T/c6.sh shot x1-03-after-export-copy
GUEST_TYPE_DELAY=0.2 $T/console.sh $T/lines-x2.txt 6
sleep 20
$T/tm-restart.sh x1-04-tm-turnoff-selected turnoff
$T/wait-exit.sh 150
echo "CPU resets in qemu-dbg.log: $(grep -ac 'CPU Reset' "$EV/qemu-dbg.log")"
