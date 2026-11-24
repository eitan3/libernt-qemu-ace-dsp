#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# run-control.sh — the regression control: the same image, the same QEMU, with
# QEMU's stock ich9-intel-hda (8086:293e) instead of the ACE model (default),
# or with no HDA controller at all (arg "none": the QEMU-default baseline).
# Expected serial lines: plan §6.2 / TESTING.md (a).
#
# This work is licensed under the terms of the GNU GPL, version 2 or later.
# See the COPYING file in the top-level directory.
set -u
cd "$(dirname "$0")"
case "${1:-ich9}" in
    ich9|none) HDA="$1" ;;
    *) echo "usage: run-control.sh [ich9|none]" >&2; exit 2 ;;
esac
. ./lib-run.sh
