# DIVERGENCE — LiberNT `intcdsp.sys` (image p2b4, `feat/audio-control-polish @ b392065b2cf`) against the ACE model

Written by the simulator side (qemu-ace-dsp). Nothing in the driver was patched; the LiberNT tree was not
written to in this round (its git objects were read at `b392065b2cf` for diagnosis only, as in the p2b3 round).
Image: `bootcd.iso` sha256 `f4c4636d5e1351…`, `LiberNT.vhd` `8e079736612f84…` (both verified with
`sha256sum -c SHA256SUMS`); `intcdsp.sys` in the ISO = `41bd1405…` (extracted with bsdtar and hashed; =
PROVENANCE.txt; built from `24b0394e1e0`, the published tip `b392065b2cf` has the same tree content).
Model: qemu-ace-dsp `main` at `b139810` (patches 0001–0010, QEMU 11.1.3; binary sha256 `a6a4371b911a…`,
qtest 9/9 before the first VM run), q35, TCG, `-smp 1`, `-icount shift=auto,align=off,sleep=off` on every
run, logs on tmpfs.

**Result of this round: D1 and D2 stay fixed; D3 is fixed (both rows name the failure, power the DSP down
and recover); the R1, R2 and R6 changes are measured as the image's TESTING.md describes them, with one
model-ordering note (N5: `HFINTIPPTR` still reads all ones on the `subsystem powered` line), one
observability note (N6: the serial log cannot show R6), one expectation note (N7) and one TESTING.md
row expectation that does not match the model's fault (N8, `drop-requests`). No new driver
divergence was found: the matrix is **20 of 20 rows bounded**, each with its named failure, a real `after N
us`, no bugcheck, no hang, and a `boot ok` on the next power cycle (`fault-matrix.md`; `tools/fm-check.sh`:
0 rows with a failed check); every one of the 40 `boot` lines of the matrix reads `0 DSP interrupts`.**

## D1 — stays FIXED (`39e50ba6036`; re-verified on p2b4)

Every `boot ok` of this round has the `mtl_ipc_irq_thread` order in the device trace (A2: reply
`0xe1000000` → `HFIPCXIDA` read → `HFIPCXTDDY` read → DONE acknowledged), `boot ok … IPC status 0, last DSP
message 0x61000000|0x00000000` and `firmware ready: version 2.15.0.1, ABI 1, … 7 tuples`. No `Work queue … no
progress` line and no bugcheck in any run (A1, A2, A4, the 23 boots of `ac3-cycles`, the matrix rows).

## D2 — stays FIXED (`ee1338426b1`; re-verified on p2b4)

The `booting:` line carries `clock <N> us at 10000000 Hz`, the `boot` line `after <M> us (clock <N'> us)`, and
N' − N − M is 80–82 µs on all 23 boots of `ac3-cycles`, 322 µs in A2, and within the matrix tolerance on every
row (`fault-matrix.md`, `tools/fm-check.sh`). Every budget fires on time and names its step (the `never-*`
rows, `x-delay-scale=1550` on the power-up budget). `clock stalled` did not appear in any run.

## D3 — FIXED in `1171e65e774` (verified; rows `bad-tuples` and `truncated-reply`, `fm-bad-tuples`, `fm-truncated-reply`)

