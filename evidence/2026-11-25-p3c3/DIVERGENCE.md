# DIVERGENCE — the p3c3 round (the model half, 2026-11-25)

**No driver–model divergence this round: no VM run was made** (the C3 image is the driver half's).
Nothing here asks the driver to change, and the model was not changed to make anything pass.

Findings on the model side, each fixed inside the round and before the binary of record
(`a894197d…`) was built:

| # | finding | where it showed | what was done |
|---|---|---|---|
| M1 | After a stream was stopped and run again, the **position buffer's entry in guest memory kept its stale value** (2048) while LPIB and the extended register correctly read 0: the entry was written only when a period moved | the new qtest's placeholder sequence, first run: `check_position: (posbuf == want): (2048 == 0)` | a stream now reports its position when it starts running (`ace_stream_report` from the stream-run hook) and after every period; the test's expectation stood | 
| M2 | The placeholder copier printed "stream tag 256" (index 0xff + 1) | the trace | printed as "without a stream (the placeholder index 0xff)" |
| — | *(process)* a mutation row's sed held the harness's own separator `\|` | `gw-interrupts` NOT APPLIED in trial 1 | rewritten with `.` for that character |
| — | *(process)* `gw-forwarding`'s first definition removed the whole period and died on the same assertion as the position row — not a test of the forwarding | trial 1 | redefined: the capture never written while the render moves |
| — | *(process)* the first draft of `affected-rows.sh` reported "none affected" while its hit test could not match | its own sanity check (the five new rows must land in a hunk) | fixed; two existing rows (`ppl-exists`, `ppl-missing`) are affected, re-run and killed |

Open for the driver half (from `MODEL-NOTES.md`, INFO_NEEDED 9–12): the trigger order the firmware
really needs; what the firmware does with a capture stream that is not running; the format
conversion across the pipeline (the model forwards only when both host streams have the same frame
size, so the 16- and 24-bit self-tests should open both streams in the same container); whether the
copier re-configuration at prepare is needed and with which parameter id.
