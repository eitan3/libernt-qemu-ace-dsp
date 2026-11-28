# P5 E5c — the volume-level row in the VM made repeatable; FD-01 / FD-02 on the host (evidence/2026-11-28-p5-e5c)

Round of 2026-11-28. Two VMs that count, under `ICOUNT=1`, one at a time, none during a compile (and two attempts stopped
before their step, below). **Image** `test-burnboot-leg1-909633bdde3`: the owner's audio image, the pushed tip `39e4bc940a5`
plus three diagnostic trace commits and the baked settings (`BootDsp = 1`, `SelfTest = 3`, `Topology = sof-ipc4-loopback.tplg`),
the VHD `LiberNT.vhd` (80 GiB virtual, kept on disk). **It does not contain this pass's commits**: the row is proven on it; the
properties are proven again in E5's regression on the final image. The model is `qemu-ace-dsp` `main` (not rebuilt). Nothing
here was driven on real hardware.

## The headline

- **The level row is obtained, with no long typed line.** The default render endpoint is set by a data-disk tool
  (`setdef`, six typed characters), the slider is moved by the tray's keys, and the driver answers for the DSP's endpoint:
  `gain: -8.00 dB, mute 0`. dsploop at that level compares **3 of 3 depths, max abs error 0** (`1295 tests executed … 0 failures`),
  and once more after: the same (`1293 … 0 failures`).
- **Mute / unmute** through `IAudioEndpointVolume::SetMute` by a data-disk tool (the call the tray's button makes):
  `gain: -8.00 dB, mute 1`, then `gain: -8.00 dB, mute 0`; the stream test after it is exact again (**3 of 3, max abs error 0**,
  `1280 … 0 failures`). The tray itself takes no mute key (`mute` ×2 moved no driver line), and the pointer path was not driven.
- **FD-01 / FD-02 are closed on the host** (two commits; the mappings host-tested, 317/0, seven mutations killed). The owner's
  image shows the gap in its registry: both render endpoints have no adapter path, no physical speakers, and form factor
  `1` (Speakers), the loopback too; their friendly names carry no index (`Speakers (Intel SST Loopback)`, `Speakers (HD Audio
  Line out)`).

## The commits (LiberNT, `feat/audio-control-polish` from `39e4bc940a5`; nothing pushed)

| # | commit | what |
|---|---|---|
| 1 | `807b814ff66` | [MMDEVAPI][HOSTTESTS] The driver's backend answers an endpoint's adapter path, form factor and physical speakers (FD-01): `endpoint_props.h`, `reactos_get_prop_value`; mmdevapi host 317/0, mutations m47–m53 |
| 2 | `89ed252ffe2` | [MMDEVAPI] A device whose driver tells no name is not named by its wave index (FD-02) |
| 3 | `b7274b3e004` | [HDAUDIO] The jack description's line is told once for an endpoint and then only when its answer changes (Megan's item) |

### What each property answers, and from where (FD-01)

| property | answered with | source |
|---|---|---|
| the adapter path (`{b3f8fa53-0004-438e-9003-51a46e139bfc},2`, `devicepath_key`) | the KS filter the endpoint's wave pin is connected to, e.g. `\\?\intcdsp#pcm&…\loopbacktopo` | `reactos_wave_connector` → `IOCTL_GETWAVECONNECTOR` (`libernt_wdmaud.c`, `reactos_get_prop_value`) |
| `PKEY_AudioEndpoint_FormFactor` | by the reference string of that path: `eSpeaker` → Speakers (1), `eLineOut` → LineLevel (2), `eHeadphone` → Headphones (3), `eMicIn` → Microphone (4), `eLineIn` → LineLevel (2), `eSpdifOut` → SPDIF (8), `eHDMIOut` → DigitalAudioDisplayDevice (9); any other codec kind → UnknownFormFactor (10); an endpoint of the DSP's PCM (`intcdsp#pcm&ctlr_ven_8086&ctlr_dev_7f50|7e28`) → UnknownFormFactor (no jack); any other path → not answered | `endpoint_props.h`, `endpoint_form_factor`: the codec driver names a pin's subdevices by the kind of its configuration default (`hdaudio/common.cpp`, `ChooseSubdeviceName`); the DSP by the apitests' rule (`apitest_dspidentity.h`) |
| `PKEY_AudioEndpoint_PhysicalSpeakers` | the speaker mask of the endpoint's own format: 1 → 0x4, 2 → 0x3, 4 → 0x33, 6 → 0x3f, 8 → 0xff; another count → not answered | `reactos_driver_device_format` → `endpoint_physical_speakers` (the masks `channel_mask_from_count` builds the formats with) |

