#!/bin/bash
# logstats.sh <dir> -- per boot log: the lines after NUL stripping (boot<n>.txt), the
# `intcdsp.sys:` lines, the kernel's stop lines, and the last line.
set -u
d="${1:?dir}"
for f in "$d"/boot*.log; do
    b=$(basename "$f" .log)
    tr -d '\000' < "$f" > "$d/$b.txt"
    printf '%-12s lines %4s  intcdsp.sys: %3s  stop lines %s  bytes %s\n' "$b" "$(wc -l < "$d/$b.txt")" \
        "$(grep -c 'intcdsp.sys:' "$d/$b.txt")" "$(grep -c 'STOP:' "$d/$b.txt")" "$(stat -c %s "$f")"
    printf '    last: %s\n' "$(tail -n 1 "$d/$b.txt" | tr -d '\r' | cut -c1-150)"
done
