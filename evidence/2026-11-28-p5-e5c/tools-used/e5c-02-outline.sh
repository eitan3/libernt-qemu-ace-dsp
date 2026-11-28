#!/bin/bash
# READ-ONLY: outline of the backend and the test dir.
R=<home>/Projects/LiberNT
F=$R/dll/win32/mmdevapi/libernt_wdmaud.c
echo "== function definitions in libernt_wdmaud.c"
grep -n -E '^[A-Za-z_][A-Za-z0-9_ \*]*\(' "$F" | grep -v -E '^\s*[0-9]+:(if|for|while|switch|return)\b' | cut -c1-170
echo "== includes"
grep -n -E '^#(include|define)' "$F" | cut -c1-160 | head -80
echo "== wc"
wc -l "$F" $R/dll/win32/mmdevapi/devenum.c $R/dll/win32/mmdevapi/unixlib.h $R/dll/win32/mmdevapi/mmdevapi_private.h
echo "== host-tests/mmdevapi"
ls -la $R/submodules/host-tests/mmdevapi/
echo "== host-tests top"
ls $R/submodules/host-tests/
