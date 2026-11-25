# The C1 simulator round — expectations → measured (Tasks A–D)

Image p3c1 (`feat/audio-control-polish @ 9c9a876c6a3`, built from `5773fcfa7af`; `intcdsp.sys` in the ISO
`cc6c1309…`), model `main` at `9713aa0` (patches 0001–0018; binary `be8667eb…`, rebuilt from the series, qtest
14/14 before the first VM run — `PROVENANCE.md`). q35, TCG, `-smp 1`, `ICOUNT=1` on every run, one VM at a
time. Serial lines are quoted from each run's `serial.log` with the kernel timestamp kept; the device trace is
`qemu-dbg.log.gz`, from the power-up on in `qemu-dbg.excerpt.txt` and from the firmware's FW_READY notification
on in `ipc-trace.txt`.

## A — regression: the unfaulted boot is p2b4's, with N5 and N6

### A1 — stage 1 (`BootDsp = 0`): `a1-stage1-firstboot`

The first boot of the fresh overlay `disk/p3c1.qcow2`: the boot manager, the three-page first-boot wizard
(closed as on p2b4 with `tab tab ret`, `ret`, `tab tab tab ret`; `s1`–`s4`), a console (`s5-cmd.png`),
`BootDsp = 1` set and read back (`s6-reg-query.png`: `BootDsp 0x1`, `SelfTest 0x0`, `UseInterrupts 0x0`,
`IpcTimeoutMs 0x1f4`), a clean S5 (QEMU exit 0). This boot turns the overlay into the stage-2 overlay.

The driver's lines (`stage1-lines.txt`) are p2b4's thirteen with two differences (`diff` of the two files,
timestamps removed):

```
< intcdsp.sys: firmware \SystemRoot\System32\drivers\intel\sof\sof-arl-s.ri: 1158164 bytes, ok, image 'ADSPFW' version 2.15.0.1, 32 modules, payload 0xc14 + 0x11a000, 282 preload pages
---
> intcdsp.sys: firmware \SystemRoot\System32\drivers\intel\sof\sof-arl-s.ri: 1158164 bytes, read, image 'ADSPFW' version 2.15.0.1, 32 modules, payload 0xc14 + 0x11a000, 282 preload pages
> intcdsp.sys: SelfTest = 0, UseInterrupts = 0, IpcTimeoutMs = 500 ms
> intcdsp.sys: SelfTest = 0, UseInterrupts = 0, IpcTimeoutMs = 500 ms
```

The firmware line says `read` (N6: the call read the file) and the settings line follows `BootDsp = 0: probe
only` — twice (`DIVERGENCE.md`, N9). The trace holds exactly the six BAR4 reads of the `reading BAR4 at …`
line (`+0x1000 +0x1108 +0x1140 +0x73228 +0x163200 +0x163204`), 0 `ace_unexpected`.

### A2 — stage 2 (`BootDsp = 1`), a plain boot of the stage-2 overlay: `a2-stage2-boot`

