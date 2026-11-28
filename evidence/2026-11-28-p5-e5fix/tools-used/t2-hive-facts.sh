#!/bin/bash
# Facts about hivesys.inf: HEAD blob vs index vs worktree hashes, mtimes, repo locks/flags, other writers.
set -u
cd <home>/Projects/LiberNT || exit 1
F=image/data/hivesys.inf
echo "--- now: $(date -u '+%Y-%m-%dT%H:%M:%S UTC')  (local: $(date '+%H:%M:%S %Z'))"
echo "--- hashes: HEAD blob / index entry / worktree"
echo "HEAD    : $(git rev-parse HEAD:$F)"
echo "index   : $(git ls-files -s -- $F | awk '{print $2}')"
echo "worktree: $(git hash-object $F)"
echo "--- counts in each (wifi.sys / nwifi.sys)"
echo "HEAD    : wifi=$(git show HEAD:$F | grep -c 'drivers\\wifi\.sys') nwifi=$(git show HEAD:$F | grep -c 'drivers\\nwifi\.sys')"
echo "worktree: wifi=$(grep -c 'drivers\\wifi\.sys' $F) nwifi=$(grep -c 'drivers\\nwifi\.sys' $F)"
echo "--- upstream master bb96c5e4abf blob"
echo "master  : wifi=$(git show bb96c5e4abf:$F | grep -c 'drivers\\wifi\.sys') nwifi=$(git show bb96c5e4abf:$F | grep -c 'drivers\\nwifi\.sys')"
echo "--- file stat"
stat -c 'mtime %y  size %s  ino %i' $F
echo "index entry mtime: $(date -u -d @1795882985 '+%Y-%m-%dT%H:%M:%S UTC')"
echo "--- repo state files (names only)"
ls -la --time-style='+%H:%M:%S' .git/index .git/HEAD 2>/dev/null
ls .git | grep -E 'lock|rebase|merge|cherry|revert|ORIG' || echo "(no lock/in-progress files)"
echo "--- gitattributes filters on *.inf?"
git check-attr -a -- $F
echo "--- config filters (keys only)"
git config --name-only --get-regexp 'filter\..*' || echo "(no filter config)"
echo "--- diff-index HEAD (worktree vs HEAD, ignoring index stat cache)"
git diff-index --stat HEAD -- $F; echo "diff-index rc=$?"
echo "--- last commits touching the file"
git log --format='%h %ad %s' --date=format:'%m-%d %H:%M' -3 -- $F
