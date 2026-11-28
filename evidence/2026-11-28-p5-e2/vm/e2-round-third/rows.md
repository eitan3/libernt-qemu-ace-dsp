
| row | the setting | what the log shows | the run | the counts |
|---|---|---|---|---|
| (a) | BootDsp = 1, BootAtStart unset | after the cycle: booting 0, boot ok 0, boot at open ok 0, failed-boot 0, D0 not booted 1, idle 0, recovered 0, render opens 0, timeouts 0, fault-during 0, pin-told 0, release 0, topology 1, audio child 1, stop lines 0, fatal 0, ace_unexpected 0 | baseline: PASS; the run from its start: booting 1, boot ok 1, boot at open ok 1, failed-boot 0, D0 not booted 0, idle 0, recovered 0, render opens 3, timeouts 0, fault-during 0, pin-told 0, release 0, topology 1, audio child 0, stop lines 0, fatal 0, ace_unexpected 0 | the first open: boot at stream open: ok after 6 ms |
