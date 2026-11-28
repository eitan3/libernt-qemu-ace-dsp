#!/bin/bash
# cur.sh -- move the pointer by (dx dy) and print the box of the pixels that changed (the cursor's old and new places)
#   cur.sh <dx> <dy>
set -u
cd /tmp/e5/ev/flow
cp cur-a.png cur-b.png 2>/dev/null
bash /tmp/e5/ptr.sh shot cur-a >/dev/null
python3 /tmp/e5/tools/diffbox.py cur-b.png cur-a.png 2>/dev/null | sed 's/^/before (vs the last shot): /'
bash /tmp/e5/ptr.sh mv "$1" "$2" >/dev/null
sleep 0.7
bash /tmp/e5/ptr.sh shot cur-b >/dev/null
echo "after mv $1 $2: $(python3 /tmp/e5/tools/diffbox.py cur-a.png cur-b.png)"