```
[    7.508047] intcdsp.sys: firmware \SystemRoot\System32\drivers\intel\sof\sof-arl-s.ri: 1158164 bytes, read, image 'ADSPFW' version 2.15.0.1, 32 modules, payload 0xc14 + 0x11a000, 282 preload pages
[    7.508047] intcdsp.sys: BootDsp = 1: the DSP is booted at the next D0 entry
[    7.508047] intcdsp.sys: SelfTest = 0, UseInterrupts = 0, IpcTimeoutMs = 500 ms
[    7.508047] intcdsp.sys: SelfTest = 0, UseInterrupts = 0, IpcTimeoutMs = 500 ms
[    7.508047] intcdsp.sys: firmware \SystemRoot\System32\drivers\intel\sof\sof-arl-s.ri: 1158164 bytes, resident, image 'ADSPFW' version 2.15.0.1, 32 modules, payload 0xc14 + 0x11a000, 282 preload pages
[    7.523672] intcdsp.sys: booting: firmware 'ADSPFW' 2.15.0.1, 1155072 payload bytes in 1 descriptors on stream 1, BAR4 FFFF808007200000, clock 17979428 us at 10000000 Hz
[    7.523672] intcdsp.sys: interrupts before power-up: ADSPCS 0x00000000 (SPA 0, CPA 0), HFINTIPPTR 0xffffffff, INTEN 0xffffffff, HfHIPCIE 0x00000000, HFIPCXCTL 0x00000000
[    7.523672] intcdsp.sys: subsystem powered: ADSPCS 0x01010000 (SPA 1, CPA 1), HFINTIPPTR 0xffffffff, INTEN 0xffffffff, HfHIPCIE 0x00000000, HFIPCXCTL 0x00000000
[    7.539297] intcdsp.sys: code-loader stream 1: 1155072 bytes in 1 descriptors (LVI 0), SPIB 1155072, format 0x0040
[    7.539297] intcdsp.sys: ROM ready for the firmware: ADSPCS 0x01010000 (SPA 1, CPA 1), HFINTIPPTR 0x00000120, INTEN 0x00000000, HfHIPCIE 0x00000000, HFIPCXCTL 0x00000000
[    7.539297] intcdsp.sys: firmware entered: ADSPCS 0x01010000 (SPA 1, CPA 1), HFINTIPPTR 0x00000120, INTEN 0x00000000, HfHIPCIE 0x00000000, HFIPCXCTL 0x00000000
[    7.539297] intcdsp.sys: FW_READY received: ADSPCS 0x01010000 (SPA 1, CPA 1), HFINTIPPTR 0x00000120, INTEN 0x00000000, HfHIPCIE 0x00000000, HFIPCXCTL 0x00000000
[    7.539297] intcdsp.sys: boot ok after 10546 us (clock 17990619 us): state ready, failed in off (ok), ROM status 0x00000005 firmware entered, ROM error 0x00000000 unknown ROM error, IPC status 0, last DSP message 0x61000000|0x00000000, attempt 1, 0 DSP interrupts, cleanup ok, ADSPCS 0x01010000
[    7.539297] intcdsp.sys: firmware ready: version 2.15.0.1, ABI 1, ROM implementation 0.3 version 1.2 platform 288, ROM info 0x0000005a, downlink mailbox 4096 bytes, uplink mailbox 4096 bytes, trace log 131072 bytes, 16 pipelines, 4 libraries, context save 1, 7 tuples
[    7.539297] intcdsp.sys: ipc: link ready, polled, 500 ms per message
```

The P2 lines are p2b4's (`boot ok … attempt 1, 0 DSP interrupts, cleanup ok, ADSPCS 0x01010000`;
`firmware ready: version 2.15.0.1, ABI 1 … 7 tuples`); end clock − start clock − N = 645 µs. Counts over the
serial log: `1 DSP interrupts` 0, `first DSP interrupt` 0, `interrupt storm` 0, `clock stalled` 0, fatal 0.

**The boot path in the trace.** From the power-up on, p3c1's trace has 100 lines against p2b4's 92
(`a2-stage2-boot/qemu-dbg.excerpt.txt` against `evidence/2026-11-25-p2b4/a2-stage2-boot/qemu-dbg.log.gz`,
event names dropped). `diff` shows three differences and nothing else:

- **N5, +9 lines** right after `state purging -> rom-ready`, before the firmware copy:
  ```
  BAR4 +0x1108 -> 0x00000120 HFINTIPPTR (model value)
  BAR4 +0x120 -> 0x00000000 INTEN (register the pointer names, model value)
  BAR4 +0x120 <- 0x00000000 INTEN (register the pointer names, model value)     <- the mask
  BAR4 +0x120 -> 0x00000000 INTEN (register the pointer names, model value)
  BAR4 +0x1140 -> 0x00000000 HfHIPCIE
  BAR4 +0x1140 <- 0x00000000 HfHIPCIE                                          <- masked again
  BAR4 +0x1140 -> 0x00000000 HfHIPCIE
  BAR4 +0x73228 -> 0x00000000 HFIPCXCTL
  BAR4 +0x73228 <- 0x00000000 HFIPCXCTL                                        <- masked again
  ```
  followed by the `ROM ready for the firmware` reads (`HFINTIPPTR 0x120`, `INTEN 0`, `HfHIPCIE 0`,
  `HFIPCXCTL 0`, `ADSPCS`). It is the whole trace's only write to `+0x120`; p2b4's trace has none (its mask
  came while the pointer still read all ones, so it named no register).
