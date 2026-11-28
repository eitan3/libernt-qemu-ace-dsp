#!/bin/bash
# mut-e5b.sh -- the E5b mutation rows (E4b's mut-e4b.sh): one line of the new logic changed at a time, the host
# test rebuilt and run, the failures counted, the file restored and compared.
#   m40  the walk follows the parts outgoing from a render endpoint's connector (E5a's direction, N15-20)  -> dsploop CheckWalkDirection
#   m41  the walk always follows the incoming parts                                                      -> dsploop CheckWalkDirection
#   m42  the walk always follows the outgoing parts                                                      -> dsploop CheckWalkDirection
#   m43  the two flows exchanged (In 1, Out 0)                                                           -> dsploop CheckWalkDirection
R=<home>/Projects/LiberNT
S=/tmp/ht-e1a
M=/tmp/e5b/mut
mkdir -p "$M"
[ "$(ps -eo comm | grep -c qemu-system || true)" = 0 ] || { echo "!! a VM is up: the compiles are not run"; exit 2; }
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
    summary=$(grep -E "^(dsploop):" "$M/mut-$name.txt" | tail -1)
    first=$(grep -m1 "FAIL" "$M/mut-$name.txt" | sed 's|.*t_[a-z]*\.c:||' | cut -c1-120)
    if [ "$red" = "0" ]; then echo "$name: 0 red -- SURVIVED ($desc)"; else echo "$name: $red red ($desc); first: $first [$summary]"; fi
    cp "$M/mut-$name.orig" "$F"
    cmp -s "$F" "$M/mut-$name.orig" && echo "   restored: identical" || echo "   restored: DIFFERS"
}
echo "== base $(date +%T) =="
ninja -C "$S" dsploop/dsploop > /dev/null 2>&1
"$S/dsploop/dsploop" 2>&1 | grep "dsploop:"
W=modules/rostests/apitests/dsploop/walk.h
run $W m40 "the walk follows the parts outgoing from a render endpoint's connector (E5a's direction, N15-20)" dsploop/dsploop \
"    return Flow == DsploopFlowIn;" \
"    return Flow == DsploopFlowOut;"
run $W m41 "the walk always follows the incoming parts" dsploop/dsploop \
"    return Flow == DsploopFlowIn;" \
"    return 1;"
run $W m42 "the walk always follows the outgoing parts" dsploop/dsploop \
"    return Flow == DsploopFlowIn;" \
"    return 0;"
run $W m43 "the two flows exchanged (In 1, Out 0)" dsploop/dsploop \
"    DsploopFlowIn = 0,   /* a render endpoint: the signal enters its connector */
    DsploopFlowOut = 1   /* a capture endpoint: the signal leaves its connector */" \
"    DsploopFlowIn = 1,   /* a render endpoint: the signal enters its connector */
    DsploopFlowOut = 0   /* a capture endpoint: the signal leaves its connector */"
# the control interface's node flag (dll/win32/mmdevapi/devicetopology_control.h, N15-20) -> mmdevapi's checks of the request bytes
H=dll/win32/mmdevapi/devicetopology_control.h
echo "== the header's node flag rows (mmdevapi) $(date +%T) =="
ninja -C "$S" mmdevapi/mmdevapi > /dev/null 2>&1
"$S/mmdevapi/mmdevapi" 2>&1 | grep "mmdevapi:"
run $H m44 "a node's property request without KSPROPERTY_TYPE_TOPOLOGY (the E5a request: answered STATUS_NOT_FOUND)" mmdevapi/mmdevapi \
"    request.Property.Flags |= KSPROPERTY_TYPE_TOPOLOGY;
" \
"    request.Property.Flags |= 0;
"
run $H m45 "a node's event request without KSEVENT_TYPE_TOPOLOGY" mmdevapi/mmdevapi \
"    request.Event.Flags |= KSEVENT_TYPE_TOPOLOGY;
" \
"    request.Event.Flags |= 0;
"
run $H m46 "a node's method request without KSMETHOD_TYPE_TOPOLOGY" mmdevapi/mmdevapi \
"    request.Method.Flags |= KSMETHOD_TYPE_TOPOLOGY;
" \
"    request.Method.Flags |= 0;
"
echo "== after the header rows $(date +%T) =="
cmp -s "$R/$H" "$M/mut-m44.orig" && echo "$H: identical to its copy before its first row"
ninja -C "$S" mmdevapi/mmdevapi > /dev/null 2>&1
"$S/mmdevapi/mmdevapi" 2>&1 | grep "mmdevapi:"
echo "== after $(date +%T) =="
cmp -s "$R/$W" "$M/mut-m40.orig" && echo "$W: identical to its copy before the first row"
ninja -C "$S" dsploop/dsploop > /dev/null 2>&1
"$S/dsploop/dsploop" 2>&1 | grep "dsploop:"
