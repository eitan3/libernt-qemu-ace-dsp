# AC4 fault matrix in the VM -- p2b2 image (intcdsp.sys of feat/audio-control-polish @ 5286c0598d6) against the model of 2026-11-24 (patches 0001-0008)

One boot per row on the stage-2 overlay (BootDsp=1 persisted in the guest), driven by tools/fault-matrix.sh from a tmpfs copy of the overlay; bounded = the driver logs its terminal line within 30 guest-seconds of its booting line (and powers the DSP down). Every unbounded row is the D0Entry hang of DIVERGENCE.md (D1: the reply never handed to the state machine, D2: no budget ever fires); the kernel repeats `Work queue 1 has made no progress for 3 passes` while it lasts. Rows whose first boot sat at the boot manager (a host timer stall, see README) were retried; the table reads the final attempt.

| fault | the driver's terminal line (after its `booting:` line) | booting -> line (guest s) | verdict |
|---|---|---|---|
| abi=2 | boot ABI mismatch after 0 us: state failed, failed in FW_READY wait (ABI mismatch), ROM status 0x00000005 firmware entered, ROM error 0x00000000 unknown ROM error, IPC status 0, attempt 1, 1 DSP interrupts, cleanup ok | 0.048 | bounded (->off 1) |
| bad-tuples | none: 296834 register polls, no line, no power-down (the D0Entry hang of D1) | - | **unbounded** |
| crash-notification | boot firmware crash after 0 us: state failed, failed in FW_READY wait (firmware crash), ROM status 0x00000005 firmware entered, ROM error 0x0000000a unknown ROM error, IPC status 0, attempt 1, 1 DSP interrupts, cleanup ok | 1.322 | bounded (->off 1) |
| drop-requests | none: 330092 register polls, no line, no power-down (the D0Entry hang of D1) | - | **unbounded** |
| halt-fw=51 | boot ROM error after 0 us: state failed, failed in loading (ROM error), ROM status 0x8000002a ROM firmware code loaded, ROM error 0x00000033 base firmware incompatible, IPC status 0, attempt 1, 0 DSP interrupts, cleanup ok | 0.047 | bounded (->off 1) |
| halt-rom=43 | boot ROM error after 0 us: state failed, failed in ROM init (ROM error), ROM status 0x80000009 ROM purge boot, ROM error 0x0000002b base firmware not found, IPC status 0, attempt 3, 0 DSP interrupts, cleanup ok | 4.656 | bounded (->off 3) |
| halt-rom=44 | boot ROM error after 0 us: state failed, failed in ROM init (ROM error), ROM status 0x80000009 ROM purge boot, ROM error 0x0000002c CSE validation failed, IPC status 0, attempt 3, 0 DSP interrupts, cleanup ok | 0.047 | bounded (->off 3) |
| ipc-status=5 | none: 331337 register polls, no line, no power-down (the D0Entry hang of D1) | - | **unbounded** |
| never-ack | none: 510837 register polls, no line, no power-down (the D0Entry hang of D1) | - | **unbounded** |
| never-enter | none: 160258 register polls, no line, no power-down (the D0Entry hang of D1) | - | **unbounded** |
| never-fwready | none: 328399 register polls, no line, no power-down (the D0Entry hang of D1) | - | **unbounded** |
| never-power | none: 465415 register polls, no line, no power-down (the D0Entry hang of D1) | - | **unbounded** |
| never-ready | none: 165266 register polls, no line, no power-down (the D0Entry hang of D1) | - | **unbounded** |
| never-reply | none: 386697 register polls, no line, no power-down (the D0Entry hang of D1) | - | **unbounded** |
| none | none: 320904 register polls, no line, no power-down (the D0Entry hang of D1) | - | **unbounded** |
| none-scale0.001 | boot ROM error after 0 us: state failed, failed in loading (ROM error), ROM status 0xa0000005 firmware entered, ROM error 0x00000000 unknown ROM error, IPC status 0, attempt 1, 1 DSP interrupts, cleanup ok | 0.562 | bounded (->off 1) |
| none-scale1550 | none: 322503 register polls, no line, no power-down (the D0Entry hang of D1) | - | **unbounded** |
| truncated-reply | none: 338287 register polls, no line, no power-down (the D0Entry hang of D1) | - | **unbounded** |
| version-shift | none: 394193 register polls, no line, no power-down (the D0Entry hang of D1) | - | **unbounded** |
| window-read-fail | boot ABI mismatch after 0 us: state failed, failed in FW_READY wait (ABI mismatch), ROM status 0x00000005 firmware entered, ROM error 0x00000000 unknown ROM error, IPC status 0, attempt 1, 1 DSP interrupts, cleanup ok | 0.048 | bounded (->off 1) |