- **+1 line**, the model's own: `IPC reply type 1 (config-get) status 0: FW_CONFIG` (the decoded reply of
  patches 0011–0014).
- **−2 lines**, timing: p2b4's first poll of the reply registers came before the FW_READY notification and
  saw nothing (`HFIPCXIDA 0`, `HFIPCXTDR 0`); on this launch the notification was there at the first poll.

**What the VM can and cannot show of N5.** It shows the mask *where TESTING.md says*: the trace's write of 0
through the pointer at ROM ready, and `INTEN 0x00000000` on the `ROM ready for the firmware` line. It cannot
show that the mask *changes* anything: on the model `INTEN` resets to 0 and nothing writes it before the mask
(no BIOS runs, and the driver masks while the pointer names no register), so the register reads 0 before and
after. The case N5 was written for — an `INTEN` left set by the firmware/BIOS — is not reachable in this VM;
what is shown is the action, not its effect.

**N6 as observed.** Every D0 entry that boots the DSP prints the pair `read` then `resident`: at
`PrepareHardware` of a new device object (the file read) and at the boot's call on the same object (resident).
On this image that is 1 pair on the first boot of the stage-2 overlay (A2), 3 in `b1-selftest` (the boot and
two disable/enable cycles: each makes a new device object), 1 in `b2-selftest-boot`, 23 in `ac3-cycles`, 40
in the matrix's 40 boots, 4 in the two self-test rows with their recoveries — 72 pairs, and one `read` alone at
stage 1 (A1), where nothing boots. The VM cannot show `resident` **alone** — R6's own case, the same device object
entering D0 again after an S3: this VM does no S3. The old wording `bytes, ok` is gone.

## B — the C1 acceptance: `SelfTest = 1` (`b1-selftest`, `b2-selftest-boot`)

### B1 — set in the guest, then disable/enable: `b1-selftest`

The stage-2 overlay booted (`SelfTest = 0`, `boot ok after 5365 us (clock 18632471 us)`), a console opened,
and:

```
reg add "HKLM\SYSTEM\CurrentControlSet\Services\intcdsp\Settings" /v SelfTest /t REG_DWORD /d 1 /f
reg query "HKLM\SYSTEM\CurrentControlSet\Services\intcdsp\Settings"
    BootDsp        REG_DWORD    0x1
    SelfTest       REG_DWORD    0x1
    UseInterrupts  REG_DWORD    0x0
    IpcTimeoutMs   REG_DWORD    0x1f4
```

(`selftest-set.png`.) Then two disable/enable cycles of the DSP device (`tools/cycle.sh`, `cycles.log`). The
first, serial lines 167–203 (`selftest-lines.txt`):

