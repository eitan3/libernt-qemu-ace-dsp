# Evidence 2026-11-27-p5-e1c — the P5 E1c VM round: the asynchronous exception's poll point, and the fixed knobs

What this is: the simulator-side round for **P5 E1c** (the approved design `p5-e1-design.md` §7: the asynchronous
exception, read at a stream's period) with the three items Megan ruled on E1b's report (N10-04 the D0 entry's guard,
N10-01 the codec half, N10-03 the host case) and the two knobs E1a built, run in a VM for the first time since their
fix (N10-02). One image, under `<home>/libernt-build-logs/`:

| image | tip | what |
|---|---|---|
| `test-audio-intel-sst-p5e1c-77b7f22dd68` | `77b7f22dd68` | E1b's `d013757ebfb` plus E1c's four commits (`405f134d472` the N10-04 guard and host case i21, `7c27f16ee0e` the codec stream's reset, `7a20d5a6689` host case i22, `77b7f22dd68` the poll point and host case i23); `BOOTLOADER_DEBUG_PORT = FILE,SCREEN` |

With SHA256SUMS, PROVENANCE.txt and gates/ (its identity `20261127-nt10.0-045-2839-g77b7f22.libernt`, the six audio
binaries of the ISO byte-identical to the build tree's). NOT handed to the owner: a round image. The model:
`qemu-ace-dsp` `main` `f22c4b3` (the series of 29 patches, 0026-0029 the `crash-async` knob's; the model's master
`61174d3c3`), built from the exported series, qtest 17/17. Every line below was measured in the VM. Written by the
simulator side (Tasker) for Megan. One VM, no failed attempt.

## Conditions

As E1b's: one QEMU at a time; q35, pure TCG, `-cpu max`, `-smp 1`, 2 GB RAM, OVMF, `-nic none`,
`-icount shift=auto,align=off,sleep=off` on `tcg,thread=single`, the ACE HDA model + hda-duplex, the serial console,
no build and no network while a VM was up. Every compile of the round ran with no QEMU alive: the image at 23:03,
the model's rebuild and the apitest at 23:26, the gates at 23:28 (23:28:48); the VM ran 23:29:06–23:41:05. Another
agent's VM of this project's build was up from 23:16:44 to about 23:26 (its logs under /tmp): no compile
of mine ran while it was up (two of mine refused on it and waited); my last qtest run had ended by 23:16:10. Each VM
through `lib-run.sh` under a cap; the guest driven only through the monitor's `sendkey`; nothing read from a
screenshot. The text the guest wrote went to a FAT16 data disk (the pouch), read on the host with mtools. The host's
clock is UTC in the logs.

## Results — the VM round

| step | verdict | evidence |
|---|---|---|
| the first boot of a fresh overlay (the Setup wizard's chords), `BootDsp = 1`, the loopback topology made live by one disable/enable cycle; a baseline `dsploop` run | **PASS**: no stop line, 0 `ace_unexpected`; after the cycle `boot ok`, the topology line; the baseline `3 of 3 depths compared`, `1297 tests executed (0 failures)` | `vm/e1c-round/driver.log`, `pouch/baseline.txt` |
| (b) `never-reply-running=19`, set at the first open of a run | **THE KNOB FIRES** (the fix of N10-02 holds against the driver's streams), and the application saw no error: three faults in the run, each `fault during stream 1: reply timeout after 500 ms` (both streams), the pin told, `release: 2 streams let go, 2 buffers held for their pins, 2 tags back`, two of them followed in the same run by `recovered: open ok after 6 ms` (the engine opened the stream again); the run ended by itself after 12 s as a **pass** (`3 of 3 depths compared`, `1300 tests executed (0 failures)`), the third fault leaving the DSP down; the second run passed with `recovered: open ok after 6 ms` at its first open, no reboot | `driver.log`, `pouch/b.txt`, `pouch/b-second.txt` |
| (c) `crash-during-stream=1` and `=2`, set at the first open | **NOT PRODUCED, and it cannot be, against this driver**: no fault, no exception in the model's trace, both runs `3 of 3`. The naming is no longer the cause; the trace of the run shows the set-state's reply `pipeline 11: paused -> running`, the gateway armed, then the stream's periods with **no IPC request until the stream stopped**: a knob that needs n replies while a stream runs has nothing to act on (N11-02) | `driver.log` (`c1`, `c2`: fault-during lines 0), `qemu-dbg.log.gz` |
| the asynchronous exception, `crash-async=500` set at the first open | **PASS**: the exception posted 638 ms after the open with no request outstanding, and read by the poll point: `ipc: firmware crash with no request outstanding, read at a stream's period; the link is faulted`, `fault during stream 1: firmware crash with no request outstanding, read at a stream's period` (both streams), the pin told, the release, `DSP power down from state ready: ok`; `dsploop` ended by itself with its error after 22 s (`dsploop.c:507: Test failed: dsploop: 0 of 3 depths compared`, `329 tests executed (2 failures)`), the pins' frees returning their buffers once each; a NEW `dsploop` passed with `recovered: open ok after 6 ms` and no reboot | `driver.log`, `pouch/async.txt`, `pouch/async-second.txt`, `e1-lines.txt` |
| (d) a D0 cycle in session | **NOTHING REMAINS in this VM**: `powercfg` is not a command of this image (`Can't recognize 'powercfg /a '`); `rundll32 powrprof.dll,SetSuspendState 0,1,0` produced no sleep line in 90 s; the DSP device's disable is refused (`Failed to disable device: A device attached to the system is not functioning`), no D0 line, and the run after it `3 of 3` | `pouch/d-powercfg.txt`, `pouch/d-disable.txt`, `driver.log` |
| the whole VM | stop lines 0, fatal lines 0, `ace_unexpected` 0, freed-under lines 0, kernel-debugger prompts 0; ended by the ACPI power button, `qemu exited rc=0`, wall 720 s | `e1-lines.txt`, `lib-run.out` |

## The poll point's lines, quoted once (the async row)

```
[ 1523.460155] intcdsp.sys: ipc: firmware crash with no request outstanding, read at a stream's period; the link is faulted
[ 1523.460155] intcdsp.sys: fault during stream 1: firmware crash with no request outstanding, read at a stream's period
[ 1523.460155] intcdsp.sys: stream 1: the pin is told: device removed
[ 1523.460155] intcdsp.sys: fault during stream 1: firmware crash with no request outstanding, read at a stream's period
[ 1523.460155] intcdsp.sys: stream 1: the pin is told: device removed
[ 1523.460155] intcdsp.sys: release: 2 streams let go, 2 buffers held for their pins, 2 tags back
[ 1523.460155] intcdsp.sys: DSP power down from state ready: ok, cleanup ok, ADSPCS 0x00000000 (SPA 0, CPA 0)
```

The open was at guest 1522.822404 s; the knob was set at the open line with 500 ms. The pins' frees came 14 s later,
when the application gave its streams up: `stream 1: its pin's free returned the buffer (7680 bytes); 1 held left`,
then `… 0 held left`; dsppcm's lines are its transitions' `stream: state N not set, 0xc00002b6`. The application's own:

```
dsploop.c:411: dsploop: 38176 frames of the tone rendered, 30240 frames captured in 15062 ms
dsploop.c:431: Test failed: dsploop: 29247 of 48000 frames compared within 1 LSB, max abs error 0, first sample beyond it 4294967295
dsploop.c:492: dsploop: stopped after the run above, the plan's stop rule
dsploop.c:507: Test failed: dsploop: 0 of 3 depths compared
dsploop: 329 tests executed (0 marked as todo, 2 failures), 0 skipped.
```

The capture stopped moving where the DSP died (the 15 s are the application's own wait): an error, never a hang.

## The rows (`vm/e1c-round/rows.md`, as the round wrote it)

| knob | at open | fault during stream | the pin told | release | the pin's free | the run | the second run |
|---|---|---|---|---|---|---|---|
| never-reply-running=19 | 1 | fault during stream 1: reply timeout after 500 ms | 6 | release: 2 streams let go, 2 buffers held for their pins, 2 tags back | 6 | dsploop: 1300 tests executed (0 marked as todo, 0 failures), 0 skipped. | PASS |
| crash-during-stream=1 | 1 | **none** | 0 | **none** | 0 | dsploop: 1297 tests executed (0 marked as todo, 0 failures), 0 skipped. | PASS |
| crash-during-stream=2 | 1 | **none** | 0 | **none** | 0 | dsploop: 1300 tests executed (0 marked as todo, 0 failures), 0 skipped. | PASS |
| crash-async=500 | 1 | fault during stream 1: firmware crash with no request outstanding, read at a stream's period | 2 | release: 2 streams let go, 2 buffers held for their pins, 2 tags back | 2 | dsploop: 329 tests executed (0 marked as todo, 2 failures), 0 skipped. | PASS |

Method (`tools-used/e1c-round.sh`, the E1b round's functions unchanged): per knob, one `dsploop` run with the knob set
over QMP at the render stream's first "opened" line (a 100 ms poll), the knob cleared when the run had ended, then a
second run that must pass; every run bounded (150 s), every liveness check bounded (25 s). "The run" is the first
run's own `tests executed` line. The 20 boot-phase fault rows of E1b were not repeated (Megan's ruling).

## Directories

- `vm/e1c-round/` — `driver.log` (every step, every count), `rows.md`, `e1-lines.txt`, `serial.log` and `serial.txt`,
  `pouch/` (the runs' texts), `pouch-sha256.txt`, `setfault-*.out` (the model's answers), `cycle-tp-1.out`, `*.out`,
  `qemu-dbg.log.gz`, the screenshots.
- `tools-used/` — the scripts exactly as run (`vmcommon.sh`, `make-pouch.sh`, `e1c-run.sh`, `e1c-round.sh`,
  `collect.sh`, `collect-e1c.sh`, `scrub-dmi.sh`, `verify.sh`).
- `mutation-crash-async.md` — the two rows of `mutation-check.sh` for the knob's logic alone (both KILLED), run
  before the VM.

## Privacy

The machine is "the test machine"; no brand, model, serial or IP. The driver's DMI line is scrubbed to placeholders in
every text file (`scrub-dmi.sh`); host paths are replaced by `normalise-evidence.sh`; no account was created on the
overlay (the wizard's Skip), so no password was typed. `verify.sh` checks the three over the evidence tree.

## What was not done

- (c) as designed: a crash "after n replies while a stream runs" has no replies to wait for against this driver
  (above); `crash-async` is the mid-run crash. Megan's ruling: whether the knob stays as a model-only row.
- (d): no D0 cycle in session in this VM, so N10-04's guard ran by its host case (i21) alone; the D0 entry's own
  half (its mark waiting at the lock for an open) is reasoned in the commit, not driven.
- The interrupt mode of the transport (`UseInterrupts = 1`): not run; in it the poll leaves the IPC enables masked
  after a notification that is not a crash (N11-03).
- Not run: the 20 fault rows, the 22 cycles, the first-session flow, the flyouts (the regression's rows).
- E1b's own evidence tree lists a `pouch/` under each VM that it does not hold (its `pouch-sha256.txt` names 134
  files): this round's pouch texts are in the tree.
