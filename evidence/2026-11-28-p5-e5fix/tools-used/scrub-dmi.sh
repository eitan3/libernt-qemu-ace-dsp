#!/bin/bash
# scrub-dmi.sh -- privacy: the driver's DMI line prints the machine's SMBIOS strings.  No raw DMI line goes into a
# committed file: the values are replaced by placeholders, the line's shape kept, in every text file under the
# evidence directory (idempotent).  The E5 round's, re-pointed.
set -euo pipefail
cd "$(cd "$(dirname "$0")/../../.." && pwd)"
E=evidence/2026-11-28-p5-e5fix
pat='DMI ok: SMBIOS [0-9.]+ DMI [0-9]+, vendor "[^"]*" product "[^"]*" version "[^"]*" board "[^"]*" "[^"]*", quirk'
rep='DMI ok: SMBIOS <ver> DMI <rev>, vendor "<vendor>" product "<product>" version "<version>" board "<board>" "<board version>", quirk'
n=0
for f in $(grep -rlaF 'DMI ok: SMBIOS' "$E" --exclude='*.png' --exclude='*.gz' --exclude='*.fd' 2>/dev/null || true); do
    c=$(grep -caE "$pat" "$f" || true)
    sed -i -E "s/$pat/$rep/g" "$f"
    n=$((n + c))
done
left=$({ grep -rlaF 'vendor "QEMU"' "$E" 2>/dev/null | grep -v 'tools-used/scrub-dmi.sh\|tools-used/verify.sh' || true; } | wc -l)
echo "dmi lines scrubbed: $n; files still holding the raw strings: $left"