```
[  345.125963] intcdsp.sys: firmware \SystemRoot\System32\drivers\intel\sof\sof-arl-s.ri: 1158164 bytes, read, image 'ADSPFW' version 2.15.0.1, 32 modules, payload 0xc14 + 0x11a000, 282 preload pages
[  345.125963] intcdsp.sys: BootDsp = 1: the DSP is booted at the next D0 entry
[  345.125963] intcdsp.sys: SelfTest = 1, UseInterrupts = 0, IpcTimeoutMs = 500 ms
[  345.126963] intcdsp.sys: SelfTest = 1, UseInterrupts = 0, IpcTimeoutMs = 500 ms
[  345.126963] intcdsp.sys: firmware \SystemRoot\System32\drivers\intel\sof\sof-arl-s.ri: 1158164 bytes, resident, image 'ADSPFW' version 2.15.0.1, 32 modules, payload 0xc14 + 0x11a000, 282 preload pages
[  345.128963] intcdsp.sys: booting: firmware 'ADSPFW' 2.15.0.1, 1155072 payload bytes in 1 descriptors on stream 1, BAR4 FFFF808007200000, clock 356133311 us at 10000000 Hz
[  345.134963] intcdsp.sys: boot ok after 5366 us (clock 356138758 us): state ready, failed in off (ok), ROM status 0x00000005 firmware entered, ROM error 0x00000000 unknown ROM error, IPC status 0, last DSP message 0x61000000|0x00000000, attempt 1, 0 DSP interrupts, cleanup ok, ADSPCS 0x01010000
[  345.134963] intcdsp.sys: firmware ready: version 2.15.0.1, ABI 1, ROM implementation 0.3 version 1.2 platform 288, ROM info 0x0000005a, downlink mailbox 4096 bytes, uplink mailbox 4096 bytes, trace log 131072 bytes, 16 pipelines, 4 libraries, context save 1, 7 tuples
[  345.134963] intcdsp.sys: ipc: link ready, polled, 500 ms per message
[  345.134963] intcdsp.sys: ipc self-test: create pipeline 1: status 0 after 63 us
[  345.134963] intcdsp.sys: ipc self-test: pipeline 1 paused: status 0 after 63 us
[  345.134963] intcdsp.sys: ipc self-test: pipeline 1 running: status 0 after 63 us
[  345.134963] intcdsp.sys: ipc self-test: pipeline 1 paused: status 0 after 63 us
[  345.134963] intcdsp.sys: ipc self-test: pipeline 1 reset: status 0 after 63 us
[  345.134963] intcdsp.sys: ipc self-test: delete pipeline 1: status 0 after 63 us
[  345.134963] intcdsp.sys: ipc self-test: 6 requests, 6 replies, 0 notifications, 0 timeouts, 0 DSP interrupts, ok
```

The seven lines are TESTING.md's, in its order, every status 0, every exchange 63 µs. The second cycle
(`selftest2`, serial lines 203–…) is the same block again: `boot ok after 5737 us (clock 1103775347 us)`, the
seven lines at 63 µs, the summary `ok`. The settings line reads `SelfTest = 1, UseInterrupts = 0, IpcTimeoutMs
= 500 ms` — twice per start, as with `SelfTest = 0` (N9). End clock − start clock − N: 81 µs on all three boots.

The model's registers over qtest (`cycles.log`): disabled, all zero but the host's own field
(`adspcs=00000000 dsp2cxctl=02000000 inten=00000000 irqsts=00000000 hfhipcie=00000000 hfipcxtdr=00000000
hfipcxida=00000000 hfipcxctl=00000000 hfipcxtddy=00000000 fsr=00000000`) — p2b4's reading; in D0 after each
self-test: `adspcs=01010000 dsp2cxctl=02000101 inten=00000000 irqsts=00000000 hfhipcie=00000000
hfipcxtdr=1b080000 hfipcxida=32000000 hfipcxctl=00000000 hfipcxtddy=00000000 fsr=a0000005` — p2b4's D0 reading
except `hfipcxida`: `0x32000000` is the delete-pipeline reply's bits after the acknowledgement (the last
message acknowledged; p2b4's `0x61000000` is the FW_CONFIG reply's — DIVERGENCE.md, the N2 note). The pipeline
table is empty again: the self-test deletes pipeline 1.

### B2 — a plain boot with `SelfTest = 1` persisted: `b2-selftest-boot`

`boot ok after 5987 us (clock 18186887 us) … attempt 1, 0 DSP interrupts, cleanup ok, ADSPCS 0x01010000`
(end − start − N = 321 µs), `firmware ready … 7 tuples`, `ipc: link ready, polled, 500 ms per message`, then
the seven lines at **66 µs** each and the summary `ok` (`selftest-lines.txt`). The VM was stopped on the
summary line (SETTLE 10 s).

### The model's side of the self-test (`b1-selftest/ipc-trace.txt`, `b2-selftest-boot/ipc-trace.txt`)

After the FW_READY notification is taken and acknowledged, each exchange is: the request written to
`HFIPCXIDR`, the driver's polls (a read of `HFIPCXIDA`, a read of `HFIPCXTDR` each), the reply armed by the
model 50 µs after the request, the reply read, `HFIPCXTDDY` read, the acknowledgement (`HFIPCXIDA ← 0x80000000`),
`HFIPCXIDDY ← 0` and the next request. The first cycle of `b1-selftest`, in order:

