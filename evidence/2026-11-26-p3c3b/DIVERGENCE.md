# DIVERGENCE — the p3c3b round (2026-11-26)

The micro rerun of P3 C3 on the fixed image: the loopback self-test of image p3c3b (`1619498f85e`) against
the model of `main 9f6d31c` (the binary `a894197d…`, qtest 15/15 before the first VM run).

**The result in one paragraph.** The loopback self-test comes back sample-exact in the VM. Six self-tests
(18 runs: 16-, 24- and 32-bit each — two at system boots, four at D0 re-entries), and every run ends `4096 frames captured after 85 ms, offset 0 frames, max abs error 0, … ok`
with `2 capture periods`; every self-test ends `3 runs, 3 matched, 0 failed, 45 requests, 0 notifications,
0 timeouts, 0 DSP interrupts, ok` and `ran (0x00000000), the DSP is left running` — TESTING.md's lines
exactly (`vm/expected-vs-measured.txt`). The model's trace agrees with the driver: two periods of each
stream per run, the render's and the capture's `ace_audio` line identical in every pair, the samples the
driver's own sine at the frame each period starts from, the rms the sine's exact rms. **D1 and D2 are
measured fixed.** No divergence of data, sequence or timing between the driver and the model was found.
One note is for the driver's reporting (the 16-bit rms figure, below); nothing was tuned or fixed on this
side, and the model was not changed.

| # | finding | class | status |
|---|---|---|---|
| **D1** | the self-test's wait could only time out | driver — the kernel glue (`intcdsp.sys`) | **fixed, measured**: 18 of 18 runs end at the second period |
| **D2** | the streams' descriptor lists lay one page below the buffers | driver — the bus (`hdaudbus.sys`) | **fixed, measured**: the first descriptor is the buffer's first page, at all three depths |
| T1 | the topology line's byte count | driver — wording | fixed, carried: the line exact on all 8 DSP boots with a topology |
| O1 | the driver's 16-bit rms figure is 0.006 % below the rms of its own sine | driver — reporting precision | noted, not a gate: the model's figure is the exact one |
| — | where a descriptor carries its interrupt on completion | for the C6 checklist | spec-consistent on the model; silicon to confirm |

### D1 — measured fixed

