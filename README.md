# qemu-ace-dsp — a QEMU model of the Intel ACE 1.0 audio DSP (`intel-hda-ace`)

`intel-hda-ace` is a QEMU device model of the Intel **Smart Sound Technology BUS**
function of Arrow Lake-S/HX (PCI `8086:7f50`, class 0403): the HD Audio
controller QEMU already has (`intel-hda`), plus the **ACE 1.0 audio DSP** that
sits behind the function's second memory BAR (BAR4) — its power and IPC
registers, its SRAM windows, the processing-power and software-position-in-buffer
capabilities the DSP drivers walk, and the **boot handshake** a host driver
performs: power-up, the ROM purge, the code-loader stream that carries the
firmware, FW_READY, the IPC4 configuration reply and the controller interrupt.

It exists so that an operating system's Intel SST driver can be run and observed
in a VM without the laptop: every MMIO access, the DMA of the firmware, the
state machine's timings and the interrupt path become things you can read in a
serial log next to the device's own trace.

## Licence and provenance

- **GPL-2.0-or-later.** This is a derived work of QEMU: `COPYING` is QEMU's,
  every new file carries QEMU's header text and the SPDX id. The project is a
  patch series against the pinned **QEMU 11.1.3**, never a fork.
- **Every re-declared hardware definition cites its studied source** (one
  citation per block in `intel-hda-ace-regs.h`): Linux v6.12
  `sound/soc/sof/intel/{mtl.h,hda.h}` (dual-licensed BSD-3/GPL-2.0 — own
  declarations, no text copied), the SOF project's IPC4 headers (BSD-3), the
  Intel HD Audio specification, and the pinned firmware file whose `.ri`
  container layout was verified byte for byte.
- **The behaviour was re-derived** from documented facts (the register
  semantics, the SOF boot documentation, the boot handshake as described in
  prose in the plan's P2a/P2b NOTES and the image's TESTING.md) — no driver
  source was copied into this project, and nothing from the GPL-3 LiberNT tree
  was used to shape the model. Nothing flows back, either. Driver-side findings
  are reported in `evidence/*/DIVERGENCE.md` for the driver's owners.
- **AI assistance disclosed:** this model, its tests and this README were
  produced with AI agents under the direction of the project owner, reviewed
  by a human coordinator; every claim below is backed by a stored trace or a
  test run.

## What it proves — and what it never proves

**Proves** (the kernel glue, under real timing, with the real firmware bytes):

| Layer | How |
|---|---|
| PCI/PnP gate | the bus driver creates its DSP child for `8086:7f50` because BAR4 is the function's BAR4 resource and the processing-power capability answers at BAR0 + 0x180 |
| BAR mapping | BAR0 (0x4000) and BAR4 (2 MB) are mapped by the guest's PCI stack; the driver's own probe lines name the offsets it reads |
| Code-loader DMA | the firmware is streamed on an HDA output stream; the model consumes exactly SPIB bytes through QEMU's DMA and writes the stream's completion status as the controller does |
| The P2a boot state machine | power-up, purge, DONE, INIT_DONE, the ROM walk, FW_ENTERED, FW_READY, the IPC4 reply — with virtual-clock timers, polled by the real driver under its real budgets |
| The interrupt | raised only while a message is pending and every enable is set; observed on the INTx line through the I/O APIC and as MSI; counted by the real driver's ISR (`1 DSP interrupts` on the rows that reach FW_READY) |
| Fault handling | 17 injectable faults, each with a bounded shape asserted by the qtest |

**Never proves** (silicon truth — only the real device can): the ROM's real
behaviour, its undocumented checks and signature enforcement, powered-down read
values, real timings, the interrupt's trigger type on the real line, the
controller's DMA details, SoundWire, D0i3. A green VM boot is not silicon proof.

### What the simulator caught on its real boots

The model is only useful if it can embarrass a driver. Two rounds of it did.

