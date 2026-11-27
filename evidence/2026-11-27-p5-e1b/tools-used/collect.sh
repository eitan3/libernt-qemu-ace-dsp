#!/bin/bash
# collect.sh <live VM dir> <dest dir> [png name ...] -- copy a lib-run.sh VM's evidence into the
# project's evidence tree: the raw serial log and a text copy (ANSI escapes, NULs and CRs
# removed), the driver log, the text the guest wrote to its data disk (every *.txt of the VM
# dir), the command line, the start and end lines, lib-run's output, the -d log gzipped, the
# named screenshots; contents.txt lists what was kept.  Paths inside the files are left as they
# are (normalise-evidence.sh runs over the tree at the end).
set -u
SRC="${1:?live vm dir}"; DST="${2:?dest dir}"; shift 2
mkdir -p "$DST"
cp -f "$SRC"/serial.log "$SRC"/driver.log "$SRC"/command.txt "$SRC"/qemu-args.txt "$SRC"/start.txt \
      "$SRC"/end.txt "$SRC"/lib-run.out "$SRC"/qemu.log "$SRC"/cycles.log "$SRC"/summary.txt \
      "$SRC"/*.out "$SRC"/*.txt "$DST"/ 2>/dev/null
[ -f "$SRC/serial.log" ] && tr -d '\r\0' < "$SRC/serial.log" | sed "s/\x1b\[[0-9;]*[A-Za-z]//g" > "$DST/serial.txt"
[ -f "$SRC/qemu-dbg.log" ] && gzip -9 -c "$SRC/qemu-dbg.log" > "$DST/qemu-dbg.log.gz"
for p in "$@"; do [ -f "$SRC/$p.png" ] && cp -f "$SRC/$p.png" "$DST/"; done
( cd "$DST" && ls -la | awk 'NR>1 && $NF !~ /^\.+$|^contents\.txt$/ {printf "%10s  %s\n", $5, $NF}' | sort -k2 > contents.txt )
echo "collected $(ls "$DST" | wc -l) files into $DST ($(du -sh "$DST" | cut -f1))"
