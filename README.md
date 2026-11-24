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
(50 ms … 3 s) ever fires — a `never-power` boot polls for minutes. These blocked the VM
acceptance runs (`boot ok`, the power cycles, the bounded fault matrix) on the p2b2 image; the
model side was proven by the qtest only.

**Round 3 (image p2b3, 2026-11-25): both driver fixes verified, AC3 and AC4 closed, one new divergence.**
D1 and D2 were fixed in LiberNT `39e50ba6036` and `ee1338426b1` (published as image p2b3, built
on master `a19eacb7fea`). Against the same model (`f53ff8b`, patches 0001–0008, unchanged) the
driver now takes the reply on its first poll and acknowledges it after reading the payload (the
`mtl_ipc_irq_thread` order, visible in every trace), prints `boot ok after 21334 us (clock
17954746 us) … attempt 1, 1 DSP interrupts, cleanup ok` on a plain boot and `firmware ready:
version 2.15.0.1, ABI 1`; 22 disable/enable cycles in one VM each end in `boot ok` with the
model's registers reading identically before and after every one; all 20 fault rows end bounded
on their documented budgets, leave the device started and recover on the next power cycle
(`evidence/2026-11-25-p2b3`). What this round found: **D3** — the FW_CONFIG tuple list is
validated by its version tuple only, so the `bad-tuples` and `truncated-reply` rows boot `ok` with
0-byte mailboxes where the plan expected `truncated`/`ipc bad reply`; **E1**, an environment
limitation of the simulator host (the model's timers stand still while the guest's clock runs:
`-icount` is the fix); and three expectation corrections (N1–N3).
`evidence/2026-11-25-p2b3/DIVERGENCE.md`.

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
serial line; `ICOUNT=1` runs under icount (see "A note on the host");
`QTESTSOCK=1` opens a qtest socket for `tools/qtest.py`; see `lib-run.sh` for
the rest. `tools/guest.sh` types into the guest through the monitor (~100 ms
per key), `snapshot.sh` screenshots it, `set-fault.sh` injects a fault at run
time over QMP, `tools/waitline.sh` waits (bounded) for a serial line,
The image of this rerun: `~/libernt-build-logs/test-audio-intel-sst-p2b3-a19eacb7fea/`
(`bootcd.iso` sha256 `2b12b75066da32a8…`, `LiberNT.vhd` `12a232c8ce73e955…`, in-ISO
`intcdsp.sys` `b42955ef…`, built from `feat/audio-control-polish @ ee1338426b1`, 62 commits
over master `a19eacb7fea`; the images of the earlier rounds are
`test-audio-intel-sst-p2b2-a676708a/` and `test-audio-intel-sst-p2b-*`). Its boot chain
changed since round 1 (FreeLoader is gone; `LiberNT Boot Manager` reads a BCD store and hands
over to the OS loader with `SOS DEBUG DEBUGPORT=COM1 BAUDRATE=115200` — the kernel's debug
output is still on the serial log), and the first boot of a fresh overlay shows a **first-boot
Setup wizard** (`oobe.exe`, from the HKLM `Run` key; it deletes its own `Run` value at start,
so it comes once — dismiss it with `tab`, `tab`, `ret` from its first page; Escape and Alt+C
are ignored). The ADSP instance id on the installed image is
`CSAUDIO\ADSP&CTLR_VEN_8086&CTLR_DEV_7F50\4&aeefd634&0&1000000000`.

