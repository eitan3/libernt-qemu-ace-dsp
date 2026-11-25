# DIVERGENCE — LiberNT `intcdsp.sys` (image p3c1, `feat/audio-control-polish @ 9c9a876c6a3`) against the ACE model: the VM half of C1

Written by the simulator side (qemu-ace-dsp). Nothing in the driver was patched and the LiberNT tree was not
written to: its git objects were read at `9c9a876c6a3` (`git show`, `git grep`) to locate the two lines whose
wording diverges from the image's TESTING.md. Image: `bootcd.iso` sha256 `1e381a4be043…`, `LiberNT.vhd`
`97c09c3acee9…` (verified with `sha256sum -c SHA256SUMS`); `intcdsp.sys` in the ISO = `cc6c1309…` (extracted
with bsdtar and hashed; = `PROVENANCE.txt` of the image dir; built from `5773fcfa7af`, the published tip
`9c9a876c6a3` has the same tree content). Model: qemu-ace-dsp `main` at `9713aa0` (patches 0001–0018, QEMU
11.1.3; binary sha256 `be8667eb…`, rebuilt from the series, qtest 14/14 before the first VM run), q35, TCG,
`-smp 1`, `-icount shift=auto,align=off,sleep=off` on every run, logs on tmpfs.

**Result of this round: the C1 VM acceptance passes.** With `SelfTest = 1` the driver prints the seven lines of
TESTING.md and the plan's §8, every exchange `status 0 after 62–66 us`, the summary `6 requests, 6 replies, 0
notifications, 0 timeouts, 0 DSP interrupts, ok`, and the model's trace holds the six requests in the plan's
words, each answered with its type and status 0 (`c1-acceptance.md`, B). The two self-test fault rows end
bounded with TESTING.md's lines, power the DSP down, leave the device started and recover with `boot ok` and a
passing self-test (C). The unfaulted boot is p2b4's with the N5 mask in its trace and the N6 wording (A); AC3 is
22 of 22 and AC4 20 of 20, the matrix rows' terminal lines identical to p2b4's (D). **One driver-side
divergence, wording only (D4)**, one expectation correction (N9), two notes on what the VM can show of N5 and
N6, one observation on the model's stale reply bits, three environment notes (E5–E7). `tools/fm-check.sh`: 0
rows with a failed check on both matrices.

Classes: **D** driver-side (the image differs from what its TESTING.md or the plan says, for a reason in the
driver's code; reported for the driver's owners, never fixed here) · **N** expectation correction (TESTING.md's
text against what the driver does; no functional effect) · **M** model-side note · **E** environment · **P**
plan-side. Numbers continue the earlier rounds (D1–D3, N1–N8, E1–E4).

## D4 — the power-down line names the state *after* the power-down (driver; wording; no functional effect)

| | |
|---|---|
| **What** | `intcdsp.sys: DSP power down from state off: ok, cleanup ok, ADSPCS 0x00000000 (SPA 0, CPA 0)` on every power-down, where TESTING.md expects `DSP power down from state ready: …` after a failed self-test. The words promise the state the DSP is powered down **from**; the value printed is always `off`. |
| **Where** | `IntcDspPowerDown()` (`drivers/wdm/audio/intcdsp/intcdsp.c:221–236` at `9c9a876c6a3`): `Status = FwloadPowerDown(&Dev->Fw);` runs first and the log line at `:234` then prints `FwloadStateName(Dev->Fw.State)`. `FwloadPowerDown()` (`sdk/lib/drivers/fwload/fwboot.c`) sets `PoweringDown`, calls `FwloadPowerOff()` and leaves the state `off` (the model's trace: `state running -> off`). |
| **Proof** | `selftest-faults/fm-ipc-status=5_19/serial.log`: `boot ok … state ready …` then, after the faulted self-test, `DSP power down from state off: ok, cleanup ok, ADSPCS 0x00000000 (SPA 0, CPA 0)`; the same in `fm-never-reply=19`. p2b4's faulted boots said `from state off` as well, after `state failed, failed in configuring` (`evidence/2026-11-25-p2b4/fm-ipc-status=5`). |
| **Effect** | None on the power-down itself (`ok, cleanup ok, ADSPCS 0`). The line cannot tell which state the DSP was in — on silicon a capture of a failed boot or self-test loses that fact. |
| **Minimal fix (for the driver's owners)** | Take the name before the loader's power-down: `const char *From = FwloadStateName(Dev->Fw.State);` ahead of `FwloadPowerDown()`, and print `From`. |
| **In this round's checks** | `tools/fm-check.sh` verifies the functional content of the line (`ok, cleanup ok, ADSPCS 0x00000000 (SPA 0, CPA 0)`) and shows the state word with its note; `tools/fault-matrix.sh` quotes the line as printed. |

## N9 — the settings line is printed twice per start, not once (expectation)

TESTING.md: "A settings line is printed once at start, beside `BootDsp = …`". The log shows it after
`BootDsp = …` **and again two lines later**, before the `resident` firmware line, at every start:

```
[    7.508047] intcdsp.sys: BootDsp = 1: the DSP is booted at the next D0 entry
[    7.508047] intcdsp.sys: SelfTest = 0, UseInterrupts = 0, IpcTimeoutMs = 500 ms
[    7.508047] intcdsp.sys: SelfTest = 0, UseInterrupts = 0, IpcTimeoutMs = 500 ms
[    7.508047] intcdsp.sys: firmware …: 1158164 bytes, resident, image 'ADSPFW' …
```

(`a2-stage2-boot`; 46 `SelfTest = 0` lines for the 23 starts of `ac3-cycles`, 4 `SelfTest = 1` lines for the
2 starts of `b1-selftest`.) The cause is in the driver: `IntcDspReadIpcSettings()` logs at its end
(`intcdsp.c:80`) and is called from both `IntcDspEvtDevicePrepareHardware` (`:502`) and
`IntcDspEvtDeviceD0Entry` (`:545`) — "the three values are read again at every D0 entry, as `BootDsp` is", and
each read logs. `BootDsp = …` itself is logged once (in `PrepareHardware` only). No effect on the self-test or
on "exactly these seven lines". Either TESTING.md's sentence becomes "printed at every read of the settings:
twice per start, and once more at each later D0 entry of the same device object (an S3 resume)", or the line
moves to the `PrepareHardware` call. The driver's owners choose; not changed here.

## N5 and N6 in the VM — what is shown, and what cannot be

- **N5 (p2b4: the `INTEN` mask was skipped where the pointer names no register; the driver repeats it at ROM
  ready since `f24c0184e5d`).** Shown: the mask is where TESTING.md says. `a2-stage2-boot`'s trace has, right
  after `state purging -> rom-ready`, the read of `HFINTIPPTR` (`0x120`), a read, a write of 0 and a read-back of
  `+0x120`, `HfHIPCIE` and `HFIPCXCTL` masked again, and then the `ROM ready for the firmware` reads — the only
  write to `+0x120` of that boot; p2b4's trace has none. The serial line reads `INTEN 0x00000000` from `ROM
  ready` on. **Not shown: that the mask changes anything.** On the model `INTEN` resets to 0 and nothing writes
  it before the mask (no BIOS; the driver masks while the pointer names no register), so it reads 0 before and
  after. The fix is verified as present, not as necessary — the silicon question of p2b4's N5 (does `HFINTIPPTR`
  also read all ones right after the subsystem's CPA; would a BIOS-left `INTEN` stay set) stays open.
- **N6 (p2b4: the firmware line could not say whether the bytes were read or resident).** As TESTING.md
  predicts: every D0 entry that boots the DSP prints `read` (the `PrepareHardware` of a new device object) and
  then `resident` (the boot's call on the same object) — 72 pairs over this round's boots, and one `read` alone
  at stage 1 where nothing boots; the old `bytes, ok` is gone. **The VM cannot show `resident` alone**, R6's own case (the same device object entering D0 again
  after an S3): a disable/enable makes a new object, and this VM does no S3.

## The model's stale reply bits (N2 of the model half): the transport is not disturbed

After an acknowledgement the model's reply register keeps the message's bits with the done bit cleared
(`../MODEL-NOTES.md`, row 16, a model value). The driver's transport reads `HFIPCXIDA` and `HFIPCXTDR` on every
poll and so sees them constantly: `0x31000000`/`0x33000000` (the acknowledged create and set-state replies) and
`0x1b080000` (the acknowledged FW_READY notification) — three times per exchange, 1049 times in the timed-out
one — and never takes them for a reply or a notification: it looks at the done bit alone. The D0 reading after
a self-test therefore differs from p2b4's in `hfipcxida` alone (`0x32000000`: the delete-pipeline reply's bits;
p2b4's `0x61000000` is the FW_CONFIG reply's). No action; recorded so that the silicon question (does the real
register clear on the acknowledgement) stays with the model half's row 16.

## Environment notes (not driver divergences)

- **E5 — `after N us` is TCG execution time, and it differs from p2b4's by a factor of four.** This round's idle
  cycles measure `boot ok after 5366–5737 us` where p2b4's measured 21406–21726 µs, with the model unchanged:
  `-icount shift=auto` calibrates a shift at every launch, and the loader's byte-by-byte copy of the 1.15 MB
  payload is priced by it. Within one launch a boot-time boot takes up to twice an idle cycle's (AC3's own boot
  10415 µs against its cycles' 5366; this round's boot-time boots range 5365–10546 µs), and AC3's boot-time boot
  shows end clock − start clock − N = 1289 µs where its 22 cycles show 80–82 µs: the end clock is read when the
  line is formatted, and on that boot 1.2 ms more of the guest's time passed there. No budget is near (the
  smallest is 50 ms). The self-test's exchanges are **62–66 µs in every launch**: they are timed by the model's
  50 µs timer and the driver's 20 µs stall, both virtual time, not by instruction counts — the one figure of
  this round that can be carried to the hardware stage as a shape (three polls without a reply, the reply on
  the fourth).
- **E6 — the first-boot wizard's third page** lists 11 components, "about 5340 MB" (p2b4's image: 3.3 GB). The
  image's component feed differs; unrelated to the driver. The wizard is still closed with `tab tab ret`,
  `ret`, `tab tab tab ret`.
- **E7 — two version stamps of the same image disagree.** The console's banner reads `LiberNT [Version
  0.4.17-amd64-dev-20261125-23beab8]` (the checkpoint's start commit) while the desktop's watermark reads
  `feat/audio-control-polish.5773fcf.amd64.clang.3208-251126` (the build tip). An observation for whoever stamps
  the image; the drivers under test are identified by the hashes in `PROVENANCE.md`.

## Tooling changed in this round (the simulator side)

- `tools/fault-matrix.sh` **recognises self-test rows**: a row whose driver settings line (before `booting:`)
  reads `SelfTest = 1` ends with the self-test's summary (`ipc self-test: N requests, … ok | failed at …`), not
  with `boot ok`; without a summary within the window the row is unbounded whatever its `boot ok` said. The row
  quotes the boot's own line, the failing exchange and the model's registers read over qtest after the row, and
  the recovery cycle needs `boot ok` **and** the summary's `ok`. A `:` of a typed fault becomes `_` in the row's
  directory name (`fm-ipc-status=5_19`; the table keeps the value). The qtest socket is opened for `RECOVER=1`
  too: p2b4's `recover.out` files carry a `qtest.py` traceback and empty model readings because it was opened
  only with `HEARTBEAT=1`. A `|` inside a table cell is escaped (this launch's shorter figures let the
  200-character cut land inside `0x61000000|0x00000000`). The 20 boot rows are produced as before.
- `tools/fm-check.sh` adds a second table for self-test rows — the boot's line and clocks, the failing exchange
  (the status, or the timeout on its 500 ms budget), the summary's counters against TESTING.md for
  `ipc-status=5:19` and `never-reply=19`, the power-down line, and the recovery — appended only when there is
  such a row: on the p2b4 rows the output is identical to the previous script's (27 lines, the timestamp
  aside). D4's state word is shown in the table and counted apart from failed checks.
- The driver's serial lines end in CR LF: a first draft compared the summary without stripping the tail and
  flagged a passing self-test as a mismatch; the tail is stripped before an exact comparison.
- The two self-test rows were run three times: the table format of `fault-matrix.sh` was finished between the
  passes (a pipe left raw in the `boot ok` quote, then a cut in the middle of `ADSPCS 0x…`). Only the last pass
  is kept; all three ended the same way (`c1-acceptance.md`, C). After the last change to the scripts (the
  escape of a `|` inside any row's 200-character cell, which this launch's shorter figures had exposed on the
  `none` row) the `ipc-status=5:19` row was run once more into a scratch directory: its row equals the kept
  one apart from the timings and the poll count. The kept boot matrix was assembled from the run's output: the
  rows put in the canonical order (`none` first, although it ran last) and the `|` in its `boot ok` quote
  escaped there by hand, as the script now does itself.
- `tools/cycle.sh` and `tools/ac3-cycles.sh` are unchanged. The `search` tool of the agent host does not run
  under this machine's shell wrapper; grep was used instead.

## Not run in this round

- `UseInterrupts = 1` (TESTING.md: "debug only; not the acceptance configuration"): `ipc: link ready,
  interrupts on, 500 ms per message`, the summary's `6 DSP interrupts`, and whether the first reply raises the
  line once or a storm follows. The model's interrupt path is proven by the qtest (`irq-intx`, `irq-msi`), not by
  the transport in a VM.
- S3 (N6's `resident` alone), and everything on silicon: the real firmware's statuses for the six steps, whether
  it accepts pipeline 1 created with no pages, the real latency, which enable gates the line, whether it accepts
  the loopback topology; the model's 50 µs and its status codes are model values (`../MODEL-NOTES.md`).
