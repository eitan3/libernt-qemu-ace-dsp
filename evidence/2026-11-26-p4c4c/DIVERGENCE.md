# DIVERGENCE — the p4c4c round (2026-11-26)

The P3 close-out regression on image p4c4c (`feat/audio-control-polish @ ec8ce887b1b` on master `f71e13cc154`: p4c4b2's branch
after six fix passes, 56 commits) against the unchanged model of `main f1b0538` (the binary `a894197d…`, qtest 15/15 before the
first VM run).

**The result in one paragraph.** **The first boot passes on upstream's swenum fix** (five first boots: the kernel's removal of
the software-bus node completes with `Safe removal: ROOT\SYSTEM\0000` where p4c4b bugchecked — **U1 closed**). **The stream through
the audio stack runs sample-exact at all three depths** — `dsploop: 3 of 3 depths compared`, `max abs error 0` at 16 valid bits
(within the 1-LSB tolerance), 24-in-32 and 32, `1285 tests executed (0 marked as todo, 0 failures), 0 skipped` under
`LIBERNT_APITEST_REQUIRED=1`, **`apitest-gate.sh --required` GREEN**; two more full runs launched from the data disk itself — **D3
closed**: the names are complete, `Speakers - Intel SST Loopback` / `Microphone - Intel SST Loopback`. **`SelfTest = 2` is
sample-exact at a system boot** (`3 runs, 3 matched, 0 failed`, `max abs error 0`, the 16-bit rms `5794.253`, `ran (0x00000000)`) and at
a D0 entry. The no-topology boot, the 22-cycle regression (22 `boot ok`, the model's registers identical before and after every
cycle), the fault rows and the `SelfTest = 0` boot regression are as expected. **D4 is the upstream limitation this image names**: a
disable of the DSP device with the audio service running is refused (`Failed to disable device: A device attached to the system is
not functioning.`) — **and it is refused with the audio service stopped too** (`AudioSrv` read `STOPPED`): the veto's handles are not the
service's, so TESTING.md's C11 path — the child and its endpoints going and returning over three cycles — **is not reached** (C11 below).
One new finding, **not in the audio path: the data disk's letter** — on `D:` the launch and the copy of
a file from the data disk answer `The system cannot find the path specified.` while `certutil` reads the same file; on `E:` both
work (E24′ below). Nothing was tuned or fixed on this side; the model was not changed; the model is in none of the findings
(`ace_unexpected` 0 in every VM).

