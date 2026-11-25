# qemu-ace-dsp — a QEMU model of the Intel ACE 1.0 audio DSP (`intel-hda-ace`)

`intel-hda-ace` is a QEMU device model of the Intel **Smart Sound Technology BUS**
function of Arrow Lake-S/HX (PCI `8086:7f50`, class 0403): the HD Audio
controller QEMU already has (`intel-hda`), plus the **ACE 1.0 audio DSP** that
sits behind the function's second memory BAR (BAR4) — its power and IPC
registers, its SRAM windows, the processing-power and software-position-in-buffer
capabilities the DSP drivers walk, and the **boot handshake** a host driver
performs: power-up, the ROM purge, the code-loader stream that carries the
firmware, FW_READY, the IPC4 configuration reply and the controller interrupt.
Once the firmware runs it also keeps the **pipeline table** a host driver's
streams are made of: create, set-state and delete pipeline are tracked and
answered.

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
| The interrupt | raised only while a message is pending and every enable is set; observed on the INTx line through the I/O APIC and as MSI; counted by the p2b3 driver's ISR (`1 DSP interrupts` on the rows that reach FW_READY); the p2b4 driver masks the enables and polls (`0 DSP interrupts`, the mask in every trace) |
| Fault handling | 16 injectable faults — 18 forms, two of them naming one IPC4 message type (`ipc-status=<n>:<type>`, `never-reply=<type>`) — each with a bounded shape asserted by the qtest |
| The pipeline table | create, set-state and delete pipeline are tracked by instance id and answered with the request's type and a status; a pipeline asked to run before it was paused answers the plan's status 5 and does not move; the table is empty again at every firmware start (patches 0011–0014; qtest `pipeline-table`, `pipeline-illegal`, `pipeline-faults`) |
| The IPC self-test (C1) | the real driver's `SelfTest = 1` path against the pipeline table, on image p3c1: the seven lines of the plan's §8, every exchange `status 0 after 62–66 us`, `6 requests, 6 replies, 0 notifications, 0 timeouts, 0 DSP interrupts, ok`; the two typed fault rows end bounded, power the DSP down and recover (`evidence/2026-11-25-p3c1/vm`) |
| A malformed image | a stream that ends inside a structure of the image is refused with the walk halted in that structure's state and with its code; an offset of the image near 2^32 never makes a read leave the stream (patches 0015–0018; qtest `short-stream`, `wrapped-offset`) |

**Never proves** (silicon truth — only the real device can): the ROM's real
behaviour, its undocumented checks and signature enforcement, powered-down read
values, real timings, the interrupt's trigger type on the real line, the
controller's DMA details, SoundWire, D0i3, the firmware's real pipeline state
machine and status codes beyond the plan's one rule, and the ROM's real codes for a malformed
image. A green VM boot is not silicon proof.

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
`evidence/2026-11-25-p2b3/DIVERGENCE.md`. After the evidence was taken, Task C (patches
0009/0010) made **R1** visible in the model — `HFINTIPPTR` reads all ones while the DSP is
unpowered — and one boot with it shows the driver bounds-checking the pointer and re-reading it
after power-up, so its boot is unchanged (`ac3-r1-model`).

