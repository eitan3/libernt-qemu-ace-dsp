# P5 E4b — the rulings and the leftovers: the Volume tab, dsploop at a level, D12 d and D14 (evidence/2026-11-28-p5-e4b)

Round of 2026-11-28, one VM. Image **p5e4b** (`test-audio-intel-sst-p5e4b-82d9cf754e9`: the drivers and the applet at
`82d9cf754e9`, identity `20261128-nt10.0-045-2927-g82d9cf7.libernt`; the apitest beside it at the same tip, sha256
`2d1ffc883b545194…`). The model is `qemu-ace-dsp` `main` at `cd2f209` (unchanged), qtest 18/18. One QEMU run on the
fresh overlay `p5e4b` (the first boot, the wizard, the settings, a reboot; 2385 s; ended by the ACPI button, rc 0;
0 stop lines, 0 fatal, 0 kdb, 0 `ace_unexpected`). Nothing here was driven on real hardware.

**The headline.** Megan's four code rulings are in (N14-04, N14-05, N14-01, N14-02: three commits), their gates green.
In the VM the Volume tab follows the default render endpoint (N14-01 **shown**); dsploop at unity still compares
exact (3 of 3); **dsploop at a kept level does not compare: the level mmdevapi answers is not the level the driver
runs** (N14-17, new); D12 d and D14 are measured by eye; D13 was not driven. FD-01 / FD-02 were not reached.

## The commits (LiberNT; nothing pushed)

| # | commit | what |
|---|---|---|
| 1 | `9eda11f2483` | [AUDIODSP_E4b] the pin's line at a refused open is the first refusal's alone (N14-04: the audio interface's `ModelRefused`, version 3, read without the lock); the position poll waits for no transition (N14-05: a zero-time wait on the manager's mutex, no drain under a transition). sofipc 7802/0; mutation rows m36, m37 |
| 2 | `d15d2d19a67` | [AUDIODSP_E4b] mmsys.cpl's Volume tab is the default render endpoint's (N14-01: `IAudioEndpointVolume` on the eMultimedia default, the applet's eConsole as the second; a control-change callback posting the page; Cancel restores) |
| 3 | `82d9cf754e9` | [AUDIODSP_E4b] dsploop compares a stream at the endpoint's master volume (N14-02: the driver's gain table and arithmetic in `compare.c`, the tolerance one unit more under a gain). dsploop host 1321/0; mutation rows m38, m39 |

## The VM (one run, `vm/e4b/`)

The rows were driven by hand through `tools/guest.sh` (the monitor's `sendkey` and `type`; the pointer was not used:
its calibration was started, ~1.7 px a unit, and left). The applet opens on the Audio or the Playback page; `ctrl+tab`
walks the pages (Playback, Recording, Sounds, Volume, Audio, Hardware); `shift-tab` does not walk back; Tab moves
the focus off the page's first control but the trackbar never took the arrow keys here (below).