Why the path and not the jack description or the topology pin: the codec driver's `KSPROPERTY_JACK_DESCRIPTION` carries the
colour, the connection type, the locations, the port connectivity and IsConnected — not the kind; every render pin of its
topology is `KSNODETYPE_SPEAKER` and every capture pin `KSNODETYPE_MICROPHONE` (`hdaudio/tables.h:287,325`); the mixer's
destination line follows that node type. On this image dsploop prints the real connector paths, lower-cased by the PnP
manager: `{2}.\\?\intcdsp#pcm&ctlr_ven_8086&ctlr_dev_7f50#5&4d9fad45&0&00#{…}\loopbacktopo` and `…\hdaudio#…\elineintopo`
(`vm/mute/dl-unmuted.txt`): the matching is without regard to case.

## The VM row (`vm/level3/`)

A fresh first-boot overlay over the VHD (`tools-used/mkqcow2.py`, `disk/e5c-firstboot3.qcow2`). The data disk
(`tools-used/make-pouch.sh`, 32 MiB of FAT16): `dsploop_apitest.exe` (sha256 `b1b44b5ff30f01a4…`, built at `39e4bc940a5` by
`build-dsploop.py`: link rc 0, pefixup rc 0), `setdefault.exe` (`0006b89564cac66c…`, `tools-used/setdefault.c`,
`build-setdefault.py`: the build's own flags of a C win32cui), `setdef.cmd`, `dl.cmd`, `pouch.tag`. The harness
(`tools-used/round.sh`, `vmcommon.sh`) types short lines only, at 100 ms a key.

| step | what was typed | what was seen | result |
|---|---|---|---|
| the first boot | — | `Storage expansion not offered` at 104 s; `SelfTest = 3, UseInterrupts = 0, IpcTimeoutMs = 500 ms, BootAtStart = 0, DspIdleSec = 0 s`; `boot ok after 592686 us`; `loopback self-test: 6 runs, 6 matched, 0 failed` (the gain step at −6.00 dB); the four `registered as` | the DSP boots by the baked settings; the wizard still has to be gone through |
| the default device | `E:` ⏎, `setdef` ⏎ | `setdef.txt` after 4 s: `{BDA7C5A8-F3C6-8B76-ABDB-D685E723178B}` … `Speakers (Intel SST Loopback)` … `render endpoints: 2, the one named Loopback: 1`; `DefaultOutput set to {0.0.0.00000000}.{BDA7C5A8-…}: error 0`; read back the same | **set, no long line typed** |
| the slider | `Win+D`, `volumedown` ×4 | `[  788.107485] … gain: -2.00 dB, mute 0, kept until the DSP runs the PCM again`, `… -4.00 …`, `… -6.00 …`, `[  911.510707] … gain: -8.00 dB, mute 0, kept until the DSP runs the PCM again` | the tray's keys reach the DSP's endpoint: **the level is −8 dB** |
| dsploop at the level | a new console, `E:`, `dl level` | `[ 1059.326826] dsppcm.sys: endpoint 'Loopback' render: pin created, 48000 Hz 2 ch 32 in 32 bits`; `[ 1059.342451] intcdsp.sys: gain: -8.00 dB, mute 0`; `dsploop.c:775: dsploop: the volume node: -8.00 dB (level -524288, the driver's level), mute 0: the expectation scaled by the gain 0x32f52cff, the tolerance 2 LSB`; `48000 frames compared within 2 LSB, max abs error 0, offset 993 … ok`; `(24 valid in 32): … within 1 LSB, max abs error 0, offset 513 … ok`; `(32): … within 1 LSB, max abs error 0, offset 993 … ok`; `3 of 3 depths compared, 0 preconditions missing`; `1295 tests executed (0 marked as todo, 0 failures), 0 skipped.` | **PASS at −8 dB: exact (max abs error 0) at all three depths** |
| the tray's mute key | `Win+D`, `mute` ×2 | no driver line (serial 651 → 652) | not obtained by the key (N15-42) |
| dsploop once more | `dl after` | the same node line and the three rows; `3 of 3`; `1293 tests executed (0 marked as todo, 0 failures), 0 skipped.`; no new `gain:` line (the gain was not programmed again, N15-43) | **PASS** |

`lib-run.sh` wall 374 s, ended by the ACPI button, rc 0, 0 fatal, 0 `ace_unexpected`; gain lines 10.

## The mute row (`vm/mute/`)

On the installed overlay of the row (its second boot; no wizard), the data disk of the row copied with `endpointmute.exe`
(`aa1c2c522846cd0b…`, `tools-used/endpointmute.c`) and `mute.cmd` (`tools-used/roundmute.sh`). The boot restored the level:
`[   33.900636] intcdsp.sys: gain: -8.00 dB, mute 0, kept until the DSP runs the PCM again`.

| step | typed | seen | result |
|---|---|---|---|
| mute | `mute 1` | `mute-1.txt`: `DefaultOutput: {0.0.0.00000000}.{BDA7C5A8-…}`, `the call: IAudioEndpointVolume::SetMute(1)`, `before: mute 0`, `SetMute: 0x00000000`, `after: mute 1`; `[  390.634206] intcdsp.sys: gain: -8.00 dB, mute 1, kept until the DSP runs the PCM again` | **the DSP's endpoint is muted** |
| unmute | `mute 0` | `before: mute 1`, `SetMute: 0x00000000`, `after: mute 0`; `[  474.414305] intcdsp.sys: gain: -8.00 dB, mute 0, kept until the DSP runs the PCM again` | **unmuted** |
| the stream test after | `dl unmuted` | `[  569.179577] intcdsp.sys: gain: -8.00 dB, mute 0`; `the volume node: -8.00 dB (level -524288, the driver's level), mute 0 …`; the three rows `max abs error 0`; `3 of 3 depths compared`; `1280 tests executed (0 marked as todo, 0 failures), 0 skipped.` | **PASS: still exact after mute and unmute** |

`lib-run.sh` wall 238 s, ended by the ACPI button, rc 0, 0 fatal, 0 `ace_unexpected`.

### The two attempts before (`vm/level-cmd-script/`)

1. The brief's batch script: the guest's `cmd` does not expand `%GUID:~0,38%`; the file says `GUID=~0,38`, and `DefaultOutput`
   was written as `{0.0.0.00000000}.~0,38` with `The operation completed successfully` (`setdef.txt`). The round was stopped at
   that step: a default that names no device makes every later row a unity row. A helper exe replaced the script (N15-41).
2. The first helper cut the endpoint id's suffix one character short; seen on a re-read before its VM reached the step; the
   round was stopped, the helper rebuilt, the row above is the third (`disk/e5c-firstboot3.qcow2`).

## The host side (`host/`)

- `mmdevapi.txt`: 317 checks / 0 failures (251 + 66), ASan and UBSan; `host-build.txt`: 0 warnings.
- `mutations.txt`: m47 (headphone → speaker) KILLED, 1 red; m48 (no suffix check) KILLED, 4 red; m49 (case-sensitive) KILLED,
  2 red; m50 (the DSP rule gone) KILLED, 6 red; m51 (5.1's mask → 7.1's) KILLED, 1 red; m52 (no ordinal) KILLED, 2 red;
  m53 (kinds without a member answer 0) KILLED, 4 red; the header restored identical, rebuilt 317/0.
- `mmdevapi-build.txt`, `mmdevapi-build-final.txt`: `mmdevapi.dll` rc 0, 0 warnings; `drivers-build.txt`,
  `drivers-build-final.txt`, `hdaudio-build.txt`: `intcdsp.sys hdaudbus.sys dsppcm.sys hdaudio.sys` rc 0, 0 warnings (the
  last with the jack line's change).
- `cppcheck-backend.txt`: `libernt_wdmaud.c` analysed (0 errors), 12 note lines, all `intToPointerCast` on unchanged lines
  (199 … 1503), none in the changed ranges; `cppcheck-host.txt`: `t_mmdevapi.c` 0 findings; `cppcheck-prophnd.txt`: **not
  effective** — the gate stops at the C++ runtime's `platform.h:50` `#error` on `__BYTE_ORDER__` (N15-40).
- `build-dsploop.txt`: link rc 0, pefixup rc 0; `build-setdefault.txt`, `build-endpointmute.txt`: link rc 0, pefixup rc 0;
  `SHA256SUMS` of the three exes.

## What was not done

- The pointer path: the slider was moved by the tray's keys (the tray, not the Volume tab's slider or a pointer drag), and
  mute / unmute by a tool's `SetMute`, not by the tray's button or the tab's box.
- The properties were not read from a registry that holds FD-01's answers: that is E5's regression on the final image
  (the expected values are in `reviews/2026-11-28-p5-e5c-new-findings.md`, N15-37).
- The backend's answer itself (the adapter path's buffer protocol, the IOCTLs) is not host-tested; the nameless-driver fallback
  of FD-02 is build-verified only; the jack line's change is build-verified only.
- The jack line's change and FD-02 were not run in any VM; the form factor's kinds without a member are this pass's reading
  (N15-38, INFO_NEEDED on Windows 11).