| # | finding | class | status |
|---|---|---|---|
| **U1** | the first boot bugchecked in the PnP manager's walk of a removed device's stack (p4c4b) | upstream (kernel PnP with `swenum.sys`) | **closed — upstream's fix measured on this image**: five first boots (one without the data disk), `KsCreateBusEnumObject …` → `Safe removal: ROOT\SYSTEM\0000` 0.09–0.42 s later → the Setup phase; no stop line in any VM |
| **D3** | the apitest was skipped: the MMDevice names were cut at 31 characters and lost "Loopback" (p4c4b2) | driver (the endpoint's names) | **closed**: `MMDevices` holds `Speakers - Intel SST Loopback` and `Microphone - Intel SST Loopback` complete (29 and 31 characters), `{A45C254E-…},14` = `Speakers (Speakers - Intel SST Loopback)` / `Microphone (Microphone - Intel SST Loopback)`; the Sound applet lists both (Ready); the test finds both by identity and the stream runs (B5) |
| **D4** | a disable of an audio device with subdevices is refused once the audio service runs (`PiQueryRemoveDevice`'s open-handle veto) | **upstream limitation** (the kernel's query-remove veto; the fix passes ruled it the tree's own PnP path, not this driver) | **as TESTING.md says for C10, and beyond it for C11**: with the service running the disable of the DSP device (the child present) is **refused** — `DisableDeviceInstance(…)`, no `Safe removal`, pnputil `Failed to disable device: A device attached to the system is not functioning.`, the device `Started`. **With `AudioSrv` stopped it is refused all the same** (the DSP device, the child alone, the codec), so the C11 cycles are **not reached**: the veto's handles are not the audio service's (C11) |
| **E24′** | the apitest does not launch from the data disk (p4c4b2's E24) | **upstream (the OS's command shell / file system on the drive letter `D:`), not the driver, not the model, not the host** | **narrowed**: the failure follows the **letter**, not the file: with the data disk on `D:` (VM 1, and p4c4b2's r1/r5) the launch by its absolute path *and* `copy` answer `The system cannot find the path specified.` while `certutil -hashfile` reads the same file; with the data disk on `E:` (VM 5) the launch by the long name, by the 8.3 name `dsploop.exe`, and both `copy` forms work. Which component refuses on `D:` was not read (the tree was off limits); recorded, not fixed |
| O2 | the topology line says `4286 bytes (model 2384 bytes)`; p4c4b2's said `model 2288 bytes` | driver-side figure (the model binary is unchanged, `a894197d…`) | a note: the "model" byte count is the driver's own measure of the built topology model (T1 of the C2 round), and it grew by 96 bytes with the fix passes' parser; TESTING.md of p4c4c pins no value |
| — | the first launch of the round (the no-disk first boot) on a host saturated by another build | **environment** | recorded (r0a): `Storport: a request to 0:0:0 timed out after 10 seconds` ×7, `Failed to read attribute contents!`, `The volume holds a hibernated system. Opening disk as readonly.`, `WL: Failed to initialize Gina`, the display `User Interface Failure — The Logon User Interface DLL msgina.dll failed to load`; `ninja -j 3` with three compiler processes on the 4-CPU host (load average 4.4) during the whole boot; the same image, overlay type and command line reached the wizard on its next launch with the host quiet (r0, 0 Storport lines). Not a finding about the image |
| — | the C4a leftovers (i) and (ii) | — | (i) closed on p4c4b2 and measured again here (C8); (ii) is D4: refused with the service running (upstream), completed with it stopped (our path) |

### U1 — closed: the first boot on upstream's fix

Five first boots of fresh overlays (r0 without the data disk; r1, r2, r3 with it; r0a, the host-loaded one, also passed this step),
in the guest's time (r1 quoted; the others differ in the timestamps alone — `vm/measured-lines.txt`):

```
[    7.451273] intcdsp.sys: SelfTest = 0, UseInterrupts = 0, IpcTimeoutMs = 500 ms
[   39.879548] (\drivers\ksfilter\ks\swenum.c:1518) KsCreateBusEnumObject Devices BusDeviceObject FFFF8180005D5AD0
[   40.301425] (\base\services\umpnpmgr\event.c:360) Safe removal: ROOT\SYSTEM\0000
[   41.020177] (\drivers\ksfilter\ks\swenum.c:1518) KsCreateBusEnumObject Devices BusDeviceObject FFFF8180005D5D50
[   82.360257] (\base\services\umpnpmgr\rpcserver.c:6517) PNP_RegisterNotification(… 'Program Manager' …)
[   86.516522] (\base\setup\libernt\oobe.c:1071) Storage expansion not offered
```

The step at which p4c4b bugchecked on 11 of 11 boots is the `Safe removal` 0.09–0.42 s after swenum's first line; here it completes
on every first boot and the boot goes on to `First-boot setup lists 11 components`, the Setup wizard (r0's `s1-desktop-before-wizard.png`:
`LiberNT Setup — Choose your language and keyboard`), the desktop after the wizard's chords (`s3`, `s4`: the wallpaper, the icons, the
taskbar with its tray; the watermark `feat/audio-control-polish.ec8ce88.amd64.clang.0521-261126`) and a clean S5. The display is neither
blank nor garbled on this master's graphics rework (A2). No `The system has been stopped`, no `Stop code`, in any VM of the round.

### D3 — closed: the names, and the stream

`MMDevices\Audio` as the guest holds it (r1, `reg-mmdev.txt`):

```
HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render\{BDA7C5A8-F3C6-8B76-ABDB-D685E723178B}
    DeviceState    REG_DWORD    0x1
    {026E516E-B814-414B-83CD-856D6FEF4822},2    REG_SZ    Speakers - Intel SST Loopback
    {A45C254E-DF1C-4EFD-8020-67D146A850E0},2    REG_SZ    Speakers
    {A45C254E-DF1C-4EFD-8020-67D146A850E0},14   REG_SZ    Speakers (Speakers - Intel SST Loopback)
HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Capture\{E77CD7FF-39A3-83CB-BBF3-5EC2E8266020}
    DeviceState    REG_DWORD    0x1
    {026E516E-B814-414B-83CD-856D6FEF4822},2    REG_SZ    Microphone - Intel SST Loopback
    {A45C254E-DF1C-4EFD-8020-67D146A850E0},2    REG_SZ    Microphone
    {A45C254E-DF1C-4EFD-8020-67D146A850E0},14   REG_SZ    Microphone (Microphone - Intel SST Loopback)
```

The Sound applet lists the endpoint on Playback (`Speakers | Speakers - Intel SST Loopb… | Ready`) and on Recording
(`Microphone | Microphone - Intel SST Loo… | Ready`) beside the codec's `HD Audio Line out` / `Line In` (r1's `s8-sound-playback.png`,
`s9-sound-recording.png`; the applet's *Connected to* column is cut by its own width at the ellipsis — the value is complete in
the registry).

The stream (r5, the exe copied to the system disk, `LIBERNT_APITEST_REQUIRED=1`; `dsploop-out.txt`):

```
dsploop.c:73: dsploop: endpoint is of the DSP's PCM: filter {2}.\\?\intcdsp#pcm&ctlr_ven_8086&ctlr_dev_7f50#5&4d9fad45&0&00#{6994ad04-93ef-11d0-a3cc-00a0c9223196}\loopbacktopo
dsploop.c:73: dsploop: endpoint is not of the DSP's PCM: filter {2}.\\?\hdaudio#func_01&ven_1af4&dev_0022&subsys_1af40022&rev_1001#4&aeefd634&0&0001#{6994ad04-93ef-11d0-a3cc-00a0c9223196}\elineintopo
dsploop.c:73: dsploop: endpoint is of the DSP's PCM: filter {2}.\\?\intcdsp#pcm&ctlr_ven_8086&ctlr_dev_7f50#5&4d9fad45&0&00#{6994ad04-93ef-11d0-a3cc-00a0c9223196}\loopbackintopo
dsploop.c:411: dsploop: 48000 frames of the tone rendered, 96000 frames captured in 2016 ms
dsploop.c:426: dsploop: 48000 frames compared within 1 LSB, max abs error 0, offset 993, ok
dsploop.c:411: dsploop (24 valid in 32): 48000 frames of the tone rendered, 96000 frames captured in 2015 ms
dsploop.c:426: dsploop (24 valid in 32): 48000 frames compared within 0 LSB, max abs error 0, offset 513, ok
dsploop.c:411: dsploop (32): 48000 frames of the tone rendered, 96000 frames captured in 2000 ms
dsploop.c:426: dsploop (32): 48000 frames compared within 0 LSB, max abs error 0, offset 993, ok
dsploop: 3 of 3 depths compared, 0 preconditions missing (LIBERNT_APITEST_REQUIRED=1, a failure)

dsploop: 1285 tests executed (0 marked as todo, 0 failures), 0 skipped.
```

Exit code 0. `tools/apitest-gate.sh --required dsploop-out.txt`: **GREEN** (`dsploop: 1285 tests executed (0 marked as todo, 0 failures), 0 skipped.
(allowance 0, required)`). The program's wording differs from TESTING.md's (`compared within 1 LSB, max abs error 0` for "max abs
error <= 1 LSB (tolerance 1)"; `within 0 LSB` at 24-in-32 and 32); the measured error is 0 at every depth. The pins: the engine
opens each at `48000 Hz 2 ch 32 in 32 bits` (`dsppcm.sys: endpoint 'Loopback' render: pin created, 48000 Hz 2 ch 32 in 32 bits`, and the
capture's), three pairs for three depths (18 `pin created` and 18 `latency` lines in VM 5: three runs).

The FIFO constraint (B6): `intcdsp.sys: stream 1: latency: fifo 257 bytes, dsp estimate 2496 bytes (the copier's gateway buffer and the
PCM's module buffers)` on the render pin, `fifo 257 bytes, dsp estimate 2880 bytes` on the capture pin — on every one of the 18 lines of
the three runs (r5's 9, the data disk's two runs' 9). 257 bytes is 32 frames of 8 bytes (0.67 ms): under one period of the engine's
buffer at any period the engine would use for a 48000 Hz stream (its 10 ms default is 3840 bytes). The engine's period itself is not
printed by the driver or the test, so the constraint is read against the default, not against a measured period.

The model's side (`vm/rms-and-trace.txt`): 3618 `ace_audio` lines of the three runs — 1800 carrying the tone (every one the same line:
`rms 759251747.567 peak 1073741824 first 0 0 140181504 140181504 277872640 277872640 410910720 410910720`, a half-amplitude tone in
16-bit steps, periodic within the gateway's 3840-byte period), 1818 of silence; the render's and the capture's line identical in every pair
(no tone line without its twin). `ace_unexpected` 0.

### D4 — the upstream limitation, measured both ways (C10 and C11)

#### C10 — the service running: refused, as TESTING.md expects (r3; each command's own text from the data disk)

| command | pnputil's answer | the serial lines after it |
|---|---|---|
| `pnputil /disable-device "CSAUDIO\ADSP&CTLR_VEN_8086&CTLR_DEV_7F50\4&aeefd634&0&1000000000"` (the DSP device, the child present) | `Failed to disable device: A device attached to the system is not functioning.` | `PNP_DisableDevInst(… CSAUDIO\ADSP&… 0 0x00000000)` → `DisableDeviceInstance(CSAUDIO\ADSP&… 0)` — **no `Safe removal`** |

The Media list after it: the DSP device, `INTCDSP\PCM&…` and the codec all `Started` (`x-c10-media.txt`). The kernel prints nothing that
names the refusal — the veto itself (`PiQueryRemoveDevice`) is not in the serial log; the evidence of the refusal is the pair of lines without
the removal event, as on p4c4b2.

#### C11 — the service stopped: **the disable is refused all the same** — not as TESTING.md expects

`net stop audiosrv` (r3, `x-svc-stop.txt`): **no text** — but the service did stop: `sc query AudioSrv` afterwards reads
`SERVICE_NAME: AudioSrv  TYPE : 10 WIN32_OWN_PROCESS  STATE : 1 STOPPED  WIN32_EXIT_CODE : 0 (0x0)` (`x-svcq-AudioSrv.txt`), and the serial
log shows the service's PnP notification registration going: `PNP_UnregisterNotification(… 000000F60F5C3E90)` — the handle of the boot's
`PNP_RegisterNotification(… 'AudioSrv' … 000000F60F5C3E90 …)`. The service keys the registry names (`x-svc-keys.txt`): `AudioSrv` (the
user-mode service), `sysaudio` (`TYPE : 1 KERNEL_DRIVER`, `STATE : 4 RUNNING`, `STOPPABLE`), `usbaudio` (`STOPPED`, never loaded); there is
no endpoint-builder service in this tree.

With `AudioSrv` stopped, three asks (each answered within 4 s; the devices `Started` after):

| command | pnputil's answer | the serial lines after it |
|---|---|---|
| the DSP device, the child present (`x-c11-1-disable.txt`, `x-c11-dsp-retry.txt`) | `Failed to disable device: A device attached to the system is not functioning.` (twice) | `PNP_DisableDevInst(… CSAUDIO\…)` → `DisableDeviceInstance(…)`, no `Safe removal` |
| the child alone (`x-c11-child-disable.txt`) | the same text | the same two lines for `INTCDSP\PCM&…`, no `Safe removal` |
| the codec (`x-c11-codec-disable.txt`) | the same text | the same two lines for `HDAUDIO\FUNC_01&…`, no `Safe removal` |

Then `net stop sysaudio` (the kernel mixer; `x-svc-stop-sysaudio.txt`): no text in 180 s, and whether it stopped was not read; the DSP device
asked once more: **refused again**. So the veto's open handles are **not the audio service's** — they survive the service's stop — and the
C11 path (the child and its endpoints going and returning, a pin open across the cycle, the streams released at power-down, three cycles) **cannot
be reached from the guest by a disable while the child's KS devices exist**. Which component holds the handles was not read (the tree was off
limits): the kernel mixer (`sysaudio`, named by the fix passes' own analysis: "an adapter whose KS subdevices the mixer holds open") is the
candidate, but its stop did not free the device either — if it stopped at all. **Class: upstream** (the kernel's query-remove veto with open
handles on the KS devices), the same limitation as D4, one level deeper than TESTING.md's "with the audio service stopped" assumed.

What was not run because of it: the three cycles with the child present, the pin-open row (the generation check in the VM), the
"streams released at power-down" line at a power-down with streams built (`streams: released for the power-down` is in the driver's strings
but was never printed in this round: no power-down with a child ever happened), the leak check across cycles.

#### E16 (N5-05) — the codec's restart (r3, the service stopped; r4, the service running)

`pnputil /restart-device "HDAUDIO\FUNC_01&VEN_1AF4&DEV_0022&SUBSYS_1AF40022&REV_1001\4&AEEFD634&0&0001"`: `Restarting device: HDAUDIO\…` then
**`System reboot is needed to complete the operation!`**; **no serial line at all after it** (no `PNP_DisableDevInst`, no `Safe removal`, no
driver line). The restart does not go through a stop the driver would see now; it is deferred to the next boot. N5-05's expectation ("the adapter
is kept across a stop now") is therefore **not exercised** by this command on this image: there is no stop. Class: upstream (pnputil's/the PnP
manager's restart semantics with the veto).

### E24′ — the data disk's letter

The rows (each command's own text from the data disk; `dir` and `certutil` read the same file in the same console):

| VM | the data disk | command | the guest's answer |
|---|---|---|---|
| r1 | `D:` | `certutil -hashfile D:\dsploop_apitest.exe SHA256` | the hash (`3b6c1a60…`), `command completed successfully` |
| r1 | `D:` | `D:\dsploop_apitest.exe > D:\x-launch-pouch.txt 2>&1` (the launch by its absolute path) | `The system cannot find the path specified.` |
| r1 | `D:` | `copy D:\dsploop_apitest.exe C:\dsploop_apitest.exe` | `The system cannot find the path specified.` |
| r1 | `D:` | `C:\dsploop_apitest.exe` | `Can't recognize 'C:\dsploop_apitest.exe ' as an internal or external command, or batch script.`, errorlevel 9009 (the copy had failed) |
| r5 | `E:` | `dir E:\dsploop_apitest.exe`, `dir E:\dsploop.exe` | each `1 file 211,968 bytes` |
| r5 | `E:` | `certutil -hashfile E:\dsploop.exe SHA256` | the hash |
| r5 | `E:` | `copy E:\dsploop.exe C:\dsploop_apitest.exe` | `1 file(s) copied` |
| r5 | `E:` | `copy E:\dsploop_apitest.exe C:\x-lfn.exe` | `1 file(s) copied` |
| r5 | `E:` | `E:\dsploop_apitest.exe` (no switch) | the whole test: `3 of 3 depths compared`, `max abs error 0` ×3, `1259 tests executed (0 marked as todo, 0 failures), 0 skipped` |
| r5 | `E:` | `E:\dsploop.exe` (no switch) | the whole test: `3 of 3 depths compared`, `max abs error 0` ×3, `1290 tests executed (…), 0 skipped` |

p4c4b2's rows agree with the letter: its r1 and r5 had the data disk on `D:` and the launch failed; its r3 had it on `E:` but typed `D:\…`
(E30 there — which, by this table, failed because `D:` was not the data disk, or because of `D:`; the two were not separated there).
What `D:` is on this image when the data disk gets another letter was not examined (r5's `D:` was not the data disk). The image's own
`pouch.tag` probe (`if exist D:\pouch.tag`) and `echo … > D:\alive.txt` work on `D:`, as does `certutil`'s read; the launch, `copy`
(and p4c4b2's E24) do not. **Class: upstream** — the shell's or the file system's handling of a file on the letter `D:`; the DSP driver
is not in the path of any of these commands, and the model is not either. For the next round: give the data disk a letter above `D:`
or copy the tool in by another way; the gate's stream run needs the copy.

### The rest of TESTING.md's runs — measured

| run | measured | evidence |
|---|---|---|
| A3: `SelfTest = 0` at a system boot (with the topology) | `SelfTest = 0, UseInterrupts = 0, IpcTimeoutMs = 500 ms`; `boot ok after 5451 us (clock 1028730059 us) … attempt 1, 0 DSP interrupts, cleanup ok, ADSPCS 0x01010000`; `firmware ready: version 2.15.0.1, ABI 1, … downlink mailbox 4096 bytes, uplink mailbox 4096 bytes, …` (E17: 4096, as expected); the topology line, the modules line, `audio child 'INTCDSP\PCM&CTLR_VEN_8086&CTLR_DEV_7F50\00' for pcm 'Loopback': 2 endpoints`, the two endpoint lines and the four `registered as` lines; no self-test line; clean S5 (r1's reboot: rc=0; r5's boot: rc=0) | `vm/r1-…`, `vm/r5-…` |
| B7: `SelfTest = 2` at a system boot | `4096 frames captured after 85 ms, offset 0 frames, max abs error 0, render rms 5794.253, capture rms 5794.253, ok` (16 bits); `… render rms 379742706.482, capture rms 379742706.482, ok` (24 and 32); `3 runs, 3 matched, 0 failed, 45 requests, 0 notifications, 0 timeouts, 0 DSP interrupts, ok`; `ran (0x00000000), the DSP is left running`; the model's 12 `ace_audio` lines: every pair identical, every line the sine (`ace-audio-check.py`: rc=0) | `vm/r1-…`, `vm/rms-and-trace.txt` |
| B7, the D0 entry | `SelfTest = 2` set before the cycle that brings the child (the disable completes: no child exists yet): at the enable's D0 entry the same nine lines as the system boot's, `85 ms`, `max abs error 0`, `5794.253` / `379742706.482`, `3 runs, 3 matched, 0 failed, 45 requests`, `ran (0x00000000), the DSP is left running`; then run 1's lines at the same entry (the topology line, the modules line, `audio child … 2 endpoints`, the two endpoint lines, the four `registered as`); the model's 12 `ace_audio` lines as r1's | `vm/r3-…`, `vm/rms-and-trace.txt` |
| C8: no topology | `topology: none selected (no override, no quirk, no _DSD name); the DSP is powered down, no audio endpoint`; `DSP power down from state ready: ok, cleanup ok, ADSPCS 0x00000000 (SPA 0, CPA 0)`; 0 `audio child` lines, 0 `dsppcm.sys` lines in the VM; no `INTCDSP` entry in the Media list | `vm/r2-…` |
| C9: the DSP device alone | two more cycles after C8's: each `Safe removal: CSAUDIO\…`, `boot ok after … 0 DSP interrupts`, the power-down; rc=0 | `vm/r2-…` (`cycles.log`) |
| the regression: 22 cycles | `AC3 cycles: 22 run, 22 boot ok, 0 bounded timeouts, 0 other outcomes, 0 waits not seen, clock stalled lines: 0`; the model's registers read over qtest before and after each cycle: **one distinct reading** before (`adspcs=00000000 dsp2cxctl=02000000 inten=00000000 irqsts=00000000 hfhipcie=00000000 hfipcxtdr=00000000 hfipcxida=00000000 hfipcxctl=00000000 hfipcxtddy=00000000 fsr=00000000`) and one after — equal, as p3c1's; 25 `Safe removal`, 25 `none selected`, 25 power-down lines in the VM; clean S5 | `vm/r2-…` (`cycles.log`, `summary.txt`) |
| the regression: the fault rows | **20 of 20 bounded and recovered** (`none`, the 17 faults, the two delay scales), each with a real `after N us` on its budget and its two clock readings consistent (`N' - N - M` 93–187 µs), no bugcheck, no hang, `tools/fm-check.sh`: **0 rows with a failed check**; each row followed by a recovery cycle with `boot ok` (`recovered: boot ok` ×20). The terminal lines are p3c1's (timings aside): `boot ROM error … 0x0000002b base firmware not found`, `… 0x0000002c CSE validation failed`, `… 0x00000033 base firmware incompatible`, `boot firmware crash`, `boot ABI mismatch` (×2), `boot power-up timeout after 52480 us`, `boot ROM init timeout after 1509343 us`, `boot ROM status timeout after 909338 us`, `boot base firmware timeout after 3004644 us`, `boot FW_READY timeout after 1006451 us`, `boot IPC reply timeout` (×2), `boot IPC error`, `boot bad IPC reply`, `boot truncated`, `boot version mismatch`, `boot power-up timeout` (scale 1550), `boot ROM error … 0xa0000005` (scale 0.001), `boot ok after 5450 us` (`none`); 40 settings lines for 40 device starts, 0 stop lines | `vm/fault-matrix.md`, `vm/fm-<fault>/` |

### Notes (E33–E45): the environment, the tools and my own faults

| # | note |
|---|---|
| E33 | **my own faults, all found in the logs.** (a) `vmcommon.sh`'s first `waitre` required its third argument and `set -u` ended `boot0.sh` right after `start_vm` (r0): the VM kept running, `boot0b.sh` took it over (its `wait` on the launcher's pid returned at once because the pid was not its child; the launcher was then seen to exit and the line was written by hand). (b) The first launch of `boot1.sh` ended before its VM started: the data disk's directory under `/tmp` did not exist (`!! no data disk`); made, and the launch repeated (r1). (c) A `pkill -f` of mine matched my own wrapper shell and killed it (as p4c4b2's E27) while ending r0a: the VM was then shut down by hand through the monitor, cleanly. (d) `cmd` (the typed-command helper) returns at the first bytes of a command's output: in r5 the second launch line was typed while the first apitest still ran — the console buffered it, both runs completed, and their files were read back in full after the VM ended (the `driver.log` quotes only their first lines). (e) The round's copy of `tools/fault-matrix.sh` lives outside the project's `tools/` directory, so the path it derives from its own location was wrong: the first launch of the batch started no VM (`env: './run.sh': No such file or directory`, every row "not reached" within seconds, no VM time spent); the path was set in the copy, one row was run as a pre-flight, then the other nineteen |
| E34 | the host: another build (`ninja -j 3`, three compiler processes) ran on the 4-CPU host from about 21:12Z to 21:23Z; the VM launched in that window is r0a (the environment row above). Every evidence VM ran with the host quiet (`uptime` checked before r0) |
| E35 | `pnputil /enum-devices /class AudioEndpoint /ids` answers `No devices were found on the system.` (r1, r2, r5; as on p4c4b2): the endpoints are not PnP devices of that class in this tree — the lists of record are the Media list and the `MMDevices` registry |
| E36 | the Sound applet's *Connected to* column cuts the endpoint's name at an ellipsis (`Speakers - Intel SST Loopb…`): the column's width, not the name (the registry's value is complete). Cosmetic; upstream |
| E37 | the guest's clock in the screenshots of the first-boot session runs ahead of the host (r0: `9:53 PM` then `10:07 PM` within a minute of wall time; the host's UTC was 21:29): the guest's time under `-icount` is not evidence and was not used |
| E38 | the image prints `UBSAN:` lines of its storage path in the first boots (`fastfat/deviosup.c`), as p4c4b2 did (its E32); its update agent tried `https://libernt.com/api/update/…` once a session (`0x80072ee7`; the VM has no network interface: `-nic none`) — as p4c4b2's E31 |
| E39 | r1's last query (`reg query …\Settings` after `SelfTest = 0` was set) left no file on the data disk; the setting itself landed (r5's boot printed `SelfTest = 0`) |
| E40 | the screenshots read by me: A2 (r0's s1–s4, r1's s1–s3), B4 (r1's s8, s9), r0a's `x-user-interface-failure.png`, and group D's (listed there). None was read to decide a serial line or a file's text |
| E41 | the test program counts its executed tests by timing: `1259`, `1290` and `1285 tests executed` in r5's three runs of the same binary — the number of assertions that ran, not a difference in outcome (each `0 failures`) |
| E42 | this image's `net stop` prints nothing (`x-svc-stop.txt`, `x-svc-stop-sysaudio.txt`: 0 bytes; the service's state was read with `sc query` instead), and `net start` answers `Error: 234` (`ERROR_MORE_DATA`: its service list does not fit the tool's buffer). Upstream, outside the audio path; recorded because the run book's "the audio service stopped" was read through them |
| E43 | `pnputil /enum-devices /class Media /ids` and the registry show the three audio devices `Started` after every refused disable (r3: `x-c10-media.txt`): a refusal leaves no trace in the device state |
| E44 | the Sound applet opened with the audio service stopped (r3's `s5-sound-service-stopped.png`) lists the devices from the registry (`HD Audio Line out`, `Speakers - Intel SST Loopb…`, both as before): the applet's list does not need the service |
| E45 | **the end of r4.** After the by-eye steps the Sound dialogs did not close on `Escape` (this applet ignores it, as the wizard does; `alt+c` did not close the sheet either in the state it was in), the Run dialog kept the line my `console` had typed into it, and `boot4end.sh` read no console: its probe (both services stopped, each state read before and after, the DSP device asked once more) and the registry read of the changed format **did not run**; the script waited its bounded waits and was stopped by my wrapper's 15-minute cap; the VM was ended by the power button (clean S5, `DSP power down from state ready: ok`), wall 2110 s — the round's longest VM and its least productive |

### Group D — the user-mode fixes by eye

Driven step by step from the host (a few keys, a screenshot each: `step.sh`, `dsteps.sh`), in r4 (the overlay of VMs 1 and 5: the DSP boots with
its child at the system boot; the audio service running). The vision reading of a screenshot is approximate — the focus rectangle and the
selection highlight were read more than one way at the scale of the whole screen, so each step was read on a zoomed crop (`z-*.png`) before the
next — and no line of the serial log or of the data disk was ever decided from one.

| item | what was done | what was seen | verdict |
|---|---|---|---|
| D12 c: the device's Properties opened **again after its format was changed once** (the page was freed through the heap before) | the Sound applet (`mmsys.cpl`), the DSP's device selected in the list (`home`: `Speakers | Speakers - Intel SST Loopb… | Ready`), `alt+p`: the Properties sheet; `ctrl+tab`: the Advanced tab, `Default Format: 2 channel, 32 bit, 48000 Hz (Studio Quality)` → `up up` → `2 channel, 16 bit, 48000 Hz (DVD Quality)`; `alt+a` (Apply), `ret` (OK); then `alt+p` again | the sheet opens again — `Properties for Speakers (Speakers - Intel SST Loopback)`, the Advanced tab active, `2 channel, 16 bit, 48000 Hz (DVD Quality)` kept — no crash, no garbage (`d12-11-properties-again.png`). Before: the General tab had `Controller: Intel Smart Sound Technology DSP Audio`, `Manufacturer: Intel`, `Driver provider: LiberNT`, `Driver version: 1.0.0.0`, `Driver date: 11/26/2026`, `Jack Information — Connector: Speakers` (`d12-6-properties.png`) — **the complete name in the sheet's title** | **measured: the page opens again after a format change; the change is kept** (the registry read of the new format was not taken: see E45) |
| D12 d: the format strings on the Sound page of Settings in the UI language | `ms-settings:sound` typed in the Run dialog | nothing visible opened (`d12d-1-settings-sound.png`: no Settings window); the applet's own format strings are in the UI language (`2 channel, 16 bit, 48000 Hz (DVD Quality)`, `2 channel, 32 bit, 48000 Hz (Studio Quality)`) | the applet's strings seen; **Settings' Sound page not run** |
| D12 a, b: the list refreshes when a device arrives or is removed; Set Default on a gone device shows a message | — | **not reachable**: no removal can happen while the veto stands (C10, C11), with or without the service; with the service stopped the applet still lists the devices from the registry (r3's `s5-sound-service-stopped.png`) | **not run** |
| D13: the tray's volume flyout, the mixer flyout, the quick-settings flyout (N6-02) | — | the tray was not reached by keyboard in the time left; no click was attempted | **not run** |
| D14: the Microphone page names WASAPI only | `ms-settings:privacy-microphone` typed in the Run dialog | nothing visible opened (`d14-1-privacy-microphone.png`) | **not run** |
| E16 in r4: `pnputil /restart-device` on the codec with the service running | the command's own text to the data disk | `Restarting device: HDAUDIO\…` → `System reboot is needed to complete the operation!`; no serial line after it — as in r3 | recorded (both ways alike) |

The overlay `p4c4c.qcow2` keeps the render endpoint's format at 16 bits, 48000 Hz (the default was not restored).

### What the round did not run

- **The C11 path with the child present**: the child and its endpoints going and returning by a disable, a pin open across the cycle (the generation
  check in the VM), `streams: released for the power-down` printed at a power-down with streams built (the string is in the driver; the line never
  printed in this round: no power-down with a child ever happened), the leak check across three cycles — refused with the service running and with
  it stopped (D4, C11).
- Of group D: the applet's list refresh on arrival/removal and Set Default on a gone device (no removal can happen), Settings' Sound page and the
  Microphone page (the `ms-settings:` URIs opened nothing from the Run dialog), the tray flyouts (not driven). The registry read of the format change
  and the end-of-VM probe of D4's holder (both services stopped, the states read) did not run (E45).
- Which component holds the handles behind the veto (INFO_NEEDED 10 in the README): for the driver owner to read in the tree.
- The live read of the descriptor lists during the apitest's runs (the p4c4b round's `livecap.py`): not run — the stream was read from the test's
  own output, the driver's lines and the model's trace.
- As before: `UseInterrupts = 1`, the refusal rows of the topology selection, silicon; Meteor Lake on silicon; the 32-bit wrap (the plan's INFO_NEEDED).
