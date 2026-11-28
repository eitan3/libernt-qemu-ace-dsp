# P5 E3 — the VM round of the volume and the mute through the gain module (evidence/2026-11-28-p5-e3)

Round of 2026-11-28 on image **p5e3** (`test-audio-intel-sst-p5e3-ae97c6a7a3e`: LiberNT `feat/audio-control-polish`
at `ae97c6a7a3e`, p5ntfs's `30aaa73a8c2` plus E3's three commits, on master `fc098016408`; its PROVENANCE.txt and
SHA256SUMS are in its staging directory). The model is `qemu-ace-dsp` `main` at the E3 commit: the gain module
scales what it forwards (patches 0030–0035), its qtest 18/18. Three QEMU runs, one at a time, each bounded; nothing
here was driven on real hardware.

**The headline.** On the final image, row (a) passes: `SelfTest = 3` at a D0 entry runs the loopback self-test at
16, 24 and 32 bits at unity (`max abs error 0`) and again at −6 dB through the gain module — three rows
`max abs error 0, gain 0x4026e73d`, the capture RMS 2903.940 against the render's 5794.253 at 16 bits (one half of
it within 0.24 %: −6 dB is 0.5012, N13-02) and 190322196.559 against 379742706.482 at 24 and 32 bits — and
`6 runs, 6 matched, 0 failed`. Row (b) passes: 4 dsploop runs after it with `DspIdleSec = 3`, each 3 of 3 depths
exact, each after an idle power-down and a boot at open. Rows (c) and (d) — the applet's slider and mute, a level
across an idle power-down — were **not driven** (the budget went to the finding below and the rebuild); the host
cases cover the kept-and-resent path. The second VM found a defect and the third is its proof: the first complete
round failed the 24-bit self-test row at unity (`max abs error 255`), because the model and the driver's expected
capture cleared the low 8 bits of a 32-bit container at 24 valid bits and the driver's own fill does not
(N13-07, fixed in `ae97c6a7a3e`).

## The commits (LiberNT; nothing pushed)

