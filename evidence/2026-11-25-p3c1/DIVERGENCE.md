# DIVERGENCE — the p3c1 round (P3 C1, the model half, 2026-11-25)

The model side of checkpoint C1: the pipeline table and the two typed faults, then (the same
day) the follow-up fixes. **No VM run was made in this round** — the C1 image does not exist yet
(the driver half, with its `SelfTest=1` path, is being written in another conversation), so **no
driver divergence could be observed**. Everything below is a plan-side finding, a pre-existing
item noticed while working, or a tooling fix.

**Amended in the follow-up** (Megan's go of 2026-11-25 07:40Z, after she had verified and pushed
the first delivery as `main` 4bb8022): P1, P2 and P3 ruled; **N1 and N3 fixed, N2 documented**;
and one finding the follow-up made on its own — **a guest could crash the emulator** — fixed.

**Amended again — the VM half** (the C1 simulator round, same day: image p3c1 against the model of `9713aa0`, the
first run of the driver's `SelfTest = 1` path). Its divergences are in `vm/DIVERGENCE.md`: **D4** (the
power-down line names the state *after* the power-down — always `off` — where TESTING.md expects `ready`),
**N9** (the settings line is printed twice per start), what the VM can and cannot show of N5 and N6, the
transport against the model's stale reply bits, and E5–E7. "No VM run was made in this round" above refers to
the model half; its text is unchanged.

## The finding of the follow-up: a guest could crash the emulator (fixed)

| | |
|---|---|
| **What** | The bounds of a read of the streamed firmware image were checked with an addition, `off + 4 > payload_len`, in 32-bit arithmetic. The offsets are the image's own — the `ADSP.man` entry's offset in the partition directory, a module segment's file offset — and the image is what the guest streams. An offset just under 2^32 passed the check (the sum wrapped), and the model read four gigabytes past the stream. |
| **Proof** | With the offset field of the qtest image set to `0xfffffffe`, the emulator of `main` 4bb8022 died: `kill_qemu() detected QEMU death from signal 11 (Segmentation fault)`, `coredumpctl`: `Signal: 11 (SEGV) si_code: SEGV_MAPERR`; the faulting frame `ace_rom_judge` at `intel-hda-ace.c:656` (`n1-payload-reads.md`, section 3). |
| **Reach** | Any guest that can make the driver stream a crafted file — a corrupted or hostile firmware image is enough. A host-process crash (denial of service), not an escape: the read is outside the stream buffer, and nothing is written. The model with the flaw is public since Megan's push of `4bb8022` (07:39Z of 2026-11-25) until the follow-up is pushed. |
| **Fix** | Patches 0017 (model) / 0018 (qtest): the bounds of both payload reads are checked without an addition that can wrap; the end of a segment (`file offset + pages × 4 KiB`), which had the same flaw, too. An image with such an offset is refused like any other whose word cannot be read. Mutation rows `payload-bounds-wrap` (the row that makes the emulator die again: killed as an abort) and `segment-end-wrap`. |
| **Scope** | Beyond the wording of N1 ("check the two return values"): found while fixing it, in the same function family. Its own patch, so it can be reverted alone; Megan was told first in the report. |
| **Still true** | The model is a test oracle, not a hardened emulator: other guest-controlled values may hold similar flaws. None is known; none was audited for beyond the ROM's judgement. |

## Plan-side findings (for the plan's owner and the driver half)

| # | Finding | Where | What became of it |
|---|---|---|---|
| P1 | **Notation conflict.** Plan §8 C1's VM acceptance line used `fault=ipc-status=19:17` and expected "`set pipeline state (19) … status 5`". Under the plan's own definition — `ipc-status=<n>:<type>` — that value means *status 19 for create pipeline (17)*. The quoted line needs **`ipc-status=5:19`**. | plan §8 C1, "VM acceptance (serial)" | **Ruled by Megan (P1): the definition stands, the example was wrong.** The driver half uses `ipc-status=5:19` in its TESTING.md; the plan's line is corrected (2026-11-25): `ipc-status=5:19` with the note "(corrected 2026-11-25: the model implements the `<status>:<type>` definition)". The model had implemented the definition from the start (`pipeline-trace.txt` §4) |
| P2 | **The name of status 5.** The plan writes "status 5 (invalid resource state)". SOF's `src/include/ipc4/error_status.h` (BSD-3; `v2.12.1` and `main`, read 2026-11-25) names 5 `IPC4_BAD_STATE` and 12 `IPC4_INVALID_RESOURCE_STATE`. | plan §5.5, §8 C1 | **Ruled by Megan (P2): agreed.** The driver half prints `BAD_STATE` per SOF's header, never "invalid resource state" for 5. The model answers the plan's number 5; the real code is INFO_NEEDED for C6 (`MODEL-NOTES.md`, item 1). The plan's text still says "invalid resource state" in its §8 C1 rows (lines 529 and 532): not changed — the correction was not asked for |
| P3 | The plan gives **one rule** of the pipeline state machine (paused before running) and no status for: a duplicate create, a set-state/delete of an unknown pipeline, the id 0, an id past the limit, a state the ABI does not have, the multi-pipeline form. The model had to answer all of them; each answer is a model value from the ABI's error list. | plan §5.5 | **Recorded for C6 (Megan, P3):** `MODEL-NOTES.md`, rows 3–11 |

