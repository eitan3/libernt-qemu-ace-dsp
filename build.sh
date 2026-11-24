#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# qemu-ace-dsp: build the patched QEMU.
#
#  1. on a separate branch `applied`: reset src/qemu-11.1.3 to the clean v11.1.3
#     baseline and `git am` every patches/*.patch onto it (none yet -> the
#     pristine tree).  The development branch `master` is left alone; the
#     script refuses to run on a tree with uncommitted changes.  PATCHDIR
#     selects another series directory (the mutation check uses it);
#  2. configure out of tree in build/ (the gate-(c) option line of the plan:
#     x86_64-softmmu only, no system meson needed -- configure makes its own
#     pyvenv).  EXTRA_CONFIGURE adds options (e.g. host-specific -O3/-march);
#  3. ninja. The wall time is appended to build/TIME.txt (the first, cold
#     build is the measurement the plan asked for; later runs are incremental).
#
# Run `RECONFIGURE=1 build.sh` after changing the configure options.
# build/ lives under /home, never in the tmpfs /tmp.
#
# This work is licensed under the terms of the GNU GPL, version 2 or later.
# See the COPYING file in the top-level directory.
set -euo pipefail
cd "$(dirname "$0")"
VER=11.1.3
SRC="$PWD/src/qemu-$VER"
B="$PWD/build"
mkdir -p "$B"

t0=$(date +%s)
CONFIGURED=no
if ! git -C "$SRC" diff --quiet || ! git -C "$SRC" diff --cached --quiet; then
    echo "build FAILED: $SRC has uncommitted changes; commit them on master first (build.sh resets the applied branch)" >&2
    exit 1
fi
echo "== $(date -u +%FT%TZ) branch applied = v$VER + patches"
# an interrupted run may have left an apply state behind
git -C "$SRC" am --abort -q 2>/dev/null || true
rm -rf "$SRC/.git/rebase-apply"
git -C "$SRC" checkout -q -B applied "v$VER"
# whatever happens below, leave the development branch checked out
cleanup() {
    git -C "$SRC" am --abort -q 2>/dev/null || true
    rm -rf "$SRC/.git/rebase-apply"
    git -C "$SRC" checkout -q master 2>/dev/null || true
    git -C "$SRC" branch -q -D applied 2>/dev/null || true
}
trap cleanup EXIT
PATCHDIR="${PATCHDIR:-$PWD/patches}"
shopt -s nullglob
patches=("$PATCHDIR"/*.patch)
if [ ${#patches[@]} -gt 0 ]; then
    if ! git -C "$SRC" -c user.name=qemu-ace-dsp -c user.email=qemu-ace-dsp@localhost \
            am -q "${patches[@]}"; then
        echo "build FAILED: git am could not apply the series from $PATCHDIR"
        exit 1
    fi
fi
git -C "$SRC" log --format='%h %s' "v$VER..HEAD" > "$B/applied-patches.txt"
echo "applied $(wc -l < "$B/applied-patches.txt") patch(es)"

cd "$B"
if [ ! -f config-host.mak ] || [ "${RECONFIGURE:-0}" = 1 ]; then
    CONFIGURED=yes
    echo "== $(date -u +%FT%TZ) configure (extra: ${EXTRA_CONFIGURE:-none})"
    # shellcheck disable=SC2086
    "$SRC/configure" \
        --target-list=x86_64-softmmu \
        --prefix="$B/inst" \
        --disable-werror --disable-docs --disable-tools \
        --disable-guest-agent --audio-drv-list= \
        --disable-opengl --disable-virglrenderer --disable-gtk --disable-sdl \
        --disable-spice --disable-vnc --disable-curses --disable-usb-redir \
        --disable-libnfs --disable-vde --disable-xen \
        --disable-vhost-user --disable-vhost-vdpa --enable-modules \
        ${EXTRA_CONFIGURE:-} \
        > configure.log 2>&1 || { echo "build FAILED: configure"; tail -30 configure.log; exit 1; }
    echo "extra configure options: ${EXTRA_CONFIGURE:-none}" >> TIME.txt
fi

echo "== $(date -u +%FT%TZ) ninja (${JOBS:-$(nproc)} jobs)"
ninja -j "${JOBS:-$(nproc)}" > ninja.log 2>&1 || { echo "build FAILED: ninja"; tail -60 ninja.log; exit 1; }
tail -1 ninja.log
t1=$(date +%s)
echo "$VER patches=$(wc -l < applied-patches.txt | tr -d ' ') rc=0 wall=$((t1 - t0))s jobs=${JOBS:-$(nproc)} configure=$CONFIGURED extra='${EXTRA_CONFIGURE:-none}' $(date -u +%FT%TZ)" >> TIME.txt
echo "== build ok in $((t1 - t0)) s: $(wc -l < "$B/applied-patches.txt") patch(es) applied"
./qemu-system-x86_64 --version
