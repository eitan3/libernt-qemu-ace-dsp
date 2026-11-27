# Evidence 2026-11-27-p5-e1b — the P5 E1b VM micro round: the driver's in-place recovery

What this is: the simulator-side round for **P5 E1b** (the approved design `p5-e1-design.md` §7: the driver boots the DSP at a stream open and
recovers in place after a fault or a power-down). Two images, both under `<home>/libernt-build-logs/`:

| image | tip | what |
|---|---|---|
| `test-audio-intel-sst-p5e1b-7664a41eeb7` | `7664a41eeb7` | E1a's `2e0451fc53a` plus E1b's three commits (`761c39e1a9d` the m4a refusal, `c7bcd988cf3` DspState / `IntcDspBootSequence` / the Boot operation, `7664a41eeb7` audioif's statuses and the rescan rule); `BOOTLOADER_DEBUG_PORT = FILE,SCREEN`; attempts 1–3 of the round ran on it |
| `test-audio-intel-sst-p5e1b-d0bb1c7cec9` | `d0bb1c7cec9` | the same plus `d0bb1c7cec9` (`[HDAUDBUS]` a DSP stream going back to the pool forgets its owner's events: N10-01); attempt 4 and the round ran on it |

Each with SHA256SUMS, PROVENANCE.txt and gates/. Neither is handed to the owner. The model: `qemu-ace-dsp` `main` `19324ab` + `fe0e271`
(the two knob rows of `mutation-check.sh`, `set-fault.sh`'s usage) for the whole round; the fix of the two knobs (N10-02) came after the
VMs and is a later commit of the series. Every line below was measured in the VM. Written by the simulator side (Tasker) for Megan.

## Conditions

One QEMU at a time; q35, pure TCG, `-cpu max`, `-smp 1`, 2 GB RAM, OVMF, `-nic none`, `-icount shift=auto,align=off,sleep=off` on
`tcg,thread=single`, the ACE HDA model + hda-duplex, the serial console, no build and no network while a VM was up (every compile of the round
— the drivers, the images, the model — ran with no QEMU alive). Each VM through `lib-run.sh` under a cap; the guest driven only through the
monitor's `sendkey`; nothing read from a screenshot. The text the guest wrote went to a FAT16 data disk (the pouch: `dsploop_apitest.exe` in,
the runs' texts out), read on the host with mtools. The host's clock is UTC.

## Results

| step | launches | verdict | evidence |
|---|---|---|---|
| the first boot of a fresh overlay (the Setup wizard), `BootDsp = 1`, the loopback topology made live by one disable/enable cycle; a baseline `dsploop` run | 2 (attempt 1 on `7664a41eeb7`, attempt 4 on `d0bb1c7cec9`) | **PASS** — the wizard's chords, the console, the settings, `boot ok`, `topology 'sof-ipc4-loopback.tplg'`, the audio child; the baseline `3 of 3 depths compared, 0 failures` | `vm/e1b-attempt1/`, `vm/e1b-attempt4/` |
| (a) the 20 fault rows of the fault matrix, each followed by a stream open | 2 VMs (attempt 4: rows 1–2; the round: rows 3–20) | **20 of 20 PASS** (`recovered: open ok after <ms> ms` in every row, no stop line, no kernel debugger prompt): `halt-rom=43`, `halt-rom=44` on attempt 4's VM; the other 18 on the round's VM | `vm/e1b-attempt4/rows.md` (2 rows), `vm/e1b-round/rows.md` (18 rows), the table below |
| (b) `never-reply-running=<type>` with a stream open | — | **NOT PRODUCED**: the knob never fires against the driver's streams (N10-02: the capture stream is an input, the render stream carries the loader's tag); the entry step of every row used `never-reply` at the first open instead (the regression's S4a fault), which gives the fault-during-stream lines below; a second `dsploop` passes without a reboot after every entry run | `vm/e1b-attempt2/` (the knob set at the third open, no fault, the run 3/3) |
| (c) `crash-during-stream=<n>` mid-run | — | **NOT PRODUCED** (the same defect) | `vm/e1b-attempt2/` |
| (d) D0 cycles with a stream open | (attempt 4's VM) | **SKIPPED**: the guest does not sleep — `powercfg` is not a command of this image, `rundll32 powrprof.dll,SetSuspendState 0,1,0` produced no sleep line in 90 s (the README's "no S3 in the VM"); the disable of the DSP device is refused with the topology loaded (C10/C11, the regression's S6) | `vm/e1b-attempt4/driver.log` (the `d-sleep` lines) |
| (e) what the application and the engine saw | (every entry run) | `dsploop` ends by itself with its own error and the plan's stop rule; dsppcm logs each transition's `0xc00002b6` and nothing for the position | below |
| a kernel exception at the open after a fault | attempt 3 | **found and fixed** (N10-01): on `7664a41eeb7`, the second row's first open, before the injected fault fired; 0 kernel-debugger prompts on `d0bb1c7cec9` (attempts 4 and the round) | `vm/e1b-attempt3/serial.txt` |

## The three E1 lines, quoted once each (attempt 4, the first row's entry run, `never-reply` at the first open)

```
intcdsp.sys: fault during stream 1: reply timeout after 500 ms
intcdsp.sys: stream 1: the pin is told: device removed
intcdsp.sys: release: 2 streams let go, 2 buffers held for their pins, 2 tags back
```

and the fourth of the design's §4, the pin's free: `intcdsp.sys: stream 1: its pin's free returned the buffer (7680 bytes); 1 held left`,
then `… (7680 bytes); 0 held left`. Around them, the request's own line (`ipc: set pipeline state (19) 0x… reply timeout after 500413 us;
the link is faulted`), `stream 1: a pipeline could not be paused (0xc00000b5)`, the second stream's pair (the capture, tag 1 as well),
`streams: released after the fault; nothing is sent until the next stream open or D0 entry`, `DSP power down from state ready: ok, cleanup
ok, ADSPCS 0x00000000 (SPA 0, CPA 0)`. No "freed under a pin" line in any run of the round (0 in every count); the counts are in
`e1-lines.txt`.

## (a) the rows

Method (`tools-used/e1b-round.sh`): the overlay of `d0bb1c7cec9` with the settings in the guest's registry (the DSP boots with the topology
at every D0 entry), a console on the data disk. Per row, three `dsploop` runs: **(1) into the need of a boot** — `never-reply` set at the
render stream's first "opened" line (a 100 ms poll), the next request dropped, the fault at its 500 ms reply timeout, the release, the DSP
powered down; the fault is cleared when the run has ended (it stays set through the run: N10-05); **(2) the row's fault set** — a run whose
first open boots the DSP under it: the boot's own terminal line, `boot at stream open failed: the DSP is not ready after the boot
(0xc00000a3); no stream is taken`, dsppcm's `the DSP gives no stream, 0xc00000a3`; **(3) the fault cleared** — a run whose first open boots:
`recovered: open ok after N ms`, then the run passes (`3 of 3 depths compared, 0 failures`). The two scale rows set `x-delay-scale` instead
of a fault; the `none` row has no step (2): its open boots at once. Every run is bounded (150 s), every liveness check bounded (25 s), the
round stops at the first `kdb:>` of the serial log.

| halt-rom=43 | boot ROM error after 8337 us (clock 1586068737 us): state failed, failed in ROM init (ROM error), ROM status 0x80000009 ROM purge boot, ROM error 0x0000002b base firmware not found, IPC status 0, last | 1 | recovered: open ok after 6 ms | PASS |
| halt-rom=44 | boot ROM error after 8337 us (clock 1988136000 us): state failed, failed in ROM init (ROM error), ROM status 0x80000009 ROM purge boot, ROM error 0x0000002c CSE validation failed, IPC status 0, last D | 1 | recovered: open ok after 6 ms | PASS |
| halt-fw=51 | boot ROM error after 6287 us (clock 640923187 us): state failed, failed in loading (ROM error), ROM status 0x8000002a ROM firmware code loaded, ROM error 0x00000033 base firmware incompatible, IPC sta | 1 | recovered: open ok after 6 ms | PASS |
| crash-notification | boot firmware crash after 6832 us (clock 906524579 us): state failed, failed in FW_READY wait (firmware crash), ROM status 0x00000005 firmware entered, ROM error 0x0000000a unknown ROM error, IPC stat | 1 | recovered: open ok after 6 ms | PASS |
| abi=2 | boot ABI mismatch after 6835 us (clock 1144312715 us): state failed, failed in FW_READY wait (ABI mismatch), ROM status 0x00000005 firmware entered, ROM error 0x00000000 unknown ROM error, IPC status  | 1 | recovered: open ok after 6 ms | PASS |
| window-read-fail | boot ABI mismatch after 6837 us (clock 1640961026 us): state failed, failed in FW_READY wait (ABI mismatch), ROM status 0x00000005 firmware entered, ROM error 0x00000000 unknown ROM error, IPC status  | 1 | recovered: open ok after 6 ms | PASS |
| never-power | boot power-up timeout after 52031 us (clock 1880724738 us): state failed, failed in powering up (power-up timeout), ROM status 0x00000000 init, ROM error 0x00000000 unknown ROM error, IPC status 0, la | 1 | recovered: open ok after 6 ms | PASS |
| never-ack | boot ROM init timeout after 1509348 us (clock 2133445253 us): state failed, failed in ROM init (ROM init timeout), ROM status 0x00000000 init, ROM error 0x00000000 unknown ROM error, IPC status 0, las | 1 | recovered: open ok after 6 ms | PASS |
| never-ready | boot ROM status timeout after 909057 us (clock 2478312934 us): state failed, failed in ROM init (ROM status timeout), ROM status 0x00000009 ROM purge boot, ROM error 0x00000000 unknown ROM error, IPC  | 1 | recovered: open ok after 6 ms | PASS |
| never-enter | boot base firmware timeout after 3004715 us (clock 2728925915 us): state failed, failed in loading (base firmware timeout), ROM status 0x0000002a ROM firmware code loaded, ROM error 0x00000000 unknown | 1 | recovered: open ok after 6 ms | PASS |
| never-fwready | boot FW_READY timeout after 1006754 us (clock 3004327744 us): state failed, failed in FW_READY wait (FW_READY timeout), ROM status 0x00000005 firmware entered, ROM error 0x00000000 unknown ROM error,  | 1 | recovered: open ok after 6 ms | PASS |
| never-reply | boot IPC reply timeout after 506900 us (clock 3401837976 us): state failed, failed in configuring (IPC reply timeout), ROM status 0x00000005 firmware entered, ROM error 0x00000000 unknown ROM error, I | 1 | recovered: open ok after 6 ms | PASS |
| drop-requests | boot IPC reply timeout after 506917 us (clock 3680013745 us): state failed, failed in configuring (IPC reply timeout), ROM status 0x00000005 firmware entered, ROM error 0x00000000 unknown ROM error, I | 1 | recovered: open ok after 6 ms | PASS |
| ipc-status=5 | boot IPC error after 7473 us (clock 3966061785 us): state failed, failed in configuring (IPC error), ROM status 0x00000005 firmware entered, ROM error 0x00000000 unknown ROM error, IPC status 5, last  | 1 | recovered: open ok after 6 ms | PASS |
| bad-tuples | boot bad IPC reply after 7453 us (clock 4257913476 us): state failed, failed in configuring (bad IPC reply), ROM status 0x00000005 firmware entered, ROM error 0x00000000 unknown ROM error, IPC status  | 1 | recovered: open ok after 6 ms | PASS |
| truncated-reply | boot truncated after 7453 us (clock 4938387976 us): state failed, failed in configuring (truncated), ROM status 0x00000005 firmware entered, ROM error 0x00000000 unknown ROM error, IPC status 0, last  | 1 | recovered: open ok after 6 ms | PASS |
| version-shift | boot version mismatch after 7456 us (clock 5381217130 us): state failed, failed in configuring (version mismatch), ROM status 0x00000005 firmware entered, ROM error 0x00000000 unknown ROM error, IPC s | 1 | recovered: open ok after 6 ms | PASS |
| scale:1550 | boot power-up timeout after 52032 us (clock 5852391840 us): state failed, failed in powering up (power-up timeout), ROM status 0x00000000 init, ROM error 0x00000000 unknown ROM error, IPC status 0, la | 1 | recovered: open ok after 6 ms | PASS |
| scale:0.001 | boot ROM error after 4786 us (clock 6112356339 us): state failed, failed in loading (ROM error), ROM status 0xa0000005 firmware entered, ROM error 0x00000000 unknown ROM error, IPC status 0, last DSP  | 1 | recovered: open ok after 6 ms | PASS |
| none | - (no fault: the open boots) | 0 | recovered: open ok after 6 ms | PASS |

Per row the model figures differ between runs (the clocks, `after N us`); the terminal lines are p4c4g's for each fault (`ROM error 0x2b`
base firmware not found, `0x2c` CSE validation failed, …). The `recovered` times: 5–7 ms for the ROM and IPC errors, longer where the
failed boot's power-down left the subsystem to settle. Each row's three runs: `opens`, `recovered`, `failed-boot`, `fault-during`, `pin-told`,
`release`, `pin-free`, `freed-under`, `stop`, `fatal`, `ace_unexpected` counts in `driver.log`.

## (e) what the application and the engine saw

The application (`dsploop`, the pouch text of the first row's entry run):

```
dsploop.c:411: dsploop: 48000 frames of the tone rendered, 96000 frames captured in 2000 ms
dsploop.c:311: Test failed: dsploop (24 valid in 32): render: Initialize 0x8889000f
dsploop.c:492: dsploop: stopped after the run above, the plan's stop rule
dsploop: 1 of 3 depths compared, 0 preconditions missing (LIBERNT_APITEST_REQUIRED 1: required, a failure)
dsploop: 435 tests executed (0 marked as todo, 2 failures), 0 skipped.
```

The first depth had run when the fault landed (the 100 ms poll sets the fault after the open line; the depth's allocate and run had gone
through), so its capture compared; the fault came at the free's pause; the next depth's open booted under the still-set fault and was
refused. The run ended by itself (about 5 s after the fault): an error, never a hang; the console answered after every run.

The engine and the pin: dsppcm's lines after the fault, per pin — `stream: state 2 not set, 0xc00000b5` (the pause that met the fault),
then `stream: state 0 not set, 0xc00002b6`, `state 1`, `state 2` (`STATUS_DEVICE_REMOVED` at STOP, PAUSE and RUN on the Lost stream), and
PortCls's `pin_wavert.cpp:363 RegisterNotificationEvent failed with c0000008`. **dsppcm logs no line for the position's error**: the
position property's path (`GetPosition` → `DsppcmStreamPosition` → `GetPositionRegister` → `IntcDspStreamPositionRegister`) passes
`STATUS_DEVICE_REMOVED` to PortCls silently (N10-06, INFO_NEEDED 4). The next open after a stopped boot reads dsppcm's `endpoint 'Loopback'
render: the DSP gives no stream, 0xc00000a3`.

## The attempts (each one is kept, nothing forced)

1. `vm/e1b-attempt1/` (`7664a41eeb7`, the first boot): the harness's labels held `=`, which cmd.exe takes for a separator, so each run's
   text went to another name and every run waited out its cap; the first boot, the wizard, the settings and the cycle were fine. The VM
   was cut with the script.
2. `vm/e1b-attempt2/` (the second boot of that overlay): the labels fixed; the entry step used `crash-during-stream=1` at the third open
   — **no fault**: the knob did not fire, the runs passed 3/3 (N10-02). The VM was cut with the script.
3. `vm/e1b-attempt3/` (the third boot): the entry step with `never-reply`; **row 1 PASS**, the first row of the round; at row 2's first open
   **the guest took a kernel exception into its debugger** (`Exception c0000420 at <ntoskrnl.exe!KeSetEvent+0x52 (/ntos/ke/syncobj.c:89)>`
   from `HDAudBus.sys!hda_dpc+0x730`): N10-01, fixed in `d0bb1c7cec9`. The VM was stopped with the script.
4. `vm/e1b-attempt4/` (`d0bb1c7cec9`, a fresh overlay: the first boot, the wizard, the cycle): the baseline PASS, **rows 1–2 PASS**, then the
   harness's liveness check reused one file name and the rows loop stopped (the console was answering: `powercfg` was answered a line
   later); (d) was tried on this VM; the running script was edited and broke at its end (the launcher stopped the VM cleanly).
5. `vm/e1b-round/` (`d0bb1c7cec9`, the same overlay's next boot): the baseline PASS, **rows 3–20**.

## Directories

- `vm/<attempt>/` — `driver.log` (every step, every count), `rows.md`, `e1-lines.txt` (the round), `serial.log` and `serial.txt`, `pouch/`
  (the runs' texts), `pouch-sha256.txt`, `setfault-*.out` (the model's answers), `cycles.log`, `*.out`, `qemu-dbg.log.gz`, the screenshots.
- `tools-used/` — the scripts exactly as run (`vmcommon.sh`, `make-pouch.sh`, `e1b-run.sh`, `e1b-round.sh`, `collect.sh`, `collect-e1b.sh`).
- `mutation-knobs.md` — the two knob rows of `mutation-check.sh` on the model of E1a (both KILLED), run before the VMs.

## Privacy

The machine is "the test machine"; no brand, model, serial or IP. The driver's DMI line (the SMBIOS strings) is scrubbed to placeholders
in every text file (`scrub-dmi.sh`); host paths are replaced by `normalise-evidence.sh`; no account was created on these overlays (the
wizard's Skip), so no password was typed. `verify.sh` checks the three over the evidence tree.

## What was not done

- (b) and (c) in a VM: the knobs as E1a built them never fire against the driver's streams (N10-02); the fix is in the series after this
  round and was not run in a VM (the budget). The fault-during-stream rows above are `never-reply`'s.
- (d): no D0 cycle in session (no S3 in the VM; the disable refused).
- The stop rule of plan E1 was not exercised as a failure: every stopped boot of the round had its fault injected (N10-05).
- `SelfTest = 1`/`2` at a boot at an open (the self-tests are skipped there by the driver; not measured).
- Not run: the 22 cycles, the first-session flow, the flyouts (the regression's rows; this is the micro round of E1b).
- The codec's own stream-free path (`hdaudio.cpp`), which has the shape N10-01 fixed on the DSP child's: not touched.
