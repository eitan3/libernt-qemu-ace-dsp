#!/bin/bash
# Provenance of the nwifi.sys hive fix on upstream master; master's netvwifi.inf comment. Read-only.
set -u
cd <home>/Projects/LiberNT || exit 1
echo "--- upstream commits that changed the Nwifi ImagePath line (pickaxe on the string)"
git log bb96c5e4abf --format='%h %ad %an  %s' --date=format:'%m-%d %H:%M' -S'drivers\nwifi.sys' -- image/data/hivesys.inf | head -3
echo "--- and on the branch (pre-rebase tip b7274b3e004 had wifi.sys?)"
echo "b7274b3e004: wifi=$(git show b7274b3e004:image/data/hivesys.inf | grep -c 'drivers\\wifi\.sys') nwifi=$(git show b7274b3e004:image/data/hivesys.inf | grep -c 'drivers\\nwifi\.sys')"
echo "--- final proof: line 2052 as bytes"
sed -n '2052p' image/data/hivesys.inf | cat -A
echo "--- master's netvwifi.inf line 3"
git show bb96c5e4abf:drivers/network/dd/vwifi/netvwifi.inf | sed -n '3p'
echo "--- any Enum\\Root or VWIFI seed in hivesys.inf at HEAD (case-insensitive)"
grep -n -i -e 'enum\\root' -e 'vwifi' image/data/hivesys.inf | head -5 || true
echo "(end)"
