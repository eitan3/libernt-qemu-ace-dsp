# DIVERGENCE — LiberNT `intcdsp.sys` (image p2b3, `feat/audio-control-polish @ ee1338426b1`) against the ACE model

Written by the simulator side (qemu-ace-dsp). Nothing in the driver was patched; the LiberNT
tree was not touched in this round. Image: `bootcd.iso` sha256 `2b12b75066da32a8…`,
`LiberNT.vhd` `12a232c8ce73e955…` (both verified with `sha256sum -c SHA256SUMS`);
`intcdsp.sys` in the ISO = `b42955ef…` (extracted with bsdtar and hashed; = PROVENANCE.txt).
Model: the qemu-ace-dsp series at `f53ff8b` (patches 0001–0008, QEMU 11.1.3; binary sha256
`84cb786c86fa…`, rebuilt from the committed series before the first VM run, qtest 8/8), q35,
TCG, `-smp 1`.

**Result of this rerun: the two divergences of the p2b2 round (D1, D2) are fixed in the image as
PROVENANCE.txt says, and the acceptance runs they blocked (AC3, AC4) are closed below; one new
driver-side divergence was found (D3: the FW_CONFIG tuple list is validated by its version tuple
only, so a malformed or truncated reply boots `ok`).** What this round also found is (E1) an
**environment** limitation of the simulator host that the D2 fix turned from a hang into a
bounded, named failure — not a driver fault — three places where the *plan's* or TESTING.md's
expected words differ from what the driver prints (N1–N3), and one matrix row that no longer
measures what the plan wanted from it (N4), none of them faults. R1/R2 of the read-only review are
only touched where this round adds to them (R1, Task C, at the end).

## D1 — FIXED in `39e50ba6036` (verified)

The receive path now reads `HFIPCXIDA` first, takes the extension from `HFIPCXTDDY`, and writes
DONE back only after the payload was read — the trace of every `boot ok` of this round shows
exactly the order of Linux `mtl_ipc_irq_thread`:

```
ace_ipc IPC reply primary 0xe1000000 ext 0x00000000        the FW_CONFIG reply
ace_reg_read  BAR4 +0x73214 -> 0xe1000000 HFIPCXIDA        header = the register with DONE set
ace_reg_read  BAR4 +0x73300 -> 0x00000000 HFIPCXTDDY       extension
ace_reg_write BAR4 +0x73214 <- 0x80000000 HFIPCXIDA        DONE acknowledged afterwards
```

and the state machine consumes it: `boot ok … IPC status 0, last DSP message 0x61000000|0x00000000,
attempt 1 …` followed by `firmware ready: version 2.15.0.1, ABI 1, … 7 tuples` (the version is the
one the model read out of the bytes that crossed the DMA). `D0Entry` returns: PnP goes on, the
device is started, the boot continues (no `Work queue … no progress` line in any run of this
round; 0 bugchecks). Evidence: `ac3-boot2-icount` (trace `qemu-dbg.log`, 94 lines, the whole
boot), `ac3-interactive`, `ac3-cycles-icount`, every `fm-*` row.

## D2 — FIXED in `ee1338426b1` (verified)

- The `booting:` line carries `clock <N> us at 10000000 Hz`, the `boot` line `after <M> us (clock
  <N+M> us)`, and the end clock is the start clock plus M (±50 µs: 17933371 + 21334 = 17954705
  against 17954746 in `ac3-boot2-icount`; 1043354109 + 25369 = 1043379478 against 1043380393 in
  `ac3-interactive`).
