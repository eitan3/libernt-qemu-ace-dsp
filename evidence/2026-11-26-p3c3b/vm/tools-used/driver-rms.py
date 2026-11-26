#!/usr/bin/env python3
"""driver-rms.py -- the driver's own rms arithmetic applied to the driver's own sine
over the whole 4096-frame buffer, beside the exact rms of the same samples.

IntcDspStreamCompare (drivers/wdm/audio/intcdsp/stream.c at 1619498f85e) sums,
sample by sample, the square divided by the number of samples:

    RenderSum += ((UINT64)((INT64)Sample * Sample)) / (UINT64)(Frames * Channels);

and IntcDspRms(Sum, Count) returns the millionths of the square root of that
integer sum.  The division truncates each term, so the sum is the mean of the
squares less the lost fractions; at 16-bit a square is at most 67,108,864 and the
count 8192, so each term loses up to just under one unit of the mean (about half
on average); at 24/32-bit a square is about 2.9e17 and the loss is nil.
"""


def isqrt(n):
    r = int(n ** 0.5)
    while r * r > n:
        r -= 1
    while (r + 1) * (r + 1) <= n:
        r += 1
    return r


def intc_dsp_rms(s):
    q = s // 1000000
    root = isqrt(q)
    r = (q - root * root) * 1000000000000 + (s % 1000000) * 1000000
    big = root * 1000000
    d = isqrt(r) if big == 0 else r // (2 * big)
    while 2 * big * d + d * d > r:
        d -= 1
    return big + d


T = [0, 280302863, 555809667, 821806413, 1073741823, 1307305214, 1518500249, 1703713325,
     1859775393, 1984016188, 2074309916, 2129111627, 2147483647, 2129111627, 2074309916,
     1984016188, 1859775393, 1703713325, 1518500249, 1307305214, 1073741823, 821806413,
     555809667, 280302863, 0, -280302863, -555809667, -821806413, -1073741823,
     -1307305214, -1518500249, -1703713325, -1859775393, -1984016188, -2074309916,
     -2129111627, -2147483647, -2129111627, -2074309916, -1984016188, -1859775393,
     -1703713325, -1518500249, -1307305214, -1073741824, -821806413, -555809667, -280302863]

FRAMES = 4096
N = FRAMES * 2
print("depth            exact rms      the driver's figure   mean square lost per sample")
for shift, name in ((18, "16-bit (>> 18)"), (2, "24/32-bit (>> 2)")):
    exact = drv = 0
    for f in range(FRAMES):
        v = (T[f % 48] >> shift) ** 2
        exact += 2 * v
        drv += 2 * (v // N)
    r = (exact / N) ** 0.5
    m = intc_dsp_rms(drv)
    print("%-16s %12.3f   %18s   %.4f" % (name, r, "%d.%03d" % (m // 1000, m % 1000),
                                          (exact / N - drv) / N))