| # | commit | what |
|---|---|---|
| 1 | `ef61e6c0c07` | [AUDIODSP_E3] a gain widget is initialized with its volume entry (the firmware's `volume_init` refuses the base configuration alone: N13-01), the entry declared from the pinned SOF source |
| 2 | `93f11c644b0` | [AUDIODSP_E3] the level kept per PCM across every boot, sent as a large-config set of parameter id 0 (`gain: -6.00 dB, mute 0`), `SelfTest = 3`, host cases i27–i29 |
| 3 | `ae97c6a7a3e` | [AUDIODSP_E3] the gain's sample is the container whole at 24 valid bits too (N13-07) |

The simulator: the gain module scales a period (the volume entry read at the init and at a set of parameter 0; the
product rounded as the firmware's component does; unity a copy), the qtest row `audio-gain`, and two model
mutation rows (`gain-never-scales` KILLED at `audio-gain`; `gain-never-known` BUILD FAILED, N13-06).

## The round table (the whole of it in `vm/e3-round/rows-corrected.md` and `e3-lines.txt`)

| row | the VM | what the log shows | result |
|---|---|---|---|
| (a) `SelfTest = 3` | `e3-round` (third VM) | three depths at unity `max abs error 0`; `the gain step, three depths at -6.00 dB (gain 0x4026e73d)`; three rows `max abs error 0, gain 0x4026e73d ... ok`; `6 runs, 6 matched, 0 failed, 92 requests, 0 timeouts` | **PASS** by the lines (the script's `ok$` count missed the CR LF line ends: N13-10) |
| (b) the stream test after it, `DspIdleSec = 3` | `e3-round` | 4 runs, 4 × `3 of 3 depths compared`, 5 `idle power down after 3 s`, 4 `boot at stream open: ok after 6 ms` | **PASS** (4 of 4) |
| (c) the applet's slider and mute | — | not driven | **NOT RUN** (N13-09) |
| (d) a level across an idle power-down | — | not driven (host case i28: kept across a release, told at the next build) | **NOT RUN** (N13-09) |

## The VMs

| VM | the image | what it ran | how it ended |
|---|---|---|---|
| `e3-round-first` | `93f11c644b0` | the first script, its first wait on a D0-entry line a first boot without a topology does not print | the script was stopped at 05:23 and the VM with it (the job's process group); 4 min, no row |
| `e3-round-second` | `93f11c644b0` | the first complete round: (a) **failed** at the 24-bit unity row (`max abs error 255 ... render 70075715, capture 70075648`: N13-07), (b) passed (4 of 4) | ended by the script (509 s); 0 stop lines, 0 fatal, 0 kdb |
| `e3-round` | `ae97c6a7a3e` | the round on the final image: (a) passes, (b) passes | ended by the script (638 s); 0 stop lines, 0 fatal, 0 kdb |

## The lines (from `vm/e3-round/e3-lines.txt`)

```
(a) e3-round, the boot after the reboot that made SelfTest = 3, BootDsp = 1 and DspIdleSec = 3 live:
  [    5.748271] intcdsp.sys: SelfTest = 3, UseInterrupts = 0, IpcTimeoutMs = 500 ms, BootAtStart = 0, DspIdleSec = 3 s
  [    5.748271] intcdsp.sys: boot ok after 5451 us (clock 1863929388 us): state ready, ...
  [    5.748271] intcdsp.sys: gain: 0.00 dB, mute 0, kept until the DSP runs the PCM again
  [    5.748271] intcdsp.sys: gain: 0.00 dB, mute 0
  [    6.029522] intcdsp.sys: gain: -6.00 dB, mute 0, kept until the DSP runs the PCM again
  [    6.029522] intcdsp.sys: loopback self-test: the gain step, three depths at -6.00 dB (gain 0x4026e73d)
  [    6.029522] intcdsp.sys: gain: -6.00 dB, mute 0
  [    6.123272] intcdsp.sys: loopback self-test: 4096 frames captured after 85 ms, offset 0 frames, max abs error 0, gain 0x4026e73d, render rms 5794.253, capture rms 2903.940, ok
  [    6.217022] intcdsp.sys: loopback self-test: 4096 frames captured after 85 ms, offset 0 frames, max abs error 0, gain 0x4026e73d, render rms 379742706.482, capture rms 190322196.559, ok
  [    6.310773] intcdsp.sys: loopback self-test: 4096 frames captured after 85 ms, offset 0 frames, max abs error 0, gain 0x4026e73d, render rms 379742706.482, capture rms 190322196.559, ok
  [    6.310773] intcdsp.sys: gain: 0.00 dB, mute 0, kept until the DSP runs the PCM again
  [    6.310773] intcdsp.sys: loopback self-test: 6 runs, 6 matched, 0 failed, 92 requests, 0 notifications, 0 timeouts, 0 DSP interrupts, ok
(b) the first dsploop run after the self-test:
  [    9.325560] intcdsp.sys: idle power down after 3 s
  [  240.801672] intcdsp.sys: boot ok after 5452 us (clock 2098981480 us): state ready, ...
  [  240.801672] intcdsp.sys: boot at stream open: ok after 6 ms
  [  240.801672] intcdsp.sys: gain: 0.00 dB, mute 0
  [  249.964580] intcdsp.sys: idle power down after 3 s
```

The second VM's finding (`vm/e3-round-second/e3-lines.txt`):

```
  [    9.281531] intcdsp.sys: loopback self-test: 4096 frames captured after 85 ms, offset 0 frames, max abs error 255, render rms 379742706.482, capture rms 379742681.699, mismatch at frame 1 channel 0 (render frame 1): render 70075715, capture 70075648, failed
  [    9.281531] intcdsp.sys: loopback self-test: 2 runs, 1 matched, 1 failed, 31 requests, 0 notifications, 0 timeouts, 0 DSP interrupts, failed
```

## The host side (`host/`)

- `qtest.tap`: 18/18; `audio-gain` — the pattern at unity byte for byte; the driver's −6 dB word 0x4026e73d: every
  sample within one unit, `capture rms 501187.000` (the pattern's 501187.234); one channel only; the exact half
  `500000.000`; muted `0.000`; unity again; a channel id that is no channel refused.
- `mutation-check.md`, `mutation-check-2.md`: `gain-never-scales` KILLED (`audio-gain`); `gain-never-known` BUILD
  FAILED twice (N13-06).
- `mutations.txt`, `mutations-2.txt`: the driver's rows m23–m32, 10 killed.
- `sofipc.txt`: 7729 checks, 0 failures. `probe-gain.c` / `probe-gain.out`: the entry's layout against the pinned
  header's struct, 24 bytes, offsets 0/4/8/12/16; the bytes on the wire `ff ff ff ff 3d e7 26 40 00 00 ...`.

The tools as they ran under `tools-used/`. normalise-evidence.sh applies the path and listing rules; verify.sh's
counts are in the commit.
