# The C2 acceptance — the image's expectations (TESTING.md of p3c2) and the measured lines

Image p3c2 (`intcdsp.sys` `7bca0a5741c8…`), model `main d2dc604` (`build/qemu-system-x86_64` `be8667eb…`, qtest 14/14
before the first boot). The micro round of the owner's ruling: three VM boots, four DSP boots, no fault matrix, no
cycle run. Serial lines are quoted without their timestamps and CR LF. Every line below was compared with the
image's TESTING.md as text (`grep -Fx` on the lines of its code blocks), not by eye.

**The result in one paragraph.** The boot block is p3c1's, line for line, on all four DSP boots (timings aside), with
`boot ok … attempt 1, 0 DSP interrupts, cleanup ok` each time, no `1 DSP interrupts`, no stall, no storm, no
bugcheck. **N9 is fixed** (one settings line per start: 6 lines for 6 device starts) and **D4 is fixed** (every
power-down of a booted DSP says `from state ready`). Run 2 prints TESTING.md (a)'s two lines exactly, in order, after
`ipc: link ready`. Runs 3 and 4 and a plain boot print (b)'s two lines right after `ipc: link ready` with no
power-down following; the modules line is byte-exact. **Two findings:** the summary line's byte count is `2288`, not
the `4286` of the file (T1, driver: the line prints the size of the built model), and run 4 does not show a kept
model — a disable/enable builds a new device object, which reads the file again by design; the kept-model line of
TESTING.md's resume paragraph needs an S3, which this VM cannot do (X1). Details and classes: `DIVERGENCE.md`.

## Run 1 — stage 1, `BootDsp = 0` (`r1-stage1-firstboot`: the first boot of the fresh overlay)

| expectation | measured | verdict |
|---|---|---|
| the probe lines unchanged against p3c1 | the 14 `hdaudbus.sys` / `intcdsp.sys` lines are p3c1 `a1-stage1-firstboot`'s fifteen with one line removed: the diff of the two logs (timestamps stripped) is `15d14 < intcdsp.sys: SelfTest = 0, UseInterrupts = 0, IpcTimeoutMs = 500 ms` — the second settings line | unchanged |
| the settings line once per start (N9) | `intcdsp.sys: SelfTest = 0, UseInterrupts = 0, IpcTimeoutMs = 500 ms` — **1 line** in the whole boot (p3c1: 2), after `BootDsp = 0: probe only, the DSP is not touched` | **fixed** |
| the model touched only by the probe | 6 `ace_*` trace lines (the six BAR4 reads), 0 `ace_unexpected`, ADSPCS `0x00000000 (SPA 0, CPA 0)` in the line | pass |
| — | the desktop at 78.9 s of guest time; the wizard closed with `tab tab ret`, `ret`, `tab tab tab ret` (`s1`–`s4`); `BootDsp = 1` set and read back (`s6-reg-query.png`); clean S5 (`Entering sleep state S5`, QEMU rc=0, 307 s) | — |

## Run 2 — stage 2, `BootDsp = 1`, no `Topology` (`r2-stage2-no-topology`, its boot; `stage2-lines-none.txt`)

Measured, from the firmware line on:

