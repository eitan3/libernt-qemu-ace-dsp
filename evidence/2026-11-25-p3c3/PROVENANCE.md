# Provenance — the p3c3 model half (P3 C3, the model half, 2026-11-25)

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

## The runs (all on CachyOS, UTC)

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

- **The LiberNT repository** (`/home/megan/Projects/LiberNT`, `feat/audio-control-polish` at
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
- **Linux headers on the build host** (the CachyOS kernel headers' copies), for the citations in
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
