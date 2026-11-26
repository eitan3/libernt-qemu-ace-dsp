#!/bin/bash
# collect.sh -- copy the VM runs of the p4c4b round from /tmp (tmpfs) into the project's evidence
# directory.  Re-runnable: a run is copied again each time (the last VM is copied after it ended).
#   collect.sh <evidence-dir>/vm <run-dir>...
# Per run: the driver log, the serial log raw and normalised (ANSI escapes, NULs and CRs removed:
# serial.txt), the command line and arguments, lib-run's output, start/end, the -D trace log,
# the stops and reads of the bugcheck tools, the text the guest wrote to its data disk, the
# screenshots and the live-read windows.  Left out: OVMF_VARS.fd, the socket directory note, an
# empty qemu.log; what was kept is listed in contents.txt.
set -u
DEST="${1:?usage: collect.sh <dest> <run-dir>...}"; shift
for R in "$@"; do
    N=$(basename "$R")
    D="$DEST/$N"
    mkdir -p "$D"
    for f in driver.log command.txt qemu-args.txt lib-run.out start.txt end.txt qemu-dbg.log \
             bugpause-check.out bugpause-crash.out bugpause-crash2.out bugread.txt bugread-2.txt \
             bugread.out bugread-2.out pouch-made.out livecap.out \
             exe-hash.txt enum-media.txt enum-endpoint.txt dsploop-out.txt dsploop-rc.txt \
             cycles.log selftest-lines.txt driver-lines.txt ace-audio-lines.txt ace-trace.txt; do
        [ -f "$R/$f" ] && cp -f "$R/$f" "$D/"
    done
    [ -f "$R/serial.log" ] && { cp -f "$R/serial.log" "$D/serial.log"
        sed "s/\x1b\[[0-9;]*[A-Za-z]//g" "$R/serial.log" | tr -d "\0" | tr -d "\r" > "$D/serial.txt"; }
    for f in "$R"/*.png "$R"/*.bin "$R"/livecap-*.txt; do
        [ -f "$f" ] && cp -f "$f" "$D/"
    done
    ( cd "$D" && ls -la --time-style=+%FT%TZ | awk 'NR>1 && $7 != "." && $7 != ".." {print $5, $7}' ) > "$D/contents.txt"
    echo "== $N: $(wc -l < "$D/contents.txt") files, $(du -sk "$D" | cut -f1) KiB"
done
