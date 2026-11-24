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
  prose) — no driver source was copied into this project, and nothing from the
  GPL-3 LiberNT tree was used here. Nothing flows back, either.
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
| The interrupt | raised only while a message is pending and every enable is set; observed on the INTx line through the I/O APIC and as MSI |
| Fault handling | 17 injectable faults, each with a bounded shape asserted by the qtest |

**Never proves** (silicon truth — only the real device can): the ROM's real
behaviour, its undocumented checks and signature enforcement, powered-down read
values, real timings, the interrupt's trigger type on the real line, the
controller's DMA details, SoundWire, D0i3. A green VM boot is not silicon proof.

### What the simulator caught on its first real boot

The model is only useful if it can embarrass a driver. On the first `BootDsp=1`
boot of the real LiberNT driver against it, the driver read every probe
register correctly, prepared the loader stream correctly, started its boot state
machine — and **bugchecked on a NULL-pointer dereference inside its own
`IntcDspOpRead32` on the very first read the state machine issued**, before any
BAR4 access reached the model (`cmp qword ptr [rax+0xC8], 0` with `rax = 0`,
called from `FwloadBoot → FwloadUpdate → FwloadRead`). The driver's host test
had run the same state machine against a fake DSP whose operations table
replaced the driver's, so this path had never executed. The evidence is in
`evidence/2026-11-24/c3-stage2-run1` (serial log with the crash dump and the
device trace showing zero boot-path BAR4 accesses). The fix belongs to the
driver; the VM acceptance runs that depend on it (`boot ok`, the VM fault
matrix) are marked *blocked, rerun pending* below.

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
incremental 15–20 s; a VM boot to the driver's probe lines 53 s (live ISO) /
159 s (installed image); the qtest 30 s. Build only on a disk with a few GB
free — never on a tmpfs `/tmp`.

The image under test is set with `ISO=` (a live ISO) or `DISK=` (a disk
image, e.g. a qcow2 overlay made by `make-overlay.sh`), `CDROM=none` to boot
the disk alone; `TRACE=1` enables the device traces; `FAULT=never-reply` (or
`ACE_ARGS=`) configures the model; `STOP_ON='<regex>'` stops the VM at a
serial line; see `lib-run.sh` for the rest. `tools/guest.sh` types into the
guest through the monitor, `snapshot.sh` screenshots it, `set-fault.sh`
injects a fault at run time over QMP.

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

with exactly those seven BAR4 reads in the device trace and no `ace_unexpected`.

## Acceptance status

| AC | What | Status |
|---|---|---|
| AC1 | qtest passes; mutation check recorded | **PASS** — 8 cases; `mutation-check.sh`, results in `evidence/<date>/mutation-check.md` |
| AC2 | VM stage 1: all lines with the model's values, no unexpected access | **PASS** — `evidence/2026-11-24/c2-stage1-run1` |
| AC3 | VM stage 2: `boot ok` attempt 1, version from the streamed bytes, 2 DSP interrupts, power cycles | **BLOCKED** by the driver bug above — rerun pending a fixed driver image; the qtest proves the model side end to end |
| AC4 | Fault matrix | model side **PASS** (qtest case `faults`, 17 rows + truncated/corrupted/delay-scale); VM matrix **BLOCKED** by the same driver bug |
| AC5 | README + scripts reproduce AC2 from a clean checkout | **PASS** — see "Reproducibility" |

Re-running AC3/AC4 once the driver is fixed: `./make-overlay.sh`, boot the
overlay with `CDROM=none`, set `BootDsp=1` in the guest (the overlay
`disk/bootdsp.qcow2` made during this work already carries it), then
`pnputil /disable-device` and `/enable-device` on
`CSAUDIO\ADSP&CTLR_VEN_8086&CTLR_DEV_7F50\4&aeefd634&0&1000000000` (or a
reboot); each fault is `FAULT=<name>` on the command line or `set-fault.sh`.

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
| FSR after entry | running (bit 31) \| module BASE_FW \| state 5 = 0xA0000005 | — | — |
| Interrupt | MSI or INTx | `msi=` | — |

## Layout

| Path | What |
|---|---|
| `COPYING` | QEMU's licence text (GPL-2.0-or-later) |
| `fetch.sh`, `build.sh`, `export-patches.sh` | the pinned source, the build, the series export |
| `patches/0001…0006` | internal header; capability chain (`x-caps`); stream-run + interrupt hooks; `intel-hda-ace`; the qtest; the docs page |
| `run.sh`, `run-control.sh`, `lib-run.sh`, `make-overlay.sh` | the VM runs |
| `snapshot.sh`, `set-fault.sh`, `tools/` | screenshots, QMP faults, monitor/typing helpers |
| `mutation-check.sh` | AC1's mutation run |
| `evidence/<date>/` | serial logs, device traces and screenshots of every acceptance run (paths normalised) |

## Evidence index (2026-11-24)

| Run | What it shows |
|---|---|
| `c1-control-ich9`, `c1-control-ich9-o3` | the stock controller: the four regression lines for `8086:293e` |
| `c1-timing-arch` | the packaged QEMU on the same command line (timing comparison) |
| `c2-stage1-run1` | **AC2**: the real driver's probe on the model |
| `c3-vhd-boot1/2` | the installed image booting on the overlay (stage 1 lines again) |
| `c3-interactive` | BootDsp=1 set in the guest, pnputil disable/enable, the first boot attempt and the crash |
| `c3-stage2-run1/2` | the same on a plain boot: the driver bugcheck with the model's trace |
| `mutation-check.md` | AC1's mutation results |

## INFO_NEEDED

1. The driver fix for the NULL dereference in `IntcDspOpRead32` (LiberNT side), then a fixed image for the AC3/AC4 reruns.
2. The real BAR4 size, the capability offsets, the `HFINTIPPTR` value, the powered-down read values, the ROM timings, MSI vs INTx — each replaces a model value above.
3. Whether the real ROM accepts the firmware from this boot path (never answerable by the model).