| row | how it was driven | what was seen | result |
|---|---|---|---|
| the default device | `reg query` of the two render endpoints to the data disk (`pouch/def.txt`) | the DSP's: `{026E516E-…},2` = `Speakers - Intel SST Loopback`, `{A45C254E-…},2` = `Speakers`, `{A45C254E-…},14` = `Speakers (Speakers - Intel SST Loopback)`, the adapter `{233164C8-…},1` = the endpoint's own id; the codec's: `HD Audio Line out`, `Speakers (HD Audio Line out)` | the subdevice names as the registry holds them (board 0b931523: N14-12) |
| `DefaultOutput` | `reg query HKCU\Software\Wine\Drivers\wdmaud.drv /v DefaultOutput` (`pouch/defout.txt`) | `Unable to find the specified registry value`: no default was set; the enumerator answers the first active device | the Audio page's combo and OK did not write it here (the keys did not land on OK) |
| Set Default by the registry | `reg add … /v DefaultOutput /t REG_SZ /d "{0.0.0.00000000}.{BDA7C5A8-…}" /f` (`pouch/setdef.txt`), the applet reopened | the Volume tab: **`Speakers (Speakers - Intel SST Loopback)`** (26-volume-tab-dsp, 28-volume-tab-after-tabs); before, with the codec the default, `Speakers (HD Audio Line out)` (17, 21) | **N14-01 shown**: the tab is the default endpoint's, no longer mixer 0's |
| the Volume tab's slider | `tab`, then `left` ×5, repeated; `ctrl+tab` ×5 and `left` ×5 without a Tab | no `gain:` line in the serial log either way; the focus rectangle was not read (the vision model's reading of a focused control is unreliable, N14-07) | **not driven**: the slider's reach to the DSP is not shown from the tab; the tray's keys reach it (below) |
| the level by the tray | `Win+D`, `volumedown` ×4, `volumeup` ×4 | `gain: -2.00, -4.00, -6.00, -8.00 dB, mute 0, kept …` one line a key (30-tray-osd-level); back `-2.00`, `0.00` | **PASS** as in E4 |
| dsploop at −8 dB | `D:\dsploop_apitest.exe` with `LIBERNT_APITEST_REQUIRED=1`, after the keys (`pouch/e4b-level.txt`) | `dsploop: the endpoint's master volume -7.68 dB (level -503335), mute 0: the expectation scaled by the gain 0x34f2162e, the tolerance 2 LSB`; `the tone was not captured (96000 frames)`; `0 of 3 depths compared`, 438 tests, 2 failures; the driver: `boot at stream open: ok after 6 ms`, `gain: -8.00 dB, mute 0` | **FAIL, and a finding** (N14-17): the stream ran at the driver's −8.00 dB; the test was told −7.68 dB (the scalar 0.92 the tray set, × 96 dB), a word 4 % above the driver's → no frame matches. The stream is at the kept level; the level's source is not the driver's |
| dsploop at unity | `volumeup` ×4 (0.00 dB), the same run (`pouch/e4b-unity.txt`) | `the endpoint's master volume 0.00 dB (level 0), mute 0: the expectation scaled by the gain 0x7fffffff, the tolerance 1 LSB`; three rows `48000 frames compared within 1/0/0 LSB, max abs error 0, offset 993/513/513, ok`; `3 of 3 depths compared`, `1296 tests executed (0 marked as todo, 0 failures), 0 skipped` | **PASS**: the new compare at unity is the old one |
| D12 d | `C:\Windows\ImmersiveControlPanel\SystemSettings.exe ms-settings:sound` from the console (the app is not on the PATH: `systemsettings.exe` is not found; the Run dialog's `ms-settings:sound` opened nothing in p4c4c) | Settings, System > Sound (43-d12d-settings-sound): Output `Speakers (Speakers - Intel SST Loopback)`, Format `32 bit, 48000 Hz`, Volume 100, Mute output; Input `Microphone (HD Audio Line in)`, `16 bit, 48000 Hz`, Volume 100 | **measured**: the format strings in the UI language (English) |
| D14 | `… SystemSettings.exe ms-settings:privacy-microphone` | Privacy & security > Microphone (44-d14-privacy-microphone): `Microphone access` (on, checked), `Let desktop apps access your microphone` (checked), `Strict mode` (unchecked); the text names **WASAPI** four times and ends "A program that talks to the audio driver directly is not stopped." | **measured**: the page names WASAPI only |
| D13 | `Win+A` sent (42-d13-wina) | not read in the time left; the tray's icons not clicked | **not run** |

The driver's lines of the run (`vm/e4b/e4b-lines.txt`): `booting 3, boot ok 3, boot at open ok 2, failed-boot 0, idle 3,
timeouts 0, fault-during 0, selftest runs 1 (6 runs, 6 matched), gain lines 16`.

## The host side (`host/`)

- `sofipc.txt`: 7802 checks, 0 failures (7788 + 14: case i30's flag checks, the contended poll); `dsppcm.txt` 26312/0;
  `dsploop.txt` 1321/0 (+ CheckGain); `mmdevapi.txt` 152/0; `host-audio-list.txt`: 18 registered, 14 passed, the 4
  non-audio ones Not Run (their targets are not built in the scratch tree); `host-audio-list-14.txt`: `ctest -E` those
  four, 14/14.
- `mutations.txt`: m36 (the refused-model query answers FALSE) KILLED, 5 red; m37 (the poll waits again) KILLED, 2 red;
  m38 (the gain word is unity) KILLED, 198 red; m39 (the expectation unscaled) KILLED, 283 red; the files restored identical.
- `drivers.txt`: the four drivers, `mmdevapi.dll`, `mmsys.cpl`, rc 0, 0 warnings; `kmtest.txt`: 17/17, 0 warnings;
  `apitest-compile.txt`, `build-dsploop.txt` (link and pefixup rc 0); `qtest.tap`: 18/18; `simulator-build.txt`: build ok.
- `identity.txt`: `20261128-nt10.0-045-2927-g82d9cf7.libernt`; the in-ISO drivers, `mmdevapi.dll` and `mmsys.cpl` 6 of 6
  identical to the build tree's; `images-build.txt`: rebuild_cache, buildstamp, 1463 steps, 0 warnings (N14-03's order).

The tools as they ran under `tools-used/` (`gates.sh`, `mut-e4b.sh`, `image.sh`, `identity.py`, `e4b-vm.sh` with
`vmcommon.sh`, `make-pouch.sh`, `collect-e4b.sh`, `px.py`, `diffbox.py`: the cursor by a diff of two screendumps).

## What was not done

- FD-01 / FD-02: not reached (the lever is located, N14-13). D13: not run. The Volume tab's slider: not driven.
- The proof row of board 27f810b4 (`waveInOpen` under Deny): not written (optional in Megan's ruling).
- N14-06 stands as reasoned (Megan's ruling 5): no change, recorded.
- The model mutation rows of the simulator were not rerun (no model change).
