# Provenance — the p3c1 simulator round (P3 C1, 2026-11-25)

Written by the simulator side. The VM half of C1: the first time the driver's IPC self-test talks to the model's
pipeline table. Nothing in the LiberNT tree was touched: it was read (`git show` / `git grep` at the image's
commit) only to learn where the driver prints its settings line and how its fault lines are worded.

## Image under test

`~/libernt-build-logs/test-audio-intel-sst-p3c1-f2bf7a98990/` — `feat/audio-control-polish` published as
`9c9a876c6a39e08ee413146da23610846099a68f` (84 commits over master `f2bf7a98990`; built from `5773fcfa7af`,
identical tree content per `MEGAN-NOTE.txt`). Verified with `sha256sum -c SHA256SUMS`:

| file | sha256 | check |
|---|---|---|
| `bootcd.iso` | `1e381a4be0434fcf46d2e25207906198dcd45960ff55ea6b291e43190b6662e9` | OK |
| `LiberNT.vhd` | `97c09c3acee91104a641021e20be854b464b018e202671dd10502e340b8b4fd1` | OK |
| `LiberNT.img` | `5802921164371f68a513eff16d3c1ebacf3ced0ed63719590696325f783baafd` | OK |

`intcdsp.sys`, `hdaudbus.sys` and the rest extracted from the ISO with `bsdtar` and hashed (= `PROVENANCE.txt`
and `gates/in-iso.txt` of the image dir):

| file in the ISO | sha256 |
|---|---|
| `Windows/system32/drivers/intcdsp.sys` | `cc6c1309d0f6a76a2bf7ac12736d470cf341b485349408981bc2e8f03417b748` |
| `Windows/system32/drivers/hdaudbus.sys` | `e5702615cc8f59155e17c78f72b9a6c74d15f5172877b703de774b539994bacd` |
| `Windows/inf/intcdsp.inf` | `6e7603e40cd72cf5371333a2b4a602f95bdd44fbaf50185ea542ddf09bafb28d` |
| `Windows/system32/drivers/intel/sof/sof-arl-s.ri` | `f37a055cefef26bbe14906ec6cd5fe5532c2a4419de87612d8b45b45dc647c6e` |
| `Windows/system32/drivers/intel/sof/LICENCE.Intel` | `80169325f69cf8288ff225b590ca4bf2e8e2a15759076616fae0bfe2610427c9` |

The desktop's build stamp on the first boot: `feat/audio-control-polish.5773fcf.amd64.clang.3208-251126`
(`a1-stage1-firstboot/s1-desktop-firstboot.png`).

## Model

- qemu-ace-dsp `main` at `9713aa0` (patches 0001–0018 applied on QEMU 11.1.3; `build/applied-patches.txt`
  lists the 18 commits).
- **Rebuilt from the series before the first VM run** (`./build.sh`, 2026-11-25 09:51:42Z, 18 patches, rc=0,
  17 s): the tree's previous binary was the mutation check's last build, which may be a mutant.
  `build/qemu-system-x86_64` sha256 `be8667eb822902f712334caf3484762285bd0c936787e5906cfea8895750481d` and
  `build/tests/qtest/intel-hda-ace-test` sha256 `5d908c0786cb7c35e00ef352dfecd53ffce52f13b5cff7f572e57cefec468ab4`
  — both equal to the hashes the model half recorded (`../qtest.txt`): the binary of this round is the model
  half's.
- qtest before the first VM run: **14/14** (`qtest.txt`; the transcript with the `ace_*` trace in
  `qtest-before-vm.txt.gz`).
- Every VM run: q35, TCG, `-smp 1`, `ICOUNT=1` (`-icount shift=auto,align=off,sleep=off`,
  `tcg,thread=single`), one VM at a time on the host, logs on tmpfs (`/tmp/qad-ev/p3c1/…`) copied into this
  tree afterwards (the whole device trace gzipped; `qemu-dbg.excerpt.txt` from the power-up on, `ipc-trace.txt`
  from the firmware's FW_READY notification on).

## Overlays

- `disk/p3c1.qcow2`: a fresh qcow2 overlay over the p3c1 `LiberNT.vhd` (`make-overlay.sh`, backing format vpc,
  80 GiB virtual). `a1-stage1-firstboot` turns it into the stage-2 overlay (`BootDsp = 1` set in the guest);
  `b1-selftest` adds `SelfTest = 1`. The self-test fault rows (`selftest-faults/`) run on it.
- `disk/p3c1-st2.qcow2`: a copy of the stage-2 overlay taken after `a2-stage2-boot` (`BootDsp = 1`,
  `SelfTest = 0`), so that AC3 and the AC4 boot matrix (`ac3-cycles/`, `fm-<fault>/`) run with p2b4's settings
  and compare with p2b4's rows.

## Layout of this evidence tree

| run | what |
|---|---|
| `qtest.txt`, `qtest-before-vm.txt.gz` | the qtest before the first VM run: 14/14, the binary hashes; the transcript with the `ace_*` trace |
| `c1-acceptance.md` | Tasks A–D: the image's expectations → the measured lines (the P2 block with N5 and N6, the seven self-test lines and the trace sequence, the two fault rows, AC3 and AC4) |
| `DIVERGENCE.md` | D4 (the power-down line's state), N9 (the settings line twice), the N5/N6 observations, the stale reply bits, E5–E7, the tooling changes, what was not run |
| `a1-stage1-firstboot` | the first boot of the fresh overlay: the three-page first-boot wizard (`s1`–`s4`), a console (`s5-cmd`), `BootDsp=1` set and read back (`s6-reg-query`), the stage-1 lines (`stage1-lines.txt`: p2b4's thirteen with N6's `read` and the two settings lines), clean S5 — this boot turns the overlay into the stage-2 overlay |
| `a2-stage2-boot` | a plain boot of the stage-2 overlay: the full block with the `interrupts …` lines, N6's `read` then `resident`, the new `ipc: link ready` line (`stage2-lines.txt`); the trace of the boot (`qemu-dbg.excerpt.txt`, 100 lines from the power-up on; `ipc-trace.txt` from the FW_READY notification on) with N5's mask |
| `b1-selftest` | **the C1 acceptance**: `SelfTest = 1` set in the guest (`selftest-set.png`), two disable/enable cycles (`cycles.log`), each `boot ok` then the seven lines; `selftest-lines.txt`, `ipc-trace.txt` (three boots) |
| `b2-selftest-boot` | a plain boot with `SelfTest = 1` persisted: the seven lines at boot time |
| `selftest-faults/` | the two self-test fault rows `ipc-status=5:19` and `never-reply=19` (`fm-ipc-status=5_19/`, `fm-never-reply=19/`: `serial.log`, `recover.out`, the trace excerpt + the whole trace gzipped, `desktop.png`/`console.png`) and `fault-matrix.md` (the rows and `tools/fm-check.sh`'s self-test table) |
| `ac3-cycles` | AC3: 22 disable/enable cycles under icount (`cycles.log`, `summary.txt`, the whole trace gzipped), clean S5 |
| `fm-<fault>` | the 20 boot rows of the matrix, each with its recovery cycle (`serial.log`, `recover.out`, the trace excerpt + the whole trace gzipped, `desktop.png`/`console.png`) |
| `fault-matrix.md` | the boot matrix in the canonical order (the `none` row ran last; the table was assembled from the run's output and the `|` inside that row's `boot ok` quote escaped by hand) and the checks beyond "bounded" (`tools/fm-check.sh`: 0 rows with a failed check) |

Serial lines end in CR LF in the logs; they are quoted without the tail.
