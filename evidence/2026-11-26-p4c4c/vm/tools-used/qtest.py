#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# qemu-ace-dsp: a minimal qtest client for a VM lib-run.sh started with
# QTESTSOCK=1 -- reads of the ACE model's BAR4 registers while the guest runs.
#
#   qtest.py <qtest.sock> readl 0x81001000 [readl 0x81163200 ...]
#   QTEST_BAR4=0x81000000 qtest.py <qtest.sock> adspcs fsr ...   (named registers)
#
# Reads only: every ace_reg_read is free of side effects (intel-hda-ace.c), so
# the guest is not disturbed; the reads show up in the device trace as
# ace_reg_read lines, which is the record that the check was made.
#
# This work is licensed under the terms of the GNU GPL, version 2 or later.
# See the COPYING file in the top-level directory.
import os
import socket
import sys
import time

# BAR4 offsets of the registers a between-cycles check reads
REGS = {
    'adspcs': 0x1000, 'dsp2cxctl': 0x178D04, 'hfintpptr': 0x1108, 'inten': 0x0120,
    'irqsts': 0x0140, 'hfhipcie': 0x1140, 'hfipcxtdr': 0x73200, 'hfipcxida': 0x73214,
    'hfipcxctl': 0x73228, 'hfipcxtddy': 0x73300, 'fsr': 0x163200,
    'romerr': 0x163204,
}


def qtest(s, cmd):
    s.sendall((cmd + '\n').encode())
    out = b''
    s.settimeout(10)
    while b'\n' not in out:
        chunk = s.recv(4096)
        if not chunk:
            break
        out += chunk
    return out.decode(errors='replace').strip()


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    s = socket.socket(socket.AF_UNIX)
    s.connect(sys.argv[1])
    bar4 = int(os.environ.get('QTEST_BAR4', '0x81000000'), 16)
    rc = 0
    argv = sys.argv[2:]
    while argv:
        op = argv.pop(0)
        if op == 'readl':
            addr = argv.pop(0)
            name = ''
        else:
            addr = '0x%x' % (bar4 + REGS[op])
            name = op
        rep = qtest(s, 'readl %s' % addr)
        if not rep.startswith('OK'):
            rc = 1
        val = rep.split()[1] if rep.startswith('OK') and len(rep.split()) > 1 else rep
        print('%s %s -> %s%s' % (time.strftime('%H:%M:%S'), addr, val,
                                 ' ' + name if name else ''))
    return rc


if __name__ == '__main__':
    sys.exit(main())
