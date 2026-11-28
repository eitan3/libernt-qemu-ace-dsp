# P5 E4 — the leftovers: rows (c) and (d) on p5e3, then the hold and N12-02 on p5e4 (evidence/2026-11-28-p5-e4)

Round of 2026-11-28. **Step 0** on image **p5e3** (`test-audio-intel-sst-p5e3-ae97c6a7a3e`, unchanged): the E3 round's
rows (c) and (d) that were not driven (N13-09). Then the E4 commits on `feat/audio-control-polish` from `ae97c6a7a3e`
to `9af75cd8052` (five commits, nothing pushed), image **p5e4** (`test-audio-intel-sst-p5e4-a6ab68c812d`: the drivers
at `a6ab68c812d`, identity `20261128-nt10.0-045-2923-ga6ab68c.libernt`; the apitest shipped beside it at
`9af75cd8052`), its round. The model is `qemu-ace-dsp` `main` at `dff6333` (unchanged), qtest 18/18. Three QEMU runs,
one at a time, each bounded; nothing here was driven on real hardware.

**The headline.** Rows (c) and (d) pass by their lines on p5e3: the system volume keys and the mute key reach the
DSP's gain module through the default device (one `gain:` line per key), and a level kept by the user survives an
idle power-down and is re-sent at the next open. On p5e4 the hold (N12-03) passes: a pin open and not started for
20.0 s sees no idle power-down, and one comes 23 s after the boot at open (20 + 3); the stream test after it is
exact. The mmsys.cpl Volume tab is not the DSP's (N14-01).

## The commits (LiberNT; nothing pushed)

| # | commit | what |
|---|---|---|
| 1 | `5c59c428b21` | [AUDIODSP_E4] a model the firmware refused is remembered: the next opens are refused without a boot (N12-02); host case i30, mutation rows m33, m34 |
| 2 | `bb9c81fa023` | [AUDIODSP_E4] the manager's two buffer lines in %u, the wording of a second free (N8-04, N8-01) |
| 3 | `56131bd06a2` | [AUDIODSP_E4] the pin's position property drains the pending teardowns (N8-02's last part: the audio interface's `TeardownPoll`, version 2); dsppcm host case, mutation row m35 |
| 4 | `a6ab68c812d` | [AUDIODSP_E4] dsploop holds a pin open and not running (`DSPLOOP_HOLD`, N12-03) |
| 5 | `9af75cd8052` | [AUDIODSP_E4] dsploop's hold is not judged as a run of the stream test (found by the round: the hold ended with the harness's own "0 of 3 depths" failure) |

## Step 0 on p5e3: rows (c) and (d) (VM `e4-cd`, `vm/e4-cd/`, `rows.md` there)

The overlay p5e3 as the E3 round left it (SelfTest = 3, BootDsp = 1, DspIdleSec = 3, the loopback topology): the
boot's self-test 6 runs matched, and its three gain rows were counted 3 by the script's own `ok$` count this time
(`vmcommon.sh`'s `norm()` strips the CR: N13-10 fixed in this round's scripts).

| row | how it was driven | the lines | result |
|---|---|---|---|
| (c) | mmsys.cpl's Playback page: "Speakers - Intel SST Loopback" selected by a click and made the default device (19, 20-setdefault); Win+D, then the tray's `volumedown` ×4 and `audiomute` | `gain: -2.00 dB, mute 0, kept until the DSP runs the PCM again`, `-4.00`, `-6.00`, `-8.00`, `gain: -8.00 dB, mute 1, kept ...`; the OSD at 92 (26-osd) and muted (27-osd-muted) | **PASS** |
| (c) | mmsys.cpl's Volume tab (the applet the plan named) | "Speakers (HD Audio Line out)" (11-volume-tab): the tab's slider and mute are mixer device 0's | **NOT the DSP's** (N14-01) |
| (d1) | `audiomute` again (`gain: -8.00 dB, mute 0, kept ...`), the DSP down by idle since the boot, then dsploop | `boot at stream open: ok after 6 ms`, `gain: -8.00 dB, mute 0`; dsploop: `no frame within 48000 matches the tone's first cycle`, `0 of 3 depths compared` | **PASS** by the lines: re-sent at the open, the stream at that level (dsploop compares with the unscaled tone) |
| (d2) | `volumeup` ×4 (`-6.00`, `-4.00`, `-2.00`, `gain: 0.00 dB, mute 0, kept ...`), the idle power-down, dsploop | `boot at stream open: ok after 6 ms`, `gain: 0.00 dB, mute 0`; dsploop: three rows `48000 frames compared within 0/1 LSB, max abs error 0`, `3 of 3 depths compared`, `1294 tests executed (0 marked as todo, 0 failures), 0 skipped` | **PASS** |

