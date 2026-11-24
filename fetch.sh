#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# qemu-ace-dsp: fetch the pinned QEMU source and make a clean git baseline.
#
# Downloads qemu-11.1.3.tar.xz (sha256 pinned), unpacks it under src/, and
# turns the unmodified tarball into a git repository with one commit tagged
# v11.1.3, so build.sh can `git am` the patch series onto a clean baseline
# every time. A checksum mismatch aborts; an existing, verified tree is kept.
#
# Also populates firmware/ with the OVMF firmware blobs the VM needs (edk2,
# BSD-2-Clause-Patent, not part of this GPL project -- kept out of git):
# copied from the gate-(a) unpack under /tmp/p2c-qemu when it is there,
# otherwise the Arch `edk2-ovmf` package is downloaded and unpacked the same
# user-space way as refs/p2c/gate-a/fetch-qemu.sh (sha256 checked against the
# pacman sync database).
#
# This work is licensed under the terms of the GNU GPL, version 2 or later.
# See the COPYING file in the top-level directory.
set -euo pipefail
cd "$(dirname "$0")"

VER=11.1.3
SHA=5a8289c7940dc77d3873c81a6c29ba3afe1446fc9d36e77fa1658cdbecb84b22
URL="https://download.qemu.org/qemu-$VER.tar.xz"
GITID=(-c user.name=qemu-ace-dsp -c user.email=qemu-ace-dsp@localhost)

mkdir -p src dl
TAR="dl/qemu-$VER.tar.xz"
if [ ! -s "$TAR" ]; then
    echo "fetching $URL"
    curl -fsSL -o "$TAR.part" "$URL"
    mv "$TAR.part" "$TAR"
fi
got=$(sha256sum "$TAR" | awk '{print $1}')
if [ "$got" != "$SHA" ]; then
    echo "sha256 mismatch for $TAR: expected $SHA, got $got" >&2
    exit 1
fi
echo "ok  $TAR sha256 $got"

if [ ! -d "src/qemu-$VER/.git" ]; then
    rm -rf "src/qemu-$VER"
    tar -C src -xf "$TAR"
    git -C "src/qemu-$VER" init -q
    git -C "src/qemu-$VER" add -A
    git -C "src/qemu-$VER" "${GITID[@]}" commit -q -m "qemu-$VER: the unmodified release tarball (sha256 $SHA)"
    git -C "src/qemu-$VER" tag v$VER
    echo "baseline commit v$VER created"
fi
# The project ships QEMU's own licence text.
cp -f "src/qemu-$VER/COPYING" COPYING

# OVMF firmware for the VM (not committed; see .gitignore).
mkdir -p firmware
GATE=/tmp/p2c-qemu/usr/usr/share/edk2/x64
if [ ! -s firmware/OVMF_CODE.4m.fd ]; then
    if [ -s "$GATE/OVMF_CODE.4m.fd" ]; then
        cp -f "$GATE/OVMF_CODE.4m.fd" "$GATE/OVMF_VARS.4m.fd" firmware/
        echo "firmware: copied OVMF from $GATE"
    else
        PKG=edk2-ovmf-202608-1-any.pkg.tar.zst
        URLPKG=https://archlinux.interhost.co.il/extra/os/x86_64/$PKG
        [ -s "dl/$PKG" ] || curl -fsSL -o "dl/$PKG" "$URLPKG"
        want=$(for db in /var/lib/pacman/sync/*.db; do
                   bsdtar -xOf "$db" "edk2-ovmf-202608-1/desc" 2>/dev/null |
                       awk '/^%SHA256SUM%$/{f=1;next} f&&/^%/{exit} f{print;exit}'
               done | head -1)
        gotp=$(sha256sum "dl/$PKG" | awk '{print $1}')
        if [ -z "$want" ] || [ "$want" != "$gotp" ]; then
            echo "sha256 mismatch for $PKG: pacman db '$want' vs '$gotp'" >&2
            exit 1
        fi
        bsdtar -xOf "dl/$PKG" usr/share/edk2/x64/OVMF_CODE.4m.fd > firmware/OVMF_CODE.4m.fd
        bsdtar -xOf "dl/$PKG" usr/share/edk2/x64/OVMF_VARS.4m.fd > firmware/OVMF_VARS.4m.fd
        echo "firmware: extracted OVMF from $PKG (sha256 ok)"
    fi
fi
echo "done: src/qemu-$VER at $(git -C "src/qemu-$VER" describe --tags), firmware/OVMF_CODE.4m.fd present"
