#!/bin/bash
# verify.sh -- the evidence tree is publishable: no password string, no host path, no raw DMI
# line, no home path in refs/c6; the file counts.
#   verify.sh [after]   (after = normalise-evidence.sh has run: no path may be left)
set -u
H=<home>
Q=$H/Projects/LiberNT-IntelDSP-plan/qemu-ace-dsp
R=$H/Projects/LiberNT-IntelDSP-plan/refs/c6
E=$Q/evidence/2026-11-27-fixg-regression-p4c4g
cd "$Q"
echo "files holding the password string (must be 0): $(grep -rlF -f /tmp/c6g/.pw "$E" "$R" 2>/dev/null | wc -l)"
echo "files holding a raw DMI string (must be 0; the two checking scripts' own patterns excluded): $(grep -rlaF 'vendor "QEMU"' "$E" "$R" 2>/dev/null | grep -v 'tools-used/verify.sh\|tools-used/scrub-dmi.sh' | wc -l)"
echo "files holding a home path: $(grep -rla -e "$H" "$E" "$R" 2>/dev/null | wc -l)"
[ "${1:-}" = after ] && grep -rla -e "$H" "$E" "$R" 2>/dev/null | head -5
echo "pngs: $(find "$E" -name '*.png' | wc -l); files: $(find "$E" -type f | wc -l); size: $(du -sh "$E" | cut -f1)"
true
