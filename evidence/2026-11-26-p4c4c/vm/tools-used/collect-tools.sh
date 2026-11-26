#!/bin/bash
# collect-tools.sh -- copy the scripts the p4c4c round ran from /tmp/qad-ev/p4c4c/tools into
# evidence/2026-11-26-p4c4c/vm/tools-used/ (re-runnable).  The paths in them are made
# publishable by normalise-evidence.sh with the rest of the tree.
set -u
QAD=<project>
D=$QAD/evidence/2026-11-26-p4c4c/vm/tools-used
mkdir -p "$D"
cp -f /tmp/qad-ev/p4c4c/tools/*.sh /tmp/qad-ev/p4c4c/tools/*.py "$D"/ 2>/dev/null
# the project tool the fault rows run, and the diff of this round's copy against it
cp -f "$QAD/tools/cycle.sh" "$QAD/tools/waitline.sh" "$QAD/tools/guest.sh" "$QAD/tools/qtest.py" "$QAD/tools/mon.py" "$D"/
( cd "$QAD" && diff -u tools/fault-matrix.sh "$D/fault-matrix-p4c4c.sh" ) > "$D/fault-matrix-p4c4c.diff" 2>&1
echo "tools-used: $(ls "$D" | wc -l) files"
exit 0