**Round 4 (image p2b4, 2026-11-25): the fix round verified — R1, R2, D3 and R6 measured against the
model of `b139810`; AC3 and AC4 closed again; no new driver divergence.** The driver at `b392065b2cf`
(76 commits over master `f2bf7a98990`, with upstream sync #14) against the model with patches
0001–0010 (unchanged): the stage-1 lines are p2b3's except the two R1 lines (`+0x1108 HFINTIPPTR
0xffffffff` and `HFINTIPPTR 0xffffffff names no 32-bit register inside BAR4: the host IPC interrupt
enable cannot be reached` in place of the `+0x120` read); the boot is **poll-only** — `boot ok …
attempt 1, 0 DSP interrupts` on all 23 boots of the cycle run and on every fault row, no `first DSP
interrupt`, no `interrupt storm` — with the mask in every trace (`HfHIPCIE` read back 0,
`HFIPCXCTL` written 0; nothing written through the pointer, which names no register at that
point); the new `interrupts before power-up` / `subsystem powered` / step lines carry `ADSPCS`,
`HFINTIPPTR`, `INTEN`, `HfHIPCIE` and `HFIPCXCTL` (the pointer reads `0x120` on this model only
from `ROM ready for the firmware`, with the core's power: N5); **D3 is fixed** — `bad-tuples` ends
`boot bad IPC reply … tuple type 0x6 at offset 0x10 of the reply is malformed`, `truncated-reply`
ends `boot truncated`, both power the DSP down and recover; R6 is **not visible in the serial
log** (the `firmware … bytes, ok` line is printed whether or not anything was read: N6). 22
disable/enable cycles: 22 `boot ok` (21406–21726 µs), identical model registers before and after
every one, clean S5; 20 of 20 fault rows bounded, every one with its named failure, and recovered
(`evidence/2026-11-25-p2b4`). What this round found: N5 (a model ordering, with a question for
the silicon list: the `INTEN` mask is skipped when the pointer names no register and is not
repeated), N6, N7 (TESTING.md's "`INTEN` reads 1 before"), N8 (TESTING.md's `drop-requests` row)
and the environment notes E2–E4 (`after N us` is TCG execution time on this host; the wizard's
three pages; sync #14's display-idle lines). `evidence/2026-11-25-p2b4/DIVERGENCE.md`.

**P3 C1, the model half (2026-11-25; no VM run in it — the VM half is Round 5 below).** The model gained the pipeline table
(patches 0011–0014): create, set-state and delete pipeline are parsed as the IPC4 header
lays them out, kept by instance id and answered with the request's type and a status. The
plan gives one rule — a pipeline must be paused before it can run, anything else asked to
run answers status 5 and does not move — and every other answer is a model value, listed
one by one for C6 in `evidence/2026-11-25-p3c1/MODEL-NOTES.md`. Two faults learned to name
one message type: `ipc-status=<n>:<type>` and `never-reply=<type>`. The qtest grew from 9
to 12 cases, the mutation check from 25 to 44 rows, and every reply is now traced decoded
(`IPC reply type 19 (set-pipeline-state) status 0: pipeline 1: paused -> running`). No
driver ran against it yet: the C1 image is the driver half's (`SelfTest=1`), so this round
embarrassed nobody — it prepared the ground. Two plan-side findings for the driver's
owners (`evidence/2026-11-25-p3c1/DIVERGENCE.md`): the VM acceptance line's
`fault=ipc-status=19:17` must read `ipc-status=5:19` under the plan's own `<n>:<type>`
notation, and "status 5" is `IPC4_BAD_STATE` in SOF's error list
(`IPC4_INVALID_RESOURCE_STATE` is 12) — the model answers the plan's number.

**P3 C1, the follow-up (same day; Megan's go after she verified and pushed `4bb8022`).** Three pre-existing
items of the model were fixed or documented, and fixing them found a fourth, worse one. **A guest could crash
the emulator**: the bounds of a read of the streamed image were checked with an addition that wraps in 32-bit
arithmetic, and the offsets are the image's own — with the manifest offset of the test image set to `0xfffffffe`
the model read four gigabytes past the stream and died on a SIGSEGV
(`evidence/2026-11-25-p3c1/n1-payload-reads.md`). Since patches 0017/0018 an image with such an offset is
refused like any other malformed one. **N1**: the ROM's judgement read six words of the image without looking
at the result, so a stream that ended inside a structure was judged on a word of the stack — a stream of 8 KB
was accepted as a firmware and entered; since patches 0015/0016 every such stream is refused with the
structure's state and code. **N3**: `normalise-evidence.sh` prints its summary and exits 0 in every case.
**N2** (the reply register keeps the old message's bits after an acknowledgement) stays as it is by ruling and
is listed as a model value. The qtest grew to 14 cases and the mutation check to 50 rows; the boot-path
comparison was re-run for 18 patches: still 1137 old trace lines in order, none gone.

**Round 5 (image p3c1, 2026-11-25): the C1 simulator round — the driver's self-test against the pipeline table.** The
driver at `9c9a876c6a3` (84 commits over master `f2bf7a98990`, built from `5773fcfa7af`: the `sofipc` transport, the
`SelfTest = 1` path, N5, N6) against the model of `9713aa0` (patches 0001–0018, the binary rebuilt from the series, qtest
14/14 first). **A — regression:** the unfaulted boot is p2b4's (`boot ok … attempt 1, 0 DSP interrupts`, `firmware ready …
7 tuples`); its trace differs from p2b4's in N5's mask at `rom-ready` (+9 lines: the write of 0 through the interrupt
pointer, `HfHIPCIE` and `HFIPCXCTL` masked again), the model's decoded reply line and one timing-dependent poll; the firmware
line says `read` then `resident` at every D0 entry that boots (the VM cannot show `resident` alone: no S3). **B — the C1
acceptance:** with `SelfTest = 1`, after `ipc: link ready, polled, 500 ms per message`, the seven lines of the plan's §8 —
`create pipeline 1`, `paused`, `running`, `paused`, `reset`, `delete pipeline 1`, each `status 0 after 62–66 us`, then `6
requests, 6 replies, 0 notifications, 0 timeouts, 0 DSP interrupts, ok` — on two disable/enable cycles and a plain boot; the
trace holds FW_CONFIG, then type 17, 19 × 4, 18, each reply with the request's type and status 0 after three polls without
one (the model's 50 µs). **C — the self-test fault rows:** `ipc-status=5:19` → `ipc: set pipeline state (19)
0x93010003|0x00000000 status 5 (bad state) after 63 us; the link is faulted`, `2 requests, 2 replies, … failed at pipeline 1
paused`, power-down; `never-reply=19` → `… reply timeout after 500025 us; the link is faulted`, `2 requests, 1 replies, … 1
timeouts …`; both bounded, the DSP off (`adspcs=00000000`), the device started, and a later power cycle `boot ok` with a
passing self-test. **D — the regression:** AC3 22 of 22 (`boot ok after 5366–5693 us`, the model's registers identical before
and after every cycle, p2b4's two readings); AC4 20 of 20 bounded on their budgets with p2b4's terminal lines, recovered, 0
rows with a failed check; `0 DSP interrupts` on every one of the round's 72 DSP boots, no storm, no `clock stalled`. What
this round found: **D4**, a driver-side wording defect (the power-down line names the state *after* the power-down — always
`off` — where TESTING.md expects `ready`); **N9** (the settings line is printed twice per start); what the VM can and cannot
show of N5 (the mask is where TESTING.md says; its effect is not reachable) and of N6; the transport unaffected by the
model's stale reply bits; E5 (`after N us` is about a quarter of p2b4's on this host's launches; the self-test's 62–66 µs is
the same everywhere). `evidence/2026-11-25-p3c1/vm` (`c1-acceptance.md`, `DIVERGENCE.md`). Not run: `UseInterrupts = 1`.

**Round 6 (image p3c2, 2026-11-25): the C2 micro round — the topology selection after `boot ok`.** The first
micro round (the owner's ruling of 2026-11-25: from now on a round is one checkpoint's own acceptance plus one boot
regression; the one full regression runs before C6): three VM boots, four DSP boots, 14 minutes. The driver at
`2285127b060` (86 commits over master `93ab8fd2fc4`: the topology model, the selection, the loopback file on the image,
D4, N9) against the model of `d2dc604` — C1's binary, rebuilt from the series, qtest 14/14 first. **D4 and N9 are
fixed:** every power-down of a booted DSP says `DSP power down from state ready: …` (three), and the settings line
appears once per start (6 for 6). **Without a topology** the boot block is p3c1's, line for line, on all four DSP
boots (`boot ok … attempt 1, 0 DSP interrupts, cleanup ok`), followed by `topology: none selected (no override, no
quirk, no _DSD name); the DSP is powered down, no audio endpoint` and the power-down line — TESTING.md (a)'s two lines
exactly. **With `Topology = sof-ipc4-loopback.tplg`** (two disable/enable cycles and a plain boot) the two lines of
TESTING.md (b) follow `ipc: link ready` with no power-down; the modules line (`copier → id 5, gain → id 7; endpoint
'Loopback' render+capture 48000 Hz 2 ch 16/24/32`) is byte-exact. **Found: T1**, a driver-side wording defect — the
summary line says `2288 bytes` where the file has 4286: it prints the built model's size (`Bytes` is reused for the
measure before the log); **X1** — a disable/enable is a new device object and reads the file again by design, so the
brief's "the second D0 entry keeps the model" is not what a cycle shows: the kept-model line needs an S3 resume, which
the VM cannot do ("no re-read beyond the first" stays unverified). The model: no finding (the first boot's trace is
p3c1 a2's 106 lines plus one more poll; nothing between the FW_CONFIG reply and the power-down).
`evidence/2026-11-25-p3c2` (`c2-acceptance.md`, `DIVERGENCE.md`). Not run: the refusal rows, the self-test with a
topology, the resume.

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
The image of this round: `~/libernt-build-logs/test-audio-intel-sst-p3c3-d8f3a5bc81e/`
(`LiberNT.iso` sha256 `4134a83dfc49…`, `LiberNT.vhd` `07cd865f1930…`, in-ISO `intcdsp.sys`
`4df4d43b23da…` and `hdaudbus.sys` `9d0af5977e5c…`, built from `feat/audio-control-polish @ c595e373b3a`, 91 commits over master `d8f3a5bc81e`; the published tip `dc8c4a75be7` has the same tree; the images of
the earlier rounds are `test-audio-intel-sst-p3c2-93ab8fd2fc4/` (`LiberNT.iso` `5ba330522bd7…`, `2285127b060`),
`test-audio-intel-sst-p3c1-f2bf7a98990/` (`bootcd.iso` `1e381a4be043…`, `9c9a876c6a3`),
`test-audio-intel-sst-p2b4-f2bf7a98990/` (`b392065b2cf`),
`test-audio-intel-sst-p2b3-a19eacb7fea/`, `test-audio-intel-sst-p2b2-a676708a/` and
`test-audio-intel-sst-p2b-*`). Its boot chain
changed since round 1 (FreeLoader is gone; `LiberNT Boot Manager` reads a BCD store and hands
over to the OS loader with `SOS DEBUG DEBUGPORT=COM1 BAUDRATE=115200` — the kernel's debug
output is still on the serial log), and the first boot of a fresh overlay shows a **first-boot
Setup wizard** (`oobe.exe`, from the HKLM `Run` key; it deletes its own `Run` value at start,
so it comes once). Since sync #14 the wizard has **three pages** — language and keyboard, an
account page (Skip), a component-download page (Cancel) — closed with `tab tab ret`, `ret`,
`tab tab tab ret` (Escape and Alt+C are ignored; the p2b3 one-step `tab, tab, ret` only reaches
page 2). The ADSP instance id on the installed image is
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
p2b3 image: `evidence/2026-11-25-p2b3/ac3-interactive`). **On the p2b4 image, with the model of
patches 0009/0010, the same probe reads `+0x1108 HFINTIPPTR 0xffffffff` and prints
`HFINTIPPTR 0xffffffff names no 32-bit register inside BAR4: the host IPC interrupt enable cannot
be reached` in place of the `+0x120 (the interrupt enable register the pointer names)` line**
(`evidence/2026-11-25-p2b4/a1-stage1-firstboot`: the other eleven lines byte-identical to p2b3's,
the six BAR4 reads, 0 `ace_unexpected`): the pointer register is a DSP-domain one and does not
answer while the DSP is unpowered (a model value, the R1 scenario), and the driver (R1) trusts
it only where it is used. **On the p3c1 image** (`evidence/2026-11-25-p3c1/vm/a1-stage1-firstboot`) the same
thirteen lines except the firmware line's wording (N6: `1158164 bytes, read, image`), followed by `intcdsp.sys: SelfTest
= 0, UseInterrupts = 0, IpcTimeoutMs = 500 ms` — printed twice (N9).

Stage 2 (`BootDsp=1`), measured on the p2b4 image (`b392065b2cf`: R1, poll-only) on a plain boot
of the stage-2 overlay under icount (`evidence/2026-11-25-p2b4/a2-stage2-boot`; the p2b3 block,
with a bare `subsystem powered` and `1 DSP interrupts`, is in
`evidence/2026-11-25-p2b3/ac3-boot2-icount`):

```
intcdsp.sys: booting: firmware 'ADSPFW' 2.15.0.1, 1155072 payload bytes in 1 descriptors on stream 1, BAR4 FFFF808007200000, clock 17752743 us at 10000000 Hz
intcdsp.sys: interrupts before power-up: ADSPCS 0x00000000 (SPA 0, CPA 0), HFINTIPPTR 0xffffffff, INTEN 0xffffffff, HfHIPCIE 0x00000000, HFIPCXCTL 0x00000000
intcdsp.sys: subsystem powered: ADSPCS 0x01010000 (SPA 1, CPA 1), HFINTIPPTR 0xffffffff, INTEN 0xffffffff, HfHIPCIE 0x00000000, HFIPCXCTL 0x00000000
intcdsp.sys: code-loader stream 1: 1155072 bytes in 1 descriptors (LVI 0), SPIB 1155072, format 0x0040
intcdsp.sys: ROM ready for the firmware: ADSPCS 0x01010000 (SPA 1, CPA 1), HFINTIPPTR 0x00000120, INTEN 0x00000000, HfHIPCIE 0x00000000, HFIPCXCTL 0x00000000
intcdsp.sys: firmware entered: ADSPCS 0x01010000 (SPA 1, CPA 1), HFINTIPPTR 0x00000120, INTEN 0x00000000, HfHIPCIE 0x00000000, HFIPCXCTL 0x00000000
intcdsp.sys: FW_READY received: ADSPCS 0x01010000 (SPA 1, CPA 1), HFINTIPPTR 0x00000120, INTEN 0x00000000, HfHIPCIE 0x00000000, HFIPCXCTL 0x00000000
intcdsp.sys: boot ok after 67971 us (clock 17821036 us): state ready, failed in off (ok), ROM status 0x00000005 firmware entered, ROM error 0x00000000 unknown ROM error, IPC status 0, last DSP message 0x61000000|0x00000000, attempt 1, 0 DSP interrupts, cleanup ok, ADSPCS 0x01010000
intcdsp.sys: firmware ready: version 2.15.0.1, ABI 1, ROM implementation 0.3 version 1.2 platform 288, ROM info 0x0000005a, downlink mailbox 4096 bytes, uplink mailbox 4096 bytes, trace log 131072 bytes, 16 pipelines, 4 libraries, context save 1, 7 tuples
```

The model's side of the same boot (device trace, 98 lines): power-up (`CPA` on the driver's
first `ADSPCS` poll) → the `subsystem powered` reads (`HFINTIPPTR` all ones: names no register) →
the mask (`HfHIPCIE` ← 0 read back, `HFIPCXCTL` ← 0; no write through the pointer) → the purge
request `0x81004000` → core up → FSR `0x8`, `0x9`, the DONE reply (`0x80000000`, read, then
acknowledged) → `HFINTIPPTR 0x120`, `INTEN 0` (the `ROM ready` reads) → FSR `0x1` (INIT_DONE) →
the stream consumed (`ROM consumes stream 1: 1155072 bytes`, all ROM rules pass) → the walk
`0x25 0x27 0x28 0x29 0x2a`, each state seen on the driver's first FSR poll → `FSR state 0x5
module 0 halted 0` (the ROM's FW_ENTERED) → the FW_READY notification (`0x9b080000`), **no
`DSP interrupt` line: the enables are 0** → the poll reads the notification's extension and
acknowledges it → the FW_CONFIG request `0xC1000000|0x00700000` → the reply `0xE1000000` 50 µs
later → `HFIPCXIDA` read (`0xE1000000`), `HFIPCXTDDY` read, then DONE acknowledged — the
`mtl_ipc_irq_thread` order of the D1 fix, now taken by the poll. (2 ms after entry, `FSR state
0x5 module 2 halted 1`, the firmware's status word.) The p2b3 boot's `DSP interrupt 1` and the
ISR's reads are gone from the trace; the interrupt path itself is still proven by the qtest
(`irq-intx`, `irq-msi`).

On the p2b2 image the same boot stopped after `FW_READY received` (D1); that block is kept in
`evidence/2026-11-24-p2b2/DIVERGENCE.md`.

On the p3c1 image (`9c9a876c6a3`, the C1 driver half) the same boot (`evidence/2026-11-25-p3c1/vm/a2-stage2-boot`) has
three additions and N5's mask in its trace: the settings line `intcdsp.sys: SelfTest = 0, UseInterrupts = 0, IpcTimeoutMs
= 500 ms` (twice: N9), the firmware line's `… 1158164 bytes, read, image …` at the device object's first call and `…
bytes, resident, image …` at the boot's (N6), and the transport's line `intcdsp.sys: ipc: link ready, polled, 500 ms per
message` after `firmware ready`; `boot ok after 10546 us (clock 17990619 us) … attempt 1, 0 DSP interrupts, cleanup ok`.
From the power-up on the trace is p2b4's (92 lines) plus nine — at `rom-ready`, after the pointer first answers `0x120`:
the read of `INTEN`, the write of 0 through the pointer, the read-back, `HfHIPCIE` and `HFIPCXCTL` masked again (N5; the
VM shows the action, not an effect: `INTEN` reads 0 before and after) — plus the model's decoded reply line, minus two
polls that p2b4's launch made before the FW_READY notification.

With `SelfTest = 1` (set in the guest, then a disable/enable: `evidence/2026-11-25-p3c1/vm/b1-selftest`; the settings line
reads `SelfTest = 1, UseInterrupts = 0, IpcTimeoutMs = 500 ms`), the block above is followed by the C1 acceptance lines of
the plan's §8:

```
intcdsp.sys: ipc self-test: create pipeline 1: status 0 after 63 us
intcdsp.sys: ipc self-test: pipeline 1 paused: status 0 after 63 us
intcdsp.sys: ipc self-test: pipeline 1 running: status 0 after 63 us
intcdsp.sys: ipc self-test: pipeline 1 paused: status 0 after 63 us
intcdsp.sys: ipc self-test: pipeline 1 reset: status 0 after 63 us
intcdsp.sys: ipc self-test: delete pipeline 1: status 0 after 63 us
intcdsp.sys: ipc self-test: 6 requests, 6 replies, 0 notifications, 0 timeouts, 0 DSP interrupts, ok
```

Each exchange sits on the model's 50 µs reply timer and is seen by the driver's fourth 20 µs poll (62–66 µs in every launch
of the round). In the trace the six requests are `0x91010000`, `0x93010003`, `0x93010004`, `0x93010003`, `0x93010002`,
`0x92010000` (create, paused, running, paused, reset, delete; instance id 1), each acknowledged before the next, each reply
`status 0` with its type decoded (`IPC reply type 17 (create-pipeline) …`, `type 19 (set-pipeline-state) … pipeline 1:
uninitialized -> paused`, …, `type 18 (delete-pipeline) …`). The model's registers after the self-test are p2b4's D0
reading except `hfipcxida=32000000`, the delete reply's bits kept after the acknowledgement (the model's N2, which the
transport is not disturbed by).

## Acceptance status

| AC | What | Status |
|---|---|---|
| AC1 | qtest passes; mutation check recorded | **PASS** — 15 cases (`evidence/2026-11-25-p3c3/qtest.txt`, 15/15; the 14 of p3c1 in `evidence/2026-11-25-p3c1/qtest.txt`): the 9 earlier ones unchanged (the two-step FSR since patches 0007/0008; case `intipptr` since 0009/0010: all ones unpowered, `0x120` powered, all ones after power-down) and, since patches 0011–0018, `pipeline-table`, `pipeline-illegal`, `pipeline-faults`, `short-stream`, `wrapped-offset`. `mutation-check.sh`: **50 mutations, 49 killed, 1 survivor** (`personality-id`, an equivalent mutant: the class default it changes is overwritten by the personality at realise) — `evidence/2026-11-25-p3c1/mutation-check.md`; each of the 25 rows added since p2b3 is killed by the case that pins it, one of them (`payload-bounds-wrap`, which makes the emulator die) as an abort, and the detector no longer reads an aborted run as a survivor (`SELFTEST=1`); since patches 0019/0020 (the host gateways) the 15th case `audio-loopback`, 5 new rows (`gw-*`) and the 2 affected rows (`ppl-exists`, `ppl-missing`) killed with 0 survivors (`evidence/2026-11-25-p3c3/mutation-check.md`), the full 55-row run before C6. **The boot path itself did not change** (`evidence/2026-11-25-p3c1/boot-path-diff.txt`, re-run for 18 patches): the 10-patch model's 1137 `ace_*` trace lines of cases 1–9 are all present, in order, in the 18-patch model's run, with 16 lines added — all of them the new decoded ones. History: `evidence/2026-11-25-p2b3/mutation-check.md` (25 mutations, 24 killed, 1 survivor) |
| AC2 | VM stage 1: all lines with the model's values, no unexpected access | **PASS** — `evidence/2026-11-24/c2-stage1-run1`; unchanged on the p2b2 image (`evidence/2026-11-24-p2b2/p1-probe-interactive`) and on the p2b3 image (`evidence/2026-11-25-p2b3/ac3-interactive`: the same `intcdsp.sys` lines, the seven BAR4 reads, 0 `ace_unexpected`); **on the p2b4 image** (`evidence/2026-11-25-p2b4/a1-stage1-firstboot`): the same thirteen lines except the two R1 lines (`HFINTIPPTR 0xffffffff`, `names no 32-bit register inside BAR4`), the six BAR4 reads, 0 `ace_unexpected`; **on the p3c1 image** (`evidence/2026-11-25-p3c1/vm/a1-stage1-firstboot`): p2b4's thirteen lines with the firmware line's `read` (N6) and the settings line twice (N9), the six BAR4 reads, 0 `ace_unexpected` |
| AC3 | VM stage 2: `boot ok` attempt 1, version 2.15.0.1 from the streamed bytes, `2 DSP interrupts`, power-down/re-enable twice, 20 cycles | **PASS on the p2b4 image** (`b392065b2cf`, poll-only). Plain boot under icount: `boot ok after 67971 us (clock 17821036 us) … attempt 1, 0 DSP interrupts, cleanup ok, ADSPCS 0x01010000`; end clock = start clock + M within 0.4 ms; `firmware ready: version 2.15.0.1, ABI 1` from the bytes that crossed the DMA. **0 DSP interrupts** (R2: the enables are masked before the ROM request and never enabled; p2b3's `1` was the FW_READY interrupt its ISR took). 22 disable/enable cycles in one VM, 22 `boot ok after 21406–21726 us`, the model's registers identical before (all zero but the host's own `DSP2CXCTL` field) and after every cycle, the clock rule within 80–82 µs on all 23 boots, 0 `clock stalled`, clean S5 (`evidence/2026-11-25-p2b4/ac3-cycles`). **PASS on the p3c1 image** (`9c9a876c6a3`, `SelfTest = 0`): `boot ok after 10415 us (clock 17814116 us) … attempt 1, 0 DSP interrupts` at boot (end clock − start clock − N = 1289 µs there, E5), then 22 disable/enable cycles: 22 `boot ok after 5366–5693 us`, end − start − N 80–82 µs on each, the model's registers identical before and after every cycle and equal to p2b4's two readings, 0 `clock stalled`, clean S5 (`evidence/2026-11-25-p3c1/vm/ac3-cycles`). Earlier rounds: p2b3 `1 DSP interrupts` (N1), p2b2 the D1 hang |
| AC4 | Fault matrix | model side **PASS** (qtest case `faults`, 17 rows + truncated/corrupted/delay-scale; since patches 0013/0014 the case `pipeline-faults`: `ipc-status=5:19`, `ipc-status=7`, `ipc-status=7:1`, `never-reply=19`, `never-reply=1`, `never-reply` — the two typed forms got their VM rows on the C1 image: below). VM matrix on the p2b4 image: **PASS — 20 of 20 rows bounded and named**, every row with a real `after N us` on its documented budget and its two clock readings consistent (80–324 µs), the device started, no bugcheck, no hang, `0 DSP interrupts` on every boot, and a `boot ok` on the next power cycle (`evidence/2026-11-25-p2b4/fault-matrix.md`; `tools/fm-check.sh`: 0 rows with a failed check). `bad-tuples` and `truncated-reply` now end `boot bad IPC reply` / `boot truncated` — **D3 fixed**. **On the p3c1 image: PASS — 20 of 20 boot rows bounded on their budgets with p2b4's terminal lines (timings aside) and recovered (`evidence/2026-11-25-p3c1/vm/fault-matrix.md`, 0 rows with a failed check), and the two typed forms have their VM rows: `ipc-status=5:19` and `never-reply=19` end bounded with TESTING.md's lines, power the DSP down, leave the device started and recover (`selftest-faults/`, 0 failed checks, D4 noted).** History: p2b3 20 of 20 bounded, 18 named (D3); p2b2 7 of 20, the other 13 hung on D1/D2. Table below |
| AC5 | README + scripts reproduce AC2 from a clean checkout | **PASS** — see "Reproducibility" |

### The fix round's expectations (p2b4, TESTING.md of the image) and the measured lines

| item | expectation | measured (model `b139810`) | evidence |
|---|---|---|---|
| R1 | the pointer is read where it is used; all ones / zero / odd name no register | stage 1: `+0x1108 HFINTIPPTR 0xffffffff`, `HFINTIPPTR 0xffffffff names no 32-bit register inside BAR4: the host IPC interrupt enable cannot be reached`, no `+0x120` read; stage 2: `interrupts before power-up: ADSPCS 0x00000000 (SPA 0, CPA 0), HFINTIPPTR 0xffffffff, INTEN 0xffffffff, HfHIPCIE 0x00000000, HFIPCXCTL 0x00000000`, then `0x00000120` from `ROM ready for the firmware` on — **still all ones on `subsystem powered` (N5: the model's domain wakes with the core)** | `a1-stage1-firstboot`, `a2-stage2-boot` |
| R2 | poll-only: the enables masked right after power, `0 DSP interrupts`, no `first DSP interrupt`, no `interrupt storm` | `0 DSP interrupts` on all 23 boots of the cycle run and all 40 matrix boots; the mask in every trace (`HfHIPCIE` ← 0 read back, `HFIPCXCTL` ← 0, no `+0x120` write); 0 `interrupt storm`, 0 `interrupt enable timeout`, 0 `clock stalled` | `a2-stage2-boot`, `ac3-cycles`, `fm-*` |
| D3 | `bad-tuples` → `boot bad IPC reply` + the tuple line; `truncated-reply` → `boot truncated` | `boot bad IPC reply after 70083 us (clock 17618589 us): state failed, failed in configuring (bad IPC reply), … 0 DSP interrupts, cleanup ok, ADSPCS 0x00000000` + `firmware configuration: tuple type 0x6 at offset 0x10 of the reply is malformed`; `boot truncated after 23398 us (clock 18124993 us): state failed, failed in configuring (truncated), …`; both powered down, both recovered with `boot ok` | `fm-bad-tuples`, `fm-truncated-reply` |
| R6 | no second `firmware … bytes, ok` line on a second boot | **not observable**: the line is printed on every `IntcDspLoadFirmware` call, read or resident; the second boot prints it twice, as p2b3 did (N6) | `a4-second-boot` |

### The C2 micro round (image p3c2, 2026-11-25): TESTING.md's expectations and the measured lines

Rounds are micro from now on (the owner's ruling of 2026-11-25): one checkpoint's own acceptance plus one boot regression; the one full regression runs before C6.

| run | expectation (TESTING.md of the image) | measured (model `d2dc604`) | evidence (`evidence/2026-11-25-p3c2/`) |
|---|---|---|---|
| 1 | stage 1 (`BootDsp = 0`): the probe lines unchanged; the settings line once per start (N9) | p3c1's fifteen stage-1 lines minus the second settings line: **1 settings line**; 6 `ace_*` lines, 0 `ace_unexpected`; clean S5 | `r1-stage1-firstboot` |
| 2 | stage 2, no `Topology`: `boot ok … 0 DSP interrupts`; `topology: none selected (…)`; `DSP power down from state ready: …` (D4); the device stays started | `boot ok after 6477 us … attempt 1, 0 DSP interrupts, cleanup ok`; the two lines **exact**, in order, after `ipc: link ready`; the boot block = p3c1 `a2`'s (timings aside); 1 settings line; the device was disabled and enabled twice afterwards | `r2-stage2-no-topology` |
| 3 | `Topology = sof-ipc4-loopback.tplg`, D0 re-entered: the summary line, the modules line, the `boot ok` regression | `boot ok after 5366 us … 0 DSP interrupts`; the modules line **byte-exact**; the summary line = TESTING.md's with **`2288 bytes` for `4286`** (**T1**); no power-down follows | `r2-stage2-no-topology` (`cycle1-override-lines.txt`) |
| 4 | one disable/enable with the override: the second D0 entry keeps the model; the firmware line `resident`; one settings line per entry | firmware `read` then `resident`, 1 settings line, `boot ok after 5366 us … 0 DSP interrupts`; the topology line is the full summary `from the registry override` again — a new device object (**X1**: the kept-model line needs an S3; not shown) | `r2-stage2-no-topology` (`cycle2-override-lines.txt`) |
| 3b | the same by reboot: "exactly these two lines" after `boot ok` and `ipc: link ready` | `boot ok after 5370 us … 0 DSP interrupts`, then the two lines of run 3; 0 power-down lines in the boot | `r3b-topology-plainboot` |

Three VM boots, four DSP boots, 14 minutes: `0 DSP interrupts` on 4 of 4, no `1 DSP interrupts`, no `clock stalled`, no `interrupt storm`, no bugcheck; 6 settings lines for 6 device starts; the model's registers identical to p3c1's cycle readings. The lines in full: `evidence/2026-11-25-p3c2/c2-acceptance.md`; the findings: `DIVERGENCE.md` there.

### The C3 micro round (image p3c3, 2026-11-25): TESTING.md's expectations and the measured lines

The round of the loopback self-test — the first time the tone goes out through the driver, crosses the model's DSP
and has to come back sample-exact. Model `main 264656a` (the binary `a894197d…` of the model half, qtest 15/15
before the first boot). Serial lines are quoted without their timestamps and CR LF; the block in full is
`evidence/2026-11-25-p3c3/vm/r1-firstboot-t1-selftest/selftest-lines.txt`.

| run | expectation (TESTING.md of the image) | measured | evidence (`evidence/2026-11-25-p3c3/vm/`) |
|---|---|---|---|
| 1 | T1: `topology 'sof-ipc4-loopback.tplg': ABI 3.29.1, 4286 bytes (model 2288 bytes), 2 controls, 4 widgets, 2 edges, 1 pcm, 1 pipeline, 0 manifest items, from the registry override` right after `boot ok` and `firmware ready` | **exact** (`grep -Fx`), after `ipc: link ready`, then the modules line byte for byte; `boot ok after 5371 us … attempt 1, 0 DSP interrupts, cleanup ok`; the same line on all 8 DSP boots with a topology of the round — **T1 fixed** | `r1-firstboot-t1-selftest` (`cycles.log`, cycle `t1-1`) |
| 2 | `SelfTest = 2`, D0 re-entered: the three runs' lines (`… offset 0 frames, max abs error 0 … render rms 5793.911, capture rms 5793.911, ok` at 16 bits), the summary `3 runs, 3 matched, 0 failed, 45 requests`, `ran (0x00000000), the DSP is left running` | **differs — fails in its first run, six times alike** (one D0 re-entry, five plain boots): `loopback self-test: endpoint 'Loopback', 48000 Hz 2 ch 16-bit, render stream 1, capture stream 1, 4096 frames` → `4096 frames not captured: 1 of 2 periods after 671 ms (0xc00000b5), failed` → `stopped at render position 8192 (LPIB 8192, buffer 8192), capture position 8192 (LPIB 8192, buffer 8192), 1 capture periods, released: 1 pipelines and 3 instances deleted, 2 streams freed, ok` → `1 runs, 0 matched, 1 failed, 15 requests, 0 notifications, 0 timeouts, 0 DSP interrupts, failed` → `failed (0xc00000b5), the DSP is left running`; the 24- and 32-bit runs and the compare not reached. **D1 and D2, both driver**: the kernel glue's wait cannot succeed (`IntcDspSelfTestWait`, `intcdsp.c:285–340`) and the bus's descriptor lists lie one page below the buffers (`hdac_stream_allocate_buffer`, `hdac_stream.cpp:217`). The model's trace: the 15 requests each `status 0` (create pipeline → init ×3 → bind ×2 → paused → running → paused → large-config set → reset → delete ×3 → delete pipeline), `gateway armed (pipeline 1): host-output copier 5.0 drains stream 1 into host-input copier 5.1's stream 1; 192000 bytes a second`, 15 periods of 8192 bytes on both streams, each period's two `ace_audio 1 8192` lines identical and alternating between `rms 4100.957 … first 0 0 0 0 0 0 0 0` and `rms 5788.873 … first 7094 7094 6499 6499 5792 5792 4986 4986` | `r1-firstboot-t1-selftest` (`selftest-lines.txt`, `selftest-trace.txt`, `ace-audio-lines.txt`); the plain boots `r2`–`r4`; the live dump of the lists and the memory: `r2-selftest-plainboot/livecapture-selftest-cycle2.txt` |
| 3 | `SelfTest = 0`: `boot ok … 0 DSP interrupts`; the topology line; no `clock stalled` / `interrupt storm` / hang / bugcheck; clean S5 | `SelfTest = 0, UseInterrupts = 0, IpcTimeoutMs = 500 ms`; `boot ok after 5366 us (clock 873167361 us) … attempt 1, 0 DSP interrupts, cleanup ok`; the T1 line and the modules line; **no self-test line** in the 25 s after; 0 stall, storm, `Work queue`, bugcheck; `DSP power down from state ready: ok`, `Entering sleep state S5` (the ACPI power button), rc=0. Measured at a disable/enable cycle, not at a system boot (E11) | `r4-regression-selftest0` (`cycles.log`, cycle `selftest0-1`; `s3-selftest0-query-zoom.png`) |

Four VM boots (47 minutes: three ended by a clean S5, one by its wall-clock cap), eight DSP boots: `0 DSP interrupts`
on 8 of 8, no `1 DSP interrupts`, no `clock stalled`, no `interrupt storm`, no bugcheck; 9 settings lines for 9
device starts. The findings with their code: `evidence/2026-11-25-p3c3/DIVERGENCE.md`; the model's values of the
round: `MODEL-NOTES.md` there.

## The fault matrix in the VM (p2b4 image, 2026-11-25)

Rule: *bounded* = the driver logs its terminal line within 30 s of its `booting:` line in guest
time and powers the DSP down; the driver returns `STATUS_SUCCESS` from `D0Entry` on a failed
boot, so a bounded row leaves the device started and the boot continues. Every row below is one
boot of the stage-2 overlay under `-icount` with the logs on tmpfs, followed by a recovery cycle:
the fault cleared over QMP, one `pnputil` disable/enable → a second boot, which must be `boot ok`.
The elapsed figures are the driver's own (`after N us`); its end clock equals its start clock
plus N within 80–324 µs on every row, and the serial-observed duration agrees within one kernel
clock tick (`tools/fm-check.sh`: 0 rows with a failed check; `evidence/2026-11-25-p2b4/fault-matrix.md`).
No bugcheck, no `Work queue … no progress`, no `interrupt storm`, no `clock stalled`, and
`0 DSP interrupts` on every one of the 40 boots; 20 of 20 rows recovered with `boot ok`. The p2b3
table is kept in `evidence/2026-11-25-p2b3/fault-matrix.md`.

| fault | the driver's terminal line (after its `booting:` line) | after N us | booting → line | bounded |
|---|---|---|---|---|
| `none` | `boot ok after 56708 us (clock 17617895 us): state ready, failed in off (ok), …, last DSP message 0x61000000\|0x00000000, attempt 1, 0 DSP interrupts, cleanup ok, ADSPCS 0x01010000` | 56708 | 0.062 s | yes |
| `halt-rom=43` | `boot ROM error … failed in ROM init (ROM error), ROM status 0x80000009 ROM purge boot, ROM error 0x0000002b base firmware not found, …, attempt 3, 0 DSP interrupts, cleanup ok, ADSPCS 0x00000000` | 40800 | 0.047 s | yes (3 power-downs) |
| `halt-rom=44` | `… ROM error 0x0000002c CSE validation failed … attempt 3 … cleanup ok` | 119685 | 0.125 s | yes (3) |
| `halt-fw=51` | `boot ROM error … failed in loading (ROM error), ROM status 0x8000002a ROM firmware code loaded, ROM error 0x00000033 base firmware incompatible, … attempt 1 … cleanup ok` | 38589 | 0.031 s | yes |
| `crash-notification` | `boot firmware crash … failed in FW_READY wait (firmware crash), ROM status 0x00000005 firmware entered, ROM error 0x0000000a unknown ROM error, …, last DSP message 0x1b0a0000\|0x00000000, attempt 1, 0 DSP interrupts, cleanup ok` | 23291 | 0.024 s | yes |
| `abi=2` | `boot ABI mismatch … failed in FW_READY wait (ABI mismatch), ROM status 0x00000005 firmware entered … 0 DSP interrupts, cleanup ok` | 40007 | 0.047 s | yes |
| `window-read-fail` | the same ABI mismatch (window 0 reads all ones) | 73523 | 0.078 s | yes |
| `never-power` | `boot power-up timeout … failed in powering up (power-up timeout), ROM status 0x00000000 init … attempt 0, 0 DSP interrupts, cleanup ok, ADSPCS 0x00000000` (50 ms budget) | 52059 | 0.047 s | yes |
| `never-ack` | `boot ROM init timeout … failed in ROM init (ROM init timeout), ROM status 0x00000000 init … attempt 3 … cleanup ok` (3 × 500 ms) | 1541752 | 1.547 s | yes (3) |
| `never-ready` | `boot ROM status timeout … failed in ROM init (ROM status timeout), ROM status 0x00000009 ROM purge boot … attempt 3 … cleanup ok` (3 × 300 ms) | 941059 | 0.938 s | yes (3) |
| `never-enter` | `boot base firmware timeout … failed in loading (base firmware timeout), ROM status 0x0000002a ROM firmware code loaded … attempt 1 … cleanup ok` (3 s budget) | 3020523 | 3.016 s | yes |
| `never-fwready` | `boot FW_READY timeout … failed in FW_READY wait (FW_READY timeout), ROM status 0x00000005 firmware entered … cleanup ok` (1 s budget) | 1023709 | 1.031 s | yes |
| `never-reply` | `boot IPC reply timeout … failed in configuring (IPC reply timeout) …, last DSP message 0x1b080000\|0x00000000, attempt 1, 0 DSP interrupts, cleanup ok` (500 ms budget) | 539309 | 0.547 s | yes |
| `drop-requests` | `boot IPC reply timeout …` (the FW_CONFIG request is dropped; the same 500 ms budget — TESTING.md's "`boot ok` attempt 3" cannot arise from this fault, N8) | 539659 | 0.531 s | yes |
| `ipc-status=5` | `boot IPC error … failed in configuring (IPC error), … IPC status 5, last DSP message 0x61000005\|0x00000000, attempt 1, 0 DSP interrupts, cleanup ok` | 26956 | 0.016 s | yes |
| `bad-tuples` | **`boot bad IPC reply after 70083 us (clock 17618589 us): state failed, failed in configuring (bad IPC reply), …, attempt 1, 0 DSP interrupts, cleanup ok, ADSPCS 0x00000000`**, then `firmware configuration: tuple type 0x6 at offset 0x10 of the reply is malformed`, then the power-down line — **D3 fixed** | 70083 | 0.078 s | yes |
| `truncated-reply` | **`boot truncated after 23398 us (clock 18124993 us): state failed, failed in configuring (truncated), …, attempt 1, 0 DSP interrupts, cleanup ok, ADSPCS 0x00000000`**, then the power-down line — **D3 fixed** | 23398 | 0.016 s | yes |
| `version-shift` | `boot version mismatch … failed in configuring (version mismatch) … cleanup ok` | 40620 | 0.047 s | yes |
| `x-delay-scale=1550` | `boot power-up timeout … failed in powering up (power-up timeout) …`: every model delay 1550× longer, so the power-up itself (155 ms) exceeds its 50 ms budget long before FW_ENTERED is due — the row measures the power-up budget, not the 3 s base-firmware edge (N4; that edge is `never-enter`'s 3.02 s) | 52378 | 0.047 s | yes |
| `x-delay-scale=0.001` | `boot ROM error … failed in loading (ROM error), ROM status 0xa0000005 firmware entered …`: every model delay 1000× shorter, so the driver's first FSR sample is the firmware's status word | 37083 | 0.031 s | yes |

20 of 20 rows bounded and named (p2b3: 20 bounded, 18 named — `bad-tuples` and `truncated-reply`
booted `ok` with 0-byte mailboxes, D3; p2b2: 7 of 20, the other 13 hung on D1/D2). The elapsed
figures of the unfaulted steps are TCG execution time on this host, not DSP timings (E2 in
`evidence/2026-11-25-p2b4/DIVERGENCE.md`: the loader copies the 1.15 MB payload byte by byte and
`-icount shift=auto` prices those instructions differently per launch); the budget rows
(`never-*`, `drop-requests`, `x-delay-scale=1550`) measure their budgets.


On the p3c1 image the same 20 rows are bounded on the same budgets with the same terminal lines
(`evidence/2026-11-25-p3c1/vm/fault-matrix.md`: `after N us` from 5365 µs to the 3 s of `never-enter`; the
budget rows measure their budgets, the others about a quarter of p2b4's figures — E5), 0 rows with a failed
check, every boot `0 DSP interrupts`.

### The self-test rows (p3c1 image, the guest's `SelfTest = 1`)

The two forms of the injector that name one message type (patches 0013/0014) had no VM row until the C1 image:
on an image without the self-test they boot as `none` does unless the type they name is the boot's own. On
the p3c1 image with `SelfTest = 1` persisted in the guest they are the rows the plan's §8 asks for
(`evidence/2026-11-25-p3c1/vm/selftest-faults`; `tools/fault-matrix.sh` ends such a row with the self-test's
summary, and `tools/fm-check.sh` checks it against TESTING.md: 0 rows with a failed check):

| fault | the driver's lines after `boot ok` and `ipc: link ready` | bounded | the model after the row | recovery (fault cleared, disable/enable) |
|---|---|---|---|---|
| `ipc-status=5:19` | `ipc self-test: create pipeline 1: status 0 after 63 us` · `ipc: set pipeline state (19) 0x93010003\|0x00000000 status 5 (bad state) after 63 us; the link is faulted` · `ipc self-test: 2 requests, 2 replies, 0 notifications, 0 timeouts, 0 DSP interrupts, failed at pipeline 1 paused` · `DSP power down from state off: ok, cleanup ok, ADSPCS 0x00000000 (SPA 0, CPA 0)` (D4: `off`, not `ready`) | 0.000 s | `adspcs=00000000` (powered down) | `boot ok after 5388 us … 0 DSP interrupts`, the seven lines at 62–63 µs, `… ok` |
| `never-reply=19` | `ipc self-test: create pipeline 1: status 0 after 66 us` · `ipc: set pipeline state (19) 0x93010003\|0x00000000 reply timeout after 500025 us; the link is faulted` · `ipc self-test: 2 requests, 1 replies, 0 notifications, 1 timeouts, 0 DSP interrupts, failed at pipeline 1 paused` · the same power-down line | 0.500 s | `adspcs=00000000` | `boot ok after 5366 us …`, the seven lines at 63 µs, `… ok` |

In both rows the device stays started (the shell comes up; the started device is disabled and enabled again)
and the model's table, emptied by the power-down, accepts pipeline 1's create a second time. In the trace the
first row's set-state reply is `0xb3000005` (`IPC reply type 19 (set-pipeline-state) status 5 … status 5 injected
by the fault`); in the second the request is `IPC request dropped (set-pipeline-state)` and the driver polls 1049
times — reading the model's stale reply bits without taking them for a reply or a notification — until its
500 ms budget. The rows were run three times in the round with the same end (63–78 µs; 500025–500295 µs; the
last pass is kept), and the status row once more with the final scripts.

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
| `HFINTIPPTR` | 0x120 once powered (INTEN at BAR4 + 0x120); **all ones while the DSP domain is unpowered** (patches 0009/0010, the R1 scenario: a host that reads it before power-up gets all ones; on the model the domain is powered only with the core's CPA, so the register still reads all ones right after the subsystem's CPA — N5 of the p2b4 round) | compile-time | — |
| Powered-down reads | 0 | `x-powered-down-value` | — |
| Timings | CPA 100/200 µs, DONE 100 µs, INIT_DONE 500 µs, entry 2 ms, FW_READY 200 µs, reply 50 µs | `x-delay-scale` | — |
| ROM info | 0x0120315A | compile-time | — |
| Mailboxes / reply constants | 4096 / 4096 B, 128 KiB trace, 16 pipelines, 4 libraries | compile-time | — |
| FSR at FW_ENTERED | the ROM's word: module ROM, state 5, top bit clear = `0x00000005` | compile-time | — |
| FSR once the firmware runs | `running` (bit 31) \| module BASE_FW \| state 5 = `0xA0000005`, written 2 ms after entry (a model value; silicon: the firmware writes its status during its init, duration unknown) | compile-time | — |
| Pipeline table | 16 entries, instance ids 1–16; a new pipeline is tracked as `uninitialized`; **one rule is judged** — running needs paused, else status 5 (the plan's number; SOF's error list names 5 `IPC4_BAD_STATE`, 12 `IPC4_INVALID_RESOURCE_STATE`: INFO_NEEDED) — every other transition is tracked as asked; set-state/delete of a pipeline that does not exist 9, a second create of an id 10, id 0 or past 16 → 1, a state the ABI lacks → 1, the multi-pipeline form → 7 (not modelled); a reply 50 µs after the request with extension 0; the table emptied at every firmware start and power-down (`evidence/*/MODEL-NOTES.md`) | compile-time | — |
| Interrupt | MSI or INTx | `msi=` | — |

## Layout

| Path | What |
|---|---|
| `COPYING` | QEMU's licence text (GPL-2.0-or-later) |
| `fetch.sh`, `build.sh`, `export-patches.sh` | the pinned source, the build, the series export |
| `patches/0001…0020` | internal header; capability chain (`x-caps`); stream-run + interrupt hooks; `intel-hda-ace`; the qtest; the docs page; the two-step FSR (model, qtest); the interrupt pointer that does not answer while unpowered (model, qtest); the pipeline table with every reply traced decoded (model, qtest); the faults that name one message type (model, qtest); the ROM's judgement refusing a stream cut short (model, qtest); a payload read that never wraps (model, qtest); the host gateways — the module table, audio forwarding, the extended DMA-position registers (model, qtest) |
| `run.sh`, `run-control.sh`, `lib-run.sh`, `make-overlay.sh` | the VM runs (`lib-run.sh`: `ICOUNT=1`, `QTESTSOCK=1`, `FAULT`, `TRACE`, `STOP_ON`, …) |
| `snapshot.sh`, `set-fault.sh`, `tools/` | screenshots, QMP faults; in `tools/`: the monitor/typing helpers (`guest.sh`, `mon.py`, `qmp.py`), the qtest client and heartbeat (`qtest.py`, `heartbeat.py`), `waitline.sh`, `cycle.sh`, `ac3-cycles.sh`, the fault-matrix driver and its post-check (`fault-matrix.sh`, `fm-check.sh` — a `SelfTest = 1` guest's rows end with the self-test's summary) |
| `mutation-check.sh` | AC1's mutation run: one row per model behaviour, each breaking one piece and naming the case that goes red (the detector's rules are in the header; `SELFTEST=1` proves them on synthetic logs; `ONLY=<regex>` runs the rows whose name matches) |
| `evidence/<date>/` | serial logs, device traces and screenshots of every acceptance run (paths normalised) |

## Evidence index

### 2026-11-25-p3c3 (P3 C3: the model half — the host gateways; the VM half — the loopback self-test on image p3c3)

| Run | What it shows |
|---|---|
| `PROVENANCE.md`, `DIVERGENCE.md` | the image hashes verified (`LiberNT.iso`, `LiberNT.vhd`, `LiberNT.img`; the in-ISO `intcdsp.sys`, `hdaudbus.sys`, `sof-ipc4-loopback.tplg` from an independent extraction; the published tip `dc8c4a75be7` has the image's tree); the model's binary of record and the qtest 15/15 before the first VM run; **D1** (the self-test's wait always times out — driver, `intcdsp.c`), **D2** (the descriptor lists one page below the buffers — driver, `hdaudbus`'s `hdac_stream.cpp`), **T1 fixed**, the model half's M1/M2, the environment notes E9–E14 |
| `MODEL-NOTES.md`, `mutation-check.md`, `mutation-run-*.txt`, `affected-rows.*`, `boot-path-check.sh`, `boot-path-diff.txt`, `loopback-trace.txt`, `qtest.txt`, `qtest-full.txt.gz` | the model half: the IPC sequence the model expects, the `ace_audio` line, model values 23–45 and INFO_NEEDED 9–14; the new and affected mutation rows (7 killed, 0 survivors; the full 55-row run is before C6); the boot path unchanged for the 14 old cases; the qtest of the series |
| `vm/qtest-before-vm.txt.gz`, `vm/measured-lines.txt`, `vm/tools-used/` | the qtest before the first VM run; the driver's lines of the four VMs in one file; the throwaway scripts of the round (a read-only qtest dump of the streams; a cycle that stops the VM on the self-test's first line) |
| `vm/r1-firstboot-t1-selftest` | **runs 1 and 2**: the fresh overlay's first boot, `BootDsp=1` and the topology set (`s5-reg-query.png`), the T1 line at cycle `t1-1`, `SelfTest=2` set, the self-test's block at cycle `selftest-1` (`selftest-lines.txt`, `selftest-trace.txt`), the descriptors after the driver's reset (`streamregs-after-selftest-1.txt`); clean S5 |
| `vm/r2-selftest-plainboot` | the self-test at a plain boot and at two cycles; **the live dump of D2** (`livecapture-selftest-cycle2.txt`: the lists, the memory, the sine a page above the list); ended by the wall-clock cap (E9) |
| `vm/r3-selftest0-set` | the self-test at a plain boot again; the console's layout mishap (E10); clean S5 by the power button |
| `vm/r4-regression-selftest0` | **run 3**: `SelfTest=0` read back, the cycle `selftest0-1` with the boot block and the topology lines and no self-test line; clean S5 by the power button |

### 2026-11-25-p3c2 (P3 C2, the micro simulator round: the topology selection after `boot ok` on image p3c2)

| Run | What it shows |
|---|---|
| `PROVENANCE.md`, `qtest.txt` | the image hashes verified (`LiberNT.iso`, `LiberNT.vhd`, `LiberNT.img`); the in-ISO `intcdsp.sys`, `hdaudbus.sys` and `sof-ipc4-loopback.tplg` hashed from an independent extraction; the model binary rebuilt from the series (C1's hashes); the qtest 14/14 before the first VM run; the overlay |
| `c2-acceptance.md` | **the C2 acceptance table**: runs 1–4 and the plain boot 3b — TESTING.md's expectation next to the measured line; the round's counts; what was not run |
| `r1-stage1-firstboot` | **run 1**: the first boot of the fresh overlay — the wizard, `BootDsp=1` set (`s6-reg-query`), p3c1's stage-1 lines with one settings line (`stage1-lines.txt`), clean S5 |
| `r2-stage2-no-topology` | **runs 2–4** in one VM: the fail-safe's two lines (`stage2-lines-none.txt`); the override set and the file listed and hashed in the guest (`topology-set.png`, `topology-dir.png`); two disable/enable cycles (`cycles.log` with the model's registers, `cycle1-` / `cycle2-override-lines.txt`); all 416 `ace_*` lines (`ace-trace.txt`); clean S5 |
| `r3b-topology-plainboot` | a plain boot with the override persisted: TESTING.md (b)'s two lines at boot time, no power-down (`stage2-lines-override.txt`) |
| `trace-regression.txt` | the first boot's device trace against p3c1 `a2-stage2-boot`'s: its 106 lines all present, in order, 2 added |
| `DIVERGENCE.md` | **T1** (the summary line's byte count is the built model's size, not the file's), X1 (a disable/enable is not the kept-model entry: no S3 in the VM), D4 and N9 measured fixed, the environment notes |

### 2026-11-25-p3c1/vm (P3 C1, the simulator round: the driver's IPC self-test against the pipeline table on image p3c1)

| Run | What it shows |
|---|---|
| `PROVENANCE.md`, `qtest.txt` | the image hashes verified, the in-ISO `intcdsp.sys` hash, the model binary rebuilt from the series (the model half's hash), the qtest 14/14 before the first VM run; the two overlays |
| `c1-acceptance.md` | Tasks A–D: the image's expectations → the measured lines (the P2 block with N5 in the trace and N6's wording, the seven self-test lines and the trace sequence of the six requests, the two fault rows, AC3 and AC4); what was not run |
| `a1-stage1-firstboot` | the first boot of the fresh overlay: the three-page wizard, `BootDsp=1` set, p2b4's thirteen stage-1 lines with N6's `read` and the settings line (`stage1-lines.txt`), clean S5 |
| `a2-stage2-boot` | the stage-2 block with the `ipc: link ready` line; the boot's trace next to p2b4's: N5's mask at `rom-ready` (+9 lines), the decoded reply, one poll fewer |
| `b1-selftest`, `b2-selftest-boot` | **the C1 acceptance**: `SelfTest = 1` set in the guest, two disable/enable cycles and a plain boot — the seven lines at 63–66 µs each, the summary `ok`, the settings line `SelfTest = 1`; `ipc-trace.txt`: type 17, 19 × 4, 18, each `status 0` |
| `selftest-faults` | the two self-test fault rows (`ipc-status=5:19`: `status 5 (bad state)`; `never-reply=19`: the 500 ms timeout), each bounded, powered down, recovered with a passing self-test; `fault-matrix.md` with `tools/fm-check.sh`'s self-test table |
| `ac3-cycles` | 22 disable/enable cycles under icount: 22 `boot ok` (5366–5693 µs), the model's registers identical before and after each (= p2b4's), clean S5 (`summary.txt`) |
| `fm-<fault>`, `fault-matrix.md` | the 20 boot rows of the matrix with their recovery cycles; the table in the canonical order and the checks beyond "bounded" (0 rows with a failed check); the terminal lines are p2b4's |
| `DIVERGENCE.md` | **D4** (the power-down line names the state after the power-down), N9 (the settings line twice per start), what the VM can and cannot show of N5 and N6, the transport against the model's stale reply bits, E5–E7, the tooling changes |

### 2026-11-25-p3c1 (P3 C1, the model half: the pipeline table and the faults that name one message type; the follow-up fixes)

| File | What it shows |
|---|---|
| `qtest.txt` | 14/14: the 9 earlier cases unchanged + `pipeline-table`, `pipeline-illegal`, `pipeline-faults`, `short-stream`, `wrapped-offset`; the model and qtest binary hashes (the complete transcript with the `ace_*` trace: `qtest-0001-018.txt.gz`) |
| `boot-path-diff.txt` | the boot path unchanged: the 10-patch model (`qtest-old-0001-0010.txt.gz`) against the 18-patch one, case by case — 1137 old trace lines all present in order, 16 added, all the new decoded lines |
| `pipeline-trace.txt` | the `ace_ipc` trace of one create → state → delete sequence (request, reply, decoded type and status, acknowledgement), then the table's other answers, the illegal transition, and the typed faults |
| `mutation-check.md` | 50 mutations: 49 killed (the first red case and how many cases ran in each row; one row, which makes the emulator die, as an abort), 1 survivor (`personality-id`), 0 not applied |
| `n1-payload-reads.md` | **a guest could crash the emulator**: the record of the SIGSEGV on a wrapped offset of the streamed image and its backtrace; and N1 — what the old model did at each cut of the stream, what the fixed model answers |
| `MODEL-NOTES.md` | every reply value the model chooses — plan-given or model value — with the silicon column left for C6 (rows 1–22), and the INFO_NEEDED list |
| `fault-values.txt` | the fault property on the final binary: the bad values refused on the command line and over QMP (the fault in place kept), the good ones accepted |
| `DIVERGENCE.md` | no driver ran: the follow-up's crash finding and its fix, the rulings P1–P3, N1 and N3 fixed, N2 documented, the detector fix; a pointer to the VM half (`vm/DIVERGENCE.md`) |

### 2026-11-25-p2b4 (the fix round R1/R2/D3/R6 verified on `b392065b2cf`; AC3 and AC4 closed again)

| Run | What it shows |
|---|---|
| `PROVENANCE.md`, `qtest.txt` | the image hashes verified, the in-ISO `intcdsp.sys` hash, the model binary hash, the qtest 9/9 before the first VM run |
| `a1-stage1-firstboot` | the first boot of the fresh overlay: the three-page first-boot wizard (`s1`–`s6`), the stage-1 lines (`stage1-lines.txt`: p2b3's thirteen with the two R1 lines in place of the `+0x120` line), `BootDsp=1` set, clean S5 |
| `a2-stage2-boot` | the full stage-2 sequence with the `interrupts …` lines (`stage2-lines.txt`) and the device trace of the boot (`qemu-dbg.excerpt.txt`): the mask, no `+0x120` write, no `DSP interrupt` line |
| `a4-second-boot` | one disable/enable cycle: the second boot `boot ok … 0 DSP interrupts`; the two `firmware … bytes, ok` lines per start (N6) |
| `ac3-cycles` | 22 disable/enable cycles under icount: 22 `boot ok` (21406–21726 µs), the model's registers before and after each (`cycles.log`: one distinct disabled-state reading, one distinct D0 reading), 0 `clock stalled`, clean S5 (`summary.txt`) |
| `fm-<fault>` | one boot per fault of the matrix under icount, each followed by a recovery cycle (`serial.log`, `recover.out`, the trace excerpt + the whole trace gzipped, `desktop.png`/`console.png`) |
| `fault-matrix.md` | the matrix table in the canonical order (the two D3 rows ran first as a pre-pass) and the checks beyond "bounded" (`tools/fm-check.sh`: 0 rows with a failed check) |
| `task-a.md` | the fix-round expectations → the measured lines (A1–A4), with the environment findings of these boots |
| `DIVERGENCE.md` | D1/D2 re-verified, **D3 fixed**; R1/R2 measured; N5 (the pointer still all ones on `subsystem powered`: a model ordering, the `INTEN` mask skipped), N6 (R6 not observable in the log), N7, N8 (`drop-requests`), E2–E4 (environment); what remains unverified on silicon |

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
| `ac3-r1-model` | one plain boot with the model **after** Task C (patches 0009/0010): the probe reads `HFINTIPPTR 0xffffffff` and skips the register it names; the boot is unchanged (`boot ok after 71859 us … 1 DSP interrupts`) because the driver re-reads the pointer after power-up |
| `mutation-check.md` | AC1's mutation run with the model of this commit: 25 mutations, the `intipptr-unpowered` row added |

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

1. Resolved by image p2b4 (`b392065b2cf`): **D3 is fixed** (`bad-tuples` → `boot bad IPC reply` naming the tuple, `truncated-reply` → `boot truncated`; both power the DSP down and recover); R1 and R2 are measured as TESTING.md describes them (`HFINTIPPTR` all ones before power-up, `0 DSP interrupts` on every boot, the mask in every trace); the earlier rounds are in their evidence trees. Open now: **N5** — whether silicon's `HFINTIPPTR` also reads all ones right after the subsystem's CPA (since image p3c1 the driver repeats the `INTEN` mask at ROM ready, where the pointer first answers on the model: the mask is in every trace of `evidence/2026-11-25-p3c1/vm`, but its effect is not reachable there, since `INTEN` reads 0 before and after — the silicon question stays); **N6** — its log signature exists since image p3c1 (`read` / `resident` in the firmware line; 72 pairs measured); open is R6 on a real sleep/resume, where the line must say `resident` alone (no S3 in the VM); **N8** — TESTING.md's `drop-requests` row; **D4** — fixed on the p3c2 image (`DSP power down from state ready` on its three power-downs of a booted DSP: `evidence/2026-11-25-p3c2/DIVERGENCE.md`), N9 likewise (one settings line per start, 6 of 6); **`UseInterrupts = 1`** — not run in the VM; the storm guard of R2 stays invisible to the model.
2. The real BAR4 size, the capability offsets, the `HFINTIPPTR` value, the powered-down read values, the ROM timings, MSI vs INTx — each replaces a model value above.
3. Whether the real ROM accepts the firmware from this boot path (never answerable by the model).
4. A host whose timer delivery survives a spinning TCG guest and whose disk does not hold a 4 KB write for a quarter second — no longer needed, since every run after the first is made under `-icount` with its logs on tmpfs ("A note on the host"), but such a host would let the non-icount environment be measured too.
5. **The pipeline table (P3 C1, the model half).** On silicon: the status code of an illegal pipeline transition (the plan's 5, or SOF's 12 `IPC4_INVALID_RESOURCE_STATE`), the state a new pipeline is in, the transitions the firmware allows beyond "paused before running", the answers to a duplicate create, an unknown pipeline, instance id 0 (R-G) and the multi-pipeline form, the reply's delay and extension — every row of `evidence/2026-11-25-p3c1/MODEL-NOTES.md`. In the plan: §8 C1's `fault=ipc-status=19:17` had to read `ipc-status=5:19` under the plan's own `<n>:<type>` notation (corrected 2026-11-25). The VM row of the C1 acceptance is measured on image p3c1 (`evidence/2026-11-25-p3c1/vm`): the six `status 0` and the 62–66 µs are the model's (its 50 µs timer, the plan's status 0) seen through the driver's 20 µs poll; what the real firmware answers, and how fast, is the open item.
6. **A malformed image on silicon (the follow-up).** In which state the real ROM halts, and with which error, when the stream ends inside each structure of the image; whether it reads past the stream at all on an offset near 2^32 (`evidence/2026-11-25-p3c1/MODEL-NOTES.md`, rows 17–22); and whether silicon clears the reply register on the acknowledgement (row 16). The model's answers there are model values; what it no longer does is crash.
7. **The topology selection (P3 C2, the micro round on image p3c2).** **T1:** the summary line's byte count is the built model's size (`2288`), not the file's (`4286`) as TESTING.md says — a driver-side wording defect (`drivers/wdm/audio/intcdsp/topology.c:363–396` at `2285127b060`: `Bytes` is reused for the measure before the log). **X1:** "the model is kept while the selection names the same file" is written for a resume; a disable/enable is a new device object and reads the file again by design, so the `resident, the model of the device's first boot` line and "no re-read beyond the first" need an S3 resume (not in the VM): open for silicon. Also not run there: TESTING.md (c)'s refusal rows, "released before any other", the `_DSD` path (no `_DSD` names on this VM's controller), the WIM medium (`BOOTLOADER_WIM_RAMDISK` is off in the image), the self-test with a topology.
8. **The loopback self-test (P3 C3, the VM half on image p3c3).** Two driver-side defects stop the self-test in its first run, before any compare: **D1** the kernel glue's wait compares a per-step progress with the whole buffer, so it always ends in `STATUS_IO_TIMEOUT` (`intcdsp.c:285–340`); **D2** the bus's allocator places every descriptor one page below the buffer for a page-aligned half size (`hdac_stream.cpp:217`, `:240–241`) — `evidence/2026-11-25-p3c3/DIVERGENCE.md`. Open for the driver: both fixes and a rerun of the three runs. Open for silicon once they stand: the firmware's answers of `evidence/2026-11-25-p3c3/MODEL-NOTES.md` (INFO_NEEDED 9–14 there), and the real controller's completion interrupts and positions at the stop (TESTING.md: the positions are 0 on the model, on silicon wherever the streams stopped). Not run in the VM: the compare, the 24- and 32-bit runs, the system boot with `SelfTest = 0`, `UseInterrupts = 1` with the self-test.
