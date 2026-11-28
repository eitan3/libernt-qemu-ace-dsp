#!/bin/bash
# make-pouch.sh -- the data disk of a VM of the P5 E4 round: a small MBR disk with one FAT16
# partition ("the pouch") that carries dsploop_apitest.exe into the guest and brings the text the
# guest writes back out, read on the host with mtools.  (The E3 round's make-pouch.sh.)
#   make-pouch.sh <out.img>   (env SRC: the directory holding dsploop_apitest.exe; default: p5e3's staging)
# The exe is the image directory's (its hash checked before and after the copy); a marker file
# pouch.tag tells the guest's console which drive letter the disk got.
set -eu
OUT="${1:?usage: make-pouch.sh <out.img>}"
SRC="${SRC:-/tmp/e5fix/dsploop}"
W=$(mktemp -d /tmp/e5fix/pouch.XXXXXX)
trap 'rm -rf "$W"' EXIT
OFF=63                       # the partition's first sector
SECT=65536                   # 32 MiB of FAT16 in the partition
mkfs.vfat -C "$W/part.img" -n P5E5F -s 4 $((SECT / 2)) > "$W/mkfs.out" 2>&1
mcopy -i "$W/part.img" "$SRC/dsploop_apitest.exe" ::/
printf "e5fix pouch: the data disk of this VM\n" > "$W/pouch.tag"
mcopy -i "$W/part.img" "$W/pouch.tag" ::/
mcopy -i "$W/part.img" /tmp/e5fix/tools/setdef.cmd ::/
mcopy -i "$W/part.img" /tmp/e5fix/setdef/setdefault.exe ::/
mcopy -i "$W/part.img" /tmp/e5fix/tools/dl.cmd ::/
mcopy -i "$W/part.img" /tmp/e5fix/tools/mute.cmd /tmp/e5fix/tools/hc.cmd /tmp/e5fix/tools/snd.cmd /tmp/e5fix/tools/vol.cmd ::/
mcopy -i "$W/part.img" /tmp/e5fix/setdef/endpointmute.exe /tmp/e5fix/setdef/procinfo.exe ::/
mcopy -i "$W/part.img" /tmp/e5fix/tools/cap.cmd /tmp/e5fix/tools/svc.cmd ::/
[ "$(mdir -i "$W/part.img" ::/ | grep -c 'pouch    tag')" = 1 ] || { echo "!! pouch.tag is not on the image" >&2; mdir -i "$W/part.img" ::/ >&2; exit 1; }
truncate -s $(( (OFF + SECT) * 512 )) "$OUT"
sfdisk -q "$OUT" > "$W/sfdisk.out" 2>&1 <<EOF
label: dos
start=$OFF, size=$SECT, type=6
EOF
dd if="$W/part.img" of="$OUT" bs=512 seek=$OFF conv=notrunc status=none
echo "== $(basename "$OUT"): $(stat -c %s "$OUT") bytes"
sfdisk -d "$OUT" | grep -v '^$'
fsck.fat -n "$W/part.img" > "$W/fsck.out" 2>&1 && echo "fsck.fat -n of the partition: clean" || { cat "$W/fsck.out"; exit 1; }
echo "== the files on it (mdir):"
mdir -i "$OUT@@$((OFF * 512))" ::
mcopy -n -i "$OUT@@$((OFF * 512))" ::/dsploop_apitest.exe "$W/readback.exe"
echo "== the exe read back from the image: $(sha256sum "$W/readback.exe" | cut -d' ' -f1)"
echo "== the image directory's exe:            $(sha256sum "$SRC/dsploop_apitest.exe" | cut -d' ' -f1)"
