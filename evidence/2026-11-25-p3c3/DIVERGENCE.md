# DIVERGENCE — the p3c3 round (2026-11-25)

Two halves wrote this file: the VM half first (the loopback self-test of image p3c3 against the model
`a894197d…`), the model half as the model side wrote it (the host gateways; it made no VM run).

## The VM half: two driver findings, no model finding

**The result in one paragraph.** T1 is fixed: the topology line prints `4286 bytes (model 2288 bytes)`.
The loopback self-test ran six times — once at a D0 re-entry, five times at a plain boot — and failed
every time in its first run (16-bit) with the same line, `4096 frames not captured: 1 of 2 periods after
671–677 ms (0xc00000b5), failed`; the 24- and 32-bit runs and the compare were never reached. The model's
trace shows the sequence done: the pipeline's 15 requests each answered `status 0`, the gateway armed
(`host-output copier 5.0 drains stream 1 into host-input copier 5.1's stream 1; 192000 bytes a second`),
15 periods of 8192 bytes moved on both streams, the render and the capture line of every period identical.
Two driver-side defects, each sufficient alone, explain the line; both are in the image's own sources,
which were read (through git, read-only) to classify them, not changed. Nothing was tuned, the model was
not changed, and the stop rule held: the first failing run is the finding.

| # | finding | class | where (the image's tree, `c595e373b3a` = `dc8c4a75be7`) |
|---|---|---|---|
| **D1** | the self-test's wait can never succeed: its per-step progress is compared with the whole buffer, so the wait always ends in `STATUS_IO_TIMEOUT` | driver — the kernel glue (`intcdsp.sys`) | `drivers/wdm/audio/intcdsp/intcdsp.c:285–340`, `IntcDspSelfTestWait` |
| **D2** | the streams' descriptor lists start one page (4096 bytes) below the buffers the driver fills: the capture receives a page of zeros and three pages of the sine, not the sine | driver — the bus (`hdaudbus.sys`) | `drivers/wdm/audio/hdaudbus/hdac_stream.cpp:217` and `:240–241`, `hdac_stream_allocate_buffer` |
| T1 | the topology line's byte count — **measured fixed** | — | all 8 DSP boots with a topology of the round |

### D1 — `IntcDspSelfTestWait` ends by timeout whatever the capture holds

The kernel glue's wait registers an event the bus's DPC sets at every capture period and polls the
stream's position (`intcdsp.c:285–340`):

```c
Bytes = (ULONG)Managed->Bytes;                       /* 16384 */
Half = Bytes / Count;                                /* 8192, Count = 2 */
Last = Dev->Bus.StreamPosition(Dev->Bus.Context, Managed->Handle) % Bytes;
Status = STATUS_IO_TIMEOUT;
for (;;)
{
    Position = Dev->Bus.StreamPosition(Dev->Bus.Context, Managed->Handle) % Bytes;
    Progress = (Position - Last + Bytes) % Bytes;    /* 0 .. Bytes - 1, always */
    Last = Position;
    if (Progress >= Half * Count)                    /* Half * Count == Bytes: never true */
    {
        Status = STATUS_SUCCESS;
        break;
    }
    /* … the timeout check, then KeWaitForSingleObject(&Dev->SelfTestEvent, …, &Timeout) … */
}
*Periods = Progress / Half > Count ? Count : Progress / Half;
```

