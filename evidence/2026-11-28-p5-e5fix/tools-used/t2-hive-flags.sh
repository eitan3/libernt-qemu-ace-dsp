#!/bin/bash
# Why does git not see the hivesys.inf change? Index flags, HEAD blob vs worktree.
set -u
cd <home>/Projects/LiberNT || exit 1
echo "--- ls-files -v (lowercase = assume-unchanged, S = skip-worktree)"
git ls-files -v -- image/data/hivesys.inf
echo "--- ls-files --debug (flags)"
git ls-files --debug -- image/data/hivesys.inf | head -8
echo "--- HEAD blob line 2052"
git show HEAD:image/data/hivesys.inf | sed -n '2052p'
echo "--- worktree line 2052"
sed -n '2052p' image/data/hivesys.inf
echo "--- diff HEAD blob vs worktree (bypassing the index flags)"
git diff --no-index --stat <(git show HEAD:image/data/hivesys.inf) image/data/hivesys.inf 2>&1 | tail -3
echo "--- how many tracked files carry a lowercase/S flag in ls-files -v"
git ls-files -v | grep -c -E '^[a-zS] '
echo "--- which (first 20)"
git ls-files -v | grep -E '^[a-zS] ' | head -20
