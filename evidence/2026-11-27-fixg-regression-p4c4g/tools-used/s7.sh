#!/bin/bash
# s7.sh -- S7 on the VM r-stream.sh left running: the quick-settings flyout (Win+A) and the volume
# flyout (a volume key), each opened, one screendump, closed with Esc and a screendump after;
# then the console answers.  (The pane menu follows by hand: it needs a click whose place is read
# from the first screendump.)
set -u
RUN=r-s6
. /tmp/c6g/tools/vmcommon.sh
SOCK=$(cat "$EV/sock-dir.txt")
n0=$(lines)
log "S7: Win+A (the quick-settings flyout)"
g key meta_l-a; sleep 6
g shot s7-1-quick-settings
g key esc; sleep 3
g shot s7-2-after-esc
log "S7: volumeup (the volume flyout)"
g key volumeup; sleep 5
g shot s7-3-volume
g key esc; sleep 3
g shot s7-4-after-esc
alive s7 >/dev/null 2>&1 && log "S7: the console answers after the two flyouts" || log "S7: !! the console does not answer after the two flyouts"
log "S7: driver lines in the while (after serial line $n0): $(norm | tail -n +"$((n0 + 1))" | grep -ac 'intcdsp\.sys\|dsppcm\.sys\|hdaudbus\.sys\|mmdevapi\|wdmaud'); stop lines: $(norm | grep -ac 'The system has been stopped'); fatal: $(grep -acE 'Fatal System Error|bugcheck' "$EV/serial.log"); ace_unexpected: $(grep -ac ace_unexpected "$EV/qemu-dbg.log")"
norm | tail -n +"$((n0 + 1))" | cut -c1-200 | head -20 | sed 's/^/    /'
