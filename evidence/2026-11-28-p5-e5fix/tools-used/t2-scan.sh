#!/bin/bash
# T2 bounded scan: every ImagePath value in image/data/hivesys.inf against the tree's module names.
# Read-only. Prints: each ImagePath basename, and whether a CMake add_library/add_executable of that
# name (or a literal mention of the file) exists in the tree. Unresolved ones are listed at the end.
set -u
cd <home>/Projects/LiberNT || exit 1
HIVE=image/data/hivesys.inf

echo "== ImagePath values in $HIVE: $(grep -c '"ImagePath"' "$HIVE")"
echo "== forms:"
grep '"ImagePath"' "$HIVE" | sed -E 's/.*"ImagePath",0x[0-9a-fA-F]+,"([^"]*)".*/\1/' | sed -E 's#\\#/#g' | awk -F/ '{print $1"/"$2"/"$(NF-1)}' | sort | uniq -c | sort -rn

echo
echo "== per binary (basename -> module defined? literal mention?)"
unresolved=0
grep '"ImagePath"' "$HIVE" | sed -E 's/.*"ImagePath",0x[0-9a-fA-F]+,"([^"]*)".*/\1/' | sed -E 's#\\#/#g' | while IFS= read -r p; do
  # strip arguments (e.g. "system32\lsass.exe" has none, but some ImagePaths carry flags)
  bin=$(basename -- "$p" | awk '{print $1}')
  svc=$(grep -m1 -F "$p" "$HIVE" | sed -E 's#.*Services\\([^\\]+)\\".*#\1#')
  stem="${bin%.*}"
  mod=$(git grep -l -i -E "(add_library|add_executable|add_module)[[:space:]]*\([[:space:]]*${stem}([[:space:]]|\))" -- '*CMakeLists.txt' '*.cmake' 2>/dev/null | head -1)
  lit=$(git grep -l -i -F "$bin" -- '*CMakeLists.txt' '*.cmake' '*.inf' '*.inx' 2>/dev/null | head -1)
  if [ -n "$mod" ]; then
    printf 'OK   %-28s svc=%-22s module in %s\n' "$bin" "$svc" "$mod"
  elif [ -n "$lit" ]; then
    printf 'LIT  %-28s svc=%-22s literal in %s (no add_library/executable of that name)\n' "$bin" "$svc" "$lit"
  else
    printf 'MISS %-28s svc=%-22s no module, no literal mention\n' "$bin" "$svc"
  fi
done | sort
