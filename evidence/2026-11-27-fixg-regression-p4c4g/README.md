# Evidence 2026-11-27-fixg-regression-p4c4g — the regression round on image p4c4g (Fix G)

What this is: the simulator-side regression on **image p4c4g** — `feat/audio-control-polish` at `6bdaaa5e920`
(the identity string `20261127-nt10.0-045-2828-g6bdaaa5`, the desktop watermark `feat/audio-control-polish, 6bdaaa5,
amd64, clang, …`), `BOOTLOADER_DEBUG_PORT = FILE,SCREEN` — after Fix G (the N7 fixes and the three older
leftovers). **No code of the LiberNT tree was read, built or changed; the model (`qemu-ace-dsp` `main`, the binary of
record `a894197d…`) was not changed either.** Every line below is measured in the VM. Written by the simulator side
(Tasker) for Megan.

| file | bytes | sha256 |
|---|---|---|
| `LiberNT.iso` | 665,229,312 | `6f68a6594c7eddc5ed03372364b5ecceaebda518e0f45d3c92c10b7bd792c5fb` |
| `LiberNT.vhd` | 820,352,512 | `af8f909acb4f1e45d63798a40efa753b3368d2a17780d83fb4edfcc3b95850e7` |
| `LiberNT.img` | 1,610,612,736 | `d6432564b40ba4ee2058923ee99bd205a58fd3258d59bb25bbfcd7b7e86012ed` |
| `dsploop_apitest.exe` | 214,016 | `bd849a7ca4acc5a7de2eb8130a217ac5e1616596916bd3555c0b2f2378c99242` |

`sha256sum -c SHA256SUMS`: four of four OK before the first launch (`logs/s0/image-check.txt`). The apitest used
everywhere is THIS build's (`bd849a7c…`, read back from the data disks before each use), not the old kit's.

## Conditions

One QEMU at a time; q35, pure TCG, `-cpu max`, `-smp 1`, 2 GB RAM, OVMF, `-nic none`, `-icount shift=auto,align=off,
sleep=off` on `tcg,thread=single` (as every evidence run), the ACE HDA model + hda-duplex, no build, no network.
The first-session flow (S1) ran **without a serial port** (the owner's configuration: the loader does not add
`DEBUGPORT=COM1`), every key through the monitor's `sendkey`, the screen read through `screendump` only; every other
VM through `lib-run.sh` with the serial console. The host's clock is UTC; all times are UTC.

## Results