- Every budget fires on time and names its step: `boot power-up timeout after 53231 us … failed in
  powering up (power-up timeout)` (50 ms budget, 53 ms measured — the non-icount runs, E1),
  `boot base firmware timeout after 3126051 us … failed in loading (base firmware timeout), ROM
  status 0x05000025` (3 s budget), and in the matrix the `never-*`/`drop-requests`/`ipc-status`/
  `bad-tuples`/`truncated-reply`/`version-shift`/`x-delay-scale=1550` rows (table in
  `fault-matrix.md`: `never-power` 52080 µs, `never-ack` 1573309 µs, `never-ready` 925159 µs,
  `never-enter` 3037514 µs, `never-fwready` 1022485 µs, `never-reply` 539340 µs, `drop-requests`
  573398 µs — each on its documented budget). The bounded rows of the p2b2 round that depended on
  a single sample read the same as before.
- `clock stalled` did **not** appear in any run of this round (0 lines in every serial log; the
  cycle summary counts them), on either environment: under TCG the poll bound (2× the polls a
  budget needs) never fired before the clock budget — the driver polls at 0.5–0.83 ms per
  iteration and the budgets are met by the clock first.

## D3 — the FW_CONFIG tuple list is validated by its version tuple only: a malformed or truncated reply boots `ok` (driver)

### What was seen (rows `bad-tuples` and `truncated-reply` of the matrix, under icount; `fm-bad-tuples`, `fm-truncated-reply`)

- `bad-tuples` (the model sets the second TLV's length to 3 — not a multiple of four, so every
  following header sits at a misaligned offset):
  `boot ok after 21344 us (clock 21989564 us): state ready, … IPC status 0, last DSP message
  0x61000000|0x00000000, attempt 1, 1 DSP interrupts, cleanup ok`, then `firmware ready: version
  2.15.0.1, ABI 1, …, downlink mailbox 0 bytes, uplink mailbox 0 bytes, trace log 0 bytes, 0
  pipelines, 0 libraries, context save 0, 3 tuples`.
- `truncated-reply` (the version TLV alone, the rest of the mailbox zero): `boot ok after 21303 us
  … state ready …`, `… 1 tuples`.

Both rows are bounded and recover, but no failure is named: the plan (§6.5) and the image's
TESTING.md expect `boot ipc error` / `ipc bad reply` / `truncated` for them.

### Why (read in `sdk/lib/drivers/fwload/fwboot.c` at `1f37c158557`, diagnosis only)

`FwloadParseFwConfig` (fwboot.c:473) walks the TLVs as `type, length (bytes), value`: a zero
header ends the reply, a length past the mailbox returns `FwloadTruncated`, every other tuple is
counted (`TupleCount++`) and handed to `FwloadTupleValue`, which stores a word when `Bytes >= 4`
and 0 otherwise, and ignores unknown types; it returns `FwloadOk` whenever at least one tuple was
counted. `FwloadQueryFwConfig` (fwboot.c:615) then checks only `HasVersion` and that the version
equals the image's. With the faulted length 3 the walk is: FW_VERSION (ok) → DL_MAILBOX_BYTES with
`Bytes = 3` → `DownlinkMailboxBytes = 0`, `HasDownlinkMailbox = TRUE` → the next header is read
at offset 27 (type `0x700`, length 1024: unknown, skipped) → the zeroed area ends the walk:
`TupleCount = 3`, `FwloadOk`. The downlink mailbox is then 0 bytes and the uplink mailbox, trace
log, pipeline and library counts are simply absent; the boot is declared ready. The walk itself is
bounds-checked (no over-read), so this is a validation gap, not a memory-safety one.

### Expected, per which source

- Plan §6.5: `ipc-status=<n>` / `bad-tuples` / `truncated-reply` → `boot ipc error` / `ipc bad reply`
  / `truncated`; TESTING.md of this image: "`bad-tuples` as `truncated`".
- The qtest asserts that the model's two faults produce the malformed lists it intends
  (`intel-hda-ace-test.c`, case `faults`), so the model side is as designed.

