#!/bin/bash
# affected-rows.sh — which mutation rows of mutation-check.sh touch code that
# the patches of the round changed: a row is affected when its sed expression
# changes nothing on the new file (NOT-APPLIED) or changes a line inside a
# hunk of the diff between the two revisions.
# usage: affected-rows.sh [old revision] [new revision]
set -u
OLDREV="${1:-bfc7b18a6}"     # the model of main 5680026
NEWREV="${2:-46998f810}"     # the model of the p3c3 series
cd "$(dirname "$0")/../.." || exit 1
SRC=src/qemu-11.1.3
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
C='hw/audio/intel-hda-ace.c'; R='hw/audio/intel-hda-ace-regs.h'
mapfile -t ROWS < <(sed -n '/^MUTATIONS=(/,/^)/p' mutation-check.sh | grep '^"' | sed 's/^"//; s/"$//')
for row in "${ROWS[@]}"; do
    IFS='|' read -r name file expr what <<< "$row"
    file=$(eval echo "$file")
    git -C "$SRC" show "$OLDREV:$file" > "$T/old"
    git -C "$SRC" show "$NEWREV:$file" > "$T/new"
    if cmp -s "$T/old" "$T/new"; then
        echo "$name $file file-unchanged"; continue
    fi
    sed "$expr" "$T/new" > "$T/new.m"
    if cmp -s "$T/new" "$T/new.m"; then
        echo "$name $file NOT-APPLIED"; continue
    fi
    # the new-file line numbers the expression changes
    diff --unchanged-line-format= --old-line-format= --new-line-format=$'%dn\n' "$T/new" "$T/new.m" > "$T/changed"
    # the hunks between the revisions, in new-file numbers: start count (no count: one line)
    git -C "$SRC" diff -U0 "$OLDREV" "$NEWREV" -- "$file" | grep -E '^@@' |
        sed -E 's/^@@ -[0-9]+(,[0-9]+)? \+([0-9]+)(,([0-9]+))? @@.*/\2 \4/; s/ +$/ 1/' > "$T/hunks"
    hit=no
    while read -r a; do
        while read -r h n; do
            if [ "$a" -ge "$h" ] && [ "$a" -le "$((h + n - 1))" ]; then hit=yes; fi
        done < "$T/hunks"
    done < "$T/changed"
    echo "$name $file $([ $hit = yes ] && echo IN-HUNK || echo outside-hunks) changed: $(tr '\n' ' ' < "$T/changed")"
done
