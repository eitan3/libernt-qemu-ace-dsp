#!/bin/bash
# handminus.sh -- by hand in the proof3 VM: a new console, the DSP's endpoint as wdmaud's DefaultOutput (the value
# read back to the data disk), then Win+D and volumedown x4; the driver's gain lines of the last 40 serial lines
export RUN=proof3
EV=/tmp/e5b/ev/proof3
bash /tmp/e5b/g.sh key meta_l-r > /dev/null; sleep 4
bash /tmp/e5b/g.sh key home shift-end > /dev/null
bash /tmp/e5b/g.sh type "cmd.exe" > /dev/null; bash /tmp/e5b/g.sh key ret > /dev/null; sleep 10
bash /tmp/e5b/g.sh type 'reg add "HKCU\Software\Wine\Drivers\wdmaud.drv" /v DefaultOutput /t REG_SZ /d "{0.0.0.00000000}.{BDA7C5A8-F3C6-8B76-ABDB-D685E723178B}" /f' > /dev/null
bash /tmp/e5b/g.sh key ret > /dev/null; sleep 5
bash /tmp/e5b/g.sh shot hand-reg > /dev/null
bash /tmp/e5b/g.sh key meta_l-d > /dev/null; sleep 3
for i in 1 2 3 4; do bash /tmp/e5b/g.sh key volumedown > /dev/null; sleep 3; done
sleep 3
sed "s/\x1b\[[0-9;]*[A-Za-z]//g" "$EV/serial.log" | tr -d "\0\r" | grep -a 'gain: ' | tail -5 | cut -c1-120
date +%H:%M:%S
