#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# make-overlay.sh — a qcow2 overlay over the pinned P2b LiberNT.vhd, so the
# guest can persist a registry value (BootDsp=1, plan decision M6) without
# touching the image.  The overlay goes to disk/<name>.qcow2 (not committed).
# Uses the Arch qemu-img of the gate-(a) unpack when the self-built tree has
# no tools (--disable-tools), else build/qemu-img.
# usage: make-overlay.sh [name]   (default: bootdsp)
# This work is licensed under the terms of the GNU GPL, version 2 or later.
# See the COPYING file in the top-level directory.
set -euo pipefail
cd "$(dirname "$0")"
NAME="${1:-bootdsp}"
VHD="${VHD:-/home/megan/libernt-build-logs/test-audio-intel-sst-p2b-51f9711a/LiberNT.vhd}"
if [ -x build/qemu-img ]; then
    IMG=(build/qemu-img)
else
    IMG=(env LD_LIBRARY_PATH=/tmp/p2c-qemu/usr/usr/lib /tmp/p2c-qemu/usr/usr/bin/qemu-img)
fi
mkdir -p disk
if [ -e "disk/$NAME.qcow2" ]; then
    echo "disk/$NAME.qcow2 exists; remove it to recreate" >&2
    exit 1
fi
"${IMG[@]}" create -f qcow2 -b "$VHD" -F vpc "disk/$NAME.qcow2"
"${IMG[@]}" info "disk/$NAME.qcow2" | head -6
