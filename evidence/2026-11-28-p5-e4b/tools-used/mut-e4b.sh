#!/bin/bash
# mut-e4b.sh -- the E4b mutation rows (E4's mut-e4.sh): one line of the new logic changed at a time, the host test
# rebuilt and run, the failures counted, the file restored and compared.
#   m36  the refused-model query answers FALSE whatever the flag (N14-04)       -> sofipc case i30
#   m37  the teardown poll takes the lock with a wait again (N14-05)            -> sofipc CheckStreamTeardownPoll
#   m38  the gain word is unity whatever the level (N14-02)                     -> dsploop CheckGain
#   m39  the expectation is not scaled by the gain (N14-02)                     -> dsploop CheckGain
R=<home>/Projects/LiberNT
S=/tmp/ht-e1a
M=/tmp/e4b/mut
mkdir -p "$M"
run() {
    rel=$1; name=$2; desc=$3; target=$4; old=$5; new=$6
    F=$R/$rel
    cp "$F" "$M/mut-$name.orig"
    python3 - "$F" "$old" "$new" <<'EOF'
import sys
p, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(p).read()
n = s.count(old)
if n != 1:
    print("MUTATION NOT APPLIED: %d matches" % n); sys.exit(3)
open(p, "w").write(s.replace(old, new))
EOF
    if [ $? -ne 0 ]; then echo "$name: MUTATION NOT APPLIED"; cp "$M/mut-$name.orig" "$F"; return; fi
    ninja -C "$S" "$target" > "$M/mut-$name-build.txt" 2>&1
    if [ $? -ne 0 ]; then echo "$name: BUILD FAILED"; grep -m3 "error" "$M/mut-$name-build.txt"; cp "$M/mut-$name.orig" "$F"; return; fi
    "$S/$target" > "$M/mut-$name.txt" 2>&1
    red=$(grep -c "FAIL" "$M/mut-$name.txt")
    summary=$(grep -E "^(sofipc|dsploop):" "$M/mut-$name.txt" | tail -1)
    first=$(grep -m1 "FAIL" "$M/mut-$name.txt" | sed 's|.*t_[a-z]*\.c:||' | cut -c1-120)
    if [ "$red" = "0" ]; then echo "$name: 0 red -- SURVIVED ($desc)"; else echo "$name: $red red ($desc); first: $first [$summary]"; fi
    cp "$M/mut-$name.orig" "$F"
    cmp -s "$F" "$M/mut-$name.orig" && echo "   restored: identical" || echo "   restored: DIFFERS"
}
echo "== base $(date +%T) =="
ninja -C "$S" ipc/sofipc dsploop/dsploop > /dev/null 2>&1
"$S/ipc/sofipc" 2>&1 | grep "sofipc:"
"$S/dsploop/dsploop" 2>&1 | grep "dsploop:"
run drivers/wdm/audio/intcdsp/stream.c m36 "the refused-model query answers FALSE whatever the flag (N14-04)" ipc/sofipc \
"    return Streams->ModelRefused;
}" \
"    return FALSE;
}"
run drivers/wdm/audio/intcdsp/stream.c m37 "the teardown poll takes the lock with a wait again (N14-05)" ipc/sofipc \
"    NoWait.QuadPart = 0;
    if (KeWaitForSingleObject(&Streams->Lock, Executive, KernelMode, FALSE, &NoWait) != STATUS_SUCCESS)
        return 0;" \
"    NoWait.QuadPart = 0;
    (VOID)NoWait.QuadPart;
    if (KeWaitForSingleObject(&Streams->Lock, Executive, KernelMode, FALSE, NULL) != STATUS_SUCCESS)
        return 0;"
run modules/rostests/apitests/dsploop/compare.c m38 "the gain word is unity whatever the level (N14-02)" dsploop/dsploop \
"    if (Level >= 0)
        return DSPLOOP_GAIN_UNITY;
    Down = (uint32_t)-(int64_t)Level;" \
"    if (Level >= 0 || Level < 0)
        return DSPLOOP_GAIN_UNITY;
    Down = (uint32_t)-(int64_t)Level;"
run modules/rostests/apitests/dsploop/compare.c m39 "the expectation is not scaled by the gain (N14-02)" dsploop/dsploop \
"    Sample = GainApply(Sample, ContainerBits, Gain);" \
"    Sample = GainApply(Sample, ContainerBits, DSPLOOP_GAIN_UNITY);"
echo "== after =="
for f in drivers/wdm/audio/intcdsp/stream.c modules/rostests/apitests/dsploop/compare.c; do
    cmp -s "$R/$f" "$M/mut-$( [ "${f##*/}" = stream.c ] && echo m37 || echo m39 ).orig" && echo "$f: identical to its copy before its last row" || echo "$f: DIFFERS"
done
ninja -C "$S" ipc/sofipc dsploop/dsploop > /dev/null 2>&1
"$S/ipc/sofipc" 2>&1 | grep "sofipc:"
"$S/dsploop/dsploop" 2>&1 | grep "dsploop:"
