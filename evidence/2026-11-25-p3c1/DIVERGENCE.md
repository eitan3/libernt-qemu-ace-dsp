# DIVERGENCE — the p3c1 round (P3 C1, the model half, 2026-11-25)

The model side of checkpoint C1: the pipeline table and the two typed faults.
**No VM run was made in this round** — the C1 image does not exist yet (the driver
half, with its `SelfTest=1` path, is being written in another conversation), so
**no driver divergence could be observed**. Everything below is either a
plan-side finding, a pre-existing item noticed while working, or a tooling fix.

## Plan-side findings (for the plan's owner and the driver half)

| # | Finding | Where | What to do |
|---|---|---|---|
| P1 | **Notation conflict.** Plan §8 C1's VM acceptance line uses `fault=ipc-status=19:17` and expects "`set pipeline state (19) … status 5`". Under the plan's own definition — `ipc-status=<n>:<type>` — that value means *status 19 for create pipeline (17)*. The quoted line needs **`ipc-status=5:19`**. | plan §8 C1, "VM acceptance (serial)" | the driver's self-test run uses `ipc-status=5:19`, or the plan's line is corrected. The model implements the definition (verified: qtest case `pipeline-faults`, `evidence/2026-11-25-p3c1/pipeline-trace.txt` §4) |
| P2 | **The name of status 5.** The plan writes "status 5 (invalid resource state)". SOF's `src/include/ipc4/error_status.h` (BSD-3; `v2.12.1` and `main`, read 2026-11-25) names 5 `IPC4_BAD_STATE` and 12 `IPC4_INVALID_RESOURCE_STATE`. | plan §5.5, §8 C1 | nothing for C1: the model answers the plan's number 5. The real code is INFO_NEEDED for C6 (`MODEL-NOTES.md`, item 1). If the driver prints a name for the status, its table should not call 5 "invalid resource state" on silicon's behalf without checking |
| P3 | The plan gives **one rule** of the pipeline state machine (paused before running) and no status for: a duplicate create, a set-state/delete of an unknown pipeline, the id 0, an id past the limit, a state the ABI does not have, the multi-pipeline form. The model had to answer all of them; each answer is a model value from the ABI's error list. | plan §5.5 | listed one by one in `MODEL-NOTES.md` for C6 to replace |

## Noticed while working — pre-existing, not changed here

| # | Item | Why it matters | Suggested owner |
|---|---|---|---|
| N1 | `ace_rom_judge()` in `intel-hda-ace.c` ignores the return value of `ace_payload_u32()` for a module segment's `flags` and file offset, so a segment entry that lies outside the streamed bytes leaves both **uninitialised** (gcc: `'flags' may be used uninitialized`, `'foff' may be used uninitialized`, seen on every build of this file). The real firmware's boots pass this rule in every VM trace of the earlier rounds (`ROM rule module segments: 1`), so the model's verdicts on the real image are not in doubt — that is inferred from those traces, not from a test of a truncated module table; a truncated or hostile image could read stack garbage. | a latent model bug on malformed input; the qtest's "truncated payload" row truncates the *text*, not the table | the model: check the two returns and halt with the ROM's code for a bad module table (one small patch, its own mutation row) |
| N2 | After the host acknowledges a reply or a notification, the register keeps the previous message's bits with DONE/BUSY cleared (`HFIPCXIDA` reads `0x61000000` after the FW_CONFIG ack). Existing behaviour, the old tests mask the bit; my first draft of the new tests asserted `== 0` and failed on it. | a host that compares the whole register after an ack would misread a stale reply. Silicon's behaviour after the acknowledgement is INFO_NEEDED | the model: decide whether to clear the register on acknowledgement (a model-value change with its own evidence) |
| N3 | `normalise-evidence.sh` exits 1 without its summary line whenever **no** file under `evidence/` contains a host path: under `set -euo pipefail` the `grep … \| wc -l` that counts the leftovers inherits grep's "no match" status and `set -e` ends the script. It has only ever printed when something needed normalising. | cosmetic: the normalisation itself is a no-op in that case. The fix is `… | wc -l) || true` on the `left=` line (one token) | the model (this repository); not changed in this round — this round's evidence needed no normalisation (0 files with a host path, checked with `grep -rIl`) |

## Tooling fixed in this round

- `mutation-check.sh`'s detector read "no `not ok` line" as a survivor. A run that
  ended early — a timeout, a crash, a truncated transcript — would have been
  reported **SURVIVED**. The verdict now needs a zero exit *and* all M `ok` lines
  for a survivor; anything else without a `not ok` line is `KILLED (aborted)` with
  its reason. The rule is enforced by `SELFTEST=1`, which feeds the detector six
  synthetic logs (clean, red-early, timeout, crash, truncated, red-but-exit-0) and
  fails on a wrong verdict.
- A killed row now says how many cases ran ("the run aborted there: cases 11–12
  not evaluated"), because the qtest stops at its first failed assertion: the
  cases after it are not evidence for that mutation.
- Every table cell is one line of at most 200–240 characters with `|` replaced;
  the earlier tables could be broken by an assertion text containing the table's
  separator.
