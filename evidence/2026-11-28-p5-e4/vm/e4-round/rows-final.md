| (a) | SelfTest = 3 at a D0 entry: three depths at unity, three at -6 dB (gain 0x4026e73d) | PASS (summary rows 1, gain rows ok 3, max abs error 0 rows 3) |
| (b) | the baseline: a dsploop run after the idle power-down | PASS (3 of 3 depths exact, boots at open 1, idle power-downs in the run 1) |
| (c) | the hold (N12-03): DSPLOOP_HOLD = 20 s, the render pin open and not started | PASS (idle power-downs during the hold 1 in all, the one at guest 775 s, 23 s after the boot at open; released after 20094 ms (the timeout)) |
| (d) | a dsploop run after the hold's idle power-down | FAIL (3 of 3 depths NOT exact, boots at open 1) |
