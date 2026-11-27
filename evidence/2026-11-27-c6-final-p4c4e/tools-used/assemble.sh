#!/bin/bash
# assemble.sh -- copy this pass's evidence into the project's evidence tree (the frames, logs and
# tools the report cites).  Sources: /tmp/c6f (the VMs' working directories, the host's copies of
# the exports); the raw NUL-padded exports are left out (their NUL-stripped .txt are in logs/).
set -eu
Q=<project>
E=$Q/evidence/2026-11-27-c6-final-p4c4e
S=/tmp/c6f
rm -rf "$E"
mkdir -p $E/vm1 $E/vm1x $E/vm2 $E/vm3 $E/logs/s0 $E/logs/s5 $E/logs/s6 $E/tools-used
for f in b1-01-t50s b1-02-t62s b1-03-t97s b1-04-after-expand b1-05-account-page b1-07-account-filled \
         b1-08-components-page b1-10-steam-cleared b1-11-next-focus b1-13-after-finish-22s b1-14-console \
         b1-15-after-copy b1-16-after-savelog1-dir b1-17-tm-restart-selected b1r-early-01 b1r-early-04 b1r-early-05 b1r-early-06 b1r-early-07 \
         b2-01-after-restart-120s b2-02-signin-tile b2-03-desktop-after-signin b2-04-after-stage1 \
         b2r-early-04 b2r-early-05 b2r-early-06 b2r-early-07 b2r-early-09 b2r-early-10 b2r-early-11 b2r-signin-120s \
         b2-07-after-savelog2 b2-08-after-stage2 b3r-early-05 b3r-early-06 b3r-early-07 b3r-early-08 b3r-signin-130s \
         b3-02-after-savelog3 b3-03-sound-playback b3-04-sound-recording b3-05-after-esc b3-06-after-stage3 \
         b4r-early-05 b4r-early-06 b4r-signin-125s b4-03-at-60s b4-04-after-savelog4 b4-05-after-exit b4-06-tm-turnoff-selected \
         z-b1-08-need-line-x3 z-b1-10-list z-b3-04-recording; do
    cp "$S/ev/vm1/$f.png" "$E/vm1/"
done
for v in vm1 vm1x vm2 vm3; do
    cp "$S/ev/$v/driver.log" "$S/ev/$v/start.txt" "$S/ev/$v/qemu-args.txt" "$E/$v/"
    gzip -9 -c "$S/ev/$v/qemu-dbg.log" > "$E/$v/qemu-dbg.log.gz"
done
cp "$S"/ev/vm1x/x1-0[1-4]*.png "$E/vm1x/"
cp "$S"/ev/vm2/f6-*.png "$S"/ev/vm2/f6a-*.png "$S"/ev/vm2/f6b-*.png "$E/vm2/"
cp "$S"/ev/vm3/f7-*.png "$S/ev/vm3/serial.log" "$S/ev/f7-observe.txt" "$E/vm3/"
cp "$S"/ev/s0-*.txt "$S"/ev/vm1-start.txt "$S"/ev/vm1x-start.txt "$S"/ev/vm2-start.txt "$S"/ev/vm3-start.txt "$E/logs/s0/"
cp "$S"/logs/s5/*.txt "$E/logs/s5/"
cp "$S"/logs/s6/*.txt "$E/logs/s6/"
cp "$S"/tools/*.sh "$S"/tools/*.py "$S"/lines-*.txt "$E/tools-used/"
echo "assembled: $(find "$E" -type f | wc -l) files, $(du -sh "$E" | cut -f1)"
ls "$E" "$E/vm1" | head -80
