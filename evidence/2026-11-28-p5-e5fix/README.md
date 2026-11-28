# P5 E5-fixes — the form factor (N16-21), the two rows re-run (N16-23, N16-25) and the Wi-Fi service (evidence/2026-11-28-p5-e5fix)

Round of 2026-11-28. **Image** `test-audio-p5final-486b024c9b1`: LiberNT identity `486b024c9b1` = `feat/audio-control-polish` `d8fbfe348da`
(the E5 tip `284c85a825e` + `674015229b0` [MMDEVAPI][HOSTTESTS], the NT form of the DSP endpoint's interface path, host 326/0,
mutation m54, + `d8fbfe348da` [VWIFI], netvwifi.inf's comment) + the baked-INF commit (patch-id identical to `fb3c99d6d5f`:
`BootDsp = 1`, `SelfTest = 3`, `Topology = sof-ipc4-loopback.tplg`), built by Megan (`host/image-provenance.txt`,
`host/image-SHA256SUMS`). The VHD stays on disk; the one VM of the round ran on a fresh first-boot overlay over it
(`tools-used/mkqcow2.py`, `tools-used/e5fix-prep.sh`). The model is `qemu-ace-dsp` `main` at `7173453` (its binary, not rebuilt).
Under `ICOUNT=1`, one VM, nothing compiled or run meanwhile. Nothing here was driven on real hardware.

## The headline