**A note on the host.** These runs were made on a 4-vCPU VM (CachyOS under its
hypervisor) whose timer delivery stalls under a spinning TCG guest — OVMF's ACPI-PM-timer
delay loops or the LiberNT driver's TSC stall loop (`rcu: rcu_preempt kthread timer wakeup
didn't happen for 116308 jiffies`, `sleep 0.1` taking 98 s) while its clocks stay exact. The
model arms `QEMU_CLOCK_VIRTUAL` timers from its MMIO handlers; without icount that clock is
the host clock and the timers are run by QEMU's main loop, which sleeps in `poll()` until a
host timer or an fd event wakes it — so while the guest polls, the model's µs timers are seen
late (seconds to minutes) although the guest's TSC, read from the host clock, keeps running.
A second, larger stall comes from the evidence logs themselves: every trace and serial line is
a `write()` made from the vCPU thread under the BQL, and on this host's disk (`/home`, btrfs
on the VM's disk; 3.5 ms per 4 KB sync write) a blocked write holds the BQL for 250–285 ms at
a time — measured by a qtest read that was answered that late (`ac3-interactive/heartbeat-*.log`).
With the driver's budgets real since image p2b3, each such stall became a bounded
`boot … timeout` instead of the p2b2 hang (`evidence/2026-11-25-p2b3/DIVERGENCE.md`, E1).
**Every run after the first is made under `ICOUNT=1`** — `-icount shift=auto,align=off,
sleep=off` on `tcg,thread=single`, so the guest clock and the model's timers advance together
by executed instructions and a stall pauses both — **with the live logs on tmpfs** (`EVID=`
under `/tmp`, copied into the evidence tree afterwards). `HEARTBEAT=1` (a side-effect-free
qtest read per millisecond, `tools/heartbeat.py`) keeps the main loop running on a non-icount
VM when that is what you want to measure. A VM boots to the driver's `boot ok` in 40 s of wall
time under icount; every run is scripted, bounded and stopped from its script.
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
(unchanged on the p2b2 image: `evidence/2026-11-24-p2b2/p1-probe-interactive`; and on the
p2b3 image: `evidence/2026-11-25-p2b3/ac3-interactive`).

Stage 2 (`BootDsp=1`), measured on the p2b3 image (`ee1338426b1`, the driver with the D1/D2
fixes) on a plain boot of the overlay under icount (`evidence/2026-11-25-p2b3/ac3-boot2-icount`):

```
intcdsp.sys: BootDsp = 1: the DSP is booted at the next D0 entry
intcdsp.sys: booting: firmware 'ADSPFW' 2.15.0.1, 1155072 payload bytes in 1 descriptors on stream 1, BAR4 FFFF808007200000, clock 17933371 us at 10000000 Hz
intcdsp.sys: subsystem powered
intcdsp.sys: code-loader stream 1: 1155072 bytes in 1 descriptors (LVI 0), SPIB 1155072, format 0x0040
intcdsp.sys: ROM ready for the firmware
intcdsp.sys: firmware entered
intcdsp.sys: FW_READY received
intcdsp.sys: boot ok after 21334 us (clock 17954746 us): state ready, failed in off (ok), ROM status 0x00000005 firmware entered, ROM error 0x00000000 unknown ROM error, IPC status 0, last DSP message 0x61000000|0x00000000, attempt 1, 1 DSP interrupts, cleanup ok
intcdsp.sys: firmware ready: version 2.15.0.1, ABI 1, ROM implementation 0.3 version 1.2 platform 288, ROM info 0x0000005a, downlink mailbox 4096 bytes, uplink mailbox 4096 bytes, trace log 131072 bytes, 16 pipelines, 4 libraries, context save 1, 7 tuples
```

