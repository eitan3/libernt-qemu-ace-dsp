# Task A — the fix-round expectations on image p2b4 (one boot each)

Model `b139810` (patches 0001–0010), q35, TCG, `-smp 1`, `ICOUNT=1` on every run. Serial lines are quoted
from each run's `serial.log` with the kernel timestamp kept; the device trace is `qemu-dbg.log` (`.gz`)
and the boot excerpt `qemu-dbg.excerpt.txt`.

## A1 — stage 1 (`BootDsp = 0`): `a1-stage1-firstboot`

The first boot of the fresh overlay `disk/p2b4.qcow2` (first-boot wizard dismissed, `BootDsp=1` set in the
guest, clean S5 — this boot turns the overlay into the stage-2 overlay). The driver's 13 lines are in
`stage1-lines.txt`; a `diff` against p2b3's (`evidence/2026-11-25-p2b3/ac3-interactive/stage1-lines.txt`,
timestamps removed) differs in exactly two lines, both the R1 rule against the model of patches 0009/0010:

| p2b3 (model `f53ff8b`) | p2b4 (model `b139810`) |
|---|---|
| `BAR4 +0x1000 ADSPCS 0x00000000 (SPA 0, CPA 0), +0x1108 HFINTIPPTR 0x00000120, +0x1140 HfHIPCIE 0x00000000, +0x73228 HFIPCXCTL 0x00000000` | `BAR4 +0x1000 ADSPCS 0x00000000 (SPA 0, CPA 0), +0x1108 HFINTIPPTR 0xffffffff, +0x1140 HfHIPCIE 0x00000000, +0x73228 HFIPCXCTL 0x00000000` |
| `BAR4 +0x120 (the interrupt enable register the pointer names) 0x00000000` | `HFINTIPPTR 0xffffffff names no 32-bit register inside BAR4: the host IPC interrupt enable cannot be reached` |

The trace holds exactly the six BAR4 reads of the `reading BAR4 at …` line (`+0x1000 +0x1108 +0x1140
+0x73228 +0x163200 +0x163204`; `HFINTIPPTR (model value)` → `0xffffffff`), no `+0x120` read, 0
`ace_unexpected`, 0 fatal lines. **R9** (`has no register map: BAR4 is not read`) cannot show here: the VM has
one controller, `8086:7f50`, the booting ID, whose probe is unchanged. No `interrupts …` line exists at stage 1
(they belong to the boot). `BootDsp = 0: probe only, the DSP is not touched` as before; the firmware line
(`1158164 bytes, ok … payload 0xc14 + 0x11a000, 282 preload pages`) as before.

## A2 — stage 2 (`BootDsp = 1`), a plain boot of the stage-2 overlay: `a2-stage2-boot`

```
[    7.396565] intcdsp.sys: booting: firmware 'ADSPFW' 2.15.0.1, 1155072 payload bytes in 1 descriptors on stream 1, BAR4 FFFF808007200000, clock 17752743 us at 10000000 Hz
[    7.396565] intcdsp.sys: interrupts before power-up: ADSPCS 0x00000000 (SPA 0, CPA 0), HFINTIPPTR 0xffffffff, INTEN 0xffffffff, HfHIPCIE 0x00000000, HFIPCXCTL 0x00000000
[    7.396565] intcdsp.sys: subsystem powered: ADSPCS 0x01010000 (SPA 1, CPA 1), HFINTIPPTR 0xffffffff, INTEN 0xffffffff, HfHIPCIE 0x00000000, HFIPCXCTL 0x00000000
[    7.459065] intcdsp.sys: code-loader stream 1: 1155072 bytes in 1 descriptors (LVI 0), SPIB 1155072, format 0x0040
[    7.459065] intcdsp.sys: ROM ready for the firmware: ADSPCS 0x01010000 (SPA 1, CPA 1), HFINTIPPTR 0x00000120, INTEN 0x00000000, HfHIPCIE 0x00000000, HFIPCXCTL 0x00000000
[    7.474690] intcdsp.sys: firmware entered: ADSPCS 0x01010000 (SPA 1, CPA 1), HFINTIPPTR 0x00000120, INTEN 0x00000000, HfHIPCIE 0x00000000, HFIPCXCTL 0x00000000
[    7.474690] intcdsp.sys: FW_READY received: ADSPCS 0x01010000 (SPA 1, CPA 1), HFINTIPPTR 0x00000120, INTEN 0x00000000, HfHIPCIE 0x00000000, HFIPCXCTL 0x00000000
[    7.474690] intcdsp.sys: boot ok after 67971 us (clock 17821036 us): state ready, failed in off (ok), ROM status 0x00000005 firmware entered, ROM error 0x00000000 unknown ROM error, IPC status 0, last DSP message 0x61000000|0x00000000, attempt 1, 0 DSP interrupts, cleanup ok, ADSPCS 0x01010000
[    7.474690] intcdsp.sys: firmware ready: version 2.15.0.1, ABI 1, ROM implementation 0.3 version 1.2 platform 288, ROM info 0x0000005a, downlink mailbox 4096 bytes, uplink mailbox 4096 bytes, trace log 131072 bytes, 16 pipelines, 4 libraries, context save 1, 7 tuples
```

