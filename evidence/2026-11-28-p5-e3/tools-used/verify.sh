#!/bin/bash
# verify.sh -- the evidence tree is publishable: no credential string, no raw DMI line, no host path,
# and no login name in a listing line (N11-12: the owner or group column of an ls -l line; the name
# in prose stays, as the READMEs' "for Megan").
#   verify.sh [after]   (after = normalise-evidence.sh has run: no path may be left)
# Lives under the tree it checks (tools-used/): its own patterns are left out of the counts.
set -u
H="$(cd ~ && pwd)"
U="$(id -un)"
Q="$(cd "$(dirname "$0")/../../.." && pwd)"
E="$Q/evidence/2026-11-28-p5-e2"
LIST="^[-lbcpsD][rwxsStT-]{9}[.+@]?[[:space:]]+[0-9]+[[:space:]]+([^[:space:]]+[[:space:]]+)?$U([[:space:]]|$)"
cd "$Q" || exit 1
echo "evidence tree: $E"
echo "files holding a credential variable name (must be 0; tools-used excluded): $(grep -rlaF 'SUDO_PASSWORD' "$E" 2>/dev/null | grep -v '/tools-used/' | wc -l)"
echo "files holding a raw DMI string (must be 0; tools-used excluded): $(grep -rlaF 'vendor "QEMU"' "$E" 2>/dev/null | grep -v '/tools-used/' | wc -l)"
echo "files holding a home path: $(grep -rla -e "$H" "$E" 2>/dev/null | wc -l)"
[ "${1:-}" = after ] && grep -rla -e "$H" "$E" 2>/dev/null | head -5
echo "listing lines holding the login name (must be 0; tools-used excluded): $(grep -rlaE "$LIST" "$E" 2>/dev/null | grep -v '/tools-used/' | wc -l) files, $(grep -rhaE "$LIST" "$E" 2>/dev/null | wc -l) lines"
echo "files holding the login name in any line (informational: prose stays): $(grep -rlaF "$U" "$E" 2>/dev/null | grep -v '/tools-used/' | wc -l)"
echo "pngs: $(find "$E" -name '*.png' | wc -l); files: $(find "$E" -type f | wc -l); size: $(du -sh "$E" | cut -f1)"
true
