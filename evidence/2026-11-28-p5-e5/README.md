# P5 E5 — the regression on the final image (evidence/2026-11-28-p5-e5)

Round of 2026-11-28. **Image** `test-audio-p5final-9f023b460cc`: LiberNT identity `20261128-nt10.0-045-3158-g9f023b4`
(the console's banner in the VM: `LiberNT [Version 0.4.17-amd64-dev 20261128-nt10.0-045-3158-g9f023b4]`), the pushed tip
`b7274b3e004` of `feat/audio-control-polish` plus the one commit that bakes the owner's settings into the INF
(`9f023b460cc`, `drivers/wdm/audio/intcdsp/intcdsp.inf`: `BootDsp = 1`, `SelfTest = 3`,
`Topology = sof-ipc4-loopback.tplg`, `BootAtStart = 0`, `DspIdleSec = 0`); `LiberNT.iso` `169005d6…`, `.vhd` `6d357d63…`,
`.img` `3aee194c…` (`host/image-identity.txt`). The VHD stays on disk; every VM ran on a fresh first-boot overlay over
it (`tools-used/mkqcow2.py`, no qemu-img on the host). The model is `qemu-ace-dsp` `main` (its binary of 07:59, not
rebuilt; five tool commits of this round on top: `d25fd6d`, `46b5a10`, `69a3b4b`, `1440c2c`, `001ade9`, nothing pushed). Every VM
under `ICOUNT=1`, one at a time, none during a compile. Nothing here was driven on real hardware.

## The headline

- **The final image boots the DSP by itself and runs its self-test at every boot**: `SelfTest = 3, UseInterrupts = 0,
  IpcTimeoutMs = 500 ms, BootAtStart = 0, DspIdleSec = 0 s`, `boot ok after 5525 us … state ready`, `firmware ready:
  version 2.15.0.1, ABI 1, … 16 pipelines, 4 libraries, context save 1, 7 tuples`, `loopback self-test: the gain step,
  three depths at -6.00 dB (gain 0x4026e73d)`, `6 runs, 6 matched, 0 failed, 92 requests, 0 notifications, 0 timeouts,
  0 DSP interrupts, ok`, `ran (0x00000000), the DSP is left running`, the four `registered as` lines -- at the first
  boot of the flow overlay (8.3–8.8 s guest), at the matrix overlay's boots, at every boot of the round.
- **The 22-cycle matrix: `AC3 cycles: 22 run, 22 boot ok, 0 self-test ok, 0 not booted, 0 bounded timeouts, 0 other
  outcomes, 0 waits not seen, clock stalled lines: 0`** -- on the matrix overlay (no topology, `BootAtStart = 1`, the
  image's `SelfTest = 3` kept): each cycle `Safe removal` → `boot ok after 5530–5532 us … state ready` → `topology:
  none selected (…); the DSP is powered down, no audio endpoint` → `DSP power down from state ready: ok`; the model's
  registers one distinct reading before and one after every cycle; clean S5, wall 929 s, 0 fatal, 0 `ace_unexpected`.
  **The image as burned refuses the first disable** (D4, N16-15): with the topology baked in the PCM child is present and
  `pnputil /disable-device` is refused -- `PNP_DisableDevInst(… 0 0x00000000)` → `DisableDeviceInstance(…)`, no
  `Safe removal` -- as every earlier matrix's overlay was no-topology, so is this one's (`vm/s2-refused-as-burned/`).
- **E3 on the final image**: the tray's keys reach the DSP (`gain: -2.00, -4.00, -6.00, -8.00 dB, mute 0, kept …`), dsploop
  at −8 dB is exact (**3 of 3 depths, max abs error 0, `1299 tests executed … 0 failures`**), **the mute key works**
  (`audiomute` ×2 → `gain: -8.00 dB, mute 1` → `mute 0`: N15-42 was QEMU's mic-mute key, N16-16), and **the pointer
  path reaches the DSP**: a drag in the tray's flyout (`-9.00`, `-35.00`, `-60.00 dB`) and a drag in the Settings'
  Volume tab (`-96.00 dB`). The stream test after the mute/unmute was **not obtained** in this VM (N16-23).
- **E5c's properties in the VM's registry** (`vm/flow/setdef.txt`): the adapter paths and the physical speakers as
  predicted; **the DSP endpoint's form factor is 1 (Speakers), not 10** (N16-21); the codec's line out 2 as predicted.
- **LEG-1's no-jack rows**: `HDAUDIO: pin 3 … presence-detect 0: pin sense raw 00000000 present 0, not followed` (pin 5
  alike), the four subdevice names (`eLineOutWave`, `eLineOutTopo`, `eLineInWave`, `eLineInTopo`), the endpoints in the
  Sound page (Playback: `Speakers – Intel SST Loopback – Ready`, `Speakers – HD Audio line out – Default Device`;
  Recording: `Microphone – HD Audio Line in`, `Microphone – Intel SST Loopback – Ready`), the jack-description line
  once per endpoint (2 lines), the watcher's 10 minutes with 0 error lines; the handle count not readable (N16-22).
- **The host gates on the final tip**: `mmdevapi: 317 checks, 0 failures` (the host test binary current: `ninja mmdevapi`
  rc 0, 0 steps); `dsploop_apitest.exe` built at `b7274b3e004` (link rc 0, pefixup rc 0, `614b1c97…`).
- - **The fault rows**: 20 of the 20 rows run (none, halt-rom=43, halt-rom=44, halt-fw=51, crash-notification, abi=2, window-read-fail, never-power, never-ack, never-ready, never-enter, never-fwready, never-reply, drop-requests, ipc-status=5, bad-tuples, truncated-reply, version-shift, none scale=1550, none scale=0.001): 20 bounded, 0 late, 0 unbounded; 20 `recovered: boot ok, self-test ok`; `fm-check.sh`: 0 row(s) with a failed check.
- **E1/E2 on the final image**: E2 (b)(c)(d) 10 of 10 runs with `DspIdleSec = 3`, a boot at each first open and an idle power-down after each; E1 `never-reply=19` with a stream open → `recovered: open ok after 6 ms`, the run after PASS; `crash-async=500` set before a run not produced (N16-25).
- The LiberNT branch was rebased in place by Megan at 18:23 onto upstream `bb96c5e4abf` (245/245 commits identical; the tip `284c85a825e`): no commit of this round is on it (none was needed).

## The blocks

| block | the VM / overlay | what it ran | result |
|---|---|---|---|
| the tools | — | `tools/cycle.sh`, `ac3-cycles.sh`, `fault-matrix.sh` (five commits) | the waits take what the P5 image prints (below) |
| the 22 cycles | `e5-firstboot.qcow2` (no topology, `BootAtStart = 1`, `SelfTest = 3`) | the prep VM (`vm/s2-prep/`: the settings by `reg`, a clean shutdown), then `ac3-cycles.sh 22` | **PASS**: `vm/s2-cycles/summary.txt` |
| the refused attempt | `e5-firstboot.qcow2` as burned | the first `ac3-cycles.sh` (stopped after its first cycle) | **D4**: `vm/s2-refused-as-burned/` |
| the flow row | `e5-flow.qcow2` (fresh first boot) | `tools-used/e5-flow.sh`: the wizard, the Sound page, the handle baseline, `setdef`, the tray's keys, dsploop at the level, the mute key, the pointer path by hand, the 10-minute read, the shutdown (the ACPI button's, N16-23) | `vm/flow/`: rc 0, wall 2757 s, 0 fatal, 0 `ace_unexpected` |
| E1 / E2 | `e5-flow.qcow2` (a later boot) | `tools-used/e2-round.sh`: `DspIdleSec = 3` by a reboot, 10 dsploop runs (a boot at each first open, an idle power-down after each), E1's `never-reply=19` and `crash-async=500` with a stream open, each followed by a run that must pass | **PASS**: E2 (b)(c)(d) 10 of 10 runs, 10 boots at open, 11 idle power-downs, 30 render opens, 0 timeouts; E1 `never-reply=19` → `recovered: open ok after 6 ms`, the run after PASS; `crash-async=500` set before the run: not produced (E1c's row stands); rc 0, wall 537 s, 0 fatal (`vm/e1e2/rows.md`, `e5-e1e2-lines.txt`) |
| the fault rows | `e5-firstboot.qcow2` (the matrix overlay) | `tools/fault-matrix.sh`, the Fix G set, `RECOVER=1`, `WINDOW=30` | **20 of 20 rows on the matrix overlay** (`BootAtStart = 1`, no topology, `SelfTest = 3`), `tools/fault-matrix.sh` as the p4c4c/p4c4g rounds ran it: 20 bounded, 0 late, 0 unbounded, 20 × `recovered: boot ok, self-test ok` (the recovery cycle's entry ends at the fail-safe, counted `self-test ok`); the terminal lines p4c4g's (`boot ROM error after 8400 us … 0x0000002b base firmware not found`, …); the `none` row ends at `topology: none selected … powered down` (no PCM runs the self-test); `fm-check.sh`: 0 row(s) with a failed check. All 20 ran. |

## The tools (N12-04, N12-09)

`tools/cycle.sh` waits in two stages after an enable -- the boot's end line (`boot ok after …`) or the D0 rule's
`D0 entry: the DSP is not booted (BootAtStart = 0)`, then, when the entry's settings line says `SelfTest = 2` or `3`, the
loopback self-test's closing line (`loopback self-test: ran (0x…), the DSP is …`) or, without a topology, the fail-safe's
`topology: none selected`; its exit code is the wait's (0 as the settings say, 1 a wait timed out, 3 nothing booted).
`tools/ac3-cycles.sh` takes a first boot through the Setup wizard by chords, opens the console by Win+R, counts
self-test ok and not-booted cycles. `tools/fault-matrix.sh` the same console, and a `SelfTest = 2/3` row ends with the
loopback summary. The P5 image prints no `Program Manager` line at any boot (N16-17): the tools take the display's
`desktop ready` line as the boot's end. **N12-09, written down:** the image's baked settings are in the VHD before the
first boot; the settings a row needs beyond them (`BootAtStart = 1`, no topology, `DspIdleSec = 3`) were written in the
guest by `reg add` / `reg delete` and made live by a **reboot** (a clean shutdown and the next boot's D0 entry, or
`shutdown -r`), never by a disable/enable cycle (refused on this image, D4/N16-15).

## What was not done

- The stream test after the mute/unmute on the final image (N16-23: the Run dialog trap); E5c has it at −8 dB on the
  owner's image.
- The default rule's VM row (no active device → `0x80070490`): not reachable in the VM -- every audio device's disable
  is refused on this image (D4/C11), so "no active render device" cannot be made; the rule stays host-tested (N16-05).
- D14 (the privacy page) and D12 d by the Properties sheet: D12 d was seen in the Settings' Sound page of the pointer
  row (`p11.png`), D14 not run (E4b has it on p5e4b).
- The 50 cycles of E2 (d) as 50: E2 (d)'s 50 cycles were 30 here (10 runs × 3 opens); E2's own round has 51 on p5e2.
- A fix for N16-21 (the form factor): the cause is not read.
- Nothing was driven on real hardware; the P5-H checklist (`p5-h-checklist.md` in the plan directory) is the owner's.