Counts over the whole serial log: `0 DSP interrupts` ×1, `first DSP interrupt` ×0, `interrupt storm` ×0,
`interrupt enable timeout` ×0, `clock stalled` ×0, fatal ×0. The device trace (98 `ace_*` lines, 93 from the
power-up on): `ADSPCS ← 0x00010000` → `subsystem-powered` → the `subsystem powered` reads (`ADSPCS`,
`HFINTIPPTR 0xffffffff`, `HfHIPCIE`, `HFIPCXCTL`) → the mask: `HFINTIPPTR 0xffffffff` (names no register,
so **no write to `+0x120`**), `HfHIPCIE` read ← `0x00000000` read back, `HFIPCXCTL` read ← `0x00000000` →
the code-loader stream registers → the purge request → core up → the DONE reply → `HFINTIPPTR 0x00000120`,
`INTEN 0x00000000`, `HfHIPCIE 0`, `HFIPCXCTL 0` (the `ROM ready` reads) → the walk `0x25 0x27 0x28 0x29
0x2a` → `0x5` → the FW_READY notification `0x9b080000` → the state reads → the FW_CONFIG request
`0xC1000000|0x00700000` → the reply `0xE1000000` → `HFIPCXIDA`, `HFIPCXTDDY` read, DONE acknowledged.
No `DSP interrupt` line in the trace: the model raised nothing because the enables never left 0 — the
**R2 expectation (`0 DSP interrupts`) is met on the model, but the model cannot show that the *mask* gated
anything**: `INTEN`, `HfHIPCIE` and `HFIPCXCTL` read 0 before the mask as well (reset values; no BIOS ran to
set them).

Expectation → measured:

| expectation | measured | verdict |
|---|---|---|
| `interrupts before power-up … HFINTIPPTR 0xffffffff` | `ADSPCS 0x00000000 (SPA 0, CPA 0), HFINTIPPTR 0xffffffff, INTEN 0xffffffff, HfHIPCIE 0x00000000, HFIPCXCTL 0x00000000` | as expected (`INTEN 0xffffffff` = the pointer names no register) |
| after power-up `HFINTIPPTR 0x120` | on the `subsystem powered` line **still `0xffffffff`** (`ADSPCS 0x01010000 (SPA 1, CPA 1)`); `0x00000120` from `ROM ready for the firmware` on | **note N5**: a model ordering — the DSP domain answers only once the *core* is up (see DIVERGENCE.md) |
| `boot ok … 0 DSP interrupts` | `boot ok after 67971 us (clock 17821036 us): … attempt 1, 0 DSP interrupts, cleanup ok, ADSPCS 0x01010000` | as expected; N non-zero; end clock = start + N + 322 µs |
| no `interrupt storm`, no `clock stalled`, no `first DSP interrupt:` | 0 / 0 / 0 | as expected |
| `firmware ready: version 2.15.0.1, ABI 1 … 7 tuples` | identical to p2b3's line | as expected |

## A3 — `bad-tuples` and `truncated-reply` (the D3 proof)

Both are rows of the matrix (Task C): see `fm-bad-tuples/` and `fm-truncated-reply/` and the table in
`fault-matrix.md`; the result is summarised in the README's Round 4 table and in DIVERGENCE.md (D3).

## A4 — a second boot in the same VM (disable/enable): `a4-second-boot`