| # | the request: traced words | written to `HFIPCXIDR` | the reply | the model's decoded line | polls that saw no reply | the driver's line |
|---|---|---|---|---|---|---|
| — | `0x41000000\|0x00700000` | `0xc1000000` | `0xe1000000` | `IPC reply type 1 (config-get) status 0: FW_CONFIG` | 1 | (the boot's own exchange) |
| 1 | `0x11010000\|0x00000000` | `0x91010000` | `0xb1000000` | `IPC reply type 17 (create-pipeline) status 0: pipeline 1 created: priority 0, 0 pages, core 0, low-power 0` | 3 | `create pipeline 1: status 0 after 63 us` |
| 2 | `0x13010003\|0x00000000` | `0x93010003` | `0xb3000000` | `IPC reply type 19 (set-pipeline-state) status 0: pipeline 1: uninitialized -> paused` | 3 | `pipeline 1 paused: status 0 after 63 us` |
| 3 | `0x13010004\|0x00000000` | `0x93010004` | `0xb3000000` | `… status 0: pipeline 1: paused -> running` | 3 | `pipeline 1 running: status 0 after 63 us` |
| 4 | `0x13010003\|0x00000000` | `0x93010003` | `0xb3000000` | `… status 0: pipeline 1: running -> paused` | 3 | `pipeline 1 paused: status 0 after 63 us` |
| 5 | `0x13010002\|0x00000000` | `0x93010002` | `0xb3000000` | `… status 0: pipeline 1: paused -> reset` | 3 | `pipeline 1 reset: status 0 after 63 us` |
| 6 | `0x12010000\|0x00000000` | `0x92010000` | `0xb2000000` | `IPC reply type 18 (delete-pipeline) status 0: pipeline 1 deleted (was reset)` | 3 | `delete pipeline 1: status 0 after 63 us` |

The six words are the plan's §5.5 and TESTING.md's (`0x91010000`, `0x93010003`, `0x93010004`, `0x93010003`,
`0x93010002`, `0x92010000`), instance id 1, extension 0; every reply carries the request's type and status 0;
each is acknowledged by the done bit before the next request is sent.

**The reply delay.** Three polls see no reply and the fourth sees it: the driver polls every 20 µs of guest
time (its stall inside the first millisecond), so the reply arrives between its third poll (≈ 40 µs) and its
fourth (≈ 60 µs) — the model's 50 µs timer, measured by the driver as 62–66 µs (the stall plus the two
reads). The figure is the same in every launch of this round (62, 63, 66 µs), where the boots' own `after N us`
is 5366 µs on this round's idle cycles, 10415–10546 µs on some of its boot-time boots, and 21406–21726 µs and
37806 µs on p2b4's (`DIVERGENCE.md`, E5): the exchange is timed by the model's timer and the driver's 20 µs
stall, both virtual time, not by the loader's byte-by-byte copy nor by what else the guest is doing.

