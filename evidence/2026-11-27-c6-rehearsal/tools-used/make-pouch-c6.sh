#!/bin/bash
# make-pouch-c6.sh <out.img> -- the data disk of the C6 rehearsal VM: a small MBR disk with one
# FAT16 partition (32 MiB, sector 63) that carries the kit files into the guest once (the owner
# copies the kit from Windows onto the stick instead); afterwards the guest writes its exported
# logs onto it and the host reads them with mtools (mtools -i <img>@@32256).
set -eu
OUT="${1:?usage: make-pouch-c6.sh <out.img>}"
SRC=<home>/Projects/LiberNT-IntelDSP-plan/refs/c6/kit
W=$(mktemp -d /tmp/qad-ev/c6/pouch.XXXXXX)
trap 'rm -rf "$W"' EXIT
OFF=63; SECT=65536
mkdir -p "$(dirname "$OUT")"
mkfs.vfat -C "$W/part.img" -n C6KIT -s 4 $((SECT / 2)) > "$W/mkfs.out" 2>&1
mcopy -i "$W/part.img" "$SRC"/*.cmd "$SRC"/dsploop_apitest.exe "$SRC"/KIT-SHA256SUMS ::/
printf 'c6 kit disk: the data disk of the rehearsal VM\n' > "$W/pouch.tag"
mcopy -i "$W/part.img" "$W/pouch.tag" ::/
truncate -s $(( (OFF + SECT) * 512 )) "$OUT"
sfdisk -q "$OUT" > "$W/sfdisk.out" 2>&1 <<EOF
label: dos
start=$OFF, size=$SECT, type=6
EOF
dd if="$W/part.img" of="$OUT" bs=512 seek=$OFF conv=notrunc status=none
echo "== $(basename "$OUT"): $(stat -c %s "$OUT") bytes; the files on it (mdir):"
mdir -i "$OUT@@$((OFF * 512))" ::
mcopy -n -i "$OUT@@$((OFF * 512))" ::/dsploop_apitest.exe "$W/readback.exe"
echo "== dsploop_apitest.exe read back: $(sha256sum "$W/readback.exe" | cut -d' ' -f1)"
echo "== kit folder:                   $(sha256sum "$SRC/dsploop_apitest.exe" | cut -d' ' -f1)"
