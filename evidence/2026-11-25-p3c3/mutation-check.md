# Mutation check of the p3c3 round — the new rows and the affected rows (2026-11-25)

Model `46998f810` (src master: `5a90cf7b7` the host gateways, `46998f810` their qtest; series 0001–0020,
`patches/`); the harness `mutation-check.sh`, a clean run is **15** cases (14 + `audio-loopback`).
Scope, per the brief: rows for the new behaviour only — the new rows and the existing rows the patches
affected — no full 55-row run (that runs before C6).  **Result: 2 affected rows, both still killed; 5
new rows, all killed; 0 survivors.**

## The affected rows: 2 of the 50

Question: does a row of the 50 existing ones (`mutation-check.md` of p3c1) now mutate something else,
or nothing at all, because patches 0019/0020 moved or extended its target?

Method (`affected-rows.sh` beside this file; its table is `affected-rows.txt`): for every row, its sed
expression is applied to the file at `bfc7b18a6` (the model of `5680026`) and to the file on
`46998f810`; a row is affected when the expression changes nothing on the new file (NOT APPLIED) or
when one of the lines it changes lies inside a hunk of the two patches.

Result: **50 of 50 still apply; 48 change only lines outside every hunk; 2 are affected**:

| row | its expression | why affected now |
|---|---|---|
| `ppl-exists` | `s/return ACE_IPC4_RESOURCE_ID_EXISTS;/return ACE_IPC4_SUCCESS;/` (unanchored) | changes two lines: 956 (the pipeline table, as before) **and 1146, the module table's init-instance of an instance that exists** — the same status, now answered in two places |
| `ppl-missing` | `s/return ACE_IPC4_INVALID_RESOURCE_ID;/return ACE_IPC4_SUCCESS;/` (unanchored) | changes five lines: 983, 1006 (the pipeline table, as before) **and 1186, 1216, 1231, the module table's bind / large-config-set / delete of an instance that does not exist** |

Re-run (`ONLY=` each; 17:42Z), with their new half exercised alone through the new case:

| row | qtest result (full run) | red case | `audio-loopback` alone on the same mutant |
|---|---|---|---|
| ppl-exists | KILLED | pipeline-table (test line 921), `ipc(0, PPL_REQ(IPC4_CREATE_PIPELINE, 1)) == PPL_REPLY(IPC4_CREATE_PIPELINE, 10)`: (2969567232 == 2969567242) — the run aborted there: cases 11-15 not evaluated | not ok (test line 1411): `ipc(MOD_EXT(1, 10), MOD_REQ(IPC4_MOD_INIT, 5, 0)) == MOD_REPLY(IPC4_MOD_INIT, 10)`: (3758096384 == 3758096394) |
| ppl-missing | KILLED | pipeline-table (test line 914), `ipc(0, PPL_STATE(1, PPL_PAUSED)) == PPL_REPLY(IPC4_SET_PIPELINE_STATE, 9)`: (3003121664 == 3003121673) — the run aborted there: cases 11-15 not evaluated | not ok (test line 1412): `ipc(BIND_EXT(9, 9), MOD_REQ(IPC4_MOD_BIND, 5, 0)) == MOD_REPLY(IPC4_MOD_BIND, 9)`: (3841982464 == 3841982473) |

Both verdicts are p3c1's (same first red case, same assertion; the test lines moved 871 → 921 and
864 → 914 with the new case's macros and helpers), and the module table's 10 and 9 are detected by
the new case when it is the only one that runs — so neither row has become a weaker detector by
covering two tables.  The rows were left as they are (their "what it breaks" text still says exactly
what they break); a separate module-table row is not needed while these two reach it.

A first reading of this section said "none affected": the hit test of the first draft of
`affected-rows.sh` never matched (`diff` printed a literal `\n` for each line number, and a hunk
without a count was taken for zero lines).  The check was written to be read against its own
expectation — the five new rows must land in a hunk — which is how the fault showed; the corrected
script is the one beside this file, and its table lists the lines.

## The new rows (5): all killed

The brief's four, with "position" in two rows — the position itself (LPIB, what the DMA moved) and
its mirror (the position-buffer entry, which the extended register mirrors) — because the brief
names both as things to add.

| # | mutation | what it breaks | qtest result | red cases |
|---|---|---|---|---|
| 1 | gw-forwarding | the forwarding removed: the render stream is drained and its position moves, nothing is written into the capture stream | KILLED | audio-loopback (test line 1269) check_position: assertion failed (r0(HDA_ST_LPIB(n)) == want): (0 == 2048) — the render's position passed, the capture's did not |
| 2 | gw-tag-mapping | the gateway's node index taken for the stream tag itself (the plan's tag minus one gone) | KILLED | audio-loopback (test line 1269) check_position: assertion failed (r0(HDA_ST_LPIB(n)) == want): (0 == 2048) |
| 3 | gw-position | the positions never advance: LPIB, the position buffer and the extended register stay at 0 while the bytes move | KILLED | audio-loopback (test line 1269) check_position: assertion failed (r0(HDA_ST_LPIB(n)) == want): (0 == 2048) |
| 4 | gw-position-mirror | the position buffer's entries never written after a period (LPIB and the extended register still move) | KILLED | audio-loopback (test line 1271) check_position: assertion failed (posbuf == want): (0 == 2048) |
| 5 | gw-interrupts | the streams' completion bits never set: no period interrupt on either stream | KILLED | audio-loopback (test line 1315) check_loop_irq: assertion failed (got == asserted ? (1u << OUT5) / (1u << IN0) / (1u << 31) : 0): (0 == 2147483681) |

5 mutations: 5 killed (0 of them by an abort), **0 survived**, 0 not applied, 0 build failures.

What each red case says about the detector: the forwarding and the tag rows fall on the position
check, not on the byte compare, because the test checks the positions before the bytes; the mirror
row alone reaches the third assertion of `check_position` (the position buffer), so LPIB and the
extended register moved; the interrupt row is the only one that reaches `check_loop_irq`.  Not shown
by any row: a mutant that keeps the positions and corrupts the bytes (that would be the byte-exact
`check_capture`'s to catch; no such mutation is among the rows).

## The trials, as they happened

- Run 1 (`ONLY=^gw-`, 17:31:15Z–17:34:01Z, 170 s): rows 2, 3, 4 as above, killed; **`gw-interrupts`
  NOT APPLIED** — its sed expression held a `|` (`->ctl |= …`), the row format's own separator, so
  the harness cut the expression (`sed: unterminated 's' command`).  Rewritten with `.` for that one
  character, as the harness's rule asks.  `gw-forwarding` in that run removed the whole period
  (`ace_gateway_copy(s, g, bytes);` gone) and was killed at the render's position — the same red as
  the position row, i.e. not discriminating the *forwarding*; redefined to the capture never being
  written while the render moves.
- Run 2 (`ONLY=^gw-(forwarding\|interrupts)$`, 17:34:31Z–17:35:47Z, 80 s): both killed, as in the
  table.
- Run 3 and 4 (`ONLY=^ppl-missing$`, `ONLY=^ppl-exists$`, 17:42Z): the affected rows above.

The harness builds each mutant into `build/`.  After the last run `./build.sh` was run again from the
series: the binary is byte-identical to the one `qtest.txt` records (`a894197d…`, `f335e590…`), so no
mutant is left in the tree.
