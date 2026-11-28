#!/bin/bash
# run1.sh <file> <command> [max wait s] -- in the console in front: set WINEDEBUG=warn+mmdevapi (own line), then the command
# with its output to F:\<file>; wait for the file on the host (mtools), print it.  The serial lines between are logged.
EV=/tmp/e5b/ev/probe2
POUCH=/tmp/e5b/pouch/probe2.img
F="$1"; C="$2"; W="${3:-120}"
N0=$(sed "s/\x1b\[[0-9;]*[A-Za-z]//g" "$EV/serial.log" | tr -d "\0\r" | wc -l)
mdel -i "$POUCH@@32256" "::$F" >/dev/null 2>&1
bash /tmp/e5b/g.sh type "set WINEDEBUG=warn+mmdevapi" > /dev/null; bash /tmp/e5b/g.sh key ret > /dev/null; sleep 2
bash /tmp/e5b/g.sh type "$C > F:\\$F 2>&1" > /dev/null; bash /tmp/e5b/g.sh key ret > /dev/null
for i in $(seq 1 "$W"); do
    [ -n "$(mtype -i "$POUCH@@32256" "::$F" 2>/dev/null)" ] && { sleep 2; break; }
    sleep 1
done
echo "== $C: output after about $i s"
mtype -i "$POUCH@@32256" "::$F" 2>/dev/null | tr -d '\r' | tee "$EV/$F" | head -${LINES:-150}
sleep 3
N1=$(sed "s/\x1b\[[0-9;]*[A-Za-z]//g" "$EV/serial.log" | tr -d "\0\r" | wc -l)
echo "== the serial lines from $N0 to $N1 (not DIAG-PNP):"
sed "s/\x1b\[[0-9;]*[A-Za-z]//g" "$EV/serial.log" | tr -d "\0\r" | tail -n +"$((N0 + 1))" | head -n $((N1 - N0)) | grep -a -v "DIAG-PNP" | cut -c1-500 | tee -a "$EV/serial-parts.log" | head -${SLINES:-120}
date +%H:%M:%S
