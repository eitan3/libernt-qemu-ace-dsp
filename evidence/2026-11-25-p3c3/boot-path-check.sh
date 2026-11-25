#!/bin/bash
# boot-path-check.sh — the ace_* trace lines of the qtest cases, old against new,
# case by case.  Exact: each old case's lines must be exactly the new case's
# lines, in order.  Sub: each old line must still be there, in order, and
# every added line is listed (the rule of p3c1's boot-path-diff.txt).
# usage: boot-path-check.sh exact|sub <old transcript> <new transcript> <last case>
set -u
MODE="$1"; OLD="$2"; NEW="$3"; LAST="$4"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
emit() {
    if [ "${1%.gz}" != "$1" ]; then zcat "$1"; else cat "$1"; fi
}
split() {   # $1 = file, $2 = prefix: <prefix>.<n> = the ace_* lines before the n-th result line
    emit "$1" | awk -v p="$2" 'BEGIN{n=1} /^(not )?ok /{n++; next} /^ace_/{print > (p "." n)}'
}
split "$OLD" "$T/old"; split "$NEW" "$T/new"
bad=0; told=0; tnew=0; tgone=0; tadded=0
for n in $(seq 1 "$LAST"); do
    touch "$T/old.$n" "$T/new.$n"
    o=$(wc -l < "$T/old.$n"); w=$(wc -l < "$T/new.$n")
    told=$((told + o)); tnew=$((tnew + w))
    if cmp -s "$T/old.$n" "$T/new.$n"; then
        echo "case $n: old $o trace lines, new $w: identical"
        continue
    fi
    if [ "$MODE" = exact ]; then
        bad=$((bad + 1)); echo "case $n: old $o trace lines, new $w: DIFFER"
        diff "$T/old.$n" "$T/new.$n" | head -20
        continue
    fi
    # subsequence test: walk the new lines, matching the old ones in order
    gone=$(awk 'NR==FNR{old[FNR]=$0; o=FNR; next} $0==old[i+1]{i++} END{print o-i}' "$T/old.$n" "$T/new.$n")
    added=$(awk 'NR==FNR{old[FNR]=$0; o=FNR; next} $0==old[i+1]{i++; next} {print "      + " $0}' "$T/old.$n" "$T/new.$n")
    tgone=$((tgone + gone)); tadded=$((tadded + $(printf '%s' "$added" | grep -c . )))
    if [ "$gone" -ne 0 ]; then bad=$((bad + 1)); fi
    echo "case $n: old $o trace lines, new $w: $gone old lines gone"
    printf '%s\n' "$added"
done
if [ "$MODE" = exact ]; then
    echo "cases 1-$LAST: old $told trace lines, new $tnew, $bad case(s) differ"
else
    echo "cases 1-$LAST: old $told trace lines, new $tnew: $tgone old lines gone, $tadded added"
fi
[ "$bad" -eq 0 ]