**Round 1 (image p2b, 2026-11-24 morning): the driver's NULL ops context.** On
the first `BootDsp=1` boot of the real LiberNT driver against it, the driver read
every probe register correctly, prepared the loader stream correctly, started its
boot state machine — and **bugchecked on a NULL-pointer dereference inside its own
`IntcDspOpRead32` on the very first read the state machine issued**
(`cmp qword ptr [rax+0xC8], 0` with `rax = 0`, called from
`FwloadBoot → FwloadUpdate → FwloadRead`). The driver's host test had run the same
state machine against a fake DSP whose operations table replaced the driver's, so
this path had never executed. Evidence: `evidence/2026-11-24/c3-stage2-run1`.
**Fixed in LiberNT `51679de996b`** ([FWLOAD][INTCDSP] Pass the device as the
operations context), with `9351f39f5f4` (Bdl hardening) and `5286c0598d6`
(WriteMemory removed) on top; rerun on the p2b2 image: the driver now runs
power-up → purge → `ROM ready` → the loader stream (`1155072 bytes in 1
descriptors (LVI 0), SPIB 1155072, format 0x0040`) → the FSR walk →
`firmware entered` → `FW_READY received` with `1 DSP interrupts`, and it is the
*model* that was wrong once on the way (round 2a) and the driver that stops
afterwards (round 2b).

**Round 2a (p2b2 image, this rerun): a model divergence, fixed here.** With the
driver past round 1 it stopped at `boot ROM error … failed in loading (ROM error),
ROM status 0xa0000005 firmware entered, ROM error 0x00000000`. The model wrote
the firmware status register as `running | BASE_FW | FW_ENTERED` in the same
instant the ROM reported FW_ENTERED; the driver samples the top bit (the ROM's
halt bit) before the state code and read its first sample of state 5 as a halt.
The P2a NOTES give the two events as two: the ROM reports FW_ENTERED with the top
bit clear, the *firmware* sets the top bit (`ipc4_fw_status_reg.running`) once it
runs. Since patches 0007/0008 the model reports the ROM's word (`0x00000005`) and
writes the firmware's (`0xA0000005`) 2 ms after entry (a model value: the ROM's word
must stay readable for several 500 µs host polls — a first version wrote it 200 µs
after entry with FW_READY, and on a quiet host the driver's next poll saw the running
bit in its first sample again, the `never-reply` row of the first matrix pass read
`ROM error` instead); the qtest asserts both words and fails on a model that collapses
them (`intel-hda-ace-test.c:333`, `0xA0000005 == 5`). Evidence:
`evidence/2026-11-24-p2b2/p1-probe-interactive`.

**Round 2b (p2b2 image): two driver-side divergences — `evidence/2026-11-24-p2b2/DIVERGENCE.md`.**
D1: after `FW_READY received` the driver sends the FW_CONFIG GET, the model
answers (`HFIPCXIDA` = `0xE1000000`, status 0, the TLV list in the uplink
mailbox), the driver **acknowledges DONE and then polls `HFIPCXIDA`/`HFIPCXTDR`
forever** (> 500 000 reads, no line, no power-down): its receive path consumes
the reply's DONE bit but never hands the reply to the state machine, so `D0Entry`
never returns and PnP cannot finish starting the device (`Work queue 1 has made
no progress`). D2: every "after N us" figure reads 0 and no documented budget
(50 ms … 3 s) ever fires — a `never-power` boot polls for minutes. The VM
acceptance runs that depend on these (`boot ok`, the power cycles, the bounded
fault matrix) are **blocked on the driver** below; the model side is proven by
the qtest.

## Build and run

Requirements: Linux with gcc, ninja, python3 and the glib/pixman development
headers. No root, no system QEMU (QEMU's `configure` builds its own meson).

```sh
./fetch.sh                 # qemu-11.1.3.tar.xz, sha256-pinned, as a git baseline v11.1.3
./build.sh                 # git am patches/*.patch onto v11.1.3 -> configure -> ninja
./run-control.sh           # the stock ich9 controller: the regression control
./run.sh                   # the VM with the model (q35, TCG, -smp 1, OVMF, serial -> file)
```

Measured here: cold build 140 s with stock flags (84 s with
`EXTRA_CONFIGURE="--extra-cflags=-O3 --extra-cflags=-march=x86-64-v3"`),
incremental 15–20 s; a VM boot to the driver's probe lines 15 s (installed image,
host quiet); the qtest ~10 s. Build only on a disk with a few GB free — never on
a tmpfs `/tmp`.

The image under test is set with `ISO=` (a live ISO) or `DISK=` (a disk
image, e.g. a qcow2 overlay made by `make-overlay.sh`), `CDROM=none` to boot
the disk alone; `TRACE=1` enables the device traces; `FAULT=never-reply` (or
`ACE_ARGS=`) configures the model; `STOP_ON='<regex>'` stops the VM at a
serial line; see `lib-run.sh` for the rest. `tools/guest.sh` types into the
guest through the monitor (~100 ms per key), `snapshot.sh` screenshots it,
`set-fault.sh` injects a fault at run time over QMP, `tools/fault-matrix.sh`
boots one fault after another and tabulates the driver's outcome.