## Noticed while working — and what became of each

| # | Item | What became of it |
|---|---|---|
| N1 | `ace_rom_judge()` in `intel-hda-ace.c` read words of the streamed image without looking at the result of the read. Named first for the two gcc warns about (a module segment's flags and file offset); reading the whole function found four more of the same kind (the directory's entry count, the `ADSP.man` entry's offset, the manifest's vendor and magic). On a stream that ended inside one of those structures the word kept whatever the stack held: **a stream of 0x2084 bytes was accepted as a firmware and entered** (`FSR 5`, ROM error 0); gcc warned on every build. The real firmware's boots passed the rule in every VM trace of the earlier rounds (`ROM rule module segments: 1`) — inferred from those traces, not from a test of a truncated table. | **Fixed (Megan's go): patches 0015/0016.** Every read goes through `ace_judge_u32()`, which refuses the image with the walk halted in the state and with the code of the structure being read. qtest case `short-stream` (six cuts); mutation rows `judge-count-code`, `judge-entry-offset-code`, `judge-segment-code`, `judge-segment-inverted`. On this build the two cuts where a word of the stack decided (4, 32) reached the expected verdict by accident on the old model — the fixed model is distinguished by the cuts at 0x2084 and 0x2088 and by the code rows (`n1-payload-reads.md`). The gcc warnings are gone. The codes are model values (`MODEL-NOTES.md`, rows 17–22) |
| N2 | After the host acknowledges a reply or a notification, the register keeps the previous message's bits with DONE/BUSY cleared (`HFIPCXIDA` reads `0x61000000` after the FW_CONFIG ack). Existing behaviour; the old tests mask the bit; my first draft of the new tests asserted `== 0` and failed on it. A host that compares the whole register after an ack would misread a stale reply. | **Left as it is (Megan's ruling): the driver's receive path masks DONE.** Documented as a model value for C6 (`MODEL-NOTES.md`, row 16; INFO_NEEDED 8) |
| N3 | `normalise-evidence.sh` exited 1 without its summary line whenever no file under `evidence/` contained a host path — in fact whenever no file was *left*, including right after it had normalised one: under `set -euo pipefail` the leftover count (`grep … \| wc -l`) inherited grep's "no match" status and `set -e` ended the script. | **Fixed (Megan's go): commit 77da21b.** Before: exit 1, no line, in both cases; after: `normalised 0 files; remaining: 0` / `normalised 1 files; remaining: 0`, exit 0 |

## Tooling fixed in this round

- `mutation-check.sh`'s detector read "no `not ok` line" as a survivor. A run that ended early — a
  timeout, a crash, a truncated transcript — would have been reported **SURVIVED**. The verdict
  now needs a zero exit *and* all M `ok` lines for a survivor; anything else without a `not ok`
  line is `KILLED (aborted)` with its reason. The rule is enforced by `SELFTEST=1`, which feeds
  the detector six synthetic logs (clean, red-early, timeout, crash, truncated, red-but-exit-0)
  and fails on a wrong verdict. The follow-up's `payload-bounds-wrap` row exercises the abort
  branch for real: it makes the emulator die.
- A killed row says how many cases ran ("the run aborted there: cases 11–14 not evaluated"),
  because the qtest stops at its first failed assertion: the cases after it are not evidence for
  that mutation.
- Every table cell is one line of at most 200–240 characters with `|` replaced; the earlier
  tables could be broken by an assertion text containing the table's separator.
- A run's output is kept up to 64 MiB (`head -c`): a mutant that prints without end must not
  fill the disk — the lesson of an earlier mutation run of mine on the LiberNT side (per my own
  notes of it: its log grew to gigabytes in the tmpfs and the script was killed). A run cut by
  the cap counts as an abort.
