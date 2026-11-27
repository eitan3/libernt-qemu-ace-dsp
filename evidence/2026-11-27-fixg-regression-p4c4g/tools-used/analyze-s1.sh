#!/bin/bash
# analyze-s1.sh -- the exports of the first-session flow (read from stick B with mtools), as the
# p4c4e final pass's logstats.sh / dspdiff.sh / gate did:
#   1. the raw exports (boot<n>.log, 270,336 bytes, NUL-padded) are copied off the stick into
#      /tmp/c6g/exports; the .txt files are the same bytes without the NUL padding;
#   2. stats.txt: per boot, the lines, the `intcdsp.sys:` lines, the stop lines, the bytes, the
#      last line -- beside the p4c4e final pass's figures;
#   3. gate.txt: the gate rule on dsploop.txt (required: LIBERNT_APITEST_REQUIRED=1);
#   4. expected-vs-measured.txt: every line quoted in refs/c6/EXPECTEDED-LINES.md's code blocks
#      counted in the new log and in the p4c4e log (digits folded, so model values do not count);
#   5. dspdiff-boot<n>-p4c4e.txt: the driver lines (intcdsp.sys:, dsppcm.sys:, hdaudbus.sys:) of
#      each boot, p4c4e against the new one, digits folded; then the new ones whole.
set -u
Q=<project>
E=$Q/evidence/2026-11-27-fixg-regression-p4c4g
P=$Q/evidence/2026-11-27-c6-final-p4c4e/logs/s5
X=<home>/Projects/LiberNT-IntelDSP-plan/refs/c6/EXPECTED-LINES.md
STICK=$Q/disk/c6-stickB-p4c4g.img
OFF=1048576
S=/tmp/c6g/exports
rm -rf "$S"; mkdir -p "$S"
mdir -i "$STICK@@$OFF" ::/ > "$S/mdir-root.txt" 2>&1
mcopy -n -i "$STICK@@$OFF" "::*" "$S"/ > "$S/mcopy.out" 2>&1
cat "$S/mdir-root.txt"
echo "== copied: $(ls "$S" | wc -l) files"
cd "$S"
for f in boot1 boot2 boot2-prev boot3 boot3-prev boot4 boot4-prev; do
    [ -f "$f.log" ] && tr -d '\000' < "$f.log" > "$f.txt"
