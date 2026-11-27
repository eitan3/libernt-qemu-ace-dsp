#!/bin/bash
# make-pouch.sh <out.img> -- stick B of the final pass: a FAT32 data disk (MBR, one partition at
# sector 2048, 256 MiB) that carries the deliverable `kit` folder in once, as the owner's spare
# stick will (the run book: "Format stick B as FAT32"); afterwards the guest writes its exported
# logs onto it and the host reads them with mtools (mtools -i <img>@@<offset*512>).
set -eu
OUT="${1:?usage: make-pouch.sh <out.img>}"
SRC=<home>/Projects/LiberNT-IntelDSP-plan/refs/c6/kit
W=$(mktemp -d /tmp/c6f/pouch.XXXXXX)
trap 'rm -rf "$W"' EXIT
OFF=2048; SECT=$((256 * 2048 - OFF))
mkdir -p "$(dirname "$OUT")"
mkfs.vfat -C "$W/part.img" -n LIBERNTKIT -F 32 -s 8 -S 512 $((SECT / 8)) > "$W/mkfs.out" 2>&1
mmd -i "$W/part.img" ::/kit
mcopy -i "$W/part.img" "$SRC"/*.cmd "$SRC"/dsploop_apitest.exe "$SRC"/KIT-SHA256SUMS ::/kit/
truncate -s $(( (OFF + SECT) * 512 )) "$OUT"
sfdisk -q "$OUT" > "$W/sfdisk.out" 2>&1 <<EOF
label: dos
start=$OFF, size=$SECT, type=c
EOF
dd if="$W/part.img" of="$OUT" bs=512 seek=$OFF conv=notrunc status=none
echo "== $(basename "$OUT"): $(stat -c %s "$OUT") bytes; the files on it (mdir):"
mdir -i "$OUT@@$((OFF * 512))" ::/kit
mcopy -n -i "$OUT@@$((OFF * 512))" ::/kit/dsploop_apitest.exe "$W/readback.exe"
echo "== dsploop_apitest.exe read back: $(sha256sum "$W/readback.exe" | cut -d' ' -f1)"
echo "== kit folder:                   $(sha256sum "$SRC/dsploop_apitest.exe" | cut -d' ' -f1)"
