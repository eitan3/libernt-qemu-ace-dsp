#!/bin/bash
# READ-ONLY: state of the main checkout, no index locks taken.
R=<home>/Projects/LiberNT
G="git --no-optional-locks -C $R"
echo "== HEAD"; $G rev-parse HEAD
echo "== branch"; $G rev-parse --abbrev-ref HEAD
echo "== feat tip"; $G rev-parse feat/audio-control-polish
echo "== 39e4 type"; $G cat-file -t 39e4bc940a5
echo "== log 39e4 (12)"; $G log --oneline -12 39e4bc940a5
echo "== master"; $G rev-parse master 2>&1
echo "== files differing 39e4..HEAD (names only)"; $G diff --name-only 39e4bc940a5 HEAD
echo "== stash count"; $G stash list 2>&1 | wc -l
echo "== date"; date '+%F %T %z'