`IntcDspStreamWaitPeriods` (the driver's own wait since `ccb06bf3d84`, `stream.c:1428`) ends at the second period on every
run: `4096 frames captured after 85 ms` — two periods of 2048 frames at 48 kHz, the model's 42.7 ms each
— where p3c3 printed `4096 frames not captured: 1 of 2 periods after 671 ms (0xc00000b5), failed`. Each
run's next line says `stopped at render position 0 (LPIB 0, buffer 0), capture position 0 (LPIB 0, buffer
0), 2 capture periods, released: 1 pipelines and 3 instances deleted, 2 streams freed, ok` (18 of 18
exact): the positions are 0 as TESTING.md says they are on the model (the entries wrap to 0 after the
buffer's two periods), and the compare's offset is 0 frames — the pipeline's latency on the model.

### D2 — measured fixed: the lists at the buffers

Read over qtest with the VM stopped on a run's first line and on its `stopped at` line (`vm/live-reads.txt`,
`vm/live-reads-pages.txt`; the pages saved with the monitor's `pmemsave`, the `*.bin` windows of VMs 3 and 4).
BAR0 `0x81210000`; the lists at `0x3f21000` (render, the output stream) and `0x3f1d000` (capture, the input
stream); both streams `RUN 1, tag 1, IOCE 1`. Every descriptor is `address, 0, 4096, 0 or 1` — the fourth word
carries the interrupt on completion as its bit 0, the upper dword is 0 (its bit 31 is never set).

| depth | stream | `fmt` | `cbl` / `lvi` | the list, address:bytes:ioc | what the pages hold |
|---|---|---|---|---|---|
| 16-bit | render | `0x0011` | 16384 / 3 | `0x400000:4096:0` · `0x401000:4096:1` · `0x402000:4096:0` · `0x403000:4096:1` | the sine's frames 0–1023 (`0 0 1069 1069 2120 2120 …`), 1024–2047 (`7094 7094 …`), 2048–3071 (`-7095 -7095 …`), 3072–4095 (`0 0 1069 1069 …`): four pages, the whole buffer, none of zeros |
| 16-bit | capture | `0x0011` | 16384 / 3 | `0x404000:4096:0` · `0x405000:4096:1` · `0x406000:4096:0` · `0x407000:4096:1` | after the first period (`lpib 8192`): pages 0–1 the render's, byte for byte; pages 2–3 the poison `0xCDCD`. After the run: **the render's four pages byte for byte, no poison page** (read again at the next run's stops: VM 3 four times, VM 4 once) |
| 24-bit | render | `0x0031` | 32768 / 7 | `0x408000` … `0x40f000`, ioc `0,0,0,1,0,0,0,1` | the sine as `>> 2` in 32-bit containers (`0 0 70075715 70075715 138952416 …`), eight pages, each starting at the sine's frame 512·k mod 48 |
| 24-bit | capture | `0x0031` | 32768 / 7 | `0x410000` … `0x417000`, ioc `0,0,0,1,0,0,0,1` | all eight pages poison at `lpib 0`; after the run **the render's eight pages byte for byte** (VM 3, at each of the next two stops) |
| 32-bit | render | `0x0041` | 32768 / 7 | `0x418000` … `0x41f000`, ioc `0,0,0,1,0,0,0,1` | as the 24-bit render's (the driver's 32-bit run fills the same samples) |
| 32-bit | capture | `0x0041` | 32768 / 7 | `0x420000` … `0x427000`, ioc `0,0,0,1,0,0,0,1` | all eight pages poison at `lpib 0`; after the run **the render's eight pages byte for byte** (VM 4's last stop; in VM 3 seven of eight — the render's last page had been freed and overwritten before that stop landed) |

So the first descriptor names the buffer's first page, the list covers the whole buffer (4 pages at 16 bits,
8 at 24 and 32), and the interrupt on completion sits on the last descriptor of each half — on the model the
capture's wait ends at the second of them, as D1's line says. In p3c3 the lists were `0x414000…0x417000`
against the buffer at `0x415000…`: a page of zeros, three pages of the sine, the sine's last page outside
the list. Two instants the stops caught show the driver's order, not a defect: a list programmed while its
pages are still zero (VM 4, the 24-bit render list right after the 16-bit run), and a render buffer half
filled (VM 3, the 32-bit one at the stop that followed the 24-bit run's last line).

### T1 — fixed, carried

`intcdsp.sys: topology 'sof-ipc4-loopback.tplg': ABI 3.29.1, 4286 bytes (model 2288 bytes), 2 controls,
4 widgets, 2 edges, 1 pcm, 1 pipeline, 0 manifest items, from the registry override` — exact after `boot ok`
and `ipc: link ready` on all 8 DSP boots with a topology of the round, followed by the modules line
byte for byte.

### Run 3 — the boot regression with `SelfTest = 0`

| where | `Topology` | measured |
|---|---|---|
| a system boot | none (VM 3) | `SelfTest = 0, UseInterrupts = 0, IpcTimeoutMs = 500 ms`; `boot ok … attempt 1, 0 DSP interrupts`; `topology: none selected (no override, no quirk, no _DSD name); the DSP is powered down, no audio endpoint`; `DSP power down from state ready: ok, cleanup ok`; no self-test line; the desktop |
| a system boot | kept (VM 4, after `shutdown -r -t 0`) | `SelfTest = 0`; `boot ok`; `ipc: link ready`; the T1 line and the modules line; **no self-test line**; the desktop |
| a disable/enable cycle | kept (VM 2) | the same lines at `boot ok after 5371 us`; no self-test line |
| a disable/enable cycle | none (VM 2) | the none-selected line and the power-down line; no self-test line |

E11 of the p3c3 round (the regression at a system boot) is closed: measured in both `Topology` states.

### O1 — the driver's 16-bit rms figure (a note for the driver; no gate)

The driver prints `render rms 5793.911, capture rms 5793.911` at 16 bits. The exact rms of its own sine
(`IntcDspSineQ31`, `stream.c` at `1619498f85e`) over the 4096 frames is **5794.254**; over the two periods
the model moves it is 5786.742 (frames 0–2047) and 5801.756 (frames 2048–4095) — the two figures on the
model's `ace_audio` lines. The difference is the driver's own arithmetic: `IntcDspStreamCompare` sums each
sample's square *divided by the sample count* (`RenderSum += … / (Frames * Channels)`, `stream.c:1348`),
and the integer division drops on average half a unit of the mean square per sample (0.484 here), so the
figure comes out 0.343 (0.006 %) low; `driver-rms.py` reproduces `5793.911` exactly from that sum and the
driver's `IntcDspRms`. At 24 and 32 bits a square is about 2.9 × 10^17 and the loss is nil: the driver prints
`379742706.482`, the sine's exact rms is 379742706.4825, the model's two periods combine to the same
(`379250530.025`, `380234245.866`). TESTING.md's expected `5793.911` is the driver's figure (the host harness
prints the same), so the driver and its own expectation agree; **the rms is equal to the driver's at 24 and 32
bits and is the exact value of the driver's own sine at all three; the 16-bit figure's low bias is the
driver's reporting, not a difference between what the driver wrote and what the model moved** (`max abs
error 0` is the driver's own compare of every sample). Whether the driver sums its squares differently is
the driver's to decide.

### For the C6 checklist — where the interrupt on completion is read from

The driver writes it as the descriptor's fourth word (`HDAC_BDLENTRY.ioc`: bit 0 of the word after the
length), which is what the model reads (`intel-hda-ace`'s controller: `flags & 0x01`); the Intel HD Audio
specification's Buffer Descriptor List entry puts IOC at bit 31 of the upper dword (bit 63 of the address
word). Measured: every descriptor's upper dword is `00000000` and its fourth word is `00000001` exactly on
the last descriptor of each half — and the model interrupts there (18 of 18 runs: `2 capture periods`).
Listed as **spec-consistent, silicon to confirm**: if the silicon takes the bit from the length word's bit 31
instead, no completion interrupt fires there and the self-test's wait (and the codec path's notifications)
would end by timeout; the first reading of a silicon round, and the specification to confirm before it. Not
changed on either side (never invent semantics).

### Environment and process notes of the round

- **E15 (this round, mine) — three faults of my live-read tool cost the live read of VMs 1 and 2 and left
  VM 3 paused for 323 s.** (a) VM 1: BAR0 was read through q35's ECAM window at `0xb0000000`, which is mapped
  only once a guest has enabled the MCH's PCIEXBAR; the read gave zeros and the tool refused — correct, but
  no reading. BAR0 is taken from the monitor's `info pci` since (a query of QEMU's own state, cross-checked
  against BAR4's `0x81000000`). (b) VM 2: a `read()` outside its `with` block raised at the first line, and
  my monitor reply parsing had been copied from `tools/mon.py`, which keeps the text after the *last* prompt
  — always empty. (c) VM 3: HMP needs `pmemsave`'s file name quoted; the tool raised *after* its `stop` and
  exited without `cont`, so the VM stayed paused from 23:54:34Z to 00:00:07Z while the boot script typed on
  and its power-button request queued behind the pause. The paused state was the 16-bit reading itself
  (`salvage.py`: reads only), the VM was resumed through the repaired tool, the self-test completed and the
  queued power button ended the VM cleanly. All three were found only in a VM because my tests had not run
  the real monitor and qtest sockets; the tool was then run end to end against an idle QEMU instance before
  VM 4 (`vm/tools-used/livecap.py` is the final one; VM 4's read went through all six stops).
- **E16 (the host's monitor) — one client at a time.** A second connection to the monitor socket gets no
  answer (and can take the monitor over). Two probes of mine in VM 2 landed while the script was typing; the
  commands they could have swallowed all show in the driver's lines (`SelfTest = 0` at the next start), so
  nothing measured was lost. No probe was made into a running VM's monitor afterwards.
- **E17 (the VM's time) — where a stop lands.** The serial line is emulated at 115200 baud, so a 110-character
  line reaches the log over about 10 ms of guest time. The monitor then takes 13–16 ms to acknowledge the
  `stop` while the guest is mostly halted (icount, `sleep=off`) and 0.5–1 ms while the self-test keeps it
  busy; under icount a halted vCPU lets the guest's clock run on, so a run's 85 ms can pass within about
  20 ms of the host's time: in VM 4 the stops labelled 24 and 24end found the 32-bit run (`fmt 0x0041`),
  and each 16-bit stop shows one period moved (`lpib 8192`). The stream format at each stop names the
  run; the readings are filed by it.
- **E18 (the image) — the console's banner is not the build tip.** `LiberNT [Version 0.4.17-amd64-dev
  20261125-dc8c4a7]` is `cmd.exe`'s own version string, not relinked since the p3c3 build; the desktop's
  watermark names `1619498`.
- **E19 (the guest) — keystrokes typed into a paused VM do not land.** VM 3's `reg add … SelfTest 0` was
  typed while the VM stood paused (E15c); VM 4 booted with `SelfTest = 2`. Its script read the settings
  line, set the value and rebooted the guest for the regression boot.
- **E20 — VM 4's regression boot is a warm one** (`shutdown -r -t 0` inside the same QEMU process, `REBOOT=1`),
  not a cold boot; the cold-boot regressions are VM 3's (without `Topology`) and the boots of VMs 2–4 with
  `SelfTest = 2`.
- **E21 — the round's VM time: 19.6 minutes in four QEMU launches** (223 s, 193 s, 468 s, 292 s; five guest
  boots), of which 323 s were VM 3's pause (E15c). Without it: 14.2 minutes. The console no longer costs
  round trips: `Win+R` and `cmd.exe` open it without the Start menu, and no screenshot was read to decide
  anything.
- **E13 (carried) — `boot ok after N us` is TCG time on this host**: 5365–5371 us on the ten DSP boots.
- The model's registers before and after VM 2's two cycles (`cycles.log`) and after each live cycle
  (`driver.log`): the D0 reading `adspcs=01010000 dsp2cxctl=02000101 … fsr=a0000005` with `hfipcxida`
  `61000000` after a boot without a self-test and `32000000` after one that left the DSP running (p3c3's
  readings); the disabled reading all zero but `dsp2cxctl=02000000`.

## Open after this round

- For silicon: the firmware's answers of `evidence/2026-11-25-p3c3/MODEL-NOTES.md` (INFO_NEEDED 9–14 there);
  where the controller reads a descriptor's interrupt on completion from (above); the real completion
  interrupts and positions at the stop (0 on the model).
- For the driver, optional: the 16-bit rms figure's truncating sum (O1).
- Not run: `UseInterrupts = 1` with the self-test (TESTING.md's run 4, not a gate); TESTING.md (c)'s refusal
  rows; the fault matrix; the cycle run; S3.
