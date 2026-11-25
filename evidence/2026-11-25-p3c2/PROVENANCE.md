# Provenance — the p3c2 simulator round (P3 C2, the micro round, 2026-11-25)

Written by the simulator side. The VM half of C2: the topology selection after `boot ok` — the fail-safe without a
topology (run 2), the loopback model from the registry override (runs 3 and 4) — and the boot regression, on the
driver's image p3c2 against the model unchanged since C1. Nothing in the LiberNT tree was touched: it was read
(`git show` / `git grep` at the image's commit, never a checkout) only to see where the driver keeps a topology
model and what its summary line prints (`DIVERGENCE.md`, T1 and X1).

Scope: the owner's ruling of 2026-11-25 — micro rounds from now on: this checkpoint's own acceptance plus one
boot regression, no fault matrix, no 22-cycle run (the one full regression runs before C6). Three VM boots, four
DSP boots, 14 minutes of VM time.

## Image under test

`~/libernt-build-logs/test-audio-intel-sst-p3c2-93ab8fd2fc4/` — `feat/audio-control-polish` at
`2285127b060a944837894fe8aeaed70e3c67580e` (86 commits over master `93ab8fd2fc4`), built in `output-Clang-amd64-debug`
with `BOOTLOADER_WIM_RAMDISK` off (the file-based boot medium; the WIM medium is not what ran). Verified with
`sha256sum -c SHA256SUMS` (three of three OK):

| file | sha256 | check |
|---|---|---|
| `LiberNT.iso` (the CD image; the `bootcd.iso` of that directory is p3c1's old file under the deprecated alias, not this image) | `5ba330522bd749fa292348b72caaa44ce0118e8b1f7b40342dbefeb224c3e279` | OK |
| `LiberNT.vhd` | `4fc35027f7af0e9abe0f442f9a8c531671a993a6366ce4df2f86b136bec285e6` | OK |
| `LiberNT.img` | `40628edd2ab698c247ffc428fd270fdea95fdd98b898ac310cc6dfead8ae7b83` | OK |

Extracted from the ISO independently of the image directory's own gates (`bsdtar -xf LiberNT.iso` into `/tmp`,
hashed there) — equal to `PROVENANCE.txt` and `gates/in-iso.txt` of the image directory:

| file in the ISO | bytes | sha256 |
|---|---|---|
| `Windows/system32/drivers/intcdsp.sys` | 266240 | `7bca0a5741c8c5ee03552ed967cec7e5abbffec1dc552319224077b553a1b795` |
| `Windows/system32/drivers/hdaudbus.sys` | 258048 | `1aee432d47f1c8f7cac0dca73cb8389d6420cb380d74d98a2a2d2c1d5d30528f` |
| `Windows/system32/drivers/intel/sof-tplg/sof-ipc4-loopback.tplg` | 4286 | `0e002de8d92e94f9f961a94a72654750f42d21afbdea09a2f6f6ee7196965601` |
| `Windows/system32/drivers/intel/sof/sof-arl-s.ri` | 1158164 | `f37a055cefef26bbe14906ec6cd5fe5532c2a4419de87612d8b45b45dc647c6e` (p3c1's) |
| `Windows/inf/intcdsp.inf` | 6146 | `a7f59a66130b4cb1ae81a056f0b76c35706783f52d67313e1f7f1f1794b5ee09` |

The same two files as the guest sees them on the installed system, read in the guest's console
(`r2-stage2-no-topology/topology-dir.png`): `dir` lists `4,286 sof-ipc4-loopback.tplg` beside `LICENCE.Intel`
(52,982) and `NOTICE` (684), and `certutil -hashfile … SHA256` prints the `0e002de8…65601` hash.

The image identifies itself in the guest: the console's banner `LiberNT [Version 0.4.17-amd64-dev 20261125-2285127]`
(`r1-stage1-firstboot/s5-cmd.png`), the desktop's watermark
`feat/audio-control-polish.2285127.amd64.clang.4715-251126` — both name the build tip (C1's E7 is gone).

## Model

- qemu-ace-dsp `main` at `d2dc604` (patches 0001–0018 on QEMU 11.1.3; `build/applied-patches.txt` lists the 18
  commits). Unchanged since the C1 round's `9713aa0`: the two commits between touch evidence and tooling only.
- **Rebuilt from the series before the first VM run** (`./build.sh`, rc=0, 18 patches, 22 s, `build/TIME.txt`
  2026-11-25T16:04:46Z): `build/qemu-system-x86_64` sha256
  `be8667eb822902f712334caf3484762285bd0c936787e5906cfea8895750481d`, `build/tests/qtest/intel-hda-ace-test` sha256
  `5d908c0786cb7c35e00ef352dfecd53ffce52f13b5cff7f572e57cefec468ab4` — the same two hashes as before the rebuild
  and as the C1 round recorded.
- qtest before the first VM run: **14/14** (`qtest.txt`, rc=0, 16:05:11Z–16:05:21Z; the transcript in
  `qtest-before-vm.txt.gz`).
- Every VM run: q35, TCG, `-smp 1`, `ICOUNT=1` (`-icount shift=auto,align=off,sleep=off`, `tcg,thread=single`),
  `CDROM=none` (the installed system boots from the disk overlay, as in every round since the boot manager
  changed), `TRACE=1`, `QTESTSOCK=1`, one VM at a time on the host, logs on tmpfs (`/tmp/qad-ev/p3c2/…`) copied
  into this tree afterwards (the whole device trace gzipped per run). `qemu-args.txt` and `command.txt` of each
  run hold its exact command line.

## Overlays

- `disk/p3c2.qcow2`: a fresh qcow2 overlay over the p3c2 `LiberNT.vhd` (`make-overlay.sh`, backing format vpc, 80
  GiB virtual). `r1-stage1-firstboot` is its first boot; there `BootDsp = 1` is set (`s6-reg-query.png`: the key
  holds `BootDsp 0x1`, `SelfTest 0x0`, `UseInterrupts 0x0`, `IpcTimeoutMs 0x1f4` and no `Topology` value). In
  `r2-stage2-no-topology` the override is set after the fail-safe was seen (`topology-set.png`: `Topology REG_SZ
  sof-ipc4-loopback.tplg`). `r3b-topology-plainboot` is a plain boot of the same overlay with the override
  persisted. The overlay is not committed.

## Layout of this evidence tree

| run | what |
|---|---|
| `qtest.txt`, `qtest-before-vm.txt.gz` | the qtest before the first VM run: 14/14, the binary hashes; the transcript with the `ace_*` trace |
| `c2-acceptance.md` | **the C2 acceptance table**: runs 1–4 (and the plain boot 3b) — TESTING.md's expectation next to the measured lines, then the round's counts and what was not run |
| `DIVERGENCE.md` | T1 (the summary line's byte count is the model's size, not the file's), X1 (a disable/enable is not the "second D0 entry" the brief's run 4 assumed: a new device object re-reads by design; the kept-model line needs an S3), D4 and N9 measured fixed, the environment notes |
| `trace-regression.txt` | the first boot's device trace against p3c1 `a2-stage2-boot`'s: its 106 `ace_*` lines all present, in order, 2 added |
| `r1-stage1-firstboot` | **run 1**: the first boot of the fresh overlay — the three-page wizard (`s1`–`s4`), a console (`s5-cmd`), `BootDsp=1` set and read back (`s6-reg-query`); the stage-1 lines (`stage1-lines.txt`: p3c1's fifteen minus the duplicated settings line); clean S5 |
| `r2-stage2-no-topology` | **runs 2, 3 and 4** in one VM: the stage-2 start without a topology (`stage2-lines-none.txt`: from the firmware line on — the settings line, the boot block, the two new lines); the override set in the console (`topology-set.png`) and the file listed and hashed there (`topology-dir.png`); two disable/enable cycles (`tools/cycle.sh`: `cycles.log` with the model's registers read over qtest before and after each; `cycle1-override-lines.txt` = run 3, `cycle2-override-lines.txt` = run 4, cut at the serial line numbers `cycles.log` records — 162 and 189; the latter also holds the S5 power-down); `driver-lines.txt` = all 75 driver lines of the VM with their timestamps; `ace-trace.txt` = all 416 `ace_*` lines; clean S5 (`console-end.png`) |
| `r3b-topology-plainboot` | a plain boot with the override persisted: TESTING.md (b)'s two lines at boot time (`stage2-lines-override.txt`); the VM stopped on the modules line (not an S5) |

Serial lines end in CR LF in the logs; they are quoted without the tail.