`Progress` is the change between two consecutive readings of a position taken modulo `Bytes`, so
`0 <= Progress < Bytes` by construction; `Half * Count` is `(Bytes / Count) * Count`, which is `Bytes`
here. The success branch is unreachable: the loop leaves by the timeout with `STATUS_IO_TIMEOUT`
(`0xc00000b5`, the status on every measured line), and `*Periods` reports the last single-step change,
8192 / 8192 = 1 — `1 of 2 periods` on every run, although the model had moved 15 periods. The bus's
period path, read in the source (`hdac_controller.cpp:405–432`, `:478–503`: `SD_INT_COMPLETE 0x04`, the
bit QEMU's controller raises, cleared by `SD_STS`; `notificationPending` → the DPC → the event), is the
one the wait relies on; how many of the 15 periods it signalled is counted by nothing in the log, and
does not matter for D1. Measured: six runs — VM 1's cycle `selftest-1`, VM 2's boot and its two cycles,
VM 3's boot, VM 4's boot — `after 671 ms` ×5 and `677 ms` ×1 (`TimeoutMs = 4096 × 2000 / 48000 + 500 =
670`). This wait exists only in the kernel glue: the host harness supplies its own (`StreamWait`,
`submodules/host-tests/ipc/t_sofipc.c:1555–1560`), and the image's PROVENANCE lists "the wait" as
compile-verified only. How the progress should accumulate is the driver's to write; the mechanism is
this side's finding.

### D2 — the descriptor lists are one page below the buffers

Read live over qtest (reads only) in VM 2, second cycle: the VM was stopped the moment the self-test's
first line reached the serial log (1109 ms after the Enter) with both streams running (`RUN 1`, tag 1
each, `cbl 16384`, `lvi 3`, `fmt 0x0011`; `vm/r2-selftest-plainboot/livecapture-selftest-cycle2.txt`):

| stream | the descriptor list (address, bytes, IOC) | what the memory held |
|---|---|---|
| render — output stream 0 | `0x414000 4096 ioc 0` · `0x415000 4096 ioc 1` · `0x416000 4096 ioc 0` · `0x417000 4096 ioc 1` | `0x414000`: zeros · `0x415000`: the sine's frames 0–1023 (`0 0 1069 1069 2120 2120 …`) · `0x416000`: frames 1024–2047 (`7094 7094 6499 6499 …`) · `0x417000`: frames 2048–3071 (`-7095 -7095 …`) · `0x418000`, outside the list: frames 3072–4095 (`0 0 1069 1069 …`, the period being 48 frames) |
| capture — input stream 0 | `0x419000 4096 ioc 0` · `0x41a000 4096 ioc 1` · `0x41b000 4096 ioc 0` · `0x41c000 4096 ioc 1` | after the first period (`lpib 8192` on both streams): `0x419000`: zeros and `0x41a000`: the sine's frames 0–1023 — the render list's first period, byte for byte; `0x41b000`, `0x41c000` and `0x41d000` (outside the list): the poison `0xCDCD` (`-12851`) |

So the driver filled its render buffer at `0x415000–0x418fff` and poisoned its capture buffer at
`0x41a000–0x41dfff` (five pages are allocated for each), while the two lists describe pages 0–3. The
model moved what the lists name — as the stock codec path does — and its `ace_audio` lines say so
without the dump: the first period `rms 4100.957 peak 8192 first 0 0 0 0 0 0 0 0` (a page of zeros, then
1024 frames of the sine), the second `rms 5788.873 peak 8192 first 7094 7094 6499 6499 5792 5792 4986 4986`
(the sine's frame 1024: `IntcDspSineQ31[16] >> 18 = 7094`), the two alternating over the 15 periods.

The cause is the bus's allocator (`hdac_stream_allocate_buffer`, `hdac_stream.cpp`):

```c
halfSize = …;                                       /* 8192: half of the 16384 requested */
bufferSize = halfSize * 2;
allocOffset = PAGE_SIZE - (halfSize % PAGE_SIZE);   /* 4096 - 0 = 4096: a whole page, not 0 */
allocSize = bufferSize + allocOffset;               /* five pages */
…
*offsetFromFirstPage = allocOffset;                 /* the client (stream.c:1486) fills from page 1 on */
…
PPFN_NUMBER pfnArray = MmGetMdlPfnArray(mdl);
UINT32 offset = allocOffset;                        /* 4096: already on page 1 … */
…
    UINT32 pageOff = offset % PAGE_SIZE;            /* … % 4096 = 0 */
    UINT32 chunk = (pageOff == 0) ? PAGE_SIZE : (PAGE_SIZE - pageOff);
    PFN_NUMBER pfn = pfnArray[pageNum];             /* pageNum starts at 0: page 0, not page 1 */
    bdl->lowAddr = addr.LowPart + pageOff;
```

`offset` counts bytes from the allocation's start, so with `allocOffset == PAGE_SIZE` it is already on
page 1, but `pageNum` starts at 0 and `pageOff` is 0: the first descriptor takes page 0 at offset 0 and
every later one follows a page behind. For a half size that is not a multiple of the page size
(`0 < allocOffset < PAGE_SIZE`) the arithmetic is right; the self-test's half sizes (8192 at 16 bits,
16384 at 24 and 32) all are multiples. Both streams get it. Nothing is overrun — the fifth page exists —
but the capture is not the render: by the dump's layout (deduced, not measured), with D1 alone fixed the
compare would match frames 0–3071 and find the poison from frame 3072 on, because the list never writes
the page the client reads last.

### T1 — measured fixed

`intcdsp.sys: topology 'sof-ipc4-loopback.tplg': ABI 3.29.1, 4286 bytes (model 2288 bytes), 2 controls,
4 widgets, 2 edges, 1 pcm, 1 pipeline, 0 manifest items, from the registry override` — TESTING.md run 1's
line exactly (`grep -Fx`), on every DSP boot with a topology of the round (8: VM 1's two cycles, VM 2's
boot and two cycles, VM 3's boot, VM 4's boot and one cycle), after `boot ok` and `ipc: link ready`,
followed by the modules line byte for byte. C2's T1 is closed.

### Environment notes of the VM half

- **E9 (this round) — VM 2 ended by its wall-clock cap, not by an S5.** `WAIT=900` expired 33 s after
  the live capture of D2, while the dump was being read; QEMU exited rc=0 on SIGTERM (`lib-run.out`:
  `rc=0 (cap)`). No S5 line in that VM; its three DSP boots and the stall/storm/bugcheck counts are
  unaffected by it.
- **E10 (the guest) — the console's keyboard layout changed once.** In VM 3 keys meant for the Start
  menu reached the desktop and the first-boot wizard's language page (`Finish Setup`), whose Next applied
  a non-US keyboard layout: the console then transcribed the registry command into Cyrillic
  (`vm/r3-selftest0-set/s4-selftest0-query-zoom.png`). No command reached the driver's key, and `SelfTest`
  stayed 2 in the overlay. VM 4's console answered `Alt+Shift` (`echo abc` → `abc`, `s2-probe-altshift-zoom`)
  and took the command (`SelfTest REG_DWORD 0x0`, `s3-selftest0-query-zoom`).
- **E11 — the `SelfTest = 0` regression is measured at a disable/enable cycle, not at a system boot.**
  Because of E9 and E10 the regression's DSP boot is VM 4's cycle `selftest0-1` (D0 re-entered with
  `SelfTest = 0`, `Topology` kept), then the S5; the system boot with `SelfTest = 0` that TESTING.md run 3
  and the brief name was not run. The lines the brief lists are measured at that entry.
- **E12 — the round's VM time: 47 minutes in four VM boots** (1291 s, 900 s, 324 s, 296 s) against the
  micro round's 20–30. The VM's own work — the boots, the cycles, six self-tests of about a second each —
  is a few minutes; the rest is the console driving (each screenshot is read in a round trip) and E10's
  recovery. The number of boots is within the ruling's 3–4.
- **E13 (carried) — `boot ok after N us` is TCG time on this host**: 5371, 5371 (VM 1's cycles), 5744
  (VM 2's boot), 5371, 5373 (its cycles), 5365 (VM 3's boot), 5736 (VM 4's boot), 5366 (its cycle) µs;
  end clock − start clock − N = 80–161 µs (C1's pattern: a boot-time start costs more; no budget is near).
- **E14 (carried) — the first-boot wizard and the console**: the shell's `Program Manager` line at 83.2 s
  of guest time on the first boot (C2's: 78.9 s) and at 31.0–37.5 s on the plain ones; the wizard closed
  with `tab tab ret`, `ret`, `tab tab tab ret`. The console is the Start menu's `Command Prompt` entry,
  reached by keyboard (`meta_l`, then `down` to the first item and on to it); the menu's recent-programs
  list changes its order between boots, which is how E10 began. The vision read of the screenshots is not
  character-exact; the screenshots are the record.
- The model's registers before and after every cycle (`cycles.log`, `livecapture-*.log`): the D0 reading
  `adspcs=01010000 dsp2cxctl=02000101 … hfipcxida=61000000 … fsr=a0000005`, except VM 2's two cycles,
  taken after the self-test had left the DSP running, which read `hfipcxida=32000000`; the disabled
  reading all zero but `dsp2cxctl=02000000` after a power-up and all zero before the first.

## The model half (as the model side wrote it)

*No driver–model divergence in the model half: it made no VM run.* Nothing there asked the driver to
change, and the model was not changed to make anything pass.

Findings on the model side, each fixed inside the round and before the binary of record
(`a894197d…`) was built:

| # | finding | where it showed | what was done |
|---|---|---|---|
| M1 | After a stream was stopped and run again, the **position buffer's entry in guest memory kept its stale value** (2048) while LPIB and the extended register correctly read 0: the entry was written only when a period moved | the new qtest's placeholder sequence, first run: `check_position: (posbuf == want): (2048 == 0)` | a stream now reports its position when it starts running (`ace_stream_report` from the stream-run hook) and after every period; the test's expectation stood | 
| M2 | The placeholder copier printed "stream tag 256" (index 0xff + 1) | the trace | printed as "without a stream (the placeholder index 0xff)" |
| — | *(process)* a mutation row's sed held the harness's own separator `\|` | `gw-interrupts` NOT APPLIED in trial 1 | rewritten with `.` for that character |
| — | *(process)* `gw-forwarding`'s first definition removed the whole period and died on the same assertion as the position row — not a test of the forwarding | trial 1 | redefined: the capture never written while the render moves |
| — | *(process)* the first draft of `affected-rows.sh` reported "none affected" while its hit test could not match | its own sanity check (the five new rows must land in a hunk) | fixed; two existing rows (`ppl-exists`, `ppl-missing`) are affected, re-run and killed |

Open for the driver half (from `MODEL-NOTES.md`, INFO_NEEDED 9–12): the trigger order the firmware
really needs; what the firmware does with a capture stream that is not running; the format
conversion across the pipeline (the model forwards only when both host streams have the same frame
size, so the 16- and 24-bit self-tests should open both streams in the same container); whether the
copier re-configuration at prepare is needed and with which parameter id.
