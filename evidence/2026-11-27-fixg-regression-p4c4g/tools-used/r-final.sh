#!/bin/bash
# r-final.sh -- S8 of the p4c4g round on the VM r-stream.sh left running (its lib-run pid in
# $EV/lib-run.pid): `shutdown -s -t 0` typed in the console, QEMU must exit by itself (bounded);
# then one more boot from the same disk: the desktop's line, a console that answers, no stop line;
# ended by the ACPI power button.
set -u
RUN=r-s6
. /tmp/c6g/tools/vmcommon.sh
LR=$(cat "$EV/lib-run.pid")
SOCK=$(cat "$EV/sock-dir.txt")
g mon info status
n0=$(lines)
log "S8: shutdown -s -t 0 through the Run box (the console lost its focus to the flyouts of S7)"
g key esc; sleep 1
g key meta_l-r; sleep 4; g key home shift-end; sleep 1
g type "shutdown -s -t 0"; g key ret
t0=$(date +%s); r=""
while kill -0 "$LR" 2>/dev/null; do
    [ $(( $(date +%s) - t0 )) -ge 150 ] && { r="!! STILL RUNNING after 150 s"; break; }
    sleep 1
done
[ -z "$r" ] && r="QEMU exited $(( $(date +%s) - t0 )) s after the command"
log "S8: $r; the shutdown's own lines:"
norm | tail -n +"$((n0 + 1))" | grep -a -i -E "shutdown|power|Entering sleep|POSHUTDOWN|The system has been stopped" | cut -c1-200 | sed 's/^/    /' | tee -a "$EV/driver.log"
[ -z "$r" ] || { log "S8: ending the VM by the ACPI power button"; g mon system_powerdown >/dev/null; wait $LR 2>/dev/null; }
log "VM ended: $(grep -a 'qemu exited' "$EV/lib-run.out")"
log "S8b: one more boot from the same disk"
RUN=r-final
EV=/tmp/c6g/ev/$RUN; mkdir -p "$EV"
start_vm
waitre "Program Manager" 600 || { log "!! the desktop's line not seen in 600 s"; s5; exit 1; }
log "S8b: the desktop's line seen; AUTOCHK lines: $(norm | grep -ac 'AUTOCHK'); stop lines: $(norm | grep -ac 'The system has been stopped'); fatal: $(grep -acE 'Fatal System Error|bugcheck' "$EV/serial.log"); intcdsp.sys: boot ok: $(norm | grep -ac 'intcdsp.sys: boot ok'); topology: $(norm | grep -ac "topology 'sof-ipc4-loopback.tplg'"); audio child: $(norm | grep -ac 'audio child')"
sleep 10
console
pouchfind || { s5; exit 1; }
alive final && g shot s8b-desktop-after-boot >/dev/null
cmd s8b-enum-media.txt "pnputil /enum-devices /class Media /ids" 60
log "S8b: the child in enum-media: $(pouch_text s8b-enum-media.txt | grep -c 'INTCDSP') INTCDSP lines; stop lines: $(norm | grep -ac 'The system has been stopped'); fatal: $(grep -acE 'Fatal System Error|bugcheck' "$EV/serial.log"); ace_unexpected: $(grep -ac ace_unexpected "$EV/qemu-dbg.log")"
# S4/S5 criterion (4): after the reboot dsploop passes again
n1=$(lines)
mdel -i "$POUCH@@$POUCHOFF" "::/s8b-dsploop.txt" >/dev/null 2>&1
g type "%POUCHDRV%:\\dsploop_apitest.exe > %POUCHDRV%:\\s8b-dsploop.txt 2>&1"; g key ret
for i in $(seq 1 300); do [ -n "$(pouch_text s8b-dsploop.txt 2>/dev/null)" ] && { sleep 3; break; }; sleep 1; done
log "S8b: dsploop after the reboot: $(pouch_text s8b-dsploop.txt | grep -a -E 'depths compared|tests executed' | tr '\n' ' ' | cut -c1-200); the stream lines of it: $(norm | tail -n +"$((n1 + 1))" | grep -ac 'stream 1 opened') opens, ipc lines $(norm | tail -n +"$((n1 + 1))" | grep -ac 'intcdsp.sys: ipc:'), held/freed/tag lines $(norm | tail -n +"$((n1 + 1))" | grep -ac -E 'held|freed under|tag')"
s5
log "r-final done"
