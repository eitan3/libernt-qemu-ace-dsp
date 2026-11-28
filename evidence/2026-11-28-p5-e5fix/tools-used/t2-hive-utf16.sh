#!/bin/bash
# What the generated (UTF-16) hive sources in the build dir carry for Nwifi. Read-only.
set -u
cd <home>/Projects/LiberNT || exit 1
for f in output-Clang-amd64-debug/image/data/hivesys_utf16.inf output-Clang-amd64-debug/image/data/hivesys_amd64_utf16.inf; do
  echo "=== $f (mtime $(stat -c '%y' "$f" | cut -c1-19))"
  iconv -f UTF-16 -t UTF-8 "$f" 2>/dev/null | grep -n -i -e 'Nwifi' | head -8
done
echo "=== the source that includes them: image/data/CMakeLists.txt or the hive list (names only)"
grep -r -l -i 'hivesys_amd64' image/CMakeLists.txt image/*.txt image/*.cmake 2>/dev/null | head -3
echo "=== image/data/hivesys_amd64.inf: Nwifi lines (plain text source)"
grep -n -i 'nwifi' image/data/hivesys_amd64.inf | head -5 || echo "(none)"
