#!/bin/bash
# cmplogs.sh <old logs root> <new logs dir> -- the p4c4e final pass's cmplogs.sh: per boot, the
# lines per source file (the `(\path\file.ext)` tag, line numbers dropped, case folded): old vs
# new, the rows that differ; then the whole lines that are in one log only (old <, new >).
set -u
old="${1:?old logs root}"; new="${2:?new logs dir}"
tag() { tr -d '\r' < "$1" | sed -nE 's/^[^()]*\((\\[^():]+)(:[0-9]+)?\).*/\1/p' | tr 'A-Z' 'a-z' | sort | uniq -c; }
untag() { tr -d '\r' < "$1" | sed -E 's/^\[ *[0-9.]+\] //' | sed -E 's/\(([\\[^():]+)(:[0-9]+)?\)/(FILE)/' | sort; }
for n in 1 2 2-prev 3 3-prev 4 4-prev; do
    o="$old/boot$n.txt"; w="$new/boot$n.txt"
    [ -f "$o" ] || { echo "== boot$n: no old log $o"; continue; }
    echo "== boot$n: old $(wc -l < "$o") lines, new $(wc -l < "$w") lines"
    tag "$o" | awk '{print $2,$1}' | sort > /tmp/c6g/.tag-old.txt
    tag "$w" | awk '{print $2,$1}' | sort > /tmp/c6g/.tag-new.txt
    join -a 1 -a 2 -e 0 -o 0,1.2,2.2 /tmp/c6g/.tag-old.txt /tmp/c6g/.tag-new.txt \
        | awk '$2!=$3 {printf "  %+4d  %s (old %d, new %d)\n", $3-$2, $1, $2, $3}' \
        | sort -n -k1,1 > /tmp/c6g/.tag-diff.txt
    echo "  tagged lines: old $(awk '{s+=$1} END {print s+0}' /tmp/c6g/.tag-old.txt), new $(awk '{s+=$1} END {print s+0}' /tmp/c6g/.tag-new.txt); rows that differ: $(wc -l < /tmp/c6g/.tag-diff.txt)"
    sed 's/^/  /' /tmp/c6g/.tag-diff.txt
    echo "  whole lines in one log only (timestamps dropped, sorted; old <, new >):"
    diff <(untag "$o") <(untag "$w") | grep -a -E '^[<>]' | cut -c1-230 | sed 's/^/  /'
done
