#!/bin/bash
# cmplogs.sh <old logs root> <new logs dir> -- per boot, the lines per source file (the
# `(\path\file.ext)` tag, line numbers dropped, case folded): old vs new, the rows that differ.
#   old: <root>/s<n>/boot<n>.txt   new: <dir>/boot<n>.txt   (NUL-stripped logs)
set -u
old="${1:?old logs root}"; new="${2:?new logs dir}"
tag() { tr -d '\r' < "$1" | sed -nE 's/^[^()]*\((\\[^():]+)(:[0-9]+)?\).*/\1/p' | tr 'A-Z' 'a-z' | sort | uniq -c; }
for n in 1 2 3 4; do
    o="$old/s$n/boot$n.txt"; w="$new/boot$n.txt"
    [ -f "$o" ] || { echo "== boot$n: no old log $o"; continue; }
    echo "== boot$n: old $(wc -l < "$o") lines, new $(wc -l < "$w") lines; untagged old $(grep -c -v -E '\(\\[^():]+(:[0-9]+)?\)' "$o"), new $(grep -c -v -E '\(\\[^():]+(:[0-9]+)?\)' "$w")"
    tag "$o" | awk '{print $2,$1}' | sort > /tmp/c6f/.tag-old.txt
    tag "$w" | awk '{print $2,$1}' | sort > /tmp/c6f/.tag-new.txt
    join -a 1 -a 2 -e 0 -o 0,1.2,2.2 /tmp/c6f/.tag-old.txt /tmp/c6f/.tag-new.txt \
        | awk '$2!=$3 {printf "  %+4d  %s (old %d, new %d)\n", $3-$2, $1, $2, $3}' \
        | sort -n -k1,1 > /tmp/c6f/.tag-diff.txt
    echo "  rows that differ: $(wc -l < /tmp/c6f/.tag-diff.txt); net tagged $(awk '{s+=$1} END {print s+0}' /tmp/c6f/.tag-diff.txt)"
    head -12 /tmp/c6f/.tag-diff.txt
    [ "$(wc -l < /tmp/c6f/.tag-diff.txt)" -gt 12 ] && echo "  ..."
    tail -n +13 /tmp/c6f/.tag-diff.txt | head -24
    echo "  intcdsp files:"; grep -i 'intcdsp\|dsppcm\|audioif\|topology\|fwfile\|hwops' /tmp/c6f/.tag-diff.txt | sed 's/^/    /'
done
