# DIVERGENCE — LiberNT `intcdsp.sys` (image p2b2, `feat/audio-control-polish @ 5286c0598d6`) against the ACE model

Written by the simulator side (qemu-ace-dsp). Nothing in the driver was patched; the
LiberNT tree was read for diagnosis only. Image: `bootcd.iso` sha256 `7cb3a12f0ed9…`,
`LiberNT.vhd` `2533f34fd44a…`; `intcdsp.sys` in the image = `f62596f7…` (the build tree's
binary). Model: the qemu-ace-dsp series of 2026-11-24 with the FSR fix of this session
(patches 0007/0008), QEMU 11.1.3, q35, TCG, `-smp 1`.

Two driver-side divergences were found. The first is **blocking** for AC3/AC4: with
`BootDsp=1` the driver's `D0Entry` never returns against a faithful model, so the device
never finishes starting and the system boot hangs at it. The second removes every bound
the driver's state machine is documented to have, which turns every "wait for X" failure
into a hang.

## D1 (blocking) — the FW_CONFIG reply is acknowledged but never handed to the state machine; `D0Entry` hangs

### What the model does (per plan §4.1 "The first IPC" and Linux `mtl.c`)

- FW_READY: `HFIPCXTDR` busy | `0x1b080000` (GLB notification, FW_READY), `HFIPCXTDDY` 0, controller
  interrupt raised (observed: `DSP interrupt 1`, the driver's ISR masks the three enables).
- The host's FW_CONFIG GET: `HFIPCXIDDY` ← `0x00700000`, `HFIPCXIDR` ← `0xC1000000`.
- 50 µs later the reply: `HFIPCXIDA` = `0xE1000000` (DONE | target=module | dir=reply | type 1 |
  status 0), `HFIPCXTDDY` 0, the TLV list (`FW_VERSION` = the streamed 2.15.0.1, then the model's
  constants, a zero header) written to the uplink mailbox, window 0 + 0x1000.
- The host acknowledges DONE by writing bit 31 (the model clears only DONE: `0x61000000` stays
  readable, the W1C semantics Linux relies on when it reads the status before clearing).

### What the driver does (serial log and device trace, runs `x3-storm-stack` / `x2-thread-probe`; reproduced on a quiet host as `fm-none`)

```
[    4.409505] intcdsp.sys: booting: firmware 'ADSPFW' 2.15.0.1, 1155072 payload bytes in 1 descriptors on stream 1, BAR4 FFFF808007200000
[    4.409505] intcdsp.sys: subsystem powered
[    4.4xxxxx] intcdsp.sys: code-loader stream 1: 1155072 bytes in 1 descriptors (LVI 0), SPIB 1155072, format 0x0040
[    4.409505] intcdsp.sys: ROM ready for the firmware
[    4.409505] intcdsp.sys: firmware entered
[    4.409505] intcdsp.sys: DSP message 0x1b080000|0x00000000
[    4.409505] intcdsp.sys: FW_READY received
                       <-- nothing further from the driver, ever
[  113.937977] (\ntos\ex\exworker.c:439) Work queue 1 has made no progress for 3 passes   (repeats every few seconds)
```

The device trace after the FW_CONFIG request (`trace_ace_*`, in order):

```
ace_reg_write BAR4 +0x73380 <- 0x00700000 HFIPCXIDDY
ace_ipc IPC request primary 0x41000000 ext 0x00700000
ace_reg_write BAR4 +0x73210 <- 0xc1000000 HFIPCXIDR
ace_reg_read  BAR4 +0x73214 -> 0x00000000 HFIPCXIDA          poll 1: no reply yet
ace_reg_read  BAR4 +0x73200 -> 0x1b080000 HFIPCXTDR          (the FW_READY payload, busy clear)
ace_ipc IPC reply primary 0xe1000000 ext 0x00000000          the model's reply, 50 us later
ace_reg_read  BAR4 +0x73214 -> 0xe1000000 HFIPCXIDA          poll 2: DONE seen
ace_reg_write BAR4 +0x73214 <- 0x80000000 HFIPCXIDA          ... acknowledged (write 1 to DONE)
ace_reg_read  BAR4 +0x73200 -> 0x1b080000 HFIPCXTDR          ... then XTDR: no notification
ace_reg_read  BAR4 +0x73214 -> 0x61000000 HFIPCXIDA          poll 3 .. N: the same pair again
ace_reg_read  BAR4 +0x73200 -> 0x1b080000 HFIPCXTDR          N > 500 000 (~1.8k/s), no write, no log line
```

Read pattern = one `IpcIncoming` per 500 µs: read `HFIPCXIDA`; if DONE, write DONE; read
`HFIPCXTDR`; return on busy only. The reply is consumed (DONE acknowledged) but never
returned to the state machine, which stays in its step-5 "wait for the reply" loop.

### The guest during the hang (run `x3-storm-stack`, monitor `info registers` + stack)

RIP in `ntoskrnl.exe` in the `KeStallExecutionProcessor` TSC loop
(`rdtsc; shl rdx,32; or rax,rdx; cmp rax,[rsp+0x20]; jae; jmp`), `RBX = FFFF808007200000`
(BAR4); sampled RIP/RCX/RDX while reading: `RIP=FFFF8080074C327A`, `RCX=RDX=0x73214`
(`intcdsp.sys`, `IntcDspOpRead32`-style read of `HFIPCXIDA`). Return addresses on the stack,
relative to the `intcdsp.sys` base `FFFF8080074C0000`: `+0x3378, +0x44F1, +0x7E51, +0x8A47,
+0x8F9B, +0x172E8, +0x19285` (unsymbolised: the image carries only LiberNT's packed `.symz`
table, and an injected NMI produced no bugcheck to let `kdb` print the frames). The P2b
crash dump of the earlier image maps the same callers as `FwloadRead ← FwloadUpdate ←
FwloadBoot ← IntcDspBoot ← IntcDspEvtDeviceD0Entry`.

### Expected, per which source

- P2a NOTES, "The operations table": `IpcIncoming(Msg)` is implemented by the model with
  "the queued FW_READY notification, crash notification **or reply**"; the state machine's
  step 5 "waits for the reply (500 ms)" on it, then `SofIpc4ParseReply (status)`, then reads
  the uplink mailbox and walks the tuples.
- P2b NOTES: "a set `HFIPCXIDA` DONE is acknowledged (write 1 to bit 31), then `HFIPCXTDR` busy
  yields primary = XTDR & 0x7FFFFFFF and extension = `HFIPCXTDDY` (0x73300)".
- Linux v6.12 `sound/soc/sof/intel/mtl.c mtl_ipc_irq_thread`: when DONE is set the reply is
  processed (`snd_sof_ipc_msgs_rx`: header = `XIDA & 0x7FFFFFFF`, ext = `XTDDY`, then the
  mailbox) **before** `mtl_ipc_dsp_done` clears DONE.

The host test passed because the fake DSP's `IpcIncoming` returns the reply; the P2b
`IpcIncoming` (hwops.c) clears DONE and returns only notifications. Expected fix (driver
side, for Megan to route): `IpcIncoming` must return the reply (primary = the XIDA value it
read, masked, ext = `HFIPCXTDDY`) when DONE was set — or the state machine must read the
reply itself; whichever way, the receive path and the FSM must agree. Until then AC3
(`boot ok`, the power cycles, the 20 cycles) and every fault row at or after the
configuration reply (`never-reply`, `drop-requests`, `ipc-status`, `bad-tuples`,
`truncated-reply`, `version-shift`, any `x-delay-scale` that reaches the reply) end in this
hang.

## D2 — the driver's elapsed-time clock reads 0 µs: no budget ever fires

### Evidence

- `boot ROM error after 0 us: …` after **4.66 s** of polling (`halt-rom=43`, run `fm-halt-rom=43`)
  and after **118 s** (`p1-probe-interactive`, first attempt: `booting` at `[1023.050198]`, the line
  at `[1140.931185]`).
- `p1-probe-interactive`, first attempt, device trace: **99,640** `ADSPCS` reads returning
  `0x00010000` (SPA set, CPA clear) before the model's 100 µs power-up timer was *seen* to fire
  (≈50 s for a documented **50 ms** power-up budget); then **33,646** `DSP2CXCTL` reads waiting for
  CPA to clear (≈17 s for the **50 ms** core power-down budget) and **96,262** `ADSPCS` reads
  (≈49 s) for the subsystem power-down. The loops ended only when the model's timers fired — during
  a host-side timer stall (see "Environment", below) — never by the budget.
- `x3-storm-stack`: > 500,000 polls (≈5 min) for a **500 ms** reply budget.
- **Direct test** (`fm-none-scale1550`, model delays × 1550 so FW_ENTERED comes 3.1 s after the
  stream ran): the driver printed `firmware entered` and `FW_READY received` at 9.43 s of
  guest time — its **3 s base-firmware budget did not fire** at 3.0 s; it waited for the
  event and proceeded. With a live clock this row is the plan's `boot timeout … failed in
  loading`.
- The 500 µs poll interval is kept (≈2,000 polls/s), i.e. `KeStallExecutionProcessor`
  (TSC-calibrated) paces correctly: the kernel's TSC runs. The driver's `NowUs`
  (`KeQueryPerformanceCounter`, hal/halx86/apic/tsc.c:278: TSC scaled by the calibrated
  `HalpCpuClockFrequency`) reads 0 elapsed for the whole boot, or the FSM does not consult it in
  these loops. Not measured from inside the guest (no guest tool exposes the QPC; an in-guest test
  program was not built). The indirect test is the `x-delay-scale=1550` row of the matrix
  (FW_ENTERED at 3.1 s): with a live clock the 3 s base-firmware budget fires at 3.0 s; see
  `fault-matrix.txt` for the measured outcome.

### Consequence

Every timeout the state machine is documented to have (`FWLOAD_TIMEOUTS`: power 50 ms, ROM init
500 ms, ROM status 300 ms, base firmware 3 s, FW_READY 1 s, IPC reply 500 ms) is unbounded in
this VM: `never-power`, `never-ack`, `never-ready`, `never-enter`, `never-fwready`, `never-reply`,
`drop-requests` and the delay-scale rows hang instead of reporting `boot timeout … after … us`.
Expected fix (driver side): make `NowUs`/the budget arithmetic return advancing values on this
build (or compute the elapsed figure where the "after N us" lines read it).

## Environment (not a driver divergence, recorded because it shapes the evidence)

While the LiberNT driver spins in its TSC stall loop under TCG, **this host's own timer
interrupts stall** (CachyOS, a KVM guest: `rcu: rcu_preempt kthread timer wakeup didn't happen
for 116308 jiffies!`, `Possible timer handling issue on cpu=0/2/3`; `sleep 0.1` takes 98 s while
the VM runs and 0.106 s the moment it stops). A plain host `rdtsc` loop (39 M reads/s) and a
50 µs `clock_nanosleep` loop do not reproduce it, so it is specific to QEMU's TCG thread on this
hypervisor. Consequences for the evidence: model timers and the serial output are delayed by
seconds to minutes while the driver polls (which is why some boots show their lines in a burst
or not at all), the host's shells crawl, and every run is stopped from a script. The driver's
`KeStallExecutionProcessor` pacing itself is unaffected (2,000 polls/s throughout).

One more artefact of the stalls, on the model side this time: the model keeps the ROM's
`FW_ENTERED` word for 2 ms (model value) before the firmware's status word appears, so the
driver's 500 µs poll sees it; a host stall longer than that *between* the ROM's entry and
the driver's next poll lets the driver's first sample be the firmware's word, and the
driver takes its ROM-error path (seen once, `bad-tuples` first pass). On a quiet host the
unfaulted boot reads `firmware entered` → `FW_READY received` and stops at D1 (`fm-none`).