| step | launches | verdict | evidence |
|---|---|---|---|
| S0 integrity and identity | (vm1's Boot 1) | **PASS** — SHA256SUMS 4/4 OK; the Boot-1 screen's watermark names `6bdaaa5` | `logs/s0/image-check.txt`, `vm1/b1-02-t60s.png`, `vm1/z-b1-02-watermark.png` |
| S1 the C6 first-session flow | 2 (vm1: 5 boots of the stick; vm1x: the export boot) | **PASS** — every driver line of EXPECTED-LINES.md with p4c4e's counts; gate GREEN (`1284 tests executed … 0 failures, 0 skipped`) | `logs/s1/`, `vm1/`, `vm1x/` |
| S2 the 22 power cycles | 1 (r2: the overlay's first boot, 25 cycles) | **PASS** — `AC3 cycles: 22 run, 22 boot ok, 0 bounded timeouts, 0 other outcomes, 0 waits not seen` | `logs/s2/` |
| S3 the 20 fault rows | 20 (one boot per row) | **PASS** — 20 rows bounded with p4c4c's named failures, the DSP powered down, 20 × `recovered: boot ok`; `fm-check.sh` 0 rows with a failed check | `logs/s3/` |
| S4 a fault with a stream open | 2 (r-stream: `never-reply`; r-s4b: `crash-notification`) + the boot of S8b | **PASS on the corrected criteria (1) (2) (4)** for `never-reply`; (3) is shown up to the hold line only (no tag line on this path); **`crash-notification`: not producible** (the model's fault is a boot-phase one) | `logs/s4/`, `logs/s8/r-final/` |
| S5 a status on delete-pipeline while a stream is released | 1 (r-s6, with S6, S7, S8) | **PASS (1) (2) (4)**; the run itself passed its 3 depths (the fault came at the last release); (3): `the buffer is not released, 0xc0000186`, no freed-under line, no tag line | `logs/s5/` |
| S6 a stop and a start of the PCM / codec device | 1 (r-s6) | **the stop is refused by the image** (pnputil: `Failed to disable device: A device attached to the system is not functioning.` for the PCM child, the codec and the DSP device; `/restart-device`: `System reboot is needed to complete the operation!`); the starts are accepted; **`dsploop` PASS** afterwards; no crash — the stop itself SKIPPED by the image | `logs/s6/` |
| S7 the quick-settings flyout, the volume flyout, one pane menu | (on r-s6) | **quick settings PASS, volume OSD PASS, no crash; the pane menu NOT OPENED** (SKIPPED: the right-click did not land) | `logs/s7/` |
| S8 the final power-off and the next boot | 2 (r-s6's power-off; r-final's boot) | **PASS** — `shutdown -s -t 0`: the S5 sequence, QEMU exited 6 s after; the next boot clean (AUTOCHK on both volumes, the desktop's line at 35.9 s, `dsploop` `1284 tests … 0 failures`) | `logs/s8/` |

Not producible here (not forced), as the brief says: a busy transport at a free (N7-01: host-side lock contention;
the host cases cover it) and a notification walk at a device change (N7-04: no test client exists; the host test
covers it).

## S1 — the first-session flow against the p4c4e final pass (`logs/s1/`)

The flow exactly as the p4c4e final pass (vm1: Boot 1 with the wizard, "Expand drive C: now", the account `tester`,
the components cleared, `mkdir C:\kit` + `copy D:\kit\*.* C:\kit\`, `savelog 1`, the restarts through Task Manager,
`stage1`, `savelog 2`, `stage2`, `savelog 3`, the Sound panel's two tabs, `stage3`, `run-dsploop`, `savelog 4`,
Turn Off — QEMU exited 3 s after it; vm1x: the export boot, `copy /y C:\logs\*.* D:\`, Turn Off). The exports were
read from stick B with mtools after the clean Turn Off of vm1x.

| boot | lines p4c4g / p4c4e | `intcdsp.sys:` p4c4g / p4c4e | stop lines | last line |
|---|---|---|---|---|
| boot1 | 259 / 260 | 10 / 10 | 0 | a `fixme:` of the console |
| boot2 | 133 / 133 | 23 / 23 | 0 | a `fixme:` of the console |
| boot2-prev | 133 / 138 | 10 / 10 | 0 | `Shutdown: closing the boot log` (trimmed, 15,561 bytes) |
| boot3 | 155 / 156 | 35 / 35 | 0 | a `fixme:` of the console |
| boot3-prev | 145 / 147 | 23 / 23 | 0 | `Shutdown: closing the boot log` (17,718 bytes) |
| boot4 | 169 / 166 | 36 / 36 | 0 | `The console display is now on` |
| boot4-prev | 171 / 172 | 35 / 35 | 0 | `Shutdown: closing the boot log` (21,314 bytes) |

- The driver lines (`intcdsp.sys:`, `dsppcm.sys:`, `hdaudbus.sys:`) of each boot, digits folded, against p4c4e's:
  **0 lines differ** in boot1, boot2, boot3 and boot4 (`dspdiff-boot<N>-p4c4e.txt`). The exact lines differ only in
  the model values: the BAR4 mapping (`…7253000` for `…7252000`), the clocks and the `boot ok after 5451 us` figure.
- EXPECTED-LINES.md's 42 quoted lines, digits folded, counted in the export and in p4c4e's
  (`expected-vs-measured.txt`): identical counts for 41; the one that differs is the apitest's `preconditions missing`
  line, which prints Fix F's new form `(LIBERNT_APITEST_REQUIRED 1: required, a failure)` where p4c4e printed
  `(LIBERNT_APITEST_REQUIRED=1, a failure)` — a **wording update (R8-05/R8-09), not a regression**; the quoted line
  in `refs/c6/EXPECTED-LINES.md` was updated to the new form for this image.
- The gate (`gate.txt`): `GREEN dsploop.txt: dsploop: 1284 tests executed (0 marked as todo, 0 failures), 0 skipped.
  (allowance 0, required)`; three `compared within … max abs error 0 … ok` lines (offsets 993 / 513 / 513),
  `48000 frames of the tone rendered, 96000 frames captured in 2016 / 2016 / 2000 ms` (p4c4e: 2031 / 2032 / 1985).
  1284 is inside the expected band (1259–1290).
- The whole logs differ only outside the drivers (`cmp-vs-p4c4e.txt`): the display's idle-out lines (`standby.c`,
  pacing), `ipstats_reactos.c` 97 lines for 89, the update agent's probe line (p4c4e's boot2-prev had it, p4c4g's not),
  one Storport "miniport is busy, requeueing" line that p4c4e's boot3/4-prev had and p4c4g's not, and three
  `libernt.c` line numbers shifted by one (1106→1105, 1313→1312, 1501→1500: the new master).
- By eye (the vision model's reading of the screenshots, confirmed where it decided a key): the Storage page ("Drive
  C: is 1470 MB with 594 MB free"), the account page filled, the Components page with **9 rows** (see N9-01) cleared
  to "The selected components need about 0 MB. Drive C: has 3153 MB free" (read at x4), the desktop after Finish, the
  console with 9 files copied (214,016-byte apitest), `dir C:\` with 3,304,701,952 bytes free, the Sound panel's
  Playback tab ("Speakers - Intel SST Loopback", Ready; "HD Audio Line out", Default Device) and Recording tab
  ("Microphone - Intel SST Loopback", Ready; "HD Audio Line In", Default Device), the stream test's lines.

## S2 — the 22 cycles (`logs/s2/`)

The close-out regression's r2 again: a fresh overlay over the p4c4g `LiberNT.vhd`, its first boot (the wizard's
chords; `First-boot setup lists 9 components`, `Storage expansion not offered`), `BootDsp = 1` and no topology, then
C8 (one cycle), C9 (two cycles of the DSP device alone) and the 22 cycles (`tools/cycle.sh` unchanged).

`AC3 cycles: 22 run, 22 boot ok, 0 bounded timeouts, 0 other outcomes, 0 waits not seen, clock stalled lines: 0`
(against p4c4c's `22 run, 22 boot ok, 0 bounded timeouts, 0 other outcomes, 0 waits not seen, clock stalled lines:
0`). The VM: 25 cycles in all, 25 `Safe removal: CSAUDIO`, 25 none-selected lines, 25 power-down lines, the model's
readings before and after the 22 cycles one distinct value each, 0 `The system has been stopped`, 0 fatal lines, 0
`ace_unexpected`, a clean S5 (rc=0, wall 1016 s). Observation, simulator side: three of the 22 disables took longer
than the others (ac3-16 69 s, ac3-19 37 s, ac3-21 32 s for 25–26 s) with a jump of the guest's clock across them
(+600 s, +160 s, +90 s) while host-side log analysis was running on the same machine; every one of them still ended
`boot ok after 5447 us`. Not an image matter; the host was kept quiet for the timed injections of S4/S5.

## S3 — the 20 fault rows (`logs/s3/`)

The close-out regression's matrix again: `tools/fault-matrix.sh` as the p4c4c round ran it (`tools-used/fault-matrix-p4c4g.sh`:
`ICOUNT=1`, `TRACE=1`, `QTESTSOCK=1`, `WINDOW=30`, a recovery disable/enable cycle per row), one boot per row on the
S2 overlay (`BootDsp = 1`, no topology): the 17 faults, the two delay scales, and `none`. Every row: **bounded** with
the same named failure as on p4c4c (ROM error / firmware crash / ABI mismatch / power-up, ROM init, ROM status, base
firmware, FW_READY and IPC reply timeouts / IPC error / bad IPC reply / truncated / version mismatch), the DSP powered
down (`DSP power down from state failed: ok`), and **20 of 20 `recovered: boot ok`** — the device started again after
the fault was cleared. `tools/fm-check.sh`: **0 row(s) with a failed check** (the elapsed, the two clocks, no bugcheck,
no hang, the recovery). Wall 20 × 99–138 s, 1985 s on p4c4c.

Per row against p4c4c (`evidence/2026-11-26-p4c4c/vm/fault-matrix.md`): the same terminal line and the same
power-down count in the trace for every row; the model figures differ as they do between runs (`after 8336 us` for
8328, `1007354 us` for 1006451 in never-fwready, `boot ok after 6805 us` for 5450 in the `none` row: the one row
whose boot-ok figure is not p4c4c's 5450–5481 band). The "next stream open" of the brief: the rows run on the
no-topology overlay (as the close-out regression's did), where no stream can be opened; the stream after the faults
is S4's first run (`s4a-recovered`: `recovered: open ok`) on the same overlay with the topology set.

One tooling note: the table's "terminal line" cell of the **never-fwready** row shows the power-down line, because the
script's 0.5 s poll of the serial log met the two lines in a state it did not expect (both carry the same guest
timestamp, 9.597106); the row's own serial log (`fm/fm-never-fwready/serial.log`, lines 122–123) and `fm-check.sh`'s
table carry the boot's line, `boot FW_READY timeout after 1007354 us … failed in FW_READY wait (FW_READY timeout)`,
and the row's verdict (bounded, recovered) stands.

## S4 — a fault while a stream is open (`logs/s4/`)

Method (`tools-used/r-stream.sh`, `r2-common.sh`): the S2/S3 overlay with the loopback topology set in the guest
(`reg add … /v Topology … sof-ipc4-loopback.tplg`, made live by one disable/enable cycle of the DSP device, which
booted the DSP and registered the four endpoints); a dsploop run started from the console with
`LIBERNT_APITEST_REQUIRED=1` and its text to the data disk; the host polled the serial log every 100 ms for the render
stream's first `opened` line and injected the fault with `set-fault.sh` the moment it appeared.

**S4a — `never-reply` at the first open (VM r-stream, `logs/s4/r-stream/`).** The fault landed on the request that
followed the open (guest 572.60 s → 575.11 s):

```
intcdsp.sys: ipc: set pipeline state (19) 0x93010003|0x00000000 reply timeout after 500009 us; the link is faulted
intcdsp.sys: stream 1: a pipeline could not be paused (0xc00000b5)
intcdsp.sys: streams: released after the fault; nothing is sent until the DSP is booted again
intcdsp.sys: DSP power down from state ready: ok, cleanup ok, ADSPCS 0x00000000 (SPA 0, CPA 0)
dsppcm.sys: stream: state 2 not set, 0xc00000b5 … dsppcm.sys: endpoint 'Loopback' render: the DSP gives no stream, 0xc00000a3
```

- bounded: the run ended by itself about 5 s after the fault (`dsploop: 1 of 3 depths compared … 433 tests executed
  (0 marked as todo, 2 failures), 0 skipped`; the 16-bit depth had completed before the fault, the 24- and 32-bit
  depths' `render: Initialize 0x8889000f`), the console answered; no bugcheck (0 stop lines, 0 fatal lines, 0
  `ace_unexpected`); no "freed under a pin" line, no held-buffer line and no tag line (the release took the
  "released after the fault" path, not a hold).
- **The next dsploop run did not pass**: `dsppcm.sys: endpoint 'Loopback' render: the DSP gives no stream, 0xc00000a3`
  (STATUS_DEVICE_NOT_READY), `0 of 3 depths compared`, `5 tests executed (0 marked as todo, 2 failures)` — the
  driver's own line says why: "nothing is sent until the DSP is booted again", and only a D0 entry boots it.
- **The device could not be restarted in-session**: `pnputil /disable-device` of the DSP device was logged by the PnP
  manager (`PNP_DisableDevInst(… CSAUDIO\ADSP&CTLR_VEN_8086&CTLR_DEV_7F50\…)`, `DisableDeviceInstance(…)`, guest
  739.6 s) and never completed: no `Safe removal`, no QueryRemove line, no driver line in the remaining 700 s of the
  VM; the `/enable-device` that followed produced no boot; the run after it still read "the DSP gives no stream". (The
  cycle was `tools/cycle.sh` without a text capture of pnputil's own answer — see S6 for the captured texts.) The VM
  was then stopped by me (the script's remaining steps could only wait on the dead DSP) and ended by the job's kill
  (QEMU was cut with it; the registry values of the overlay were written before).

**S4b — `crash-notification` at the first open (VM r-s4b, its own boot, `logs/s4/r-s4b/`). Not producible here.**
The fault was injected at the first open (guest 332.36 s) and had no effect: no driver line, and the run **passed**
(`3 of 3 depths compared`, `1288 tests executed (0 marked as todo, 0 failures), 0 skipped`), as did the next run
(`1285 tests … 0 failures`: recovered: open ok). The model's `crash-notification` fires only inside `ace_fw_ready()`
(`patches/0004`, the EXCEPTION_CAUGHT notification in place of FW_READY at the boot): it is a boot-phase fault, and
the model has no run-time crash notification. Recorded as N9-02 (model side); not forced.

Deviation of the harness: the first VM's runs typed `set LIBERNT_APITEST_REQUIRED=1 && …`, and cmd.exe keeps the
space before `&&` in the value, so the apitest read `'1 '` and classified it `not a 0 or a 1, required, a failure`
(the run still counts as required; the pass/fail rule is the same). The later VMs type `=1&&` and read `1: required`.

Megan's correction of the brief, mid-round: a `dsploop` run after the fault is **not** expected to pass on this image (that is P5's
E1 behaviour); the criteria for S4 and S5 on p4c4g are (1) bounded — no stop/bugcheck line, the DSP powered down; (2) the
application's stream refused with an error, never a hang; (3) the release holds the pin's buffer and the pin's own free
returns it exactly once — no "freed under a pin" line, the tag back; (4) after a reboot or a D0 cycle `dsploop` passes
again. Measured against those: S4a (1) ✓ (2) ✓ (4) ✓ by the reboot of S8b (`dsploop: 1284 tests executed (0 marked as
todo, 0 failures), 0 skipped`); (3): no "freed under a pin" line, and on this path no hold line and no tag line at all
(`streams: released after the fault` released the streams without a hold; the serial log and the model's trace carry no
tag event of the driver), so "exactly once / the tag back" is **not shown by the log**, only not contradicted (no pool
bugcheck afterwards, the console and the next runs alive). The D0 cycle is not available with the topology loaded: pnputil
refuses the disable of the DSP device in the healthy state too (S6), so after such a fault only a reboot recovers.

## S5 — a firmware status on the delete-pipeline request at a stream's release (`logs/s5/`)

VM r-s6 (`logs/s6/r-s6/`, the same boot as S6). This build's apitest opens the render stream **three** times per run (the
p4c4c binary did nine: three groups), so the injection was at the third open (guest 2675.2 s), the last depth's stream;
`set-fault.sh <ev> ipc-status=5:18`. The request at that stream's release was answered with the status:

```
intcdsp.sys: ipc: delete pipeline (18) 0x92090000|0x00000000 firmware status after 63 us; the link is faulted
intcdsp.sys: stream 1: the PCM's pipelines could not be deleted (0xc0000186); released as after a fault
intcdsp.sys: streams: released after the fault; nothing is sent until the DSP is booted again
intcdsp.sys: DSP power down from state ready: ok, cleanup ok, ADSPCS 0x00000000 (SPA 0, CPA 0)
dsppcm.sys: stream: the buffer is not released, 0xc0000186
```

- (1) ✓: no stop line, no fatal line, 0 `ace_unexpected`, the DSP powered down. (2) ✓: the run ended by itself about 4 s
  after the fault — it even **passed** its three depths (`3 of 3 depths compared`, `1296 tests executed (0 marked as todo,
  0 failures), 0 skipped`), the fault having come at the release after the last capture; the console answered.
- (3): `dsppcm.sys: stream: the buffer is not released, 0xc0000186` is the hold (the PCM keeps the buffer because the
  pipelines could not be deleted); no "freed under a pin" line; no tag line on this path either (the serial log and the
  trace carry none) — "exactly once / the tag back" not shown by the log.
- By design (P5 E1): the next run's open read `dsppcm.sys: endpoint 'Loopback' render: the DSP gives no stream,
  0xc00000a3` (`0 of 3 depths compared`, `5 tests executed (0 marked as todo, 2 failures)`). In the faulted state pnputil's
  `/disable-device` of the DSP device answered `Failed to disable device: A device attached to the system is not
  functioning.` — the same refusal as in the healthy state (S6) — and `/enable-device` `Device enabled successfully.`.
- (4) ✓ by the reboot of S8b (above).

## S6 — a stop and a start of the DSP's PCM / codec device, no stream open (`logs/s6/`)

VM r-s6, the topology loaded (the boot: `boot ok`, the topology line, 4 `registered as`, the audio child), no stream open.
pnputil's own texts (the data disk, `r-s6/pouch/`):

| command | the image's answer |
|---|---|
| `/disable-device "INTCDSP\\PCM&…\\00"` (the PCM child) | `Failed to disable device: A device attached to the system is not functioning.` |
| `/enable-device "INTCDSP\\PCM&…\\00"` | `Device enabled successfully.` |
| `/restart-device "INTCDSP\\PCM&…\\00"` | `System reboot is needed to complete the operation!` |
| `/disable-device "HDAUDIO\\FUNC_01&…"` (the codec) | `Failed to disable device: A device attached to the system is not functioning.` |
| `/enable-device "HDAUDIO\\FUNC_01&…"` | `Device enabled successfully.` |
| `/restart-device "HDAUDIO\\FUNC_01&…"` | `System reboot is needed to complete the operation!` (N5-05, as on p4c4c) |
| `/disable-device "CSAUDIO\\ADSP&…"` (the DSP device: the devnode cycle) | `Failed to disable device: A device attached to the system is not functioning.` (C10, as on p4c4c) |
| `/enable-device "CSAUDIO\\ADSP&…"` | `Device enabled successfully.` (a no-op: no boot line) |

So **the stop cannot be driven on this image**: the PnP manager refuses the disable of the child, of the codec and of the
DSP device alike (on the serial port each refusal is only `PNP_DisableDevInst(…)` / `DisableDeviceInstance(…)`, no
`Safe removal`), and a restart asks for a reboot. The starts are accepted. Device Manager was not tried: it issues the same
PnP request. After the eight commands `dsploop` **passed** (`3 of 3 depths compared`, 0 failures; 9 opens, 0 ipc lines), the
console answered, 0 stop lines, 0 fatal lines, 0 `ace_unexpected`; the child was still listed after the "cycle"
(3 `INTCDSP` lines in `enum-devices /class Media /ids`). Recorded as the image's answer, not as a defect of Fix G: the
refusal is the p4c4c round's C10/C11, unchanged.

## S7 — the flyouts (`logs/s7/`)

On r-s6 after S5, by keyboard (the console in front): **Win+A opened the quick-settings flyout** (`s7-1-quick-settings.png`:
Wi-Fi, Bluetooth, Ethernet "Not available", Power "Balanced", the Sound section with its slider, the settings gear);
Esc closed it (`s7-2`, a desktop frame). **`volumeup` showed the volume OSD** (`s7-9-volume-osd-1s.png`, one second after
the key: a centred slider at 100 with the speaker icon), gone by itself before the next frame five seconds later. **The
pane menu did not open**: the monitor's relative `mouse_move` did not reach the flyout under `-display none` (the cursor
stayed on the console in every frame), so the right-click on the Ethernet pane landed nowhere (`s7-5-pane-menu.png`), and
`tab, tab, shift-f10` in the flyout opened no menu (`s7-10-pane-menu-kbd.png`). No crash: 0 stop lines, 0 fatal lines, the
desktop and the console intact afterwards. The frames were read by the vision model.

## S8 — the final power-off and the next boot (`logs/s8/`)

On r-s6: `shutdown -s -t 0` through the Run box (the console had lost its focus to the flyouts). The kernel's S5 sequence
ran (`Sleep: Sending the S5 set request …`, `Entering sleep state S5.`) and **QEMU exited 6 s after the command**; as on
p4c4e, `shutdown.exe`'s path left none of the `Shutdown: running the queued shutdown work … closing the boot log` lines,
so the next boot ran `AUTOCHK: Checking \\??\C:` and `\\??\H:` (VM r-final: the desktop's line at 35.9 s, `boot ok after
5898 us`, the topology line, the audio child, the console answering, the child listed). **`dsploop` after the reboot passed**
(`3 of 3 depths compared`, `1284 tests executed (0 marked as todo, 0 failures), 0 skipped`, 6 opens, 0 ipc lines) —
S4/S5 criterion (4). The VM ended by the ACPI power button with the clean lines (`Shutdown: running the queued shutdown
work … closing the boot log`), rc=0. One script quirk: `r-final.sh` logged "ending the VM by the ACPI power button" after
the exit it had just recorded — the VM had already powered itself off; the line means nothing.

## The sticks and the overlays (not committed)

- Stick A: `disk/c6-stick-p4c4g.img` — a 4 GiB raw file with `LiberNT.img` at offset 0 (the image part's sha256 EQUAL
  to the source's; MBR entry 1 `start=2048 size=131072 type=ef bootable`, entry 2 `start=133120 size=3012608 type=7`;
  `logs/s0/s0-stick-sfdisk-d.txt`). "Expand drive C: now" was chosen on Boot 1.
- Stick B: `disk/c6-stickB-p4c4g.img` — FAT32, 256 MiB, MBR, one partition at sector 2048, carrying the kit folder
  (the eight kit files of `refs/c6/kit`, THIS build's `dsploop_apitest.exe` `bd849a7c…` and a `KIT-SHA256SUMS` made
  for it: `logs/s0/s0-pouch-made.txt`). It stayed attached for the whole flow as the owner's spare stick does. The same
  kit for this image is at `refs/c6/kit-p4c4g/` (new; `refs/c6/kit` is p4c4e's and was left as it was).
- The data disks of the other VMs: FAT16 "pouches" with the same exe under both names and a marker file, made per
  VM (`tools-used/make-pouch.sh`); the guest's text was read back with mtools.
- The overlays: `disk/p4c4g-nt.qcow2` over the p4c4g `LiberNT.vhd` (`BootDsp = 1`, no topology: S2 and S3; the
  topology was set in the guest afterwards for S4–S8), made by `make-overlay.sh`.

## Directories

- `logs/s0/` — the image check, the sticks' partition tables and the kit's listing, the VMs' start lines.
- `logs/s1/` — the exports of the flow as the host read them from stick B (`boot<N>.txt`, `boot<N>-prev.txt`,
  `dsploop.txt`: the NUL-stripped `.log`; the raw 270,336-byte exports are left out), `stats.txt`, `gate.txt`,
  `expected-vs-measured.txt`, `cmp-vs-p4c4e.txt`, `dspdiff-boot<N>-p4c4e.txt`, `listing.txt`.
- `vm1/`, `vm1x/` — the two VMs of the flow: `driver.log` (every key, every typed line, every screenshot with its
  host time; the password is `<typed>`), `start.txt`, `qemu-args.txt`, `qemu-dbg.log.gz`, the screenshots.
- `logs/s2/` — S2: `overlay-made.txt`, `boot2.out`, `r2/` (the serial log and its text copy, the driver log, the
  cycles' log and per-cycle outputs, the summary, the text the guest wrote, the three screenshots, `contents.txt`).
- `logs/s3/` — S3: `fault-matrix.md` (the 20 rows and `tools/fm-check.sh`'s checks), `fm/` (each row's serial log,
  command line, screenshot, trace excerpt and gzipped `-d` log), `fault-matrix.out`, `fm-check.out`.
- `tools-used/` — the scripts exactly as run.

## Screenshots

- `vm1/` (13 + 3 crops): the Boot-1 screen with the watermark (whole and the crop read for S0), the account page filled, the
  Components page with its 9 rows (whole and the list crop), the "need about 0 MB" line after the clears (x3 and x4), the
  console after `savelog 1` and `dir C:\`, after `stage1`, the DSP power-up boot's text screen, the Sound panel's two
  tabs, the stream test's result, Task Manager with Turn Off highlighted. `vm1x/`: the console after the export copy.
- `logs/s2/r2/`: the overlay's first boot before the wizard, after it, 20 s later.
- `logs/s3/fm/<row>/`: `desktop.png` and `console.png` of each row (the tool's own).
- `logs/s4/r-stream/`: `s4a-after.png`; `logs/s4/r-s4b/`: `s4b-after.png`.
- `logs/s6/r-s6/`: `s5-after.png`, `s7-1-quick-settings.png`, `s7-5-pane-menu.png`, `s7-9-volume-1s.png`,
  `s7-10-pane-menu-kbd.png` (the last four again under `logs/s7/`).
- `logs/s8/r-final/`: `s8b-desktop-after-boot.png`.

Every decision rests on the text the guest wrote (the stick, the data disks, the serial log); the screenshots were read by
the vision model and are cited as "the screen shows".

## The password

The account's password was generated on the host into a file (`/tmp/c6g/.pw`, mode 600) and typed from it by the tool;
it is in no log (`driver.log` reads `type <typed>`), and the screenshots show dots.

## Privacy

The machine is "the test machine"; no brand, model, serial or IP. The driver's DMI line, which prints the SMBIOS
strings (the model's here), is scrubbed to placeholders in every committed text file (`tools-used/scrub-dmi.sh`);
host paths are replaced by `normalise-evidence.sh`; the account's password was generated on the host into a file
(mode 600) and typed from it (`driver.log` reads `<typed>`); `tools-used/verify.sh` checks all three over the evidence tree
and `refs/c6`: password string 0, raw DMI strings 0 in the evidence tree, home paths 0. One raw DMI line remains outside this
tree: `refs/c6/EXPECTED-LINES.md` (p4c4e's deliverable) quotes the model's line in full — left as it was for Megan's call.

## What was not done

- No build, no network; the LiberNT tree was not read or written; the model was not changed.
- **S4b** (`crash-notification` while a stream is open): not producible with the model — its fault fires only in the boot's
  FW_READY moment (N9-02); the run with the fault set passed, which proves nothing about the driver.
- **S4/S5 criterion (3)** "the pin's own free returns it exactly once … the tag back": not shown by the log on these paths
  (no hold line, no tag line; the model's trace has no driver tag event); only the hold in S5 (`the buffer is not released,
  0xc0000186`) and the absence of any "freed under a pin" line are on record. A kmtest or a debug print on the free path
  would be needed to show the count.
- **S6**'s stop: refused by the image for the child, the codec and the DSP device (pnputil's texts above); Device Manager
  not tried (the same PnP request); no stale handle was held across a cycle, since no cycle completed.
- **S7**'s pane menu: not opened (the mouse did not reach the flyout under `-display none`; the keyboard did not open a
  menu). A pane menu needs a pointer that lands or a known keyboard path.
- Per-row stream opens after the 20 fault rows: not run (the rows are on the no-topology overlay, where no stream exists;
  the stream after the faults is S4's first run and S8b's).
- The first VM of S4 (r-stream) was cut by the job's kill after its evidence was complete (the registry values of the
  overlay were written before; the next boot ran AUTOCHK, as the run book says it will).
- Not producible here, as the brief says: a busy transport at a free (N7-01) and a notification walk at a device change
  (N7-04).
- Over budget: the round took 2 h 37 min of wall time (13:02–15:39 UTC) against the 2 h 30 (the first S4 VM's dead end, the
  re-plan on fresh boots, and the mouse-less S7).
