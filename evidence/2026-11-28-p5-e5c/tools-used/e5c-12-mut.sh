#!/bin/bash
# E5c mutations of endpoint_props.h: each applied to a copy of the original, the host test rebuilt and run
# (it must go red), the original put back. The last line rebuilds the restored header and runs green.
set -u
H=<home>/Projects/LiberNT/dll/win32/mmdevapi/endpoint_props.h
B=/tmp/e5c/endpoint_props.h.orig
L=/tmp/e5c
cp "$H" "$B"
mut() {
    local id="$1" script="$2" rc
    cp "$B" "$H"
    sed -i "$script" "$H"
    if cmp -s "$B" "$H"; then echo "$id: !! NOT APPLIED"; cp "$B" "$H"; return; fi
    (cd /tmp/ht-e1a && ninja mmdevapi > "$L/mut-$id-build.txt" 2>&1); rc=$?
    if [ "$rc" != 0 ]; then
        echo "$id: !! build rc=$rc: $(grep -c ' error:' "$L/mut-$id-build.txt") errors (a build failure is not a kill)"
    else
        "$L/mut-$id-run" 2>/dev/null
        /tmp/ht-e1a/mmdevapi/mmdevapi > "$L/mut-$id.txt" 2>&1; rc=$?
        echo "$id: run rc=$rc, $(tail -1 "$L/mut-$id.txt"), red checks: $(grep -c 'FAIL' "$L/mut-$id.txt"), first red: $(grep -m1 'FAIL' "$L/mut-$id.txt" | sed 's/.*FAIL: //' | cut -c1-90)"
    fi
    cp "$B" "$H"
}
mut m47 "s/{ L.eHeadphone.,        Headphones,/{ L\"eHeadphone\",        Speakers,/"
mut m48 "/endpoint_text_same(at, L.Topo.)/{N;d}"
mut m49 "s/character >= L.A. && character <= L.Z./0/"
mut m50 "s/if (endpoint_is_dsp_pcm(path))/if (0)/"
mut m51 "s/KSAUDIO_SPEAKER_5POINT1;/KSAUDIO_SPEAKER_7POINT1;/"
mut m52 "/while (.at >= L.0. && .at <= L.9.)/{N;d}"
mut m53 "s/if (!.value)/if (0)/"
if cmp -s "$B" "$H"; then echo "restored: identical to the original"; else echo "!! the header is NOT the original"; cp "$B" "$H"; fi
(cd /tmp/ht-e1a && ninja mmdevapi > "$L/mut-restore-build.txt" 2>&1); echo "rebuild rc=$?"
/tmp/ht-e1a/mmdevapi/mmdevapi | tail -1
