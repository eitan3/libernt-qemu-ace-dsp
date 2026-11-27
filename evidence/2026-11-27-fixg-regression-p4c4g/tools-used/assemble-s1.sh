#!/bin/bash
# assemble-s1.sh -- copy the first-session flow's evidence into the evidence tree: the exports
# as the host read them from stick B (the NUL-stripped .txt; the raw 270,336-byte exports are left
# out), the comparisons against the p4c4e final pass, the two VMs' logs and a few screenshots.
set -eu
Q=<project>
E=$Q/evidence/2026-11-27-fixg-regression-p4c4g
S=/tmp/c6g/exports
V=/tmp/c6g/ev
mkdir -p "$E/logs/s1" "$E/vm1" "$E/vm1x"
for f in boot1 boot2 boot2-prev boot3 boot3-prev boot4 boot4-prev; do cp "$S/$f.txt" "$E/logs/s1/"; done
cp "$S"/dsploop.txt "$S"/stats.txt "$S"/gate.txt "$S"/expected-vs-measured.txt "$S"/cmp-vs-p4c4e.txt "$S"/listing.txt "$S"/mdir-root.txt "$S"/dspdiff-boot*-p4c4e.txt "$E/logs/s1/"
for v in vm1 vm1x; do
    cp "$V/$v/driver.log" "$V/$v/start.txt" "$V/$v/qemu-args.txt" "$E/$v/"
    gzip -9 -c "$V/$v/qemu-dbg.log" > "$E/$v/qemu-dbg.log.gz"
done
for f in b1-02-t60s z-b1-02-watermark b1-07-account-filled b1-08-components-page b1-10-steam-cleared z-b1-10-need-line-x3 \
         b1-16-after-savelog1-dir b2-04-after-stage1 b2r-early-08 b3-03-sound-playback b3-04-sound-recording \
         b4-03-at-60s-finished b4-06-tm-turnoff-selected; do
    cp "$V/vm1/$f.png" "$E/vm1/"
done
cp "$V"/vm1x/x1-03-after-export-copy.png "$E/vm1x/"
echo "assembled: $(find "$E" -type f | wc -l) files, $(du -sh "$E" | cut -f1); vm1 pngs $(ls "$E"/vm1/*.png | wc -l)"
