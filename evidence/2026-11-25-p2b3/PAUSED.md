# PAUSED — 2026-11-25 00:55 (+02:00), host restart requested by the owner

State of the p2b3 rerun (AC3/AC4) at the pause. Written by the simulator side so the
remaining work can be resumed without re-deriving anything.

## Done and in this commit

- **AC3 closed** (`ac3-interactive`, `ac3-boot2-icount`, `ac3-cycles-icount`): plain boot under
  icount `boot ok after 21334 us (clock 17954746 us) … attempt 1, 1 DSP interrupts`; 22/22
  disable/enable cycles `boot ok` (21318–21472 us) with identical model register readings before
  and after each; 0 `clock stalled`; clean S5. Stage 1 unchanged on the p2b3 image.
- **DIVERGENCE.md**: D1 and D2 marked fixed; E1 (environment: the model's timers stand still
  while the guest clock runs on this host — `-icount` is the fix), N1–N3 (expectation
  corrections). No new driver divergence.
- **Task B (AC4), 9 of 20 rows done**, all bounded, all `recovered: boot ok`, all collected
  under `fm-*` (the summary as written by the script is `fault-matrix.md`):

| row | the driver's line (as the script saw it) | booting → line | bounded | recovered |
|---|---|---|---|---|
| none | `boot ok after 21299 us (clock 17881193 us)` | 0.031 s | yes | boot ok |
| halt-rom=43 | `boot ROM error after 73086 us` | 0.062 s | yes (3 power-downs) | boot ok |
| halt-rom=44 | `boot ROM error after 50415 us` | 0.047 s | yes (3) | boot ok |
| halt-fw=51 | `boot ROM error after 261959 us` | 0.266 s | yes (1) | boot ok |
| crash-notification | the script logged the fallback `DSP power down …` line; the driver's real line in `fm-crash-notification/serial.log` is `boot firmware crash after 39018 us … last DSP message 0x1b0a0000\|0x00000000, attempt 1, 1 DSP interrupts, cleanup ok` | 0.047 s | yes (1) | boot ok |
| abi=2 | `boot ABI mismatch after 39025 us` | 0.031 s | yes (1) | boot ok |
| window-read-fail | `boot ABI mismatch after 69180 us` | 0.078 s | yes (1) | boot ok |
| never-power | fallback line logged (the real line is in the row's serial.log: the power-up timeout; read it with `tools/fm-check.sh`) | 0.047 s | yes (0 power-downs: the fault never powers) | boot ok |
| never-ack | fallback line logged (the real line in the row's serial.log) | 1.563 s | yes (3) | boot ok |

  Known script defect behind the three "fallback" rows: the terminal regex of
  `tools/fault-matrix.sh` is `boot (ok|timeout|ROM error|stopped|ABI|version|ipc|.*crashed)`, but the
  driver prints `boot firmware crash` (not `crashed`) and `boot <step> timeout` (`boot power-up
  timeout`, `boot ROM init timeout`, `boot IPC reply timeout` …) — the step name sits between
  `boot` and `timeout`, so neither matches and the row is closed on its `DSP power down` line.
  The verdict (bounded) is right; the line and the elapsed figure are the fallback's. **Pending
  fix**: TERM → `boot (ok|.*timeout|ROM error|stopped|ABI|version|ipc|.*crash)` (the script was
  not edited while it ran). `tools/fm-check.sh` already uses that pattern and re-reads the right
  line from each row's `serial.log`.

- Row in flight when the pause came: **never-ready** — stopped with the VM (monitor-side
  termination); its partial files are in `fm-never-ready-partial/` (not a result).

## To resume (after the machine is back)

1. The binary `build/qemu-system-x86_64` is the `f53ff8b` model (sha256 `84cb786c…`); nothing to
   rebuild. `/tmp` is gone with the restart: the scratch overlays must be copied again from
   `disk/p2b3.qcow2` (the stage-2 overlay: `BootDsp=1` persisted, wizard gone, clean S5).
2. Remaining 11 rows, same command as the first 9 (do **not** reuse `/tmp/qad-fm-p2b3`, it is
   empty after the restart, so the script starts a fresh summary):

   ```sh
   cd /home/megan/Projects/LiberNT-IntelDSP-plan/qemu-ace-dsp
   cp disk/p2b3.qcow2 /tmp/p2b3-fm.qcow2
   export ISO=$HOME/libernt-build-logs/test-audio-intel-sst-p2b3-a19eacb7fea/bootcd.iso DISK=/tmp/p2b3-fm.qcow2 EVROOT=/tmp/qad-fm-p2b3 ICOUNT=1 HEARTBEAT=0 RECOVER=1 WINDOW=30 COLLECT=$PWD/evidence/2026-11-25-p2b3
   tools/fault-matrix.sh FAULT=never-ready never-enter never-fwready never-reply drop-requests ipc-status=5 bad-tuples truncated-reply version-shift scale:1550 scale:0.001
   ```

   then append the new rows' lines to `evidence/2026-11-25-p2b3/fault-matrix.md` (which holds the
   first 9) and run `tools/fm-check.sh evidence/2026-11-25-p2b3` for the checks beyond "bounded"
   (elapsed consistency, bugcheck, hang, recovery). Each row takes ~90–150 s of wall time under
   icount; the 11 rows ≈ 25 min.
3. Then the documentation that was still pending at the pause: README — the "Round 3" paragraph,
   the AC4 row (it still carries the p2b2 text), the "fault matrix in the VM" section (still the
   p2b2 table), `./normalise-evidence.sh`, and the final commit. Board task `33b94861` stays open
   until the report is in.
4. Task C (unpowered `HFINTIPPTR` read = all-ones, qtest case, mutation row) was **not started**.
