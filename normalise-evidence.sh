#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# normalise-evidence.sh -- make the evidence tree publishable: replace the
# host's absolute paths (the project directory and the home directory) with
# placeholders in every file under evidence/ except the images and the
# compressed traces.  The search reads every file as text (-a): a raw serial
# log holds NUL bytes and escape sequences, which made grep -I skip it as
# "binary" -- and the guest's own UBSAN lines print the build tree's path.
# This work is licensed under the terms of the GNU GPL, version 2 or later.
# See the COPYING file in the top-level directory.
set -euo pipefail
cd "$(dirname "$0")"
H="$(cd ~ && pwd)"
Q="$PWD"
found=$(grep -rla --exclude='*.png' --exclude='*.fd' --exclude='*.gz' -e "$Q" -e "$H" evidence/ 2>/dev/null || true)
for f in $found; do
    sed -i -e "s|$Q|<project>|g" -e "s|$H|<home>|g" "$f"
done
# "no file left" is grep's "no match" exit: not an error (pipefail would stop the script here)
left=$({ grep -rla --exclude='*.png' --exclude='*.fd' --exclude='*.gz' -e "$Q" -e "$H" evidence/ 2>/dev/null || true; } | wc -l)
echo "normalised $(echo "$found" | grep -c . || true) files; remaining: $left"

# The account's login name (N11-12): replaced in listing lines only -- the owner or the group
# column of an ls -l line (a mode word, a link count, then the name) -- never in prose (the
# READMEs' "for Megan" stays). Two passes: the owner's column, then the group's; a line that
# carries the name in both columns reads <user> <user> after. Idempotent.
U="$(id -un)"
LIST="^[-lbcpsD][rwxsStT-]{9}[.+@]?[[:space:]]+[0-9]+[[:space:]]+([^[:space:]]+[[:space:]]+)?$U([[:space:]]|$)"
if [ -n "$U" ]; then
    listed=$(grep -rlaE "$LIST" evidence/ 2>/dev/null || true)
    n=0
    for f in $listed; do
        c=$(grep -caE "$LIST" "$f" || true)
        sed -i -E "s/^([-lbcpsD][rwxsStT-]{9}[.+@]?[[:space:]]+[0-9]+[[:space:]]+)(([^[:space:]]+[[:space:]]+)?)$U([[:space:]]|$)/\1\2<user>\4/g" "$f"
        sed -i -E "s/^([-lbcpsD][rwxsStT-]{9}[.+@]?[[:space:]]+[0-9]+[[:space:]]+)(([^[:space:]]+[[:space:]]+)?)$U([[:space:]]|$)/\1\2<user>\4/g" "$f"
        n=$((n + c))
    done
    echo "listing lines with the login name: $n in $(echo "$listed" | grep -c . || true) files replaced by <user>; files holding the name in any line: $(grep -rlaF "$U" evidence/ 2>/dev/null | wc -l)"
fi
