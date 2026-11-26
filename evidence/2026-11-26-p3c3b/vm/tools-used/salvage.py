#!/usr/bin/env python3
"""salvage.py -- the reading of a VM that livecap.py left paused (reads only: no stop, no
cont).   salvage.py <sock-dir> <out-dir> <label>"""
import os
import sys

sys.path.insert(0, "/tmp/qad-ev/p3c3b/tools")
import livecap as L  # noqa: E402

mon = L.Mon(os.path.join(sys.argv[1], "monitor.sock"))
block, bar, b4 = L.config(mon)
print("the monitor's view of the model:\n%s" % block)
print("BAR0 0x%x (%s); BAR4 0x%x" % (bar[1], bar[0], b4[1]))
qt = L.QTest(os.path.join(sys.argv[1], "qtest.sock"))
print("VM status: %s" % mon.cmd("info status"))
res = L.dump(mon, qt, bar[1], sys.argv[2], sys.argv[3])
qt.close()
L.pairs(res, sys.argv[3])
