#!/usr/bin/env python3
"""rms-check.py -- the rms of the driver's own sine (IntcDspSineQ31, stream.c at
1619498f85e) over the frames a stream moves per period (2048 frames: 8192 bytes
at 16-bit, 16384 at 24/32) and over the whole 4096-frame buffer, against the
ace_audio lines of a run's trace.  With file arguments it also names, from the
eight samples the model prints, at which frame of the sine each period starts.

   rms-check.py [trace ...]
"""
import re
import sys

T = [0, 280302863, 555809667, 821806413, 1073741823, 1307305214, 1518500249, 1703713325,
     1859775393, 1984016188, 2074309916, 2129111627, 2147483647, 2129111627, 2074309916,
     1984016188, 1859775393, 1703713325, 1518500249, 1307305214, 1073741823, 821806413,
     555809667, 280302863, 0, -280302863, -555809667, -821806413, -1073741823,
     -1307305214, -1518500249, -1703713325, -1859775393, -1984016188, -2074309916,
     -2129111627, -2147483647, -2129111627, -2074309916, -1984016188, -1859775393,
     -1703713325, -1518500249, -1307305214, -1073741824, -821806413, -555809667, -280302863]
assert len(T) == 48


def sq(v, n):
    """the C >> of a signed value (arithmetic), squared"""
    return (v >> n) ** 2


def rms(shift, lo, hi):
    s = n = 0
    for f in range(lo, hi):
        v = sq(T[f % 48], shift)
        s += 2 * v          # two channels
        n += 2
    r = (s / n) ** 0.5
    return s, n, r, int(r * 1000 + 0.5)


print("depth            frames      sum of squares   samples   rms (double)   thousandths")
whole = {}
for shift, name in ((18, "16-bit (>> 18)"), (2, "24/32-bit (>> 2)")):
    for lo, hi in ((0, 2048), (2048, 4096), (0, 4096)):
        s, n, r, k = rms(shift, lo, hi)
        if lo == 0 and hi == 4096:
            whole[shift] = (s, n, r)
        print("%-16s %4d-%4d  %22d  %6d   %.3f   %d.%03d"
              % (name, lo, hi - 1, s, n, r, k // 1000, k % 1000))
for shift, name in ((18, "16-bit"), (2, "24/32-bit")):
    s, n, r = whole[shift]
    k = int((s // n) ** 0.5 * 1000 + 0.5) if False else None
    # integer square root of the mean square in millionths, as a driver that
    # avoids floating point would print it: floor(sqrt(S * 10^6 / N))
    m = s * 1000000 // n
    q = int(m ** 0.5)
    while (q + 1) ** 2 <= m:
        q += 1
    print("%s: mean square %d (integer division); rms in thousandths by integer sqrt: %d.%03d"
          % (name, s // n, q // 1000, q % 1000))
if len(sys.argv) > 1:
    print()
    for fn in sys.argv[1:]:
        for line in open(fn, errors="replace"):
            m = re.search(r"ace_audio ace_audio (\d+) (\d+) rms ([0-9.]+) peak (\d+) first ((?:-?\d+ ?){8})",
                          line)
            if not m:
                continue
            tag, nb, r, pk, first = m.groups()
            shift = 18 if nb == "8192" else 2
            f0 = [int(x) for x in first.split()]
            cands = [k for k in range(48)
                     if all(f0[2 * i] == T[(k + i) % 48] >> shift for i in range(4))]
            print("%s: %s bytes rms %s peak %s: the period starts at sine frame (mod 48) %s"
                  % (fn.rsplit("/", 1)[-1], nb, r, pk, cands or "none"))
