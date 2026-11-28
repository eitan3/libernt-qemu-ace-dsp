#!/bin/bash
# T2 follow-up 2: svchost / spoolsv / telnetd definitions and the image manifest; packet. Read-only.
set -u
cd <home>/Projects/LiberNT || exit 1
for s in svchost spoolsv telnetd; do
  echo "=== $s"
  echo "--- add_executable($s ...) in any CMakeLists"
  git grep -n -F "add_executable($s" -- '*CMakeLists.txt' | head -3
  echo "--- base/services/$s/CMakeLists.txt add_* lines"
  grep -n -i -E 'add_(executable|library)' "base/services/$s/CMakeLists.txt" 2>/dev/null | head -3
  echo "--- image/data/componentfiles.txt"
  grep -n -i -F "$s.exe" image/data/componentfiles.txt | head -2
done
echo
echo "=== packet: in the manifest, and any file of that name in the tree"
grep -n -i 'packet' image/data/componentfiles.txt | head -3
git ls-files | grep -i 'packet' | grep -v -e '\.po$' | head -8
echo "=== upstream master: does it carry the same Packet and Nwifi lines? (context only)"
git grep -n -e '"Services\\Packet","ImagePath"' -e '"Services\\Nwifi","ImagePath"' bb96c5e4abf -- image/data/hivesys.inf