Not driven: the mute flag across an idle power-down (unmuted before (d1)); the self-test after an idle power-down
(it runs at a D0 entry alone: N14-02). The VM ended by the ACPI button, rc 0; 0 stop lines, 0 fatal, 0 kdb.

## The round on p5e4 (VMs `e4-round`, `e4-round2`)

| row | the VM | what the log shows | result |
|---|---|---|---|
| (a) SelfTest = 3 | `e4-round` (the first boot, the wizard, the settings, a reboot) and `e4-round2` (a later boot) | `6 runs, 6 matched, 0 failed`; three rows `gain 0x4026e73d ... ok` | **PASS** (both; the script's own count: gain rows ok 3) |
| (b) the baseline | both | one dsploop run after the idle power-down: `boot at stream open: ok after 6 ms`, `gain: 0.00 dB, mute 0`, `3 of 3 depths compared` (1301 / 1285 tests, 0 failures) | **PASS** |
| (c) the hold (N12-03) | both | `DSPLOOP_HOLD=20`: `dsploop hold: the render client initialized, its pin open and not started`, `boot at stream open: ok after 6 ms` at guest 877 s, `released after 20000 ms (the timeout)`; no `idle power down` between them; `idle power down after 3 s` at guest 900 s | **PASS**: 23 s after the boot at open (20 + 3), one power-down in the run |
| (d) the stream test after | `e4-round`: **not a stream test** — the console still had `DSPLOOP_HOLD` set, so it ran a second hold (a fault of the script, recorded as it ran); `e4-round2` with the variable cleared | `boot at stream open: ok after 6 ms`, `gain: 0.00 dB, mute 0`, `3 of 3 depths compared`, `1285 tests executed (0 marked as todo, 0 failures), 0 skipped` | `e4-round2`: **PASS** |

The lines of `e4-round2` (`vm/e4-round2/e4-lines.txt`):

```
(c)  [  877.663385] intcdsp.sys: boot at stream open: ok after 6 ms
     (dsploop hold: the render client initialized, its pin open and not started; holding up to 20 s, a key ends it)
     (dsploop hold: released after 20000 ms (the timeout); the pin closes)
     [  900.681703] intcdsp.sys: idle power down after 3 s
(d)  [ 1049.729164] intcdsp.sys: boot at stream open: ok after 6 ms
     [ 1058.914441] intcdsp.sys: idle power down after 3 s
```

Both VMs ended by the ACPI button, rc 0; 0 stop lines, 0 fatal, 0 kdb, 0 `ace_unexpected`. The hold's `ok()` of
the three runs was removed by the fifth commit after the round (the runs were made with the exe of `a6ab68c812d`,
sha256 `8e103bf5…`; the staged exe is of `9af75cd8052`, `fede97d9…`).

## The host side (`host/`)

- `sofipc.txt`: 7788 checks, 0 failures (7729 + case i30's 59), no sanitizer note; `host-audio-list.txt`: the audio
  host-test list 14/14 (dsppcm 26312 checks among them).
- `mutations.txt`, `mut-m35.txt`: m33 (an open boots again for a refused model) KILLED, 5 red; m34 (the release does
  not forget) KILLED, 9 red; m35 (the position property does not poll) KILLED, 5 red.
- `drivers.txt`: the four audio drivers, rc 0, 0 warnings; `kmtest.txt`: 17/17, 0 warnings; `build-dsploop.txt`.
- `qtest.tap`: 18/18 (the model unchanged); `simulator-build.txt`: build ok, 35 patches.
- `identity.txt`, `images-build.txt`: the identity `…-2923-ga6ab68c.libernt`, the in-ISO binaries 5 of 5 identical
  to the build tree's; the build sequence (a first build without `rebuild_cache` carried p5e3's string: N14-03).

The tools as they ran under `tools-used/` (`px.py`: the pixel reading of a screendump, the pointer's path of
N14-07). normalise-evidence.sh applies the path and listing rules; scrub-dmi.sh the DMI line; verify.sh's counts
are in the commit.

## What was not done

- The list after N12-03 in the round's brief, in its order: the legacy microphone consent (board 27f810b4, D7), FD-01 /
  FD-02, the subdevice names (board 0b931523), the UI rows D12 d, D13, D14 (board 8b424002): **not reached** (the
  budget: step 0 took 38 minutes for the applet's keyboard path, the image was built twice). None of their files was
  read or changed. Deferred by Megan before the round: N8-05, N13-06 (record only).
- The model mutation rows of the simulator were not rerun (no model change).
- N12-02 has no VM row: the loopback topology passes the limits check and the model has no knob to refuse it; the
  host case and its two mutation rows are the evidence.