The image of this rerun: `~/libernt-build-logs/test-audio-intel-sst-p2b2-a676708a/`
(`bootcd.iso` sha256 `7cb3a12f0ed9…`, `LiberNT.vhd` `2533f34fd44a…`, built from
`feat/audio-control-polish @ 5286c0598d6`). Its boot chain changed since round 1
(FreeLoader is gone; `LiberNT Boot Manager` reads a BCD store and hands over to
the OS loader with `SOS DEBUG DEBUGPORT=COM1 BAUDRATE=115200` — the kernel's
debug output is still on the serial log), and the first boot of a fresh overlay
shows a **first-boot Setup wizard** (`oobe.exe`, from the HKLM `Run` key; Cancel
is harmless — it deletes its own `Run` value at start). The ADSP instance id on
the installed image is `CSAUDIO\ADSP&CTLR_VEN_8086&CTLR_DEV_7F50\4&aeefd634&0&1000000000`.

**A note on the host.** These runs were made on a 4-vCPU VM (CachyOS under its
hypervisor). While a TCG guest spins on time — OVMF's ACPI-PM-timer delay loops,
or the LiberNT driver's TSC stall loop — the host's own timer wakeups are delayed
by seconds to minutes (`rcu: rcu_preempt kthread timer wakeup didn't happen for
116308 jiffies`, `sleep 0.1` taking 98 s) while its clocks stay exact; a plain
host `rdtsc` loop does not reproduce it. The effect: QEMU's virtual clock crawls
while the driver polls (model timers are seen to fire late), some boots sit at
the boot manager for minutes, and the serial output arrives in bursts. It is a
limitation of that host, not of the model or the image; the matrix was therefore
driven by a script and read from the logs afterwards.

The qtest:

```sh
cd build && QTEST_QEMU_BINARY=./qemu-system-x86_64 ./tests/qtest/intel-hda-ace-test
```

## Acceptance log lines