```
intcdsp.sys: firmware \SystemRoot\System32\drivers\intel\sof\sof-arl-s.ri: 1158164 bytes, read, image 'ADSPFW' version 2.15.0.1, 32 modules, payload 0xc14 + 0x11a000, 282 preload pages
intcdsp.sys: BootDsp = 1: the DSP is booted at the next D0 entry
intcdsp.sys: SelfTest = 0, UseInterrupts = 0, IpcTimeoutMs = 500 ms
intcdsp.sys: firmware \SystemRoot\System32\drivers\intel\sof\sof-arl-s.ri: 1158164 bytes, resident, image 'ADSPFW' version 2.15.0.1, 32 modules, payload 0xc14 + 0x11a000, 282 preload pages
intcdsp.sys: booting: firmware 'ADSPFW' 2.15.0.1, 1155072 payload bytes in 1 descriptors on stream 1, BAR4 FFFF808007200000, clock 18056537 us at 10000000 Hz
intcdsp.sys: interrupts before power-up: ADSPCS 0x00000000 (SPA 0, CPA 0), HFINTIPPTR 0xffffffff, INTEN 0xffffffff, HfHIPCIE 0x00000000, HFIPCXCTL 0x00000000
intcdsp.sys: subsystem powered: ADSPCS 0x01010000 (SPA 1, CPA 1), HFINTIPPTR 0xffffffff, INTEN 0xffffffff, HfHIPCIE 0x00000000, HFIPCXCTL 0x00000000
intcdsp.sys: code-loader stream 1: 1155072 bytes in 1 descriptors (LVI 0), SPIB 1155072, format 0x0040
intcdsp.sys: ROM ready for the firmware: ADSPCS 0x01010000 (SPA 1, CPA 1), HFINTIPPTR 0x00000120, INTEN 0x00000000, HfHIPCIE 0x00000000, HFIPCXCTL 0x00000000
intcdsp.sys: firmware entered: ADSPCS 0x01010000 (SPA 1, CPA 1), HFINTIPPTR 0x00000120, INTEN 0x00000000, HfHIPCIE 0x00000000, HFIPCXCTL 0x00000000
intcdsp.sys: FW_READY received: ADSPCS 0x01010000 (SPA 1, CPA 1), HFINTIPPTR 0x00000120, INTEN 0x00000000, HfHIPCIE 0x00000000, HFIPCXCTL 0x00000000
intcdsp.sys: boot ok after 6477 us (clock 18063336 us): state ready, failed in off (ok), ROM status 0x00000005 firmware entered, ROM error 0x00000000 unknown ROM error, IPC status 0, last DSP message 0x61000000|0x00000000, attempt 1, 0 DSP interrupts, cleanup ok, ADSPCS 0x01010000
intcdsp.sys: firmware ready: version 2.15.0.1, ABI 1, ROM implementation 0.3 version 1.2 platform 288, ROM info 0x0000005a, downlink mailbox 4096 bytes, uplink mailbox 4096 bytes, trace log 131072 bytes, 16 pipelines, 4 libraries, context save 1, 7 tuples
intcdsp.sys: ipc: link ready, polled, 500 ms per message
intcdsp.sys: topology: none selected (no override, no quirk, no _DSD name); the DSP is powered down, no audio endpoint
intcdsp.sys: DSP power down from state ready: ok, cleanup ok, ADSPCS 0x00000000 (SPA 0, CPA 0)
```

| expectation (TESTING.md (a) and its "short boot regression") | measured | verdict |
|---|---|---|
| the p3c1 boot block unchanged | the ten lines `booting:` … `ipc: link ready` are p3c1 `a2-stage2-boot`'s, line for line (timings aside); the whole log differs from a2's by three lines only: a2's second settings line removed, the two new lines added | pass |
| `boot ok` with `attempt 1`, `cleanup ok`, `0 DSP interrupts` | `boot ok after 6477 us (clock 18063336 us) … attempt 1, 0 DSP interrupts, cleanup ok, ADSPCS 0x01010000` (end clock − start clock − N = 322 µs at this boot-time start) | pass |
| `INTEN 0x00000000` from `ROM ready for the firmware` on | `INTEN 0x00000000` on the `ROM ready`, `firmware entered` and `FW_READY received` lines | pass |
| the firmware line's `read` at the first start of a device object, `resident` after a resume | `read` at the device's first start, `resident` at the D0 entry — p3c1's pair (N6 as it stands; a resume was not run) | as p3c1 |
| the settings line once per start, after `BootDsp = 1: …`, before the boot's first line | 1 line, after `BootDsp = 1: the DSP is booted at the next D0 entry`, before `firmware … resident` | **N9 fixed** |
| two new lines, in this order, every start | `topology: none selected (no override, no quirk, no _DSD name); the DSP is powered down, no audio endpoint` — **exact**; then `DSP power down from state ready: ok, cleanup ok, ADSPCS 0x00000000 (SPA 0, CPA 0)` — TESTING.md's line with its `0x……` filled | pass |
| the second line is D4's check: `ready`, never `off` | `from state ready` | **D4 fixed** |
| the device stays started; no endpoint child | the desktop and a console came up (`console-start.png`); the device was then disabled and enabled twice (`Safe removal: CSAUDIO\ADSP&CTLR_VEN_8086&CTLR_DEV_7F50\4&aeefd634&0&1000000000` each time, a `boot ok` after each enable); the model's registers read over qtest before the first enable (`cycles.log`): `adspcs=00000000 … ` all zero but `dsp2cxctl=02000000` — the DSP is off, as the line says. No endpoint child: not observable from this side (C4 creates children) | pass (as far as the VM shows) |