The model's side of the same boot (device trace, 94 lines): power-up (`CPA` on the driver's
first `ADSPCS` poll) → the purge request `0x81004000` → core up → FSR `0x8`, `0x9`, the DONE
reply (`0x80000000`, read, then acknowledged) → the driver enables the three interrupts → FSR
`0x1` (INIT_DONE) → the stream consumed (`ROM consumes stream 1: 1155072 bytes`, all ROM rules
pass) → the walk `0x25 0x27 0x28 0x29 0x2a`, each state seen on the driver's first FSR poll →
`FSR state 0x5 module 0 halted 0` (the ROM's FW_ENTERED) → the FW_READY notification
(`0x9b080000`) → `DSP interrupt 1` → the ISR reads `HFIPCXIDA`, `HFIPCXTDR`, `INTEN` and masks
the three enables → `DSP interrupt 0` → the receive path reads the notification's extension and
acknowledges it → the FW_CONFIG request `0xC1000000|0x00700000` → the reply `0xE1000000` 50 µs
later → `HFIPCXIDA` read (`0xE1000000`), `HFIPCXTDDY` read, then DONE acknowledged — the
`mtl_ipc_irq_thread` order of the D1 fix. (2 ms after entry, `FSR state 0x5 module 2 halted 1`,
the firmware's status word.) The per-message `DSP message` line of the p2b2 image is gone: the
last message is the `last DSP message 0x61000000|…` field of the `boot ok` line (the reply:
module target, direction reply, status 0).

On the p2b2 image the same boot stopped after `FW_READY received` (D1); that block is kept in
`evidence/2026-11-24-p2b2/DIVERGENCE.md`.

## Acceptance status

| AC | What | Status |
|---|---|---|
| AC1 | qtest passes; mutation check recorded | **PASS** — 8 cases, with the two-step FSR since this rerun (patches 0007/0008); `mutation-check.sh` (rows `fsr-running` retargeted and `fsr-entry-running` added; the new assertion fails on the old model), results in `evidence/<date>/mutation-check.md` |
| AC2 | VM stage 1: all lines with the model's values, no unexpected access | **PASS** — `evidence/2026-11-24/c2-stage1-run1`; unchanged on the p2b2 image (`evidence/2026-11-24-p2b2/p1-probe-interactive`) and on the p2b3 image (`evidence/2026-11-25-p2b3/ac3-interactive`: the same `intcdsp.sys` lines, the seven BAR4 reads, 0 `ace_unexpected`) |
| AC3 | VM stage 2: `boot ok` attempt 1, version 2.15.0.1 from the streamed bytes, `2 DSP interrupts`, power-down/re-enable twice, 20 cycles | **PASS on the p2b3 image** (`ee1338426b1`), with one correction to the expectation. Plain boot under icount: `boot ok after 21334 us (clock 17954746 us) … attempt 1, 1 DSP interrupts, cleanup ok`, end clock = start clock + M within 50 µs; `firmware ready: version 2.15.0.1, ABI 1` from the bytes that crossed the DMA. **1 DSP interrupt, not 2** (N1: the ISR masks the three enables before the FW_CONFIG request, so the reply is taken by the poll; the FW_READY interrupt is raised and taken on every boot). 22 disable/enable cycles in one VM (the two of the plan and the 20-cycle rehearsal), each `boot ok after 21318–21472 us`, the model's registers identical before (all zero but the host's own `DSP2CXCTL` field) and after every cycle, 0 `clock stalled`, clean S5 at the end (`ac3-cycles-icount`). A first interactive session on the non-icount host (`ac3-interactive`) had 17 `boot ok` and 5 bounded `power-up timeout after ≈53 ms` at the host's main-loop stalls (E1), each followed by an unassisted `boot ok` |
| AC4 | Fault matrix | model side **PASS** (qtest case `faults`, 17 rows + truncated/corrupted/delay-scale). VM matrix on the p2b3 image: **PASS — 20 of 20 rows bounded** (on the p2b2 image 7 of 20, the other 13 hung on D1/D2), every row with a real `after N us` on its documented budget and its two clock readings consistent, the device started, no bugcheck, no hang, and a `boot ok` on the next power cycle (`evidence/2026-11-25-p2b3/fault-matrix.md`; `tools/fm-check.sh`: 0 failed checks). 18 rows name the expected failure; `bad-tuples` and `truncated-reply` end in `boot ok` with 0-byte mailboxes instead of `truncated`/`ipc bad reply` — **driver divergence D3**. Table below |
| AC5 | README + scripts reproduce AC2 from a clean checkout | **PASS** — see "Reproducibility" |
## The fault matrix in the VM (p2b3 image, 2026-11-25)

Rule: *bounded* = the driver logs its terminal line within 30 s of its `booting:` line in guest
time and powers the DSP down; the driver returns `STATUS_SUCCESS` from `D0Entry` on a failed
boot, so a bounded row leaves the device started and the boot continues. Every row below is one
boot of the overlay under `-icount` with the logs on tmpfs, followed by a recovery cycle: the
fault cleared over QMP, one `pnputil` disable/enable → a second boot, which must be `boot ok`.
The elapsed figures are the driver's own (`after N us`); its end clock equals its start clock
plus N within 41–1812 µs on every row, and the serial-observed duration agrees within one kernel
clock tick (`tools/fm-check.sh`; `evidence/2026-11-25-p2b3/fault-matrix.md`). No bugcheck and no
`Work queue … no progress` line in any row; 20 of 20 rows recovered with `boot ok`.

| fault | the driver's terminal line (after its `booting:` line) | after N us | booting → line | bounded |
|---|---|---|---|---|
| `none` | `boot ok after 21299 us (clock 17881193 us): state ready, failed in off (ok), …, last DSP message 0x61000000\|0x00000000, attempt 1, 1 DSP interrupts, cleanup ok` | 21299 | 0.031 s | yes |
| `halt-rom=43` | `boot ROM error … failed in ROM init (ROM error), ROM status 0x80000009 ROM purge boot, ROM error 0x0000002b base firmware not found, … attempt 3, 0 DSP interrupts, cleanup ok` | 73086 | 0.062 s | yes (3 power-downs) |
| `halt-rom=44` | `… ROM error 0x0000002c CSE validation failed … attempt 3 … cleanup ok` | 50415 | 0.047 s | yes (3) |
| `halt-fw=51` | `boot ROM error … failed in loading (ROM error), ROM status 0x8000002a ROM firmware code loaded, ROM error 0x00000033 base firmware incompatible … attempt 1 … cleanup ok` | 261959 | 0.266 s | yes |
| `crash-notification` | `boot firmware crash … failed in FW_READY wait (firmware crash), ROM status 0x00000005 firmware entered, ROM error 0x0000000a unknown ROM error, …, last DSP message 0x1b0a0000\|0x00000000, attempt 1, 1 DSP interrupts, cleanup ok` | 39018 | 0.047 s | yes |
| `abi=2` | `boot ABI mismatch … failed in FW_READY wait (ABI mismatch), ROM status 0x00000005 firmware entered … 1 DSP interrupts, cleanup ok` | 39025 | 0.031 s | yes |
| `window-read-fail` | the same ABI mismatch (window 0 reads all ones) | 69180 | 0.078 s | yes |
| `x-delay-scale=0.001` | `boot ROM error … failed in loading (ROM error), ROM status 0xa0000005 firmware entered …`: every model delay 1000× shorter, so the driver's first FSR sample is the firmware's status word | 71074 | 0.062 s | yes |
| `never-power` | `boot power-up timeout … failed in powering up (power-up timeout), ROM status 0x00000000 init … attempt 0, 0 DSP interrupts, cleanup ok` (50 ms budget) | 52080 | 0.047 s | yes |
| `never-ack` | `boot ROM init timeout … failed in ROM init (ROM init timeout), ROM status 0x00000000 init … attempt 3 … cleanup ok` (3 × 500 ms) | 1573309 | 1.563 s | yes (3) |
| `never-ready` | `boot ROM status timeout … failed in ROM init (ROM status timeout), ROM status 0x00000009 ROM purge boot … attempt 3 … cleanup ok` (3 × 300 ms) | 925159 | 0.925 s | yes (3) |
| `never-enter` | `boot base firmware timeout … failed in loading (base firmware timeout), ROM status 0x0000002a ROM firmware code loaded … attempt 1 … cleanup ok` (3 s budget) | 3037514 | 3.047 s | yes |
| `never-fwready` | `boot FW_READY timeout … failed in FW_READY wait (FW_READY timeout), ROM status 0x00000005 firmware entered … cleanup ok` (1 s budget) | 1022485 | 1.016 s | yes |
| `never-reply` | `boot IPC reply timeout … failed in configuring (IPC reply timeout) …, last DSP message 0x1b080000\|0x00000000, attempt 1, 1 DSP interrupts, cleanup ok` (500 ms budget) | 539340 | 0.547 s | yes |
| `drop-requests` | `boot IPC reply timeout …` (the request is dropped; the same 500 ms budget) | 573398 | 0.578 s | yes |
| `ipc-status=5` | `boot IPC error … failed in configuring (IPC error), … IPC status 5, last DSP message 0x61000005\|0x00000000, attempt 1, 1 DSP interrupts, cleanup ok` | 40403 | 0.047 s | yes |
| `version-shift` | `boot version mismatch … failed in configuring (version mismatch) … cleanup ok` | 40416 | 0.047 s | yes |
| `x-delay-scale=1550` | `boot power-up timeout … failed in powering up (power-up timeout) …`: every model delay 1550× longer, so the power-up itself (155 ms) exceeds its 50 ms budget long before FW_ENTERED is due — the row measures the power-up budget, not the 3 s base-firmware edge (that edge is `never-enter`'s 3.04 s) | 52503 | 0.047 s | yes |
| `bad-tuples` | **`boot ok after 21344 us … state ready …`**, then `firmware ready: … downlink mailbox 0 bytes, uplink mailbox 0 bytes, trace log 0 bytes, 0 pipelines, 0 libraries, context save 0, 3 tuples` | 21344 | 0.021 s | yes — **but no failure named: D3** |
| `truncated-reply` | **`boot ok after 21303 us … state ready …`**, `… 1 tuples` | 21303 | 0.016 s | yes — **D3** |

20 of 20 rows bounded (on the p2b2 image: 7 of 20, the other 13 hung on D1/D2 —
`evidence/2026-11-24-p2b2/fault-matrix.md`). Eighteen rows name the failure the plan and the
image's TESTING.md expect, each on its documented budget. Two rows end bounded but **not with a
failure**: `bad-tuples` and `truncated-reply` boot as `ok` — the driver validates the FW_CONFIG
tuple list by its version tuple only (**D3**, `DIVERGENCE.md`). The run was interrupted by a host
restart after row 9 and resumed with the same command (`evidence/2026-11-25-p2b3/PAUSED.md`).
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
| `run.sh`, `run-control.sh`, `lib-run.sh`, `make-overlay.sh` | the VM runs (`lib-run.sh`: `ICOUNT=1`, `QTESTSOCK=1`, `FAULT`, `TRACE`, `STOP_ON`, …) |
| `snapshot.sh`, `set-fault.sh`, `tools/` | screenshots, QMP faults; in `tools/`: the monitor/typing helpers (`guest.sh`, `mon.py`, `qmp.py`), the qtest client and heartbeat (`qtest.py`, `heartbeat.py`), `waitline.sh`, `cycle.sh`, `ac3-cycles.sh`, the fault-matrix driver and its post-check (`fault-matrix.sh`, `fm-check.sh`) |
| `mutation-check.sh` | AC1's mutation run |
| `evidence/<date>/` | serial logs, device traces and screenshots of every acceptance run (paths normalised) |

## Evidence index

### 2026-11-25-p2b3 (AC3/AC4 closed on the image with the D1/D2 fixes, `ee1338426b1`)

| Run | What it shows |
|---|---|
| `ac3-interactive` | the first boot of the fresh overlay on the non-icount host: stage 1 unchanged, the first-boot wizard, `BootDsp=1` set, the first D0 entry failing bounded (`boot power-up timeout after 53231 us`, E1), then 22 disable/enable cycles with the qtest heartbeat (17 `boot ok`, 5 `power-up timeout` at the host's 250–285 ms main-loop stalls, each read by the heartbeat: `heartbeat-c*.log`); the model's registers between cycles in `cycles.log` and `model-state.log`; clean S5 |
| `ac3-boot2-icount` | **AC3 at boot**: a plain reboot of the overlay under `-icount`, no heartbeat: `boot ok after 21334 us (clock 17954746 us) … attempt 1, 1 DSP interrupts`, `firmware ready: version 2.15.0.1, ABI 1`; the device trace of the whole boot (94 lines) |
| `ac3-cycles-icount` | **AC3's cycles**: 22 disable/enable cycles under icount, 22 `boot ok` (21318–21472 us), the model's registers read before and after each (`cycles.log`: one distinct disabled-state reading, one distinct D0 reading), 0 `clock stalled`, clean S5 (`summary.txt`) |
| `fm-<fault>` | one boot per fault of the matrix under icount, each followed by a recovery cycle (`serial.log`, `recover.out`, the trace excerpt + the whole trace gzipped, `desktop.png`/`console.png`); `fm-never-ready-partial` is the row that was in flight when the host was restarted (not a result) |
| `fault-matrix.md` | the matrix table (fault → the driver's line → elapsed → bounded → recovery; the first 9 rows from before the restart, the rest from the resumed run) and the checks beyond "bounded" (`tools/fm-check.sh`: 0 failed) |
| `DIVERGENCE.md` | D1 and D2 marked fixed with the rerun evidence; **D3** (FW_CONFIG tuple validation, driver); E1 (environment), N1–N3 (expectation corrections), N4 (scenario note) |
| `PAUSED.md` | where the run stood when the host was restarted (9 of 20 rows in) and how it was resumed |

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

1. Resolved by image p2b3 (`39e50ba6036`, `ee1338426b1`): AC3 and AC4 are measured above. Open on the driver side now: **D3** (the FW_CONFIG tuple list is validated by its version tuple only — `bad-tuples` and `truncated-reply` boot `ok` with 0-byte mailboxes; `evidence/2026-11-25-p2b3/DIVERGENCE.md`), and from the read-only review, invisible to the model as it is: **R1** (the interrupt-enable offset is read before the subsystem is powered; the model answers `0x120` at any power state — a model that answers all-ones while unpowered would make it visible) and **R2** (no ISR storm guard). An image with their fixes is the next thing to rerun.
2. The real BAR4 size, the capability offsets, the `HFINTIPPTR` value, the powered-down read values, the ROM timings, MSI vs INTx — each replaces a model value above.
3. Whether the real ROM accepts the firmware from this boot path (never answerable by the model).
4. A host whose timer delivery survives a spinning TCG guest and whose disk does not hold a 4 KB write for a quarter second — no longer needed, since every run after the first is made under `-icount` with its logs on tmpfs ("A note on the host"), but such a host would let the non-icount environment be measured too.