Expected fix (driver side, for Megan to route): reject a tuple length that is not a multiple of
four (and an unknown type, if the firmware's list is closed), and require the tuples the driver
later relies on — at least non-zero downlink and uplink mailbox sizes — before `boot ok`; a
truncated list (version only) should end as `truncated`/`ipc bad reply` with the DSP powered down.
Until then a firmware that answers FW_CONFIG wrongly is reported as `firmware ready` with 0-byte
mailboxes, and the first real IPC would run against that configuration.

## E1 — environment: on this host the guest's clock runs while the model's timers stand still (not a driver divergence)

**What was seen (non-icount runs, logs on the `/home` disk).** With the budgets real, a
`BootDsp=1` boot from the idle desktop fails bounded at the first step whose timer the model
never got to fire: the first D0 entry of `ac3-interactive` (no workaround) → `boot power-up
timeout after 53231 us` after 64 `ADSPCS` polls, all `0x00010000` (SPA set, CPA clear) — the
model's 100 µs CPA timer was not seen for 53 ms of guest time; the cycle `c2` of the same session
→ `boot base firmware timeout after 3126051 us`, the model standing in FSR state `0x25` for 3 s.
With a 1 ms qtest heartbeat running (`tools/heartbeat.py`), 17 of 22 cycles booted (`boot ok
after 17.5–25.4 ms`) and 5 (`c6`, `c12`, `c15`, `c17`, `c18`) timed out at power-up — each one at
a moment where the heartbeat's own read was answered only after **252–284 ms** (`heartbeat-c*.log`),
i.e. QEMU's main loop did not run at all for a quarter second while the guest kept polling.

**Mechanism.** The model arms `QEMU_CLOCK_VIRTUAL` timers from its MMIO handlers
(`ace_arm`, intel-hda-ace.c:344); without icount that clock is the host clock and the timers are
run by QEMU's main loop, which sleeps in `poll()` until a host timer or an fd event wakes it.
(1) This host's timer delivery stalls under a spinning TCG guest (the p2b2 README's finding,
unchanged: a guest that is otherwise idle gives the main loop no fd event, so its timers wait for
the next event; at boot time the disk I/O provides them, which is why the p2b2 matrix's
single-sample rows went through power-up in 50 ms). (2) Every trace and serial line is a
`write()` to the evidence files made from the vCPU thread under the BQL; on `/home` (btrfs on the
VM's disk) a 4 KB sync write averages 3.5 ms and blocks far longer at times — a blocked write
holds the BQL, and the main loop cannot run timers or answer qtest until it returns. The guest's
TSC, read directly from the host clock, keeps advancing through both: its budget expires before
the model's timer is seen.

**Effect on the driver: none beyond the designed bound.** Each such stall produced one bounded
`boot … timeout` line, a DSP power-down, `cleanup ok` (once `cleanup power-up timeout`, the
cleanup's own power-down wait hit by the same stall), a started device and a `boot ok` on the
next enable without any intervention. The D2 hang of the p2b2 round is what this looked like
before the fix.

**Fix for the evidence environment (used for everything after `ac3-interactive`).** The VM runs
under `-icount shift=auto,align=off,sleep=off` on `tcg,thread=single` (`ICOUNT=1` in lib-run.sh)
and writes its logs to tmpfs (`/tmp`, copied into the evidence tree afterwards). With icount the
guest clock and the model's timers advance together by executed instructions, so a stalled main
loop pauses both and a stall can no longer turn into a budget expiry: `ac3-boot2-icount` is a plain
boot with no heartbeat, `boot ok after 21334 us`; `ac3-cycles-icount` runs 22 disable/enable
cycles the same way. The heartbeat (`HEARTBEAT=1`, a qtest read per ms) remains available for
non-icount runs and was used for the first interactive session only. Which option each run used is
recorded in its `qemu-args.txt`.

Classification: **environment** (simulator host). Nothing to change in the driver; a silicon host
does not have a main loop. The model's timer mechanism is as designed (qtest: deterministic).

## N1 — `1 DSP interrupts`, not the plan's 2 (plan expectation, not a fault)

Plan §6.4 expects `2 DSP interrupts` (FW_READY and the reply); TESTING.md of this image expects
`1`. Measured `1` on every boot of this round. The trace shows why: the FW_READY notification
raises the line (`DSP interrupt 1`), the ISR reads `HFIPCXIDA`/`HFIPCXTDR`/`INTEN`, and **masks
all three enables** (`INTEN ← 0`, `HfHIPCIE ← 0`, `HFIPCXCTL ← 0`) before the state machine sends
the FW_CONFIG request; the reply therefore cannot raise a second interrupt (the model raises the
line only while a message is pending *and* every enable is set), and the receive path takes the
reply from its 500 µs poll. The interrupt path is proven for the notification (the ISR ran once
per boot: its reads and mask writes are in every trace); the reply interrupt path is not exercised
by this driver. Not a divergence of model or driver — a driver design choice (mask in the ISR,
poll afterwards) and an expectation to correct in the plan.

## N2 — the `ROM info` field: the register is proven, the plan's literal is not what the line prints

Plan §6.4 expects `ROM info 0x0120315A` (the model's window-0 constant). The driver prints
`ROM implementation 0.3 version 1.2 platform 288, ROM info 0x0000005a`: the decoded fields of
`0x0120315a` (bits 19:12 = 3, bits 27:20 = 0x12, bits 27:16 = 0x120 = 288, fuses 7:0 = 0x5a). The
register block came through window 0 as intended. For the silicon checklist: the model's header
comment gives the field as "implementation revision 19:12, version 27:20, platform 27:16" (two
overlapping ranges — the comment is garbled), the driver prints a 12-bit platform at 27:16; the
SOF `ipc4_fw_regs` layout decides which is right on the device.

## N3 — `7 tuples`, not TESTING.md's 8

The model's FW_CONFIG reply carries FW_VERSION plus six constants (downlink/uplink mailbox bytes,
trace log bytes, pipelines, libraries, context save) = 7 TLVs, and the driver counts 7. TESTING.md's
"the tuples count is 8 on the model" is off by one in the expectation, not in the driver.

## N4 — the `x-delay-scale=1550` row measures the power-up budget, not the 3 s base-firmware edge (scenario note)

Plan §6.5 wanted this row to show `boot timeout … failed in loading` with FW_ENTERED 3.1 s out.
With every model delay scaled 1550×, the power-up itself (CPA at 155 ms) exceeds the 50 ms
power-up budget long before FW_ENTERED is due, and the driver correctly reports `boot power-up
timeout after 52503 us … attempt 0`. (On the p2b2 image the same row reached `FW_READY received`
at 9.4 s only because no budget fired.) The 3 s edge is measured by `never-enter`:
`boot base firmware timeout after 3037514 us`. A row for the edge as planned would need a model
fault that delays the firmware's entry alone.

## Still unfixed in this image (known from the read-only review)

R2 (no ISR storm guard) stays invisible to the model. **R1 is visible since Task C** (patches
0009/0010, a separate commit after the evidence above): the model now answers `HFINTIPPTR` with
all ones while the subsystem is unpowered, as a DSP-domain register would. One plain boot with
that model (`ac3-r1-model`) shows what the driver does with it: the probe logs
`+0x1108 HFINTIPPTR 0xffffffff`, bounds-checks the pointer (`IntcDspInterruptEnableOffset`,
hwops.c:287) and so prints no `+0x120 (the interrupt enable register the pointer names)` line;
the boot reads the pointer again in `FwloadInterruptsEnable` (fwboot.c:301) after power-up,
gets `0x120`, and is unchanged: `boot ok after 71859 us … 1 DSP interrupts`. So on this boot R1
has no effect — the two pre-power-up reads (probe and D0 entry) are logged and discarded, not
used. What remains a silicon question is the unpowered value itself (all ones is a model value).
