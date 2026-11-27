#!/bin/bash
# verify.sh -- the run book's picture links resolve; the file counts of the evidence tree; no
# password string and no host path in the evidence tree and the deliverables.
#   verify.sh [before|after]   (after = normalise-evidence.sh has run: no path may be left)
set -u
R=<home>/Projects/LiberNT-IntelDSP-plan/refs/c6
E=<project>/evidence/2026-11-27-c6-final-p4c4e
cd "$R"
n=0; bad=0
for p in $(grep -o '](\.\./[^)]*\.png)' RUNBOOK-first-session.md | sed 's/^](//; s/)$//'); do
    n=$((n+1))
    [ -f "$p" ] || { bad=$((bad+1)); echo "MISSING $p"; }
done
echo "run book picture links: $n, missing: $bad"
echo "pngs: vm1 $(ls "$E"/vm1/*.png | wc -l), vm1x $(ls "$E"/vm1x/*.png | wc -l), vm2 $(ls "$E"/vm2/*.png | wc -l), vm3 $(ls "$E"/vm3/*.png | wc -l); files $(find "$E" -type f | wc -l), $(du -sh "$E" | cut -f1)"
echo "files holding the password string (must be 0): $(grep -rlF -f /tmp/c6f/.pw "$E" "$R" 2>/dev/null | wc -l)"
echo "files holding a host path: $(grep -rla -e <home> "$E" "$R" 2>/dev/null | wc -l)"
[ "${1:-}" = after ] && grep -rla -e <home> "$E" "$R" 2>/dev/null | head -5
true