- `bad-tuples` (the model sets the second TLV's length to 3):
  `boot bad IPC reply after 70083 us (clock 17618589 us): state failed, failed in configuring (bad IPC reply),
  ROM status 0x00000005 firmware entered, ROM error 0x00000000 unknown ROM error, IPC status 0, last DSP
  message 0x61000000|0x00000000, attempt 1, 0 DSP interrupts, cleanup ok, ADSPCS 0x00000000`, then
  `firmware configuration: tuple type 0x6 at offset 0x10 of the reply is malformed` (the model's second tuple,
  the downlink-mailbox size, as TESTING.md predicts), then `DSP power down from state off: ok, cleanup ok, ADSPCS
  0x00000000 (SPA 0, CPA 0)`. Bounded (0.078 s guest time), the device left started, and the recovery cycle
  (fault cleared over QMP, one disable/enable) is `boot ok after 21473 us`.
- `truncated-reply` (the version tuple alone): `boot truncated after 23398 us (clock 18124993 us): state failed,
  failed in configuring (truncated), … attempt 1, 0 DSP interrupts, cleanup ok, ADSPCS 0x00000000`, then the
  power-down line. Bounded (0.016 s); the recovery cycle is `boot ok after 21803 us`.

On p2b3 both rows ended in `boot ok` with 0-byte mailboxes (the p2b3 `DIVERGENCE.md`); they now name the
failure and the tuple, as the plan (§6.5) and TESTING.md expect. Both end in `configuring`, after
`FW_READY received`, with `0 DSP interrupts`.

## R1 — the interrupt pointer is read where it is used: visible and handled (driver `b392065b2cf`)

The model of patches 0009/0010 answers `HFINTIPPTR` with all ones while the DSP domain is unpowered. The
driver's lines against it (`a1-stage1-firstboot`, `a2-stage2-boot`):

- Stage 1: `+0x1108 HFINTIPPTR 0xffffffff` and `HFINTIPPTR 0xffffffff names no 32-bit register inside BAR4: the
  host IPC interrupt enable cannot be reached` instead of p2b3's `+0x120 (the interrupt enable register the
  pointer names) 0x00000000`; the trace holds six BAR4 reads, no `+0x120` read. The other eleven stage-1 lines
  are byte-identical to p2b3's.
- Stage 2: `interrupts before power-up: ADSPCS 0x00000000 (SPA 0, CPA 0), HFINTIPPTR 0xffffffff, INTEN
  0xffffffff, HfHIPCIE 0x00000000, HFIPCXCTL 0x00000000` — the pointer names no register, so `INTEN` is
  reported as `0xffffffff`, not read. From `ROM ready for the firmware` on: `HFINTIPPTR 0x00000120, INTEN
  0x00000000`.
- The boot is unchanged in outcome: `boot ok … attempt 1, 0 DSP interrupts, cleanup ok, ADSPCS 0x01010000`,
  on all 23 boots of the cycles and every unfaulted matrix row.

What remains a silicon question is the unpowered value itself (all ones is a model value) and *when* the
register starts answering (N5).

## R2 — poll-only: `0 DSP interrupts` on every boot; the storm guard stays invisible to the model

Measured `0 DSP interrupts` on every boot of this round (A2, A4, the 23 boots of `ac3-cycles`, every matrix
row), no `first DSP interrupt:` line, no `interrupt storm`, no `interrupt enable timeout`. The mask is in
the trace of every boot right after the `subsystem powered` reads: `HFINTIPPTR` read (all ones: names no
register, so nothing is written to `+0x120`), `HfHIPCIE` read ← `0x00000000` ← read back `0x00000000`,
`HFIPCXCTL` read ← `0x00000000` (no read-back by design: "each read back where the register allows it").
The model cannot show that this mask *gated* anything: its `INTEN`, `HfHIPCIE` and `HFIPCXCTL` reset to 0 (no
BIOS sets them) and it raises the line only when all three enables are set (`ace_update_irq`: a notification
needs `INTEN ∧ HfHIPCIE.IE ∧ HFIPCXCTL.BUSY`, a reply `… ∧ HFIPCXCTL.DONE`), so the line would have stayed
low without the mask. The two enables the driver reaches without the pointer are enough to gate the line in
the model's rule; "which enable gates the line" on silicon stays to be measured, and the 16-interrupt storm
guard cannot be exercised by this model.

## N5 — `HFINTIPPTR` still reads all ones on the `subsystem powered` line: a model ordering, and what the driver does with it (note)

TESTING.md expects the pointer "as found after the power-up on the `subsystem powered` line". Measured:
`subsystem powered: ADSPCS 0x01010000 (SPA 1, CPA 1), HFINTIPPTR 0xffffffff, INTEN 0xffffffff` — the pointer
answers `0x120` only from `ROM ready for the firmware` on. That is the model's definition, not the driver's:
`ace_powered()` (`intel-hda-ace.c:233`) requires **both** the subsystem's CPA (ADSPCS) and the core's CPA
(DSP2CXCTL), and the core is powered by the purge request the driver sends after the mask — so on this model a
DSP-domain register "wakes" one step later than the subsystem's CPA. The driver's reaction, from the trace and
the source (`fwboot.c`, `FwloadInterruptsEnable(FALSE)`, read at `b392065b2cf` for diagnosis): the pointer
names no register at the mask point, so the `INTEN` write is skipped (with `Enable = FALSE` that is not a
fault), `HfHIPCIE` and `HFIPCXCTL` are masked, and **the `INTEN` mask is not repeated when the pointer becomes
valid at ROM ready** — there is no write to `+0x120` anywhere in the boot. On the model this changes nothing
(the model's rule, R2 above). It matters only if silicon behaves like the model *and* `INTEN` alone gates the
line there: a BIOS-left `INTEN = 1` would then stay set through the boot, the FW_READY notification would
raise the line once, and the ISR's own mask (through the then-valid pointer) would clear it — bounded, but
`1 DSP interrupts` and a `first DSP interrupt:` line on a boot that is meant to be poll-only. For the silicon
list: note the `subsystem powered` line's `HFINTIPPTR`; if it is all ones there too, a repeated `INTEN` mask
at ROM ready (when the pointer first names a register) would close the gap. Classification: model ordering
(the R1 scenario's "when") + a driver question for Megan to route; not a divergence on this evidence.

## N6 — R6 cannot be seen in the serial log: the `firmware … bytes, ok` line is printed whether or not anything was read (note; `a4-second-boot`)

The second boot in the same VM (one disable/enable) prints the line **twice**, as the first boot does and as
p2b3 did: `firmware \SystemRoot\System32\drivers\intel\sof\sof-arl-s.ri: 1158164 bytes, ok, …` after the
stage-1 reads and again after `BootDsp = 1: …`, then `booting:`. Read in the driver (`intcdsp/fwfile.c:127`,
`fwload/fwimage.c:35`, `intcdsp.c:149` and `:342`, diagnosis only): `IntcDspLoadFirmware` calls
`FwloadImageEnsure`, which returns at once when the device already holds the image (`if (Image->Modules != NULL)
return FwloadOk;`), and then logs the line on every call; it is called from `PrepareHardware` and from the boot
path. On the disable/enable path the device object is new (`Safe removal` → a new FDO), so the first line is a
genuine re-read at `PrepareHardware` ("kept for the device" is per device object) and the second is the resident
path that reads nothing. So the log is identical to p2b3's, where the second line was the re-read R6 removed:
**the serial log can neither confirm nor refute R6**, and TESTING.md's "no second `firmware … bytes` line" /
"the stage-1 lines repeat without the firmware line" is not a check this image's log can answer. A distinct
text for the resident case (e.g. `… bytes, resident`) would make R6 checkable. The case R6 was written for —
the same device object entering D0 again after sleep — was not exercised (no S3 in this VM run).
Classification: driver logging (observability) + expectation correction; not a behavioural divergence.

## N7 — "On the model `INTEN` reads 1 before and 0 after" (expectation note)

TESTING.md's check for the step lines. Measured: `INTEN 0xffffffff` (the pointer names no register) on the
`interrupts before power-up` and `subsystem powered` lines, and `0x00000000` from `ROM ready` on — the model's
reset value, never written on a p2b4 boot (no `+0x120` write in any trace). The model's `INTEN` resets to 0, not
to 1; the "1 before" would need a model with a BIOS that sets it, which does not exist.

## N8 — `drop-requests`: TESTING.md expects `boot ok` attempt 3, the row ends `boot IPC reply timeout` attempt 1 (expectation note)

TESTING.md's fault list says "`drop-requests` `boot ok` attempt 3". Measured, as on p2b3: `boot IPC reply
timeout after 539659 us (clock 18560427 us): state failed, failed in configuring (IPC reply timeout), … last
DSP message 0x1b080000|0x00000000, attempt 1, 0 DSP interrupts, cleanup ok, ADSPCS 0x00000000` (bounded,
0.531 s, recovered). The model's fault (`intel-hda-ace.c`, the request handler: a non-ROM request is dropped
without a reply when `fault=drop-requests`) drops the firmware's IPC — the FW_CONFIG GET — and lets the purge
request through, so the boot reaches `FW_READY received` and ends on the 500 ms reply budget; the driver sends
the configuration query once (`FwloadQueryFwConfig` is called once in `FwloadBoot`; the attempt loop is the
ROM init's), so `attempt 3` cannot arise from this fault. `never-reply` ends the same way (539309 µs) because
on this model the two faults drop the same request. The row measures the reply budget, as the p2b3 README's
table records; the TESTING.md entry is the expectation to correct.

## E2 — environment: `after N us` on this VM is TCG execution time, not a DSP timing

The loader copies the 1.15 MB payload into uncached memory byte by byte (`fwload/fwboot.c`,
`FwloadClDmaPrepare`: `for (Index = 0; Index < PayloadBytes; Index++) Dma->Virtual[Index] = Payload[Index];`)
— of the order of 10⁷ TCG instructions per boot — while the model's timers add up to about 3 ms. Under
`-icount shift=auto` the virtual cost of those instructions is set by the shift QEMU calibrates at start, so
the figure moves between launches with the model and the image unchanged: p2b3's icount run measured 37619 µs
at boot time and 21318–21472 µs on its cycles; p2b4 measures 67971 µs in A2, 37806 µs at boot time and
21406–21726 µs on the 22 cycles of `ac3-cycles`, 21392 µs at the boot-time boot of that run. Compare timings
within one launch only; none of them predicts silicon (TESTING.md's "a few hundred milliseconds" is not
confirmed or refuted by the VM).

## E3 — environment: the first-boot wizard has three pages on this image (`a1-stage1-firstboot`, `s1`–`s6`)

"Choose your language and keyboard" → "Name your computer and create your account" (Skip) → "Get the
components most programs need" (3.3 GB of downloads; Cancel). p2b3's `tab, tab, ret` now only reaches page 2.
The procedure used: `tab tab ret` → `ret` (Skip) → `tab tab tab ret` (Cancel), then the console as before.

## E4 — environment: sync #14's power-management core in the serial log

`\ntos\po\standby.c: The display idled out after 600 seconds` / `The console display is now off|on` appear in
the idle-desktop phase. Under `-icount … sleep=off` the guest clock runs ahead while the desktop idles (guest
602 s at about two minutes of wall time), so the display "idles out" within minutes of wall time;
`screendump` is unaffected. `updagent` fails its `https://libernt.com/api/update/…` request with `0x80072ee7`
(no NIC). Neither touches the DSP lines.

## Still unverified (silicon only)

1. `HFINTIPPTR`'s real unpowered value (all ones is a model value) and the point at which it starts answering
   (the model: with the core's CPA; N5).
2. Which of the three enables gates the line on the real part, and whether the line is level or edge
   triggered — the model's rule (all three) is a model value; R2's storm guard cannot be exercised by the model.
3. Real timings of every step (E2).
4. R6 on a sleep/resume cycle with the same device object (no S3 in this VM run; N6).
5. R9's "has no register map" line for the five other INF device IDs: the VM has one controller.
