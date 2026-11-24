#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# qemu-ace-dsp: heartbeat.py -- keep QEMU's main loop awake during a boot
# attempt on a host whose timer delivery stalls under a spinning TCG guest
# (README, "A note on the host"). The model's timers run off the host clock in
# the main loop, which sleeps in poll() until a timer or an fd event wakes it;
# when the host's timers are late, only an fd event makes the loop run its
# timers. This sends one side-effect-free qtest read (HFINTIPPTR, a constant)
# every PERIOD us over the qtest socket of a QTESTSOCK=1 VM, busy-waiting on
# the host clock (a nanosleep would stall with the host's timers), and logs
# the read's latency and value: a latency above a few ms is a main loop that
# could not run.
#
#   heartbeat.py <qtest.sock> <seconds> [period_us=1000] [qtest_bar4=0x81000000]
#
# Output (stdout, one line per read): <host time> latency_us value
# The reads appear in the device trace as ace_reg_read BAR4 +0x1108 lines
# (the driver itself reads that register once per D0 entry).
# This work is licensed under the terms of the GNU GPL, version 2 or later.
# See the COPYING file in the top-level directory.
import socket
import sys
import time

REG = 0x1108  # HFINTIPPTR: a model constant, no side effects on read


def qtest(s, cmd):
    s.sendall((cmd + '\n').encode())
    out = b''
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
    seconds = float(sys.argv[2])
    period = int(sys.argv[3]) if len(sys.argv) > 3 else 1000
    bar4 = int(sys.argv[4], 16) if len(sys.argv) > 4 else 0x81000000
    s = socket.socket(socket.AF_UNIX)
    s.connect(sys.argv[1])
    cmd = 'readl 0x%x' % (bar4 + REG)
    t_end = time.clock_gettime_ns(time.CLOCK_MONOTONIC) + int(seconds * 1e9)
    nxt = time.clock_gettime_ns(time.CLOCK_MONOTONIC)
    n = lat_max = 0
    lat_sum = 0
    while True:
        now = time.clock_gettime_ns(time.CLOCK_MONOTONIC)
        if now >= t_end:
            break
        if now < nxt:
            continue  # busy wait on the host clock
        nxt += period * 1000
        t0 = time.clock_gettime_ns(time.CLOCK_MONOTONIC)
        rep = qtest(s, cmd)
        t1 = time.clock_gettime_ns(time.CLOCK_MONOTONIC)
        lat = (t1 - t0) // 1000
        n += 1
        lat_sum += lat
        lat_max = max(lat_max, lat)
        if lat > 5000 or n % 200 == 1:
            print('%s %6d us %s' % (time.strftime('%H:%M:%S'), lat, rep.split()[-1][-8:]))
            sys.stdout.flush()
    print('heartbeat: %d reads, latency mean %d us, max %d us, period %d us' %
          (n, lat_sum // max(n, 1), lat_max, period))
    return 0


if __name__ == '__main__':
    sys.exit(main())