done
ls -la "$S" | awk 'NR>1 && $NF !~ /^\.+$/ {printf "%10s  %s\n", $5, $NF}' | sort -k2 > listing.txt
{
echo "# the exports of the first-session flow (p4c4g, read from stick B after the clean Turn Off of the export boot) against the p4c4e final pass (evidence/2026-11-27-c6-final-p4c4e/logs/s5)"
echo "# format: boot  lines / intcdsp.sys: lines / stop lines / bytes (raw) -- last line;   p4c4e: the same figures"
for b in boot1 boot2 boot2-prev boot3 boot3-prev boot4 boot4-prev; do
    [ -f "$b.txt" ] || { echo "$b: MISSING in the export"; continue; }
    printf '%-12s lines %4s  intcdsp.sys: %3s  stop lines %s  bytes %s\n' "$b" "$(wc -l < "$b.txt")" "$(grep -c 'intcdsp.sys:' "$b.txt")" "$(grep -c 'STOP:' "$b.txt")" "$(stat -c %s "$b.log")"
    printf '    last: %s\n' "$(tail -n 1 "$b.txt" | tr -d '\r' | cut -c1-150)"
    if [ -f "$P/$b.txt" ]; then
        printf '    p4c4e: lines %4s  intcdsp.sys: %3s  stop lines %s  bytes %s\n' "$(wc -l < "$P/$b.txt")" "$(grep -c 'intcdsp.sys:' "$P/$b.txt")" "$(grep -c 'STOP:' "$P/$b.txt")" "$(stat -c %s "$P/$b.txt")"
    fi
done
} > stats.txt
cat stats.txt
# the gate rule: the summary line with 0 failures and 0 skipped under the required switch
{
    if [ -f dsploop.txt ]; then
        s=$(grep -a "tests executed" dsploop.txt | head -1)
        if echo "$s" | grep -q "0 failures), 0 skipped" && grep -aq "0 preconditions missing" dsploop.txt && grep -aq "3 of 3 depths compared" dsploop.txt && [ "$(grep -ac 'compared within' dsploop.txt)" = 3 ]; then
            echo "GREEN dsploop.txt: $s (allowance 0, required)"; echo "rc=0"
        else
            echo "RED dsploop.txt: $s"; echo "rc=1"
        fi
    else echo "dsploop.txt: MISSING"; echo "rc=1"; fi
} > gate.txt
cat gate.txt
# every line quoted in EXPECTED-LINES.md (the code blocks), counted with digits folded
pick() { tr -d '\r' < "$1" | grep -a -E 'intcdsp\.sys:|dsppcm\.sys:|hdaudbus\.sys:' | sed -E 's/^\[ *[0-9.]+\] //'; }
fold() { sed -E 's/[0-9]+/N/g'; }
tr -d '\r' < "$X" | awk '/^```/{f=!f; next} f' | grep -a -E 'intcdsp\.sys:|dsppcm\.sys:|hdaudbus\.sys:|dsploop' | grep -a -v '^\.\.\.' | grep -a -v 'dsploop.c:426: dsploop (24-bit\|dsploop.c:426: dsploop: …' | sed -E 's/ +intcdsp\.c:[0-9]+$//; s/ +audioif\.c:[0-9]+$//; s/ +topology\.c:[0-9]+$//; s/ +hwops\.c:[0-9]+$//; s/ +\(dsppcm\.sys\)$//; s/ +\(the capture stream\)$//' > /tmp/c6g/expected-lines.txt
{
echo "# EXPECTED-LINES.md's quoted lines (digits folded: model values do not count) in the p4c4g export and in the p4c4e final pass"
echo "# boot assignment: boot1 lines are looked up in boot1, boot2 in boot2 (its prev too), boot3 in boot3, boot4 in boot4 + dsploop.txt; a line is searched in all of them and the boot with a hit is printed"
printf '%-6s %-6s %s\n' "p4c4g" "p4c4e" "line (digits folded; the first 150 characters)"
while IFS= read -r l; do
    [ -z "$l" ] && continue
    key=$(echo "$l" | fold)
    n=0; o=0; where=""
    for b in boot1 boot2 boot2-prev boot3 boot3-prev boot4 boot4-prev; do
        [ -f "$b.txt" ] || continue
        c=$(pick "$b.txt" | fold | grep -c -F -x -- "$key")
        [ "$c" -gt 0 ] && { n=$((n+c)); where="$where $b:$c"; }
        if [ -f "$P/$b.txt" ]; then
            co=$(pick "$P/$b.txt" | fold | grep -c -F -x -- "$key"); o=$((o+co))
        fi
    done
    if echo "$l" | grep -q "^dsploop"; then
        n=$(tr -d '\r' < dsploop.txt 2>/dev/null | fold | grep -c -F -x -- "$key"); o=$(tr -d '\r' < "$P/dsploop.txt" | fold | grep -c -F -x -- "$key"); where=" dsploop.txt"
    fi
    printf '%-6s %-6s %s  <-%s\n' "$n" "$o" "$(echo "$l" | cut -c1-150)" "$where"
done < /tmp/c6g/expected-lines.txt
} > expected-vs-measured.txt
echo "expected lines: $(wc -l < /tmp/c6g/expected-lines.txt); lines whose count differs from p4c4e's: $(awk 'NR>3 && $1!=$2' expected-vs-measured.txt | wc -l)"
for b in boot1 boot2 boot3 boot4; do
    {
    echo "--- $b: p4c4e driver lines: $(pick "$P/$b.txt" | wc -l), p4c4g: $(pick "$b.txt" | wc -l); differ (digits folded):"
    diff <(pick "$P/$b.txt" | fold) <(pick "$b.txt" | fold) | grep -a -E '^[<>]' | cut -c1-200
    echo "--- the lines that differ exactly (model values), p4c4e < > p4c4g:"
    diff <(pick "$P/$b.txt") <(pick "$b.txt") | grep -a -E '^[<>]' | cut -c1-330
    echo "--- p4c4g driver lines, whole:"
    pick "$b.txt" | cut -c1-330 | nl -ba
    } > "dspdiff-$b-p4c4e.txt" 2>&1
    echo "== $b: folded-diff lines: $(diff <(pick "$P/$b.txt" | fold) <(pick "$b.txt" | fold) | grep -a -c -E '^[<>]')"
done
echo "dsploop.txt (p4c4g):"; cat dsploop.txt 2>/dev/null
echo "=== dsploop diff p4c4e < > p4c4g (digits folded) ==="
diff <(tr -d '\r' < "$P/dsploop.txt" | fold) <(tr -d '\r' < dsploop.txt | fold) | grep -a -E '^[<>]' | cut -c1-200
echo "(end of the dsploop diff)"
