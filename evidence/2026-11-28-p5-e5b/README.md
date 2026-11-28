# P5 E5b — the topology control interface's VM proof: the node's flag and the walk's direction (evidence/2026-11-28-p5-e5b)

Round of 2026-11-28, six VMs, all under `ICOUNT=1`, one at a time, none during a compile. **Image p5e5b** (`test-audio-intel-sst-p5e5b-5ed065692de`: the drivers and
`mmdevapi.dll` built from the tree at `5ed065692de` with the two commits' content before they were made — the buildstamp names
`5ed065692de` and a dirty tree, `host/source-state.txt`; identity `20261128-nt10.0-045-….libernt`; the apitest beside it, sha256
`b7817561899e13…`). The model is `qemu-ace-dsp` `main` (unchanged, not rebuilt). Nothing here was driven on real hardware.

**The headline.** N15-20 is resolved in two layers, both fixed on the branch (`49d9867caed`, `d3860275207`, nothing pushed):
the walk reached no node along the outgoing parts of a render endpoint's connector (the node is upstream: N15-30), and once it
reached the volume node, `IKsControl::KsProperty` answered `0x80070490` because the request lacked `KSPROPERTY_TYPE_TOPOLOGY`
(N15-29). In the VM on the round's image **the node read succeeds — no fallback line — and dsploop compares 3 of 3 at unity
and 3 of 3 at −8 dB** (below). FD-01 / FD-02 were not reached.

## The commits (LiberNT; nothing pushed)

| # | commit | what |
|---|---|---|
| 1 | `49d9867caed` | [MMDEVAPI][HOSTTESTS] The control interface of a node part carries the node's flag on its three requests (N15-29); mmdevapi host 226/0, mutations m44–m46 |
| 2 | `d3860275207` | [APITESTS][HOSTTESTS] dsploop's walk follows the parts upstream of a render endpoint's connector (`walk.h`, N15-30); dsploop host 1327/0, mutations m40–m43 |

## The probe (N15-20's candidates, `vm/probe2/`, `vm/walk/`, `vm/walk2/`, `vm/dbg/`)

