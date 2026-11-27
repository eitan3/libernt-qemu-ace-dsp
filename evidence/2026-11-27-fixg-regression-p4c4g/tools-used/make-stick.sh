#!/bin/bash
# make-stick.sh -- stick A of the regression (p4c4g LiberNT.img on a raw virtual stick): a 4 GiB
# raw file with LiberNT.img at offset 0 -- what DD mode writes onto a larger stick.
#   make-stick.sh <source LiberNT.img> <out.img> <record dir>
set -eu
SRC="${1:?source image}"; OUT="${2:?out.img}"; REC="${3:?record dir}"
mkdir -p "$REC" "$(dirname "$OUT")"
[ -e "$OUT" ] && { echo "refusing: $OUT exists" >&2; exit 3; }
truncate -s 4G "$OUT"
dd if="$SRC" of="$OUT" bs=4M conv=notrunc status=none
# the image part's hash must equal the source's (read back from the stick file)
p=$(sha256sum "$SRC" | cut -d' ' -f1)
q=$(head -c "$(stat -c %s "$SRC")" "$OUT" | sha256sum | cut -d' ' -f1)
{
    echo "# stick A made $(date -u +%FT%TZ)"
    echo "source LiberNT.img sha256: $p"
    echo "the first $(stat -c %s "$SRC") bytes of the stick read back: $q"
    [ "$p" = "$q" ] && echo "EQUAL" || echo "DIFFERENT"
    echo "stick file: $(stat -c %s "$OUT") bytes"
    sfdisk -d "$OUT"
} | sed "s|$OUT|<project>/disk/$(basename "$OUT")|" > "$REC/s0-stick-sfdisk-d.txt"
cat "$REC/s0-stick-sfdisk-d.txt"
