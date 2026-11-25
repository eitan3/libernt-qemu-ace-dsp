# Provenance — the p3c3 round (P3 C3, 2026-11-25): the model half, then the VM half

Written by the model side (Tasker). The model half of C3 — the host gateways of plan §5.9/§8 C3, the
`ace_audio` evidence lines and their qtest — against the driver's copier configuration as it stands
at `d5e2a039be6`. Nothing in the LiberNT tree was edited (one caveat under "What was read"). No VM
run: the C3 image is the driver half's.

## The series

| item | value |
|---|---|
| development tree | `src/qemu-11.1.3`, branch `master`, 20 commits over `v11.1.3`, head `46998f810` |
| this round's commits | `5a90cf7b7` hw/audio: intel-hda-ace: the host gateways (the module table, audio forwarding, the extended DMA-position registers) — `intel-hda-ace.c`, `intel-hda-ace-regs.h`, `trace-events`, `docs/system/devices/intel-hda-ace.rst`; `46998f810` tests/qtest: intel-hda-ace: the host gateways move a loopback's PCM — `tests/qtest/intel-hda-ace-test.c` |
| author | `Tasker <tasker@localhost>`, as every commit of that tree; given on the command line (`git -c user.name=… -c user.email=… commit`) because that tree has no identity configured — no git configuration was changed |
| `patches/` | `./export-patches.sh`: 20 files. `0019` sha256 `5e52db4f9508ab40a33cf5704276ee246badf40554334f5e1aa9146aa2c6fe14`; `0020` sha256 `85b8eed4a5d549ec72a90f83440ea7daca11b2bc60f7dbee4952fb4f7730495c`; the 20 concatenated sha256 `76ea3ad5a7cf4f2a9fffa389fc85793fb3667e97dafa3a4880758681a7d7f76e` |
| `0001`–`0018` | re-exported: each differs from the p3c2 export in one line, `Subject: [PATCH n/20]` for `n/18` (checked: 2 changed lines per file, 0 outside the Subject) |
| build | `./build.sh` from the series: 20 patches applied, rc = 0, 16 s, 4 jobs, no extra configure options, `build/TIME.txt` 2026-11-25T17:36:27Z |
| host | a 4-vCPU Linux VM, 4 jobs |

## The binary

| file | sha256 |
|---|---|
| `build/qemu-system-x86_64` | `a894197dc0b040dd3d5a94d163e70dc631168e1d820b7a9468c2ecb83919e8bc` |
| `build/tests/qtest/intel-hda-ace-test` | `f335e5907c4f9f695e8e4de4f0350d95ef82325e5af63835a6f83ed513b94825` |

The binary of record is the one `qtest.txt` ran on.  The mutation harness builds every mutant into
`build/`; after its last run `./build.sh` was run again from the series (17:43Z) and both hashes are
the same — the build is reproducible and no mutant is left in the tree.

## The runs (all on the build VM, UTC)

