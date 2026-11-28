#!/bin/bash
# Diagnose the hive line the editor did not match: raw bytes, line endings, encoding.
set -u
F=<home>/Projects/LiberNT/image/data/hivesys.inf
echo "file: $(file "$F")"
echo "CRLF lines in file: $(grep -c $'\r$' "$F")"
echo "--- line 2052 raw:"
sed -n '2052p' "$F" | od -c | head -8
echo "--- grep -n wifi.sys:"
grep -n 'wifi\.sys' "$F"
