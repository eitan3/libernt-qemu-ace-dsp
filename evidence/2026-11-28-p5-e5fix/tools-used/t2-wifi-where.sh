#!/bin/bash
# Controlled check: where does 'drivers\wifi.sys' exist at all? Tree at HEAD, worktree, build dir, ISO-era files.
set -u
cd <home>/Projects/LiberNT || exit 1
echo "--- git grep at HEAD (whole tree): drivers\\wifi.sys"
git grep -n -F 'drivers\wifi.sys' HEAD | head -5 || echo "(none at HEAD)"
echo "--- worktree grep (tracked + untracked, excluding .git and output-*): drivers\\wifi.sys"
grep -r -l -F 'drivers\wifi.sys' --exclude-dir=.git --exclude-dir='output-*' . 2>/dev/null | head -5 || echo "(none)"
echo "--- build dir: any hivesys*.inf and its Nwifi line"
for f in $(find output-Clang-amd64-debug -maxdepth 4 -iname 'hivesys*.inf' 2>/dev/null | head -5); do
  echo "$f: $(grep -c 'drivers\\wifi\.sys' "$f") wifi / $(grep -c 'drivers\\nwifi\.sys' "$f") nwifi  (mtime $(stat -c '%y' "$f" | cut -c1-19))"
done
echo "--- any hivesys*.inf elsewhere under the checkout (excluding .git)"
find . -path ./.git -prune -o -iname 'hivesys*.inf' -print 2>/dev/null | head -10
echo "--- E5 image-era build dir names present"
ls -d output-* 2>/dev/null
echo "--- pipeline sanity: print the line via three different commands"
sed -n '2052p' image/data/hivesys.inf | grep -o 'drivers\\[a-z]*\.sys'
sed -n '2052p' image/data/hivesys.inf | cut -c70-
git grep -n 'Nwifi","ImagePath"' HEAD -- image/data/hivesys.inf