| when | what | command | result |
|---|---|---|---|
| 17:36:46–17:36:54 | the qtest of the series | `cd build && QTEST_QEMU_BINARY=./qemu-system-x86_64 ./tests/qtest/intel-hda-ace-test` | rc 0, **15/15** (`qtest.txt`, `qtest-full.txt.gz`) |
| after it | the boot path | `boot-path-check.sh exact` (14 cases against 5680026's transcript), `sub` (cases 1–9 against the 1137-line baseline) | 2365/2365 identical; 1137: 0 gone, 16 added — the C1 reply lines (`boot-path-diff.txt`) |
| 17:31:15–17:34:01 | mutation rows, trial 1 | `ONLY=^gw- bash mutation-check.sh` | 4 killed, `gw-interrupts` NOT APPLIED (its sed held the harness's `\|`) — `mutation-run-gw-1.txt` |
| 17:34:31–17:35:47 | mutation rows, trial 2 | `ONLY='^gw-(forwarding\|interrupts)$'` | 2 killed (`mutation-run-gw-2.txt`) |
| 17:42 | the affected rows | `ONLY='^ppl-missing$'`, `ONLY='^ppl-exists$'`; then `audio-loopback` alone on each mutant | both killed at p3c1's first red case; the new case alone goes red on the module table's 9 and 10 (`mutation-run-ppl-*.txt`) |
| 17:40–17:41 | the affected-row analysis | `affected-rows.sh bfc7b18a6 46998f810` | 50 old rows apply, 2 affected; the 5 new rows in hunks (`affected-rows.txt`) |

Development runs before the series was committed (working-tree builds with `ninja -C build`): the
fourteen old cases 14/14 after the model change, then 15/15 after the new case; the same two
boot-path comparisons with the same result.

## What was read

- **The LiberNT repository** (`<home>/Projects/LiberNT`, `feat/audio-control-polish` at
  `d5e2a039be682e99643e2caa52cc978c72d3c766`), through git only, to be sure the model parses what the
  driver sends: `sdk/lib/drivers/audio/softplg/ipc4model.c` (`SoftplgModelConfig`: the 21 words —
  words 0–9 the base configuration, 10–15 the output format of pin 0, 16 the feature mask, 17 the
  node id `type << 8 | (tag − 1)` or the placeholder `0xff`, 18 the DMA buffer size, 19 the length 1,
  20 the attributes), `ipc4model.h` (the word indices, the node constants), and
  `drivers/wdm/audio/hdaudbus/hda_registers.h` (`HDA_REG_VS_SDXDPIB_XBASE` 0x1084, `_XINTERVAL`
  0x20). Commands: `git rev-parse`, `git cat-file`, `git ls-tree`, `git show`, `git grep`.
  **One caveat:** to describe the repository's state for this file I ran `git status --short` and
  `git stash list` there at 17:46:33Z. `git status` refreshed the repository's `.git/index` (its
  mtime moved to that second) — a write of the stat cache, the one write of any kind this round made
  under that repository. Read back with plumbing that writes nothing: nothing staged, nothing
  unstaged; the one untracked file is `submodules/host-tests/ke/__pycache__/…pyc`, not this round's;
  two stashes (`storport-halfduplex-fix`, `ke-initialstack-check`) are other work. No file of the
  tree, no ref and no stash was changed.
- **Linux headers on the build host** (the build host's kernel headers' copies), for the citations in
  `intel-hda-ace-regs.h` only: `include/sound/sof/ipc4/header.h` (the module-message types and the
  extension fields: size 15:0, pipeline 23:16, core 27:24, domain 28; the bind's destination module
  and queues; the large-config block flags, parameter id and size) and `include/sound/hda_register.h`
  (`AZX_REG_VS_SDXDPIB_XBASE` 0x1084, 0x20).
- **The plan**: `p3-plan.md` §5.5–§5.10, §7.1, §8 C3, Appendix C.
- **Earlier evidence**: `evidence/2026-11-25-p3c1/{MODEL-NOTES.md, mutation-check.md,
  boot-path-diff.txt, qtest-old-0001-0010.txt.gz}`, `evidence/2026-11-25-p3c2/qtest-before-vm.txt.gz`.

## Not done

- No VM run and no driver round: whether the model's answers are silicon's is for C6, and whether
  the driver sends what the model parses is for the driver half (`DIVERGENCE.md`).
- No full 55-row mutation run (the brief's scope: the new and the affected rows; the full run is
  before C6).
- `README.md` was not updated: its acceptance and model-values sections describe VM rounds; the
  model values of this round are in `MODEL-NOTES.md` here.
- `tools/loopback-check.sh` (Appendix A's C3 entry) was not written.
- The model-hardening audit of other guest-controlled offsets was not started (deferred to the
  end-of-P3 review by the brief).
- Model values no test reaches (`MODEL-NOTES.md`): rows 26, 27, 29 (odd bytes), 31, 35, 41 (a
  smaller SPIB), 44, and row 40's reset clause.

---

# Provenance — the p3c3 VM half (P3 C3, the micro simulator round, 2026-11-25)

Written by the simulator side (Tasker). The VM half of C3: the loopback self-test (`SelfTest = 2`) of the
driver's image p3c3 against the model of this round, T1, and the boot regression. The LiberNT tree was read
through git only (`git cat-file`, `git rev-parse`, `git ls-tree`, `git show`, `git grep` at `dc8c4a75be7`
and `c595e373b3a`; no `git status`, no checkout) to classify the two findings of `DIVERGENCE.md` (D1, D2);
nothing in it was edited.

Scope: the owner's ruling — a micro round: 3–4 VM boots, no fault matrix, no cycle run.

## Image under test

`~/libernt-build-logs/test-audio-intel-sst-p3c3-d8f3a5bc81e/` — `feat/audio-control-polish` at
`c595e373b3ab0021227a806c1c228ebb97d20a20` (91 commits over master `d8f3a5bc81e5f409ad90c725a503fdaa91b672db`),
built in `output-Clang-amd64-debug` with `BOOTLOADER_WIM_RAMDISK` off (the file-based boot medium).
`MEGAN-NOTE.txt`: before the push the messages of three older commits were reworded; the published tip
`dc8c4a75be7` has the identical tree (`git rev-parse <commit>^{tree}` gives `30e6b843e60c…` for both; read in
the tree). Verified with `sha256sum -c SHA256SUMS` (three of three OK):

| file | bytes | sha256 | check |
|---|---|---|---|
| `LiberNT.iso` | 643721216 | `4134a83dfc49313a86bc7b520c73aeb05cea378650edff8fbb069241c6401208` | OK |
| `LiberNT.vhd` (dynamic, 80 GiB virtual) | 797278208 | `07cd865f19305a9d361f2f5167216d30210a08b5254311f3457138a692db13ee` | OK |
| `LiberNT.img` | 1610612736 | `4e2c820a1e6ba5463212ca6ec0da6bcd15b6a949ca3235326c5797f1ead0079c` | OK |

Extracted from the ISO independently of the image directory's own gates (`bsdtar -xf LiberNT.iso` into
`/tmp`, hashed there) — equal to `PROVENANCE.txt` and `gates/in-iso.txt` of the image directory:

| file in the ISO | bytes | sha256 |
|---|---|---|
| `Windows/system32/drivers/intcdsp.sys` | 315392 | `4df4d43b23da6b886f033ab804efbca0fb0c0b8e2fa0c56a5cbb987ed34f93cd` |
| `Windows/system32/drivers/hdaudbus.sys` | 262144 | `9d0af5977e5c1a7a0c250dbdeb6375518fb591ffecd190d0de000e98afa68d3d` |
| `Windows/system32/drivers/intel/sof-tplg/sof-ipc4-loopback.tplg` | 4286 | `0e002de8d92e94f9f961a94a72654750f42d21afbdea09a2f6f6ee7196965601` (p3c2's) |
| `Windows/system32/drivers/intel/sof/sof-arl-s.ri` | 1158164 | `f37a055cefef26bbe14906ec6cd5fe5532c2a4419de87612d8b45b45dc647c6e` (p3c2's) |
| `Windows/inf/intcdsp.inf` | 6368 | `32f3d6a106723fb3e5ef44e9129ba569804d0c39cf6a40735480c97f4b60ded5` |

The image identifies itself in the guest: the console's banner `LiberNT [Version 0.4.17-amd64-dev
20261125-c595e37]` (`vm/r1-firstboot-t1-selftest/s7-console-after-selftest.png`), the desktop's watermark
`feat/audio-control-polish.c595e37.amd64.clang.2420-251126` (`s1-after-wizard.png`) — both name the build
tip. TESTING.md of the image names the stream tags `<t1>`/`<t2>` as whatever the bus gave: both were 1 (the
render an output stream, the capture an input one; the model's output 0 and input 0).

## Model

- qemu-ace-dsp `main` at `264656a` (the history note after the rewrite of 2026-11-25; the series itself is
  `5aea8ea`, the model half): patches 0001–0020 on QEMU 11.1.3, `build/applied-patches.txt` 20 commits,
  `src/qemu-11.1.3` clean at `v11.1.3-20-g46998f810`.
- The binary of record, rebuilt from the series by the model half (`build/TIME.txt`: `patches=20 rc=0 …
  2026-11-25T17:43:56Z`): `build/qemu-system-x86_64` sha256
  `a894197dc0b040dd3d5a94d163e70dc631168e1d820b7a9468c2ecb83919e8bc`,
  `build/tests/qtest/intel-hda-ace-test` sha256
  `f335e5907c4f9f695e8e4de4f0350d95ef82325e5af63835a6f83ed513b94825` — the model half's two hashes; no
  rebuild was needed before the VM runs.
- qtest before the first VM run: **15/15**, rc=0, 2026-11-25T20:46:57Z–20:47:05Z (`vm/qtest-before-vm.txt.gz`,
  2755 lines); the transcript differs from the model half's `qtest-full.txt.gz` in the random seed, the
  socket path and three `slow test … executed in N secs` lines only.
- Every VM run: q35, TCG, `-smp 1`, `ICOUNT=1` (`-icount shift=auto,align=off,sleep=off`,
  `tcg,thread=single`), `CDROM=none` (the installed system boots from the disk overlay), `TRACE=1`,
  `QTESTSOCK=1`, one VM at a time, live logs on tmpfs (`/tmp/qad-ev/p3c3/…`) copied into this tree
  afterwards (`qemu-dbg.log` gzipped per VM). `qemu-args.txt` and `command.txt` hold each VM's command line.
- Host: a 4-vCPU Linux VM (the model half's build host), otherwise idle (load average 0.01 before the
  first boot).

## The VM boots (UTC)

| VM | evidence dir | wall | how it ended | what it measured |
|---|---|---|---|---|
| 1 | `vm/r1-firstboot-t1-selftest` | 1291 s, 20:50:30–21:12:01Z | clean S5 (`shutdown -s -t 0` in the console), rc=0 | the fresh overlay's first boot (stage 1, `BootDsp = 0`); `BootDsp=1` and `Topology` set in the console; **run 1 (T1)** at cycle `t1-1`; `SelfTest=2` set; **run 2** at cycle `selftest-1` |
| 2 | `vm/r2-selftest-plainboot` | 900 s, 21:12:34–21:27:34Z | **by the wall-clock cap** (`WAIT=900`; E9), rc=0 | run 2 at a plain boot (`SelfTest = 2` persisted); two cycles: the first stopped on the self-test's first line but was read at a mistyped BAR0 address (nothing learned; the self-test itself ran), the second is **the live capture of D2** |
| 3 | `vm/r3-selftest0-set` | 324 s, 21:28:53–21:34:17Z | clean S5 (the monitor's `system_powerdown`: the ACPI power button), rc=0 | run 2 at a plain boot again; the console's layout mishap (E10): the registry command did not land |
| 4 | `vm/r4-regression-selftest0` | 296 s, 21:35:02–21:39:58Z | clean S5 (`system_powerdown`), rc=0 | run 2 at a plain boot; `SelfTest=0` set and read back; **run 3** at cycle `selftest0-1` |

Eight DSP boots (`boot ok … attempt 1, 0 DSP interrupts, cleanup ok` on 8 of 8), six runs of the self-test
(all in its first run, all `failed (0xc00000b5)`), 9 settings lines for 9 device starts, 0 `clock stalled`,
0 `interrupt storm`, 0 `Work queue`, 0 bugcheck, 0 `Fatal System Error`, 0 `ace_unexpected` in the four
traces; `ace_*` lines 571 / 1179 / 398 / 544.

## Overlays and registry

- `disk/p3c3.qcow2`: a fresh qcow2 overlay over the p3c3 `LiberNT.vhd` (`make-overlay.sh`, backing format
  vpc). VM 1 is its first boot. Not committed.
- Under `HKLM\SYSTEM\CurrentControlSet\Services\intcdsp\Settings`, set in the guest's console with
  `reg add … /f` and read back with `reg query`: VM 1 — `BootDsp` REG_DWORD 1, `Topology` REG_SZ
  `sof-ipc4-loopback.tplg` (`s5-reg-query.png`: `BootDsp 0x1, SelfTest 0x0, UseInterrupts 0x0,
  IpcTimeoutMs 0x1f4, Topology sof-ipc4-loopback.tplg`), then `SelfTest` REG_DWORD 2 (`s6-selftest-set.png`);
  VM 4 — `SelfTest` REG_DWORD 0 (`s3-selftest0-query-zoom.png`). D0 re-entered with `tools/cycle.sh`
  (`pnputil /disable-device` / `/enable-device` of
  `CSAUDIO\ADSP&CTLR_VEN_8086&CTLR_DEV_7F50\4&aeefd634&0&1000000000`).
- The console is the Start menu's `Command Prompt` entry; the wizard (at the first boot, and `Finish Setup`
  when it was opened by mistake) closes with `tab tab ret`, `ret`, `tab tab tab ret` (E10, E14 in
  `DIVERGENCE.md`).

## Layout of the VM half's evidence (`vm/`)

| run | what |
|---|---|
| `qtest-before-vm.txt.gz` | the qtest before the first VM run: 15/15, with the `ace_*` trace |
| `measured-lines.txt` | the driver's lines of the four VMs in one file: settings, `boot ok`, topology, self-test, power-down, S5 |
| `tools-used/` | the two throwaway scripts of the round, for the record: `streamregs.py` (a read-only qtest dump of the stream descriptors, the lists and the memory) and `livecapture.sh` (a cycle that stops the VM on the self-test's first line) |
| `r1-firstboot-t1-selftest` | **runs 1 and 2**: `s1`–`s7` screenshots (wizard closed, Start menu, `reg query`, console); `cycles.log` (cycle `t1-1` = run 1, cycle `selftest-1` = run 2, with the model's registers); `selftest-lines.txt` (run 2's serial block); `selftest-trace.txt` (run 2's decoded trace: the 15 requests, the gateway, the 30 `ace_audio` lines); `ace-audio-lines.txt`; `streamregs-after-selftest-1.txt` (the descriptors after the driver reset them: `cbl 16384`, `lvi 3`) |
| `r2-selftest-plainboot` | run 2 at a plain boot and at two cycles; `livecapture-selftest-cycle2.txt` = **the live dump of D2** (descriptors, lists, memory), `.log` its timing; `s5-console-zoom.png` |
| `r3-selftest0-set` | run 2 at a plain boot; the layout mishap (`s4-selftest0-query-zoom.png`); the S5 by the power button |
| `r4-regression-selftest0` | **run 3**: `SelfTest=0` read back (`s3-selftest0-query-zoom.png`), cycle `selftest0-1` (`cycles.log`), no self-test line, the S5 by the power button |
| in every run dir | `serial.log`, `qemu-dbg.log.gz` (the whole trace), `ace-trace.txt` (the decoded lines), `driver-lines.txt`, `lib-run.out`, `command.txt`, `qemu-args.txt`, `start.txt`, `end.txt`, `contents.txt` |

Serial lines end in CR LF in the logs; they are quoted without the tail.

## Not done in the VM half

- Nothing was tuned or fixed: the two findings (D1, D2) are the driver's.
- Not run: the self-test's compare and its 24- and 32-bit runs (its first run failed each time; the stop
  rule); the system boot with `SelfTest = 0` (E11); `UseInterrupts = 1` with the self-test (TESTING.md's
  run 4, not a gate); TESTING.md (c)'s refusal rows; the fault matrix; silicon.
- Not read: the bus's stream-period interrupt path was read in the source only as far as D1's
  classification needed; no count of the periods it signalled exists.