The trace of this boot (`trace-regression.txt`): p3c1 a2's 106 `ace_*` lines, all present and in order, with 2 lines
added at 81–82 — one more poll of `HFIPCXIDA` / `HFIPCXTDR` between `firmware entered` and the FW_READY notification
(poll counts were timing-dependent in every round). 0 `ace_unexpected`.

## Run 3 — `Topology = sof-ipc4-loopback.tplg`, then D0 re-entered (`r2-stage2-no-topology`, cycle `override-1`; `cycle1-override-lines.txt`)

The value set in the console (`reg add "HKLM\SYSTEM\CurrentControlSet\Services\intcdsp\Settings" /v Topology /t
REG_SZ /d sof-ipc4-loopback.tplg /f`, read back `Topology REG_SZ sof-ipc4-loopback.tplg`: `topology-set.png`), then
`tools/cycle.sh` (`pnputil /disable-device`, `pnputil /enable-device`). The disable printed no driver line (the DSP was
already off). The enable printed the probe lines, `firmware … read`, `BootDsp = 1: …`, **one** settings line,
`firmware … resident`, the boot block with `boot ok after 5366 us (clock 1393164350 us) … attempt 1, 0 DSP interrupts,
cleanup ok, ADSPCS 0x01010000` (end − start − N = 81 µs), `firmware ready`, `ipc: link ready`, then:

```
intcdsp.sys: topology 'sof-ipc4-loopback.tplg': ABI 3.29.1, 2288 bytes, 2 controls, 4 widgets, 2 edges, 1 pcm, 1 pipeline, 0 manifest items, from the registry override
intcdsp.sys: topology: modules copier → id 5, gain → id 7; endpoint 'Loopback' render+capture 48000 Hz 2 ch 16/24/32
```

| expectation (TESTING.md (b)) | measured | verdict |
|---|---|---|
| exactly two lines after `boot ok` and `ipc: link ready` | exactly these two, nothing between them and `ipc: link ready` | pass |
| `topology 'sof-ipc4-loopback.tplg': ABI 3.29.1, 4286 bytes, 2 controls, 4 widgets, 2 edges, 1 pcm, 1 pipeline, 0 manifest items, from the registry override` | the same line with **`2288 bytes`** | **differs: T1** |
| the builder's numbers | `ABI 3.29.1`, `2 controls`, `4 widgets`, `2 edges`, `1 pcm`, `1 pipeline`, `0 manifest items` — as TESTING.md and the image's NOTES.md. The brief's "10 formats" is not a field of the line (the driver's format string has none); it stays the builder's internal count | pass |
| the modules line; the arrow is U+2192 (`e2 86 92`) | **byte-exact**, the arrow's three bytes in the log | pass |
| no power-down follows | no power-down line until the next cycle's disable; the model in D0 (`cycles.log`): `adspcs=01010000 dsp2cxctl=02000101 inten=00000000 irqsts=00000000 hfhipcie=00000000 hfipcxtdr=1b080000 hfipcxida=61000000 hfipcxctl=00000000 hfipcxtddy=00000000 fsr=a0000005` | pass |
| the `boot ok` regression, `0 DSP interrupts`, no `clock stalled` / `interrupt storm` | `attempt 1, 0 DSP interrupts, cleanup ok`; the block identical to p3c1 a2's; 0 `clock stalled`, 0 `interrupt storm` in the VM | pass |

## Run 4 — one disable/enable cycle with the override in place (`r2-stage2-no-topology`, cycle `override-2`; `cycle2-override-lines.txt`)

Measured: the disable printed `intcdsp.sys: DSP power down from state ready: ok, cleanup ok, ADSPCS 0x00000000 (SPA 0,
CPA 0)` (a booted DSP: D4) and the model read all zero but `dsp2cxctl=02000000`. The enable printed `intcdsp.sys:
loaded for the Intel audio DSP child`, the probe lines, `firmware … read`, `BootDsp = 1: …`, **one** settings line,
`firmware … resident`, the boot block with `boot ok after 5366 us (clock 1749019382 us) … attempt 1, 0 DSP interrupts,
cleanup ok` (end − start − N = 86 µs), `ipc: link ready`, then the same two topology lines as run 3 — the summary
with `2288 bytes, … from the registry override`, then the modules line. At the end of the VM the S5 printed a third
`DSP power down from state ready: …`.

