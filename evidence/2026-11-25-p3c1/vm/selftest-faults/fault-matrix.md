# AC4 fault matrix -- 2026-11-25T11:36:40Z -- overlay <project>/disk/p3c1.qcow2 -- -icount shift=auto,align=off,sleep=off -- recovery cycle per row

| fault | the driver's terminal line (after its booting line) | booting -> line (guest s) | the line's own elapsed | bounded | register polls (power-downs in the trace; wall; recovery) |
|---|---|---|---|---|---|
| ipc-status=5:19 | ipc self-test: 2 requests, 2 replies, 0 notifications, 0 timeouts, 0 DSP interrupts, failed at pipeline 1 paused; boot: boot ok after 5365 us (clock 18574725 us): state ready, failed in off (ok), ROM status 0x00000005 firmware entered, ROM error 0x00000000 unknown ROM error, IPC status 0, last DSP message 0x61000000\|0x00000000, attempt 1, 0 DSP interrupts, cleanup ok, ADSPCS 0x01010000; ipc: set pipeline state (19) 0x93010003\|0x00000000 status 5 (bad state) after 63 us; the link is faulted; model after it: adspcs=00000000 hfipcxida=00000000 fsr=00000000 | 0.000 | after 63 us | bounded | 86 (power-downs in the trace: 1; wall 88s; recovered: boot ok, self-test ok) |
| never-reply=19 | ipc self-test: 2 requests, 1 replies, 0 notifications, 1 timeouts, 0 DSP interrupts, failed at pipeline 1 paused; boot: boot ok after 5736 us (clock 18309717 us): state ready, failed in off (ok), ROM status 0x00000005 firmware entered, ROM error 0x00000000 unknown ROM error, IPC status 0, last DSP message 0x61000000\|0x00000000, attempt 1, 0 DSP interrupts, cleanup ok, ADSPCS 0x01010000; ipc: set pipeline state (19) 0x93010003\|0x00000000 reply timeout after 500025 us; the link is faulted; model after it: adspcs=00000000 hfipcxida=00000000 fsr=00000000 | 0.500 | after 500025 us | bounded | 2169 (power-downs in the trace: 1; wall 89s; recovered: boot ok, self-test ok) |

## Checks beyond "bounded" (2026-11-25T11:46:56Z)

| row | the driver's terminal line | after N us | N' - N - M (us) | serial booting -> line (s) | observed - N (ms) | elapsed ok | bugcheck | hang | recovery |
|---|---|---|---|---|---|---|---|---|---|
| fm-ipc-status=5_19 | boot ok after 5365 us (clock 18574725 us): state ready, failed in off (ok), ROM status 0x00000005 firmware entered, ROM error 0x00000000 unknown ROM e | 5365 | 81 | 0.000 | -5.4 | yes | 0 | 0 | boot ok |
| fm-never-reply=19 | boot ok after 5736 us (clock 18309717 us): state ready, failed in off (ok), ROM status 0x00000005 firmware entered, ROM error 0x00000000 unknown ROM e | 5736 | 161 | 0.000 | -5.7 | yes | 0 | 0 | boot ok |

## The self-test rows (the guest has SelfTest = 1: the row ends with the self-test summary) -- checks against the image testing notes (2026-11-25T11:46:57Z)

| fault | boot ok after N us | end clock - start clock - N (us) | the failing exchange | the self-test summary | checks | the power-down line | bugcheck | hang | device started (disabled after the row) | recovery (boot ok + self-test ok) |
|---|---|---|---|---|---|---|---|---|---|---|
| ipc-status=5:19 | 5365 | 81 | set pipeline state (19) 0x93010003\|0x00000000 status 5 (bad state) after 63 us; the link is faulted | ipc self-test: 2 requests, 2 replies, 0 notifications, 0 timeouts, 0 DSP interrupts, failed at pipeline 1 paused | as expected (the power-down line names state 'off' where TESTING.md says 'ready': the driver logs the state after its own power-down) | DSP power down from state off: ok, cleanup ok, ADSPCS 0x00000000 (SPA 0, CPA 0) | 0 | 0 | yes | boot ok + self-test ok |
| never-reply=19 | 5736 | 161 | set pipeline state (19) 0x93010003\|0x00000000 reply timeout after 500025 us; the link is faulted | ipc self-test: 2 requests, 1 replies, 0 notifications, 1 timeouts, 0 DSP interrupts, failed at pipeline 1 paused | as expected (the power-down line names state 'off' where TESTING.md says 'ready': the driver logs the state after its own power-down) | DSP power down from state off: ok, cleanup ok, ADSPCS 0x00000000 (SPA 0, CPA 0) | 0 | 0 | yes | boot ok + self-test ok |

0 row(s) with a failed check; 2 wording divergence(s) noted in the tables (DIVERGENCE.md).
