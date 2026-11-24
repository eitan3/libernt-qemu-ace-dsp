#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# make-overlay.sh — a qcow2 overlay over the installed P2b LiberNT.vhd, so the
# guest can persist a registry value (BootDsp=1) without touching the image.
# The overlay goes to disk/<name>.qcow2 (not committed).
# Uses the packaged qemu-img of the gate-(a) unpack when the self-built tree
# has no tools (--disable-tools), else build/qemu-img.
# usage: make-overlay.sh [name]   (default: bootdsp)
# env:    VHD=<path to LiberNT.vhd>   (default: disk/LiberNT.vhd)
# This work is licensed under the terms of the GNU GPL, version 2 or later.
# See the COPYING file in the top-level directory.
set -euo pipefail
QAD="$(cd "$(dirname "$0")" && pwd)"
NAME="${1:-bootdsp}"
VHD="${VHD:-$QAD/disk/LiberNT.vhd}"   # the installed image: put it under disk/ or set VHD=
if [ -x "$QAD/build/qemu-img" ]; then
    IMG=("$QAD/build/qemu-img")
else
    IMG=(env LD_LIBRARY_PATH=/tmp/p2c-qemu/usr/usr/lib /tmp/p2c-qemu/usr/usr/bin/qemu-img)
fi
mkdir -p "$QAD/disk"
if [ -e "$QAD/disk/$NAME.qcow2" ]; then
    echo "disk/$NAME.qcow2 exists; remove it to recreate" >&2
    exit 1
fi
"${IMG[@]}" create -f qcow2 -b "$VHD" -F vpc "$QAD/disk/$NAME.qcow2"
"${IMG[@]}" info "$QAD/disk/$NAME.qcow2" | head -6