One cycle (`tools/ac3-cycles.sh 1`): `boot ok after 21455 us (clock 217413156 us): … attempt 1, 0 DSP
interrupts, cleanup ok, ADSPCS 0x01010000` on the second boot; model registers before (disabled) all zero but
`dsp2cxctl=02000000`, after: `adspcs=01010000 dsp2cxctl=02000101 … hfipcxtdr=1b080000 hfipcxida=61000000
… fsr=a0000005` (p2b3's D0 reading); clean S5; 0 `clock stalled`.

**R6 as worded ("no new `firmware … bytes, ok` line on the second boot") is not what the log shows: the
second boot prints the line twice** (serial lines 167 and 169, the same pair as at boot: 108 and 110):

```
[  207.024153] intcdsp.sys: HFINTIPPTR 0xffffffff names no 32-bit register inside BAR4: the host IPC interrupt enable cannot be reached
[  207.024153] intcdsp.sys: BAR4 +0x163200 FSR 0x00000000: …
[  207.027153] intcdsp.sys: firmware \SystemRoot\System32\drivers\intel\sof\sof-arl-s.ri: 1158164 bytes, ok, image 'ADSPFW' version 2.15.0.1, 32 modules, payload 0xc14 + 0x11a000, 282 preload pages
[  207.027153] intcdsp.sys: BootDsp = 1: the DSP is booted at the next D0 entry
[  207.027153] intcdsp.sys: firmware \SystemRoot\System32\drivers\intel\sof\sof-arl-s.ri: 1158164 bytes, ok, image 'ADSPFW' version 2.15.0.1, 32 modules, payload 0xc14 + 0x11a000, 282 preload pages
[  207.029153] intcdsp.sys: booting: …
```

Read in the driver at `b392065b2cf` (diagnosis only): `IntcDspLoadFirmware` (`intcdsp/fwfile.c:127`) calls
`FwloadImageEnsure` — which returns at once when the device already holds the image (`fwload/fwimage.c:35`,
`if (Image->Modules != NULL) return FwloadOk;`) — and then logs the `firmware … bytes, ok` line **on every
call**, whether the file was read or found resident (`fwfile.c:150`). It is called twice per start: from
`PrepareHardware` (`intcdsp.c:342`, where the stage-1 lines are) and from the boot path (`intcdsp.c:149`).
On the disable/enable path the device object is new (`Safe removal` → a new FDO), so the first line is a
genuine re-read at `PrepareHardware` — "kept for the device" is per device object — and the second is the
resident path. So the log is **identical to p2b3's**, where the second line was the re-read R6 removed: the
serial log cannot show R6 either way. Note N6 in DIVERGENCE.md: an observability gap (a distinct text for the
resident case would make R6 checkable) and an expectation correction for TESTING.md's "without the firmware
line" / "no second `firmware … bytes` line" — not a behavioural divergence. The sleep/resume case R6 was
written for (the same device object entering D0 again) was not exercised: this VM run did no S3.

## Environment findings of these boots (not driver divergences)

- **The first-boot wizard has three pages on this image** (`s1`–`s3`): language and keyboard → "Name your
  computer and create your account" → "Get the components most programs need" (3.3 GB of downloads). p2b3's
  `tab, tab, ret` now only reaches page 2; it was closed with `tab tab ret` → `ret` (Skip) → `tab tab tab ret`
  (Cancel). The serial log shows the setup's own lines (`\base\setup\libernt\oobe.c`).
- **Sync #14's power-management core is visible**: `\ntos\po\standby.c: The display idled out after 600
  seconds` / `The console display is now off|on`. Under `-icount … sleep=off` the guest clock runs ahead while
  the desktop idles (guest 602 s at about two minutes of wall time), so the display "idles out" within minutes;
  `screendump` is unaffected and the driver's own `after N us` figures are unaffected (the DSP boots are busy).
- `updagent` tries `https://libernt.com/api/update/…` and fails with `0x80072ee7` (the VM has no NIC).
- **`after N us` is not a DSP timing on this VM.** The loader copies the 1.15 MB payload byte by byte
  (`fwload/fwboot.c`, `FwloadClDmaPrepare`: `for (…) Dma->Virtual[Index] = Payload[Index];`) into uncached
  memory, i.e. ~10⁷ TCG instructions per boot, while the model's timers add up to ~3 ms. Under
  `-icount shift=auto` the virtual cost of those instructions is set by the shift QEMU calibrates at start,
  so the figure moves between launches with the model unchanged: p2b3's own icount run measured 37619 µs at
  boot time and 21318–21472 µs on its 22 cycles (`ac3-cycles-icount`); on p2b4 67971 µs (A2), 37806 µs at boot
  and 21455 µs on the cycle (A4). Compare timings only within one launch.
