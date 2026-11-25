#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# normalise-evidence.sh -- make the evidence tree publishable: replace the
# host's absolute paths (the project directory and the home directory) with
# placeholders in every text file under evidence/.
# This work is licensed under the terms of the GNU GPL, version 2 or later.
# See the COPYING file in the top-level directory.
set -euo pipefail
cd "$(dirname "$0")"
H="$(cd ~ && pwd)"
Q="$PWD"
found=$(grep -rIl --exclude='*.png' --exclude='*.fd' -e "$Q" -e "$H" evidence/ 2>/dev/null || true)
for f in $found; do
    sed -i -e "s|$Q|<project>|g" -e "s|$H|<home>|g" "$f"
done
# "no file left" is grep's "no match" exit: not an error (pipefail would stop the script here)
left=$({ grep -rIl --exclude='*.png' --exclude='*.fd' -e "$Q" -e "$H" evidence/ 2>/dev/null || true; } | wc -l)
echo "normalised $(echo "$found" | grep -c . || true) files; remaining: $left"