| expectation (the brief's run 4; TESTING.md's "Resume with the override (R6)") | measured | verdict |
|---|---|---|
| the firmware line as `resident` | `firmware … resident` — after `firmware … read`, the pair of every D0 entry that boots (N6) | as N6 |
| one settings line per entry | 1 (3 in the VM for 3 starts) | pass |
| the second D0 entry keeps the model; no re-read of the file beyond the first; `topology 'sof-ipc4-loopback.tplg': resident, the model of the device's first boot` | the line is the full summary `from the registry override` again, in a start that begins `loaded for the Intel audio DSP child` — a new device object, which by the driver's source reads and builds again; the kept-model line is written for a resume (the same device object), which needs an S3 | **not shown: X1** (environment / the brief's premise; TESTING.md (b) itself promises these two lines for "Disable, Enable (or reboot)") |

## The plain boot with the override persisted (`r3b-topology-plainboot`; `stage2-lines-override.txt`)

The other way TESTING.md (b) names to re-enter D0. Lines 1–4 as run 2's (`read`, `BootDsp = 1`, the settings line,
`resident`), the boot block with `boot ok after 5370 us (clock 19016232 us) … attempt 1, 0 DSP interrupts, cleanup
ok` (end − start − N = 80 µs), `firmware ready`, `ipc: link ready`, then the two lines of run 3 verbatim (the summary
with `2288 bytes`, the modules line). 27 driver lines, **0 power-down lines** in the boot: the DSP stays booted
(ADSPCS `0x01010000` on the `boot ok` line). The VM was stopped on the modules line (`rc=0 (marker)`, 35 s).

## The round's counts

| what | measured |
|---|---|
| VM boots | 3: 307 s, 500 s, 35 s (14 minutes); the first two end in a clean S5 (`Entering sleep state S5`, QEMU rc=0) |
| DSP boots (`boot ok`) | 4 — run 2's start, runs 3 and 4, the plain boot; `attempt 1`, `cleanup ok`, `0 DSP interrupts` on 4 of 4 |
| `boot ok after N us` / end clock − start clock − N | 6477 / 322 µs · 5366 / 81 µs · 5366 / 86 µs · 5370 / 80 µs (E5: `N` is TCG time on this host) |
| the boot block against p3c1 `a2-stage2-boot` | identical, timings aside, on 4 of 4 |
| `1 DSP interrupts` · `clock stalled` · `interrupt storm` · `Work queue` · bugcheck · `Fatal System Error` | 0 · 0 · 0 · 0 · 0 · 0 in the three serial logs |
| settings lines | 6 for 6 device starts (1 + 3 + 1) |
| power-down lines | 3 × `DSP power down from state ready: ok, cleanup ok, ADSPCS 0x00000000 (SPA 0, CPA 0)`; none says `from state off`; run 3's disable printed none (the DSP was already off) |
| topology lines | `none selected` ×1; the summary line ×3 (all `2288 bytes`); the modules line ×3 |
| `ace_*` trace lines / `ace_unexpected` | 6 / 0 · 416 / 0 · 108 / 0 |
| the model's registers before and after each cycle (`cycles.log`) | 2 distinct readings, identical to p3c1 `ac3-cycles`' 22 pairs: disabled all zero but `dsp2cxctl=02000000`; in D0 `adspcs=01010000 … fsr=a0000005` |

## Not run in this round (the micro round's scope)

TESTING.md (b)'s resume (R6) and its `resident, the model of the device's first boot` line (no S3 in the VM);
(c) the refusal rows (`no-such-file.tplg`, a path, a shipped topology); "Turning it off" (`reg delete`); the
self-test blocks (`SelfTest = 1`); (d) the VirtualBox regression; the fault matrix and the cycle run (the full
regression runs before C6); silicon, the `_DSD` path (the VM has no `_DSD` names: the fail-safe line says so), the
WIM medium (`BOOTLOADER_WIM_RAMDISK` off in this image).