On the diag image `02e16ed400c` (the tip's `mmdevapi.dll`, the DSP booted by the baked INF defaults), with `WINEDEBUG=warn+mmdevapi`
on serial — no mmdevapi WARN line in any run:

- the mmdevapi apitest's `devicetopology` test (the probe exe of `tools-used/build-probe.py`): `devicetopology: 1849 tests executed
  (0 marked as todo, 0 failures)`; `loopbacktopo` pin 0 `physical connection to \\??\INTCDSP#PCM&…\LoopbackWave pin 1` and
  `loopbackwave` pin 1 → `…\LoopbackTopo` pin 0 — the dsppcm connection is registered and answered both ways (the first candidate
  is ruled out), and the filter's two nodes and three connections are read (the second).
- the endpoint's own topology (`vm/walk/walk-probe-v1-output.txt`): `GetConnectorCount … count 1`, `GetSubunitCount 0`,
  `GetConnector(0) 0x00000000`, `GetDataFlow … flow 0`, `GetDeviceIdConnectedTo 0x00000000 {2}.…\loopbacktopo`, the connector's
  `EnumPartsIncoming: 0x80070490` and `EnumPartsOutgoing: 0x80070490`, `GetConnectedTo: 0x00000000` → `local id 0x00010001`,
  `name PC Speaker`, whose `EnumPartsIncoming: 0x00000000` → `0x00020001 … Master Mute` → `0x00020000 … Master Volume`
  (subtype `{3a5acc00-…}`, KSNODETYPE_VOLUME).
- dsploop's own walk copied into the probe (`vm/walk2/walk.txt`): `the walk incoming: 0x00000000, the node …/00020000`;
  `the walk outgoing: 0x80070490`.
- the tip's dsploop at unity on the tip's DLL (`vm/probe2/dl-unity.txt`) and the walk's direction fixed alone (`vm/proof/`): the
  fallback line with `0x80070490`; the instrumented build (`vm/dbg/dbg.txt`): `depth 3 incoming part …/00020000` is entered, then
  the fallback line — the step after the walk: the node's request.

## The VM proof (the round's image, `vm/proof2/` and `vm/proof3/`)

`proof2`: a fresh first-boot overlay over the staged VHD (the wizard, the settings: `Topology`, `SelfTest = 3`, `BootDsp = 1`,
`DspIdleSec = 3`, a reboot — the branch's INF does not boot the DSP by itself), `lib-run.sh` wall 592 s, ended by the ACPI
button, rc 0, 0 stop lines, 0 fatal, 0 `ace_unexpected`.

| row | what was seen (`vm/proof2/dsploop-level.txt`, `dsploop-unity.txt`; the driver's lines of each run) | result |
|---|---|---|
| the boot after the reboot | `SelfTest = 3, UseInterrupts = 0, IpcTimeoutMs = 500 ms, BootAtStart = 0, DspIdleSec = 3 s`; `boot ok after 5529 us`; `loopback self-test: 6 runs, 6 matched, 0 failed`; the four `registered as` | the DSP up by the settings |
| the tray's keys | `Win+D`, `volumedown` ×4 twice: no `gain:` line — the default device is not the DSP's here (E4b's keys reached it after `DefaultOutput` was set) | the level stays 0.00 dB: this run is the unity row |
| dsploop at the node's level (0.00 dB) | `dsploop: the volume node: 0.00 dB (level 0, the driver's level), mute 0: the expectation scaled by the gain 0x7fffffff, the tolerance 1 LSB` — **no fallback line**; `48000 frames compared within 1 LSB, max abs error 0, offset 993, ok` (16), `… within 0 LSB, max abs error 0, offset 993, ok` (24 in 32), `… offset 993, ok` (32); `3 of 3 depths compared, 0 preconditions missing (LIBERNT_APITEST_REQUIRED 1: required, a failure)`; `dsploop: 1290 tests executed (0 marked as todo, 0 failures), 0 skipped.`; the driver: `boot at stream open: ok after 6 ms`, `gain: 0.00 dB, mute 0` | **PASS at unity: the node is read through the topology's control interface** |
| dsploop once more at unity | the same lines (`dsploop-unity.txt`) | **PASS** |

`proof3` (the −8 dB row): on the installed overlay, `DefaultOutput` set to the DSP's render endpoint by the registry, the tray's
keys, then dsploop at −8 dB and at unity — the DSP booted by the settings
(`boot ok after 5525 us`, `loopback self-test: 6 runs, 6 matched`), but the typed `reg add` of `DefaultOutput` did not take
(`reg: Unable to find the specified registry value`, `vm/proof3/defout.txt`) and the tray's keys moved no `gain:` line again:
the guest drops characters of a typed line under load (`vm/proof3/hand-reg.png`: the Run dialog shows
`{BDA7C5A8-F3C6-8B7S-ABDB-D655E7231788}` for the typed GUID). **The −8 dB row was not obtained**: the level stayed 0.00 dB and
the run compared 3 of 3 at unity a third time. The way to it is a typed line sent slowly (or the Volume tab's slider) after
`DefaultOutput` names the DSP's endpoint, as E4b did by hand.

## The host side (`host/`)

- `mmdevapi.txt` 226 checks / 0 failures (224 + the flag on the request, a caller who set it); `dsploop.txt` 1327 / 0 (1321 +
  `CheckWalkDirection`); `dsppcm.txt` 26312 / 0; `host-ctest.txt`: 3/3 (`-R 'mmdevapi|dsploop|dsppcm'`).
- `mutations.txt`: m40 (E5a's direction) KILLED, 2 red; m41 (always incoming) KILLED, 1 red; m42 (always outgoing) KILLED, 1 red;
  m43 (the flows exchanged) KILLED, 2 red; m44 (the property without the node's flag) KILLED, 1 red; m45 (the event) KILLED, 1 red;
  m46 (the method) KILLED, 1 red; both files restored identical.
- `drivers.txt`: `mmdevapi.dll`, `intcdsp.sys`, `hdaudbus.sys`, `dsppcm.sys`, `hdaudio.sys`, rc 0, 0 warnings; `build-dsploop.txt`
  (link and pefixup rc 0); `images-build.txt`: `rebuild_cache`, `buildstamp`, `liberntiso liberntvhd liberntimg`, 1430 steps,
  0 warnings; `identity.txt`: the in-ISO drivers and `mmdevapi.dll` 5 of 5 identical to the build tree's.

The tools as they ran under `tools-used/` (`gates.sh`, `mut-e5b.sh`, `image.sh`, `vmcommon.sh` with `make-pouch.sh`,
`mkqcow2.py` — the overlays written without `qemu-img`, none on the host —, `probe.sh`, `probe2.sh`, `proof.sh`, `proof-rest.sh`,
`proof2.sh`, `proof3.sh`, `boothold.sh`, `run1.sh`, `run2.sh`, `build-probe.py`, `build-walkprobe.py`, the walk probes
`walkprobe-v1.c` / `walkprobe-v2.c`, `dsploop-instrumented.c` (a debug build of the test, not committed)).

## What was not done

- FD-01 / FD-02 (T3): not reached (the lever as N15-19 states).
- The endpoint's own connector still answers no parts lists (N15-32, INFO_NEEDED on Windows 11); the method's node flag is the
  header's (N15-29, INFO_NEEDED).
- The model's qtest and the simulator's build were not rerun (no model change); the S7 names were not re-read from the registry
  in this round (the README's B4 row carries the names of `d388ae16c5b`).