**The stale bits (the model's N2).** After each acknowledgement the reply register keeps the message's bits
with the done bit cleared: the driver reads `HFIPCXIDA 0x31000000` (the create reply's), later `0x33000000`
(the set-state reply's), and `HFIPCXTDR 0x1b080000` (the acknowledged FW_READY notification's) on every poll —
and never takes them for a reply or a notification: it looks at the done bit alone. The transport is not
disturbed by the behaviour the model half listed as a model value (`../MODEL-NOTES.md`, row 16).

## C — the self-test fault rows (`selftest-faults/`)

On the `SelfTest = 1` overlay (`disk/p3c1.qcow2`), the fault set on the command line, one boot per row, then
the fault cleared over QMP and one disable/enable cycle (`tools/fault-matrix.sh RECOVER=1`, its table
`selftest-faults/fault-matrix.md`; `tools/fm-check.sh`: 0 rows with a failed check). The rows as stored:

| fault | the driver's lines after `ipc: link ready` | bounded (guest s from `booting:`) | the model after the row | recovery |
|---|---|---|---|---|
| `ipc-status=5:19` | `ipc self-test: create pipeline 1: status 0 after 63 us` · `ipc: set pipeline state (19) 0x93010003\|0x00000000 status 5 (bad state) after 63 us; the link is faulted` · `ipc self-test: 2 requests, 2 replies, 0 notifications, 0 timeouts, 0 DSP interrupts, failed at pipeline 1 paused` · `DSP power down from state off: ok, cleanup ok, ADSPCS 0x00000000 (SPA 0, CPA 0)` | 0.000 (`boot ok after 5365 us (clock 18574725 us)`) | `adspcs=00000000 hfipcxida=00000000 fsr=00000000` | `boot ok after 5388 us … 0 DSP interrupts`, the seven lines at 62–63 µs, `… 0 timeouts, 0 DSP interrupts, ok` |
| `never-reply=19` | `ipc self-test: create pipeline 1: status 0 after 66 us` · `ipc: set pipeline state (19) 0x93010003\|0x00000000 reply timeout after 500025 us; the link is faulted` · `ipc self-test: 2 requests, 1 replies, 0 notifications, 1 timeouts, 0 DSP interrupts, failed at pipeline 1 paused` · `DSP power down from state off: ok, cleanup ok, ADSPCS 0x00000000 (SPA 0, CPA 0)` | 0.500 (`boot ok after 5736 us (clock 18309717 us)`) | `adspcs=00000000 hfipcxida=00000000 fsr=00000000` | `boot ok after 5366 us … 0 DSP interrupts`, the seven lines at 63 µs, `… ok` |

These are TESTING.md's lines for the two faults — the status word `bad state` for 5 (the P2 ruling), the
counters (`2 requests, 2 replies` and `2 requests, 1 replies, 1 timeouts`), the step (`failed at pipeline 1
paused`), the timeout on its 500 ms budget — except the power-down line's state (`DIVERGENCE.md`, D4).

The trace (`selftest-faults/fm-ipc-status=5_19/qemu-dbg.excerpt.txt`): FW_CONFIG → `0xe1000000`; create
pipeline `0x91010000` → `0xb1000000`, `type 17 (create-pipeline) status 0: pipeline 1 created …`; set-state
`0x93010003` → three polls → `IPC reply primary 0xb3000005`, `IPC reply type 19 (set-pipeline-state) status 5:
pipeline 1: uninitialized -> paused; status 5 injected by the fault`; the driver reads `0xb3000005`, reads
`HFIPCXTDDY`, acknowledges; then `INTEN ← 0` through the pointer, `HfHIPCIE ← 0`, `HFIPCXCTL ← 0`,
`DSP2CXCTL ← 0x02000100`, `state running -> off`, `ADSPCS ← 0x01000000` … the loader's power-down and cleanup
as in the p2b4 faulted boots. The model applies the transition and replaces the status — "the table is still
updated as the message says" (`../MODEL-NOTES.md`, the faults table, `ipc-status=<n>:<type>`): a model value;
the table is emptied by the power-down.

`never-reply=19` (`fm-never-reply=19`): the same up to the set-state request, then `IPC request dropped
(set-pipeline-state) primary 0x13010003 ext 0x00000000` and 1049 polls that read the stale bits
(`HFIPCXIDA 0x31000000`; `HFIPCXTDR 0x1b080000` 1071 times) until the budget: `reply timeout after 500025
us`, the summary with `1 timeouts`, the power-down.

In both rows the device stays started: the shell comes up, the disable of the started device is accepted
(`Safe removal` in `recover.out`), and the enable boots and self-tests again with the summary `ok` — the
pipeline table, emptied by the power-down, accepts pipeline 1's create a second time.

The rows were run three times in the round (the first two while the table format of `tools/fault-matrix.sh`
was still being finished; only the last is kept), and the `ipc-status=5:19` row once more with the final
scripts as a check (not kept; its row equals the kept one apart from the timings). All four runs ended the
same way: `status 5 (bad state) after 66 / 78 / 63 / 63 us`, `reply timeout after 500295 / 500122 / 500025 us`,
bounded, powered down, recovered.

## D — the regression on this image: AC3 and AC4 (`ac3-cycles/`, `fm-<fault>/`, `fault-matrix.md`)

On the copy of the stage-2 overlay taken before `SelfTest` was set (`disk/p3c1-st2.qcow2`: `BootDsp = 1`,
`SelfTest = 0`), so that every row compares with p2b4's.

**AC3** (`ac3-cycles/summary.txt`): `AC3 cycles: 22 run, 22 boot ok, 0 bounded timeouts, 0 other outcomes, 0
waits not seen, clock stalled lines: 0`. 22 disable/enable cycles in one VM: `boot ok after 5366–5693 us`
(15 of them 5366), end clock − start clock − N = 80–82 µs on every one of the 22 (81 µs on 16); the VM's
own boot-time boot, `boot ok after 10415 us (clock 17814116 us)`, shows 1289 µs (`DIVERGENCE.md`, E5; no
budget is near: the smallest is 50 ms). The model's registers before every cycle (all zero but
`dsp2cxctl=02000000`) and after it (`adspcs=01010000 dsp2cxctl=02000101 … hfipcxida=61000000 …
fsr=a0000005`) are identical across the 22 and equal to p2b4's two readings; 23 boots, 23 × `0 DSP interrupts`,
0 `1 DSP interrupts`, 0 `interrupt storm`, 0 `clock stalled`; clean S5 (`Entering sleep state S5.`). Each
cycle's trace holds two writes of 0 through the interrupt pointer: N5's mask at ROM ready and the power-down's
own mask at the disable.

**AC4** (`fault-matrix.md`): **20 of 20 rows bounded**, each on its documented budget, with its named failure,
the device started, no bugcheck, no hang, and a `boot ok` on the next power cycle; `tools/fm-check.sh`: 0 rows
with a failed check (end clock − start clock − N within 80–1289 µs on every row). The terminal lines are
p2b4's: with the timing figures masked, all 20 rows' lines are identical to the p2b4 matrix's (the only
differences are where the script's 200-character cut falls). Over the 40 boots: 40 × `0 DSP interrupts`, 0 ×
`1 DSP interrupts`, `first DSP interrupt`, `interrupt storm`, `clock stalled`, no bugcheck, no hang.

| fault | after N us | booting → line (guest s) | power-downs in the trace |
|---|---|---|---|
| `none` | 5365 | 0.000 | 0 |
| `halt-rom=43` | 8300 | 0.000 | 3 |
| `halt-rom=44` | 10481 | 0.016 | 3 |
| `halt-fw=51` | 6265 | 0.016 | 1 |
| `crash-notification` | 7108 | 0.000 | 1 |
| `abi=2` | 6805 | 0.000 | 1 |
| `window-read-fail` | 6805 | 0.000 | 1 |
| `never-power` | 52007 | 0.047 | 0 |
| `never-ack` | 1509442 | 1.500 | 3 |
| `never-ready` | 909577 | 0.906 | 3 |
| `never-enter` | 3004634 | 3.000 | 1 |
| `never-fwready` | 1006820 | 1.000 | 1 |
| `never-reply` | 511875 | 0.516 | 1 |
| `drop-requests` | 506888 | 0.516 | 1 |
| `ipc-status=5` | 8482 | 0.000 | 1 |
| `bad-tuples` | 7366 | 0.007 | 1 |
| `truncated-reply` | 7740 | 0.016 | 1 |
| `version-shift` | 7748 | 0.000 | 1 |
| `x-delay-scale=1550` | 52473 | 0.062 | 0 |
| `x-delay-scale=0.001` | 5720 | 0.000 | 1 |

The budget rows measure their budgets (`never-ack` 3 × 500 ms, `never-ready` 3 × 300 ms, `never-enter` 3 s,
`never-fwready` 1 s, `never-reply` and `drop-requests` 500 ms, `never-power` and `x-delay-scale=1550` the
50 ms power-up); the unfaulted steps' figures are TCG execution time of this launch (`DIVERGENCE.md`, E5).

## Not run in this round

- **`UseInterrupts = 1`** (TESTING.md: "debug only; not the acceptance configuration"): the seven lines with
  `6 DSP interrupts` in the summary and `ipc: link ready, interrupts on, …` were not measured. The model's
  interrupt path is proven by the qtest (`irq-intx`, `irq-msi`), not by this transport in a VM.
- **S3** (R6's `resident` alone), and everything on silicon.
