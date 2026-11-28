#!/bin/bash
# Find the WIFI-1 survey: what it read and where. Read-only.
set -u
P=<home>/Projects/LiberNT-IntelDSP-plan
echo "--- files mentioning WIFI-1 (names)"
grep -r -l -i 'WIFI-1' "$P" --include='*.md' --include='*.txt' 2>/dev/null | grep -v '/.git/' | head -10
echo "--- lines (first 30)"
grep -r -n -i -e 'WIFI-1' -e 'wifi\.sys' "$P" --include='*.md' --include='*.txt' 2>/dev/null | grep -v '/.git/' | cut -c1-260 | head -30