Stage 1 (probe only, the image's default), from the VM's serial console:

```
hdaudbus.sys: ADSP child created on PCI 8086:7f50 (subclass 03): BAR4 register 0x81000000, 0x200000 bytes mapped at ..., processing capabilities at BAR0 +0x180
intcdsp.sys: controller 8086:7f50: BAR0 ... (0x4000 bytes), BAR4 ... (0x200000 bytes), PP capability ...: header 0x10030700 (id 3, version 1, next 0x0700), PPCTL 0x00000000 (GPROCEN 0), PPSTS 0x00000000
intcdsp.sys: BAR4 +0x1000 ADSPCS 0x00000000 (SPA 0, CPA 0), +0x1108 HFINTIPPTR 0x00000120, ...
intcdsp.sys: BAR4 +0x163200 FSR 0x00000000: halted 0, module 0, wait state 0x0, state 0x00 init; +0x163204 ROM error 0x00000000
intcdsp.sys: firmware \SystemRoot\System32\drivers\intel\sof\sof-arl-s.ri: 1158164 bytes, ok, image 'ADSPFW' version 2.15.0.1, 32 modules, payload 0xc14 + 0x11a000, 282 preload pages
intcdsp.sys: BootDsp = 0: probe only, the DSP is not touched
```

with exactly those seven BAR4 reads in the device trace and no `ace_unexpected`
(unchanged on the p2b2 image: `evidence/2026-11-24-p2b2/p1-probe-interactive`).

Stage 2 (`BootDsp=1`), measured on the p2b2 image up to the point where the
driver diverges:

```
intcdsp.sys: BootDsp = 1: the DSP is booted at the next D0 entry
intcdsp.sys: booting: firmware 'ADSPFW' 2.15.0.1, 1155072 payload bytes in 1 descriptors on stream 1, BAR4 FFFF808007200000
intcdsp.sys: subsystem powered
intcdsp.sys: code-loader stream 1: 1155072 bytes in 1 descriptors (LVI 0), SPIB 1155072, format 0x0040
intcdsp.sys: ROM ready for the firmware
intcdsp.sys: firmware entered
intcdsp.sys: DSP message 0x1b080000|0x00000000
intcdsp.sys: FW_READY received
                       <-- D1: the FW_CONFIG reply is acknowledged but never consumed; nothing further
```

The model's side of the same boot (device trace): power-up → purge request
`0x81004000` → core up → FSR `0x8`, `0x9`, the DONE reply, `0x1` (INIT_DONE) →
the stream consumed (`ROM consumes stream 1: 1155072 bytes`, all ROM rules pass)
→ the walk `0x25 0x27 0x28 0x29 0x2a` → `FSR state 0x5 module 0 halted 0` (the
ROM's FW_ENTERED) → 200 µs later the firmware registers and the FW_READY
notification (and, 2 ms after entry, `FSR state 0x5 module 2 halted 1`, the
firmware's status word) → `DSP interrupt 1` on the controller line → the
FW_CONFIG request `0xC1000000|0x00700000` → the reply `0xE1000000` 50 µs later →
the host's `HFIPCXIDA ← 0x80000000`.

## Acceptance status

| AC | What | Status |
|---|---|---|
| AC1 | qtest passes; mutation check recorded | **PASS** — 8 cases, with the two-step FSR since this rerun (patches 0007/0008); `mutation-check.sh` (rows `fsr-running` retargeted and `fsr-entry-running` added; the new assertion fails on the old model), results in `evidence/<date>/mutation-check.md` |
| AC2 | VM stage 1: all lines with the model's values, no unexpected access | **PASS** — `evidence/2026-11-24/c2-stage1-run1`; unchanged on the p2b2 image (`evidence/2026-11-24-p2b2/p1-probe-interactive`) |
| AC3 | VM stage 2: `boot ok` attempt 1, version 2.15.0.1 from the streamed bytes, `2 DSP interrupts`, power-down/re-enable twice, 20 cycles | **BLOCKED — driver divergence D1** on the p2b2 image: the driver reaches `FW_READY received` (so `firmware entered`, the FW_READY interrupt and the version-carrying reply are produced by the model) but never consumes the configuration reply; `D0Entry` hangs. `boot ok`, the cycles and the 20-cycle loop are not reachable with this driver. Model side proven by the qtest; `evidence/2026-11-24-p2b2/DIVERGENCE.md` |
| AC4 | Fault matrix | model side **PASS** (qtest case `faults`, 17 rows + truncated/corrupted/delay-scale). VM matrix on the p2b2 image: **7 of 20 rows** bounded (the single-sample failures: `halt-rom=43/44`, `halt-fw=51`, `crash-notification`, `abi=2`, `window-read-fail`, `x-delay-scale=0.001`); the other 13 are **unbounded** by D2 (no budget fires) or D1 (the reply hang) — the `x-delay-scale=1550` row shows the 3 s budget not firing. Table below; `evidence/2026-11-24-p2b2/fault-matrix.md` |
| AC5 | README + scripts reproduce AC2 from a clean checkout | **PASS** — see "Reproducibility" |

Re-running AC3/AC4 once the driver is fixed: `VHD=<p2b2 LiberNT.vhd>
./make-overlay.sh p2b2`, boot the overlay with `ISO=<p2b2 bootcd.iso>
DISK=disk/p2b2.qcow2 CDROM=none ./run.sh`, set `BootDsp=1` in the guest (Start →
search "cmd" → `reg add "HKLM\SYSTEM\CurrentControlSet\Services\intcdsp\Settings"
/v BootDsp /t REG_DWORD /d 1 /f`, then `pnputil /disable-device` and
`/enable-device` on the instance id above — or a reboot, the value persists in
the overlay); each fault is `FAULT=<name>` on the command line or `set-fault.sh`;
`tools/fault-matrix.sh` runs them all.

## The fault matrix in the VM (p2b2 image, 2026-11-24)

Rule: *bounded* = the driver logs its terminal line (its named failure) within
30 s of its `booting:` line in guest time and powers the DSP down. The driver
always returns `STATUS_SUCCESS` from `D0Entry`, so a bounded row leaves the
device started and the boot continues; an unbounded row is the `D0Entry` hang of
D1/D2 (the device never finishes starting: `Work queue 1 has made no progress`).

| fault | the driver's terminal line (after its `booting:` line) | bounded | booting → line |
|---|---|---|---|
| `halt-rom=43` | `ROM init attempt failed` ×2, `boot ROM error … failed in ROM init (ROM error), ROM status 0x80000009 ROM purge boot, ROM error 0x0000002b base firmware not found … attempt 3, 0 DSP interrupts, cleanup ok`, `DSP power down … ok` | yes | 4.66 s |
| `halt-rom=44` | `… ROM error 0x0000002c CSE validation failed … attempt 3 … cleanup ok` | yes | 0.05 s |
| `halt-fw=51` | `boot ROM error … failed in loading (ROM error), ROM status 0x8000002a ROM firmware code loaded, ROM error 0x00000033 base firmware incompatible … attempt 1 … cleanup ok` | yes | 0.05 s |
| `crash-notification` | `DSP message 0x1b0a0000\|0x00000000`, `boot firmware crash … failed in FW_READY wait (firmware crash) … 1 DSP interrupts, cleanup ok` | yes | 1.32 s |
| `abi=2` | `boot ABI mismatch … failed in FW_READY wait (ABI mismatch), ROM status 0x00000005 firmware entered … 1 DSP interrupts, cleanup ok` | yes | 0.05 s |
| `window-read-fail` | the same ABI mismatch (window 0 reads all ones) | yes | 0.05 s |
| `x-delay-scale=0.001` | `boot ROM error … ROM status 0xa0000005 firmware entered`: every model delay is 1000× shorter, so the driver's first FSR sample sees the firmware's status word | yes | 0.56 s |
| `never-power` | none: polls CPA (50 ms budget) for as long as the VM runs | **no** (D2) | — |
| `never-ack` | none: polls the purge DONE (500 ms budget) forever | **no** (D2) | — |
| `never-ready` | none: polls INIT_DONE (300 ms budget) forever | **no** (D2) | — |
| `never-enter` | none: polls FW_ENTERED (3 s budget) forever | **no** (D2) | — |
| `never-fwready` | none after `firmware entered`: polls FW_READY (1 s budget) forever | **no** (D2) | — |
| `x-delay-scale=1550` (FW_ENTERED at 3.1 s) | `firmware entered`, `FW_READY received` at 9.4 s — **the 3 s base-firmware budget did not fire** — then the D1 hang | **no** (D2, D1) | — |
| `never-reply`, `drop-requests` | none after `FW_READY received`: polls the reply (500 ms budget) forever | **no** (D1/D2) | — |
| `none`, `ipc-status=5`, `bad-tuples`, `truncated-reply`, `version-shift` | none after `FW_READY received`: the reply is acknowledged, never consumed, polls forever | **no** (D1) | — |

Measured on this host, with its timer stalls: 7 of 20 rows bounded, 13 unbounded. The
bounded rows are the failures the driver detects from a single sample (a halted ROM,
the exception notification, the ABI word, the version word read as all ones); every
row that depends on a budget, or on the reply reaching the state machine, hangs. On
a bounded row the driver powers the DSP down and returns; the boot went on without a
bugcheck (the VM was stopped a few seconds after the line, so "device started" was
not verified in the guest; in the interactive session, three disable/enable cycles
after such a failure each produced a fresh boot attempt). Two first attempts that
sat at the boot manager (host stall) were retried; one bounded row (`bad-tuples`, first
pass) came out as the ROM-error path because a stall let the firmware's status word
land before the driver's next FSR poll — the retry on a quieter host shows the D1 hang.

## Model versus silicon

Every value the hardware ABI does not dictate is a model choice, exposed as a
property and printed as "(model value)" in the traces. The right column is
filled from measurements on the real device; "—" means not yet measured.

| Value | Model | Property | Silicon |
|---|---|---|---|
| PCI ID / revision / class | `8086:7f50`, rev 0x10, 0403 prog-if 0x80 | `personality` | `8086:7f50` |
| BAR0 | 0x4000 | — | — |
| BAR4 | 0x200000 (2 MB) | `x-bar4-size` | — (≥ 0x189000 per the driver) |
| LLCH → PP → SPB | 0x14 = 0x0180 → PP (id 3, v1, next 0x700) → SPB (id 4, v1) | compile-time | — |
| `HFINTIPPTR` | 0x120 (INTEN at BAR4 + 0x120) | compile-time | — |
| Powered-down reads | 0 | `x-powered-down-value` | — |
| Timings | CPA 100/200 µs, DONE 100 µs, INIT_DONE 500 µs, entry 2 ms, FW_READY 200 µs, reply 50 µs | `x-delay-scale` | — |
| ROM info | 0x0120315A | compile-time | — |
| Mailboxes / reply constants | 4096 / 4096 B, 128 KiB trace, 16 pipelines, 4 libraries | compile-time | — |
| FSR at FW_ENTERED | the ROM's word: module ROM, state 5, top bit clear = `0x00000005` | compile-time | — |
| FSR once the firmware runs | `running` (bit 31) \| module BASE_FW \| state 5 = `0xA0000005`, written 2 ms after entry (a model value; silicon: the firmware writes its status during its init, duration unknown) | compile-time | — |
| Interrupt | MSI or INTx | `msi=` | — |

## Layout

| Path | What |
|---|---|
| `COPYING` | QEMU's licence text (GPL-2.0-or-later) |
| `fetch.sh`, `build.sh`, `export-patches.sh` | the pinned source, the build, the series export |
| `patches/0001…0008` | internal header; capability chain (`x-caps`); stream-run + interrupt hooks; `intel-hda-ace`; the qtest; the docs page; the two-step FSR (model, qtest) |
| `run.sh`, `run-control.sh`, `lib-run.sh`, `make-overlay.sh` | the VM runs |
| `snapshot.sh`, `set-fault.sh`, `tools/` | screenshots, QMP faults, monitor/typing helpers, the fault-matrix driver |
| `mutation-check.sh` | AC1's mutation run |
| `evidence/<date>/` | serial logs, device traces and screenshots of every acceptance run (paths normalised) |

## Evidence index

### 2026-11-24-p2b2 (the rerun with the fixed driver, image `5286c0598d6`)

| Run | What it shows |
|---|---|
| `p1-probe-interactive` | the boot gate (the new boot manager's serial output), stage 1 unchanged, the first-boot Setup wizard, `BootDsp=1` set, three disable/enable cycles: **round 2a** (the single-instant `0xA0000005` read as a halt), the host-timer stalls (99,640 CPA polls) |
| `x1-boot-no-serial-host-io-stall`, `x2-thread-probe`, `x3-storm-stack` | the rebuilt model: `firmware entered`, `FW_READY received`, then **D1** (the reply acknowledged, > 500 000 `HFIPCXIDA`/`HFIPCXTDR` polls); `x3` has the guest's registers and stack during the hang |
| `fm-<fault>` | one boot per fault of the matrix (`serial.log`, the device trace as `qemu-dbg.excerpt.txt` + `qemu-dbg.log.gz`, a screenshot) |
| `fault-matrix.md` | the matrix table with the driver's lines |
| `DIVERGENCE.md` | D1 and D2 with register values, the trace order and the serial lines |

### 2026-11-24 (round 1, image p2b)

| Run | What it shows |
|---|---|
| `c1-control-ich9`, `c1-control-ich9-o3` | the stock controller: the four regression lines for `8086:293e` |
| `c1-timing-arch` | the packaged QEMU on the same command line (timing comparison) |
| `c2-stage1-run1` | **AC2**: the real driver's probe on the model |
| `c3-vhd-boot1/2` | the installed image booting on the overlay (stage 1 lines again) |
| `c3-interactive` | BootDsp=1 set in the guest, pnputil disable/enable, the first boot attempt and the crash |
| `c3-stage2-run1/2` | the same on a plain boot: the driver bugcheck with the model's trace |
| `mutation-check.md` | AC1's mutation results |

## Reproducibility

`./reproduce.sh` from a clean checkout performs the build, the qtest and the
stage-1 VM run of AC2 and compares the driver's lines with the ones above
(`evidence/2026-11-24/ac5-reproduce.log`, `ac5-clean-TIME.txt`).

## INFO_NEEDED

1. The driver fixes for **D1** (the configuration reply never handed to the state machine; `D0Entry` hangs) and **D2** (the elapsed-time clock reads 0 µs, no budget fires), then an image for the AC3/AC4 reruns: `boot ok`, the power cycles, the 20-cycle loop and a bounded matrix are all one driver fix away from being measurable.
2. The real BAR4 size, the capability offsets, the `HFINTIPPTR` value, the powered-down read values, the ROM timings, MSI vs INTx — each replaces a model value above.
3. Whether the real ROM accepts the firmware from this boot path (never answerable by the model).
4. A host whose timer delivery survives a spinning TCG guest (the matrix here needed a script and retries; see "A note on the host").