- **Row 1, the form factor (N16-21, closed).** `setdefault.exe` in the registry of the new image (`vm/rows/setdef.txt`):
  `Speakers (Intel SST Loopback)` `{BDA7C5A8-F3C6-8B76-ABDB-D685E723178B}` -- `{b3f8fa53-…},2: REG_SZ
  \??\INTCDSP#PCM&CTLR_VEN_8086&CTLR_DEV_7F50#5&4d9fad45&0&00#{6994ad04-…}\LoopbackTopo` (the adapter path, as E5 printed it),
  **`{1da5d803-…},0: REG_DWORD 10`** (E5's image: 1), `{1da5d803-…},3: REG_DWORD 3` (the speakers, as before). The codec's line out
  `Speakers (HD Audio Line out)`: `…\eLineOutTopo`, form factor 2 (LineLevel), speakers 3 -- as E5. The capture endpoints
  (`vm/rows/cap.txt`, by `cap.cmd`: `reg query …\MMDevices\Audio\Capture /s`, as `setdefault.exe` prints the render endpoints
  only): `Microphone (Intel SST Loopback)` `{E77CD7FF-39A3-83CB-BBF3-5EC2E8266020}` -- `…\LoopbackInTopo`, **form factor `0xa`**;
  `Microphone (HD Audio Line in)` -- `…\eLineInTopo`, form factor 2 (the mapping's LineLevel for a line input).
- **Row 2, the stream test after mute/unmute (N16-23, closed).** The tray's mute key twice (`audiomute` ×2) →
  `intcdsp.sys: gain: 0.00 dB, mute 1, kept until the DSP runs the PCM again` → `gain: 0.00 dB, mute 0` (guest 920.35 / 957.93 s).
  The console re-opened by Win+R answered in 3 s (`console answering after after-mute`); `dl muted`: **`dsploop: 3 of 3 depths
  compared`, `1289 tests executed (0 marked as todo, 0 failures), 0 skipped`** (`vm/rows/dl-muted.txt`). No pointer session ran in
  this VM, so the Run dialog's trap did not arise; the ask-before-typing (`alive2`, a marker file on the pouch) is in the script.
- **Row 3, the crash mid-stream (N16-25, closed).** `crash-async=500` set at the run's first open (open #1 at guest 1469.776 s,
  the knob set at 18:08:19 host; `tools-used/e5fix-rows.sh`, E1c's 100 ms poll). The driver at 1470.505 s: `ipc: firmware crash
  with no request outstanding, read at a stream's period; the link is faulted` → `fault during stream 1: …` (twice) → `streams:
  released after the fault; nothing is sent until the next stream open or D0 entry`. The run ended by itself after 9 s with its
  error: `33087 frames compared within 1 LSB, max abs error 0` then `Test failed: … 33087 of 48000 frames`, `0 of 3 depths
  compared`, `353 tests executed (0 marked as todo, 2 failures)` (`vm/rows/dl-crash.txt`). The run after it: `boot ok after
  5526 us … state ready`, **`intcdsp.sys: recovered: open ok after 6 ms`**, `3 of 3 depths compared`, `1283 tests executed
  (0 marked as todo, 0 failures), 0 skipped` (`vm/rows/dl-a-crash-async.txt`).
- **Row 4, the Wi-Fi service (a confirmation row).** At boot (guest 9.89 s): `NWIFI: DriverEntry` → `NWIFI: control device
  \Device\Nwifi created` → `NWIFI: DriverEntry succeeded` (`\drivers\network\nwifi\wifi.c:172`, `control.c:941`, `wifi.c:199`);
  `sc query Nwifi` (`vm/rows/svc-nwifi.txt`): `TYPE : 1  KERNEL_DRIVER`, `STATE : 4  RUNNING`, `WIN32_EXIT_CODE : 0  (0x0)`.
  No line of the boot names `\wifi.sys`; the boot has no "not found" line. **The hive's line was never wrong**: `hivesys.inf:2052`
  reads `system32\drivers\nwifi.sys` on every ref (HEAD blob = index = worktree = upstream `bb96c5e4abf` = the E5 tip
  `b7274b3e004` = the build dir's generated `hivesys_utf16.inf:2052`; `tools-used/t2-hive-facts.sh`, `t2-hive-utf16.sh`,
  `t2-provenance.sh`), and `drivers\wifi.sys` is in no tracked file (`t2-wifi-where.sh`). WIFI‑1 (`wifi-plan.md:106`, which
  itself prints `drivers\nwifi.sys`) took the `\n` for a line break. The same artifact showed `wifi.sys` in this round's own
  reads of the hive until 17:24 UTC and `nwifi.sys` from 17:27, while the blob hashes and the file's mtime (16:23:05 UTC, the
  rebase) say nothing wrote it in between (N16-27).
- The boot as every P5 image: `BootDsp = 1`, `SelfTest = 3, UseInterrupts = 0, IpcTimeoutMs = 500 ms, BootAtStart = 0,
  DspIdleSec = 0 s`, `boot ok after 5525 us … state ready`, `firmware ready: version 2.15.0.1, ABI 1, … 16 pipelines, 4
  libraries`, `loopback self-test: … 6 runs, 6 matched, 0 failed, 92 requests, 0 notifications, 0 timeouts, 0 DSP interrupts,
  ok`, the four `registered as` lines. A baseline run before the mute: `3 of 3 depths compared`, `1297 tests executed … 0
  failures` (`vm/rows/dl-base.txt`). The VM: rc 0, wall 401 s, `done: booting 2, boot ok 2, selftest ok 1, recovered 1, render
  opens 10, gain lines 9, mute lines 1, fault-during 2, firmware crash 3, timeouts 0, stop lines 0, fatal 0, ace_unexpected 0`.
- The host gates of phase 1 (`host/`): `mmdevapi.devenum` 326/0 (317 + 9), mutation m54 (the NT form dropped) 5 failures →
  restored 326/0 (`mmdevapi-host-test-mutation-m54.txt`); `mmdevapi.dll` rc 0, 0 warnings; `build-dsploop.py` link rc 0,
  pefixup rc 0 (`d3b4abfc…`, the exe of the pouch); cppcheck live (the probe finds the injected read), the host unit 0 findings,
  `libernt_wdmaud.c` 24 portability notes on unchanged lines, 0 in the header.

## The block

| block | the VM / overlay | what it ran | result |
|---|---|---|---|
| the four rows | `e5fix-firstboot.qcow2` (fresh first boot over the new VHD) | `tools-used/e5fix-rows.sh`: the wizard, the console, `snd` (the Sound page), `setdef`, `cap`, `svc`, `dl base`, the tray's mute key ×2, the console re-opened and asked, `dl muted`, `dl crash` with `crash-async=500` at open #1, `dl a-crash-async`, the ACPI shutdown | **PASS**: rows 1-4 (`vm/rows/`); rc 0, wall 401 s |

## The hive's ImagePath scan (phase 1)

71 `ImagePath` values in `image/data/hivesys.inf` (`tools-used/t2-scan.sh`, `t2-followup*.sh`): 70 name a module the tree builds
(`svchost`, `spoolsv`, `telnetd` among them, by `add_cd_file` or the manifest); `wifi.sys` does not exist as a name in the hive (above);
`packet.sys` (service `Packet`, Start = 4, upstream's line) is built nowhere and is left as it is. `netvwifi.inf`'s comment claimed an
`Enum\Root` seed in the hive that does not exist; corrected in `d8fbfe348da` (comment only).

## What was not done

- The pointer path and the watcher's 10 minutes (E3's and E5's rows, not this round's).
- `endpointmute.exe` was not needed: the tray's key reached the driver (the script falls back to it).
- `packet.sys`: left for the board.
- Nothing was driven on real hardware.
