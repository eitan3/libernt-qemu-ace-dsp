#!/usr/bin/env python3
"""ace-audio-check.py -- the model's ace_audio lines of a run against the driver's own
sine (IntcDspSineQ31 at 1619498f85e) and the driver's self-test lines.

   ace-audio-check.py <qemu-dbg.log> <serial.log>

The trace line is "ace_audio <tag> <bytes> rms <r> peak <p> first <8 samples>":
one per period and stream, the render's then the capture's.  For every self-test
of the run: each pair must be identical; the samples a line prints must be the
sine's at the frame its period starts from (the two periods walk the buffer from
its start: 2048 frames each), modulo the sine's 48 frames; the rms printed must
be the exact rms of the sine over that period; and the root of the mean of the
two periods' squared rms is set beside the driver's whole-buffer figure.
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


def rms(shift, lo, hi):
    s = sum(((T[f % 48] >> shift) ** 2) * 2 for f in range(lo, hi))
    return (s / (2 * (hi - lo))) ** 0.5


def main():
    trace, serial = sys.argv[1], sys.argv[2]
    lines = [l.rstrip("\r\n") for l in open(serial, errors="replace") if "loopback self-test" in l]
    audio = [l.split() for l in open(trace, errors="replace") if l.startswith("ace_audio ")]
    ends = [l for l in lines if "endpoint '" in l]                 # one per run
    caps = [l for l in lines if " frames captured after" in l]
    fails = [l for l in lines if re.search(r"not captured|mismatch at frame|, failed$", l)]
    sums = [l for l in lines if re.search(r"\d+ runs, \d+ matched", l)]
    rans = [l for l in lines if "self-test: ran (" in l]
    print("driver lines: %d runs started, %d captured, %d failures, %d summaries, %d 'ran' lines; "
          "ace_audio lines: %d" % (len(ends), len(caps), len(fails), len(sums), len(rans), len(audio)))
    for l in fails:
        print("  FAILURE:", re.sub(r".*intcdsp\.sys: ", "", l)[:300])
    ok = (not fails and rans and len(ends) == len(caps) and len(sums) == len(rans)
          and len(audio) == 4 * len(ends))
    for k in range(len(ends)):
        d = re.search(r"2 ch (\d+)-bit", ends[k]).group(1)
        shift = 18 if d == "16" else 2
        nb = 8192 if d == "16" else 16384
        pk = 8192 if d == "16" else 536870912
        drv = re.search(r"after (\d+) ms, offset (\d+) frames, max abs error (\d+), "
                        r"render rms (\d+\.\d+), capture rms (\d+\.\d+)", caps[k])
        print("run %d (%s-bit): after %s ms, offset %s frames, max abs error %s, render rms %s, "
              "capture rms %s" % ((k + 1, d) + drv.groups()))
        r2 = 0.0
        for p in range(2):
            a, b = audio[4 * k + 2 * p], audio[4 * k + 2 * p + 1]
            same = a[2:] == b[2:]
            tag, n, r, peak = a[2], int(a[3]), float(a[5]), int(a[7])
            first = [int(x) for x in a[9:17]]
            start = p * 2048
            exact = rms(shift, start, start + 2048)
            want = [T[(start + i) % 48] >> shift for i in range(4)]
            good = (n == nb and first[0::2] == want and abs(r - exact) < 0.0006 and peak == pk)
            ok = ok and same and good
            r2 += r * r
            print("   period %d: tag %s, %d bytes, rms %.3f (the sine over frames %d-%d: %.3f), "
                  "peak %d, first %s (the sine's: %s); render and capture lines %s"
                  % (p + 1, tag, n, r, start, start + 2047, exact, peak, first[0::2], want,
                     "identical" if same else "DIFFERENT"))
            if not good:
                print("      !! not as expected: bytes %d (want %d), rms off by %.4f, peak %d (want %d)"
                      % (n, nb, r - exact, peak, pk))
        whole = (r2 / 2) ** 0.5
        print("   the two periods together: rms %.3f; the driver's whole-buffer figure %s "
              "(its per-sample truncating sum: see driver-rms.py)" % (whole, drv.group(4)))
    print("RESULT:", "every ace_audio line is the sine's and render = capture in every pair"
          if ok else "SEE THE !! LINES ABOVE")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
