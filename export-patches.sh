#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# qemu-ace-dsp: export the series (every commit on master above v11.1.3) to
# patches/ as git-format-patch output, replacing what is there.  build.sh
# applies exactly these files onto a clean v11.1.3.
# This work is licensed under the terms of the GNU GPL, version 2 or later.
# See the COPYING file in the top-level directory.
set -euo pipefail
cd "$(dirname "$0")"
rm -f patches/*.patch
mkdir -p patches
count=$(git -C src/qemu-11.1.3 rev-list --count v11.1.3..master)
git -C src/qemu-11.1.3 format-patch -q v11.1.3..master -o "$PWD/patches"
echo "exported $(ls patches/*.patch | wc -l) of $count commits to patches/"
