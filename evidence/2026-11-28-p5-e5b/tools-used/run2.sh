#!/bin/bash
# run2.sh <ev dir> <pouch img> <file> <command> [max wait s] -- type the command into the console in front with its
# output to the data disk (<POUCHDRV> is the letter in the pouch's drive.txt); wait for the file, print it, then the
# serial lines between (not DIAG-PNP).
EV=$1; POUCH=$2; F="$3"; C="$4"; W="${5:-120}"; export RUN=$(basename "$EV")
DRV=$(mtype -i "$POUCH@@32256" ::/drive.txt 2>/dev/null | tr -d ' \r\n')
[ -n "$DRV" ] || { echo "!! no drive letter"; exit 2; }
N0=$(sed "s/\x1b\[[0-9;]*[A-Za-z]//g" "$EV/serial.log" | tr -d "\0\r" | wc -l)
mdel -i "$POUCH@@32256" "::$F" >/dev/null 2>&1
bash /tmp/e5b/g.sh type "$C > ${DRV}:\\$F 2>&1" > /dev/null
bash /tmp/e5b/g.sh key ret > /dev/null
for i in $(seq 1 "$W"); do
    [ -n "$(mtype -i "$POUCH@@32256" "::$F" 2>/dev/null | grep -a 'tests executed')" ] && { sleep 2; break; }
    sleep 1
done
echo "== $C: output after about $i s"
mtype -i "$POUCH@@32256" "::$F" 2>/dev/null | tr -d '\r' | tee "$EV/$F" | head -${LINES:-200}
sleep 3
N1=$(sed "s/\x1b\[[0-9;]*[A-Za-z]//g" "$EV/serial.log" | tr -d "\0\r" | wc -l)
echo "== the serial lines from $N0 to $N1 (not DIAG-PNP):"
sed "s/\x1b\[[0-9;]*[A-Za-z]//g" "$EV/serial.log" | tr -d "\0\r" | tail -n +"$((N0 + 1))" | head -n $((N1 - N0)) | grep -a -v "DIAG-PNP" | cut -c1-500 | tee -a "$EV/serial-parts.log" | head -${SLINES:-60}
date +%H:%M:%S
