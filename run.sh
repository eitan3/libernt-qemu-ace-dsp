#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# run.sh — the LiberNT P2b image with the ACE audio DSP model (intel-hda-ace at
# the PCH address 1b.0, an hda-duplex codec on its HDA bus). See lib-run.sh for
# the environment variables (EVID, DISK, FAULT, ACE_ARGS, TRACE, WAIT, STOP_ON).
#
# Stage 1 (probe only) in one line:
#   TRACE=1 WAIT=240 STOP_ON='BootDsp = 0' ./run.sh
# This work is licensed under the terms of the GNU GPL, version 2 or later.
# See the COPYING file in the top-level directory.
set -u
cd "$(dirname "$0")"
HDA=ace . ./lib-run.sh
