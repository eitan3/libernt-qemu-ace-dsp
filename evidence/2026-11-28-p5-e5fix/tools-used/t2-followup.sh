#!/bin/bash
# T2 follow-up: the five ImagePath names the first scan did not resolve. Read-only.
set -u
cd <home>/Projects/LiberNT || exit 1
HIVE=image/data/hivesys.inf

for b in packet.sys spoolsv.exe svchost.exe telnetd.exe; do
  echo "=== $b: raw hive lines"
  grep -n -F "$b" "$HIVE" | head -4
  stem="${b%.*}"
  echo "--- CMake: any add_library/add_executable naming '$stem' (loose, incl. name alone on its line)"
  git grep -n -i -E "(add_library|add_executable|add_module)[[:space:]]*\([[:space:]]*${stem}[[:space:])]" -- '*CMakeLists.txt' | head -3
  git grep -n -i -E "^[[:space:]]*${stem}[[:space:]]*$" -- '*CMakeLists.txt' | head -3
  echo "--- literal '$b' anywhere outside the hive"
  git grep -l -i -F "$b" -- ':!image/data/hivesys.inf' | head -5
  echo
done

echo "=== the 'V' entry: ImagePath lines whose value does not end in .sys/.exe/.dll"
grep '"ImagePath"' "$HIVE" | grep -v -i -E '\.(sys|exe|dll)"' | head -5

echo
echo "=== the full service record of every ImagePath whose basename is not resolved by the first scan"
grep -n -B3 -A4 -i -e '"ImagePath",0x[0-9a-fA-F]*,"[^"]*\(packet\|telnetd\)' "$HIVE" | head -40
