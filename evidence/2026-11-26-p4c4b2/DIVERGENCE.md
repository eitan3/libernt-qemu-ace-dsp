# DIVERGENCE — the p4c4b2 round (2026-11-26)

The C4 micro round rerun on image p4c4b2 (`feat/audio-control-polish @ 13ab35e3992` on master `a81cf9e65cf`: p4c4b plus the
swenum fix) against the model of `main b8dcec7` (the binary `a894197d…`, qtest 15/15 before the first VM run).

**The result in one paragraph.** The first boot passes — **U1 is fixed**: on four first boots the kernel's removal of the
software-bus node, which bugchecked on every boot of p4c4b, completes with `Safe removal: ROOT\SYSTEM\0000`. Of TESTING.md's
runs, **run 1 is exact** (the child and the endpoint's lines, on three boots), **`SelfTest = 2` is sample-exact at 16, 24 and 32
bits** (3 runs, 3 matched, `max abs error 0`, the 16-bit rms `5794.253`), the **no-topology boot** and the **`SelfTest = 0`
boot regression** are as expected. Two things are not: **the stream through the audio stack was not reached** — the apitest
is skipped because the MMDevice enumerator's endpoint names are cut at 31 characters and lose the word "Loopback" (**D3**) —
and **a disable of any audio device that has subdevices fails** with `Failed to disable device: A device attached to the system
is not functioning.` (**D4**): the PCM child alone, the codec, and the DSP device with its child; so the C4a leftover (ii) is
re-recorded, not closed. Nothing was tuned or fixed on this side; the model was not changed; the model is in none of the
findings (no `ace_unexpected`; D4 is PnP; D3 is before any stream exists).

| # | finding | class | status |
|---|---|---|---|
| **U1** | the first boot bugchecked in the PnP manager's walk of a removed device's stack (p4c4b's round) | upstream (kernel PnP with `swenum.sys`) | **fixed — measured on this image (the local variant `13ab35e3992`); fixed upstream too in `693821aba75`, per the manager's message and confirmed in the tree (read only): the next image carries upstream's form** |
| **D3** | the apitest is skipped: `no active render endpoint named 'Loopback'; the DSP's audio child is not present (0x80070490)`. The child is present and both endpoints are active in `MMDevices`, but their interface friendly names are **cut at 31 characters** (`Speakers - Intel Smart Sound DS`, `Microphone - Intel Smart Sound `) and the device friendly names are `Speakers` / `Microphone`: the word "Loopback" is lost | **driver**: the endpoint's names as the MMDevice API gets them (the tree's endpoint list, `dll/win32/mmdevapi/devenum.c` in its ReactOS mode, takes them from the audio driver's `get_endpoint_ids`; the INF declares `FriendlyName`), not the DSP stream path, not the model | **blocking for the stream (the brief's run 2)**: 2 runs of the test in 2 VMs, the same line |
| **D4** | a disable of an audio device that has subdevices fails: `PNP_DisableDevInst(…)` → `DisableDeviceInstance(…)` → no `Safe removal`; `pnputil`: `Failed to disable device: A device attached to the system is not functioning.` The device stays `Started` | **driver or upstream — not model, not environment**: the guest's audio PnP disable path. By TESTING.md's own reading ("if the codec fails too, it is the tree's disable path") it is the tree's: the codec fails although no DSP driver is in its stack. Which component refuses was not read | **open; the C4a leftover (ii) re-recorded.** 4 asks with the child or subdevices present, 4 failures; the 3 asks without complete |
| O1 | the driver's 16-bit self-test rms was 0.006 % low (p4c4a, p3c3b: `5793.911`) | driver | **closed on this image**: `5794.253`, the exact `5794.254` to a thousandth |
| — | C4a leftover (i): no topology → no child, no endpoint | — | **closed**: measured as expected (r4) |
| — | C4a leftover (ii): the disable attribution | — | **re-recorded** (D4) |

### U1 — fixed, and what the first boot now shows

Every first boot of this image with an HDA codec present (four: r0b without the data disk, r1, r5 and r4 with it), in the guest's
time (r1 quoted; the others differ in the timestamps alone — `vm/measured-lines.txt`):

```
[   42.423941] (\drivers\ksfilter\ks\swenum.c:1518) KsCreateBusEnumObject Devices BusDeviceObject FFFF8180005D7AD0
[   42.736442] (\base\services\umpnpmgr\event.c:360) Safe removal: ROOT\SYSTEM\0000
[   43.908320] (\drivers\ksfilter\ks\swenum.c:1518) KsCreateBusEnumObject Devices BusDeviceObject FFFF8180005D7D50
[   92.969813] (\base\setup\libernt\oobe.c:1059) First-boot setup lists 11 components
[   92.969813] (\base\setup\libernt\oobe.c:1071) Storage expansion not offered
```

On p4c4b the boot stopped 0.2–0.5 s after the first line (`Stop code: 0x0000001E`, `ntoskrnl.exe + 0x17deb9`, the kernel walking
`ROOT\SYSTEM\0000`'s stack after swenum had deleted its bus device object without detaching it: the earlier round's U1). Now the
removal completes 0.16–0.44 s after that line, the bus device object is created again (`FFFF8180005D7D50`: a new object), the
codec's and the audio stack's lines follow, and the boot reaches its Setup phase and its desktop. With the data disk attached
the first object is the one p4c4b's r0a printed (`FFFF8180005D7AD0`): the same allocation, and where r0a stopped, this boot goes
on. No stop line, no `Stop code`, in any of the six VMs.

Upstream fixed the same defect independently on the morning of this round (`693821aba75`: pass the remove request down the stack
and detach before deleting the bus device), as the manager's message says; that form is not in this image.

### D3 — the apitest is skipped: the endpoint's MMDevice names lose "Loopback"

#### The lines

The test, launched from the system disk (twice: r5 at the first boot's session, r3 at a plain boot; `dsploop-out.txt` of each):

```
dsploop.c:468: Tests skipped: dsploop: no active render endpoint named 'Loopback'; the DSP's audio child is not present (0x80070490)

dsploop: 2 tests executed (0 marked as todo, 0 failures), 1 skipped.
```

Exit code 0 both times. On the serial log **no line of the stream path came**: no `dsppcm.sys: endpoint 'Loopback' … pin created`,
no `intcdsp.sys: stream <t>: latency: fifo …`, nothing — the engine was never asked for a pin. `0x80070490` is
`HRESULT_FROM_WIN32(ERROR_NOT_FOUND)`: the test's `FindEndpoint` (`modules/rostests/apitests/dsploop/dsploop.c:76–109`) asks
`IMMDeviceEnumerator_EnumAudioEndpoints(eRender, DEVICE_STATE_ACTIVE)` and takes the first device whose
`DEVPKEY_DeviceInterface_FriendlyName` or `DEVPKEY_Device_FriendlyName` contains `Loopback`; there is none.

#### What the enumerator holds — read in the guest (r3, `reg-mmdev-render.txt`, `reg-mmdev-capture.txt`)

```
HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render\{BDA7C5A8-F3C6-8B76-ABDB-D685E723178B}
    DeviceState    REG_DWORD    0x1                       (DEVICE_STATE_ACTIVE)
    \Properties
    {026E516E-B814-414B-83CD-856D6FEF4822},2    REG_SZ    Speakers - Intel Smart Sound DS
    {A45C254E-DF1C-4EFD-8020-67D146A850E0},2    REG_SZ    Speakers
    {A45C254E-DF1C-4EFD-8020-67D146A850E0},14   REG_SZ    Speakers (Speakers - Intel Smart Sound DS)

HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Capture\{E77CD7FF-39A3-83CB-BBF3-5EC2E8266020}
    DeviceState    REG_DWORD    0x1
    {026E516E-B814-414B-83CD-856D6FEF4822},2    REG_SZ    Microphone - Intel Smart Sound 
    {A45C254E-DF1C-4EFD-8020-67D146A850E0},2    REG_SZ    Microphone
    {A45C254E-DF1C-4EFD-8020-67D146A850E0},14   REG_SZ    Microphone (Microphone - Intel Smart Sound )
```

(`{026E516E-…},2` is `DEVPKEY_DeviceInterface_FriendlyName`, `{A45C254E-…},2` `DEVPKEY_Device_FriendlyName`; the legacy
endpoints `HD Audio Line out` and `HD Audio Line in` are listed beside them, the same way.) So:

1. **Both endpoints of the DSP's child are there and active.** The child is not missing; the test's skip line is wrong about
   that — it says so because it found no name.
2. **The interface friendly names are cut at 31 characters** — `MAXPNAMELEN − 1`, the legacy mixer device-name limit. The INF's
   names (`dsppcm.inf:75, 82, 89, 96`: `HKR,,FriendlyName,,%Dsppcm.LoopbackRenderName%` …), `Speakers - Intel Smart Sound DSP
   Loopback` and `Microphone - Intel Smart Sound DSP Loopback` as TESTING.md quotes them, lose their last word.
3. **The device friendly names are `Speakers` and `Microphone`**, which carry nothing to find the endpoint by.

In this tree the list the MMDevice API enumerates is built in ReactOS mode by `reactos_refresh_devices` → `load_driver_devices`
(`dll/win32/mmdevapi/devenum.c:878–947`), which takes every endpoint's name and state from the audio driver's `get_endpoint_ids`
and stores them (`MMDevice_Create`). Which member of that path holds the name in a 32-character buffer was not read.

Beside the names, the same read shows the render endpoint's device format as the tree holds it: 48000 Hz, 2 channels, 32 bits
(`{E4870E26-…},3`: `FEFF 0200 80BB …`), the deepest word the pin offers — as TESTING.md expects.

#### What it means for the round

The stream through the audio stack — the brief's run 2: the `dsploop: 48000 frames compared …` lines at 16, 24 and 32 bits, the
offset, the negotiated engine buffer and period at pin creation, the FIFO constraint, the live read of the descriptor lists,
the `ace_audio` render-against-capture comparison of the apitest — **was not reached in any depth**. The stop rule of run 2 was
not met, because no sample compared.

The fix is not on this side and I did not look for a way around it inside the guest (the test is the driver owner's, its lookup
rule the plan's). For the next round there are three places a fix could go, which I name and do not choose: the names in the INF
(short enough that the PCM's name survives 31 characters), the 32-character name buffer in the tree's endpoint list, or the
test's lookup (a property that carries the PCM's name). Until one of them, `dsploop_apitest` will skip on any image with these
names.

### D4 — a disable of an audio device that has subdevices fails

#### The rows (r3; each command's own text from the data disk, `attrib-*.txt`)

| order | command | the guest's answer | the serial lines after it |
|---|---|---|---|
| 1 | `pnputil /disable-device "INTCDSP\PCM&CTLR_VEN_8086&CTLR_DEV_7F50\5&4D9FAD45&0&00"` (the child alone) | `Failed to disable device: A device attached to the system is not functioning.` | `PNP_DisableDevInst(… INTCDSP\PCM&… )`, `DisableDeviceInstance(INTCDSP\PCM&… )`, nothing more: **no `Safe removal`** |
| 2 | `pnputil /enable-device` (the child) | `Device enabled successfully.` | nothing (the device was never down) |
| 3 | `pnputil /disable-device "HDAUDIO\FUNC_01&VEN_1AF4&DEV_0022&SUBSYS_1AF40022&REV_1001\4&AEEFD634&0&0001"` (the codec) | `Failed to disable device: A device attached to the system is not functioning.` | the same two lines for the codec, **no `Safe removal`** |
| 4 | `pnputil /enable-device` (the codec) | `Device enabled successfully.` | nothing |
| 5 | `pnputil /disable-device "CSAUDIO\ADSP&CTLR_VEN_8086&CTLR_DEV_7F50\4&aeefd634&0&1000000000"` (the DSP device, the child present) | `Failed to disable device: A device attached to the system is not functioning.` | the same two lines for the DSP device, **no `Safe removal`** |

Each command **returned**: its text was on the data disk 17–19 s after the typing of its line began (the typing of a line of
about 95 characters takes about 10 s at the monitor's pace), so within about 8 s of the Enter. Nothing stalled: after the last
row the console answered a marker in 3 s, and the VM took a clean S5. **The shape is a failure, not a stall** — p4c4a's
finding 1 ("the second disable never completed") does not describe this master.

The same row 5, seen first in r1 at the session's second cycle: `Safe removal` did not come within the script's 60 s wait, no
self-test line within 180 s, and by 12:42:17 UTC the console was back at its prompt with `Failed to disable device: A device
attached to the system is not functioning.` in its text (the script's own screenshot `s7-selftest0.png`); the exact time the
command returned was not read there. After it, the guest's own lists (`postfail-media.txt`, `postfail-system.txt`) show the DSP
device, the child and the codec all **`Started`**: none was removed.

**The three disables that completed** are the ones asked of a device with no child and no subdevice: the DSP device at its first
cycle in r1, r5 and r4 (`DisableDeviceInstance(CSAUDIO\…)` → `Safe removal: CSAUDIO\…` 11–16 ms later, with `BootDsp = 0` or
before any D0 entry had created the child).

#### Where the failure comes out (read in the tree, `13ab35e3992`)

`DisableDeviceInstance` (`base/services/umpnpmgr/rpcserver.c:494–541`): `QueryRemovalApplications` (the user-mode vetoes), then
`NtPlugPlayControl(PlugPlayControlQueryAndRemoveDevice, …)`. A `STATUS_NO_SUCH_DEVICE` would give `CR_INVALID_DEVNODE`, a
`STATUS_PLUGPLAY_QUERY_VETOED` `CR_REMOVE_VETOED` (pnputil would then say "vetoed"), any other failing status
`NtStatusToCrError(Status)` — `CR_FAILURE`'s text is the one printed; on success alone does it reach
`SetDeviceStatus(…, DN_HAS_PROBLEM, CM_PROB_DISABLED)`, and no `Safe removal` event follows a failure. So the kernel's
query-and-remove **answered a status that is neither** of those two; the kernel printed nothing that names the refusal.

#### What it means

By `TESTING.md`'s rule for this run: "If the codec fails too, it is the tree's disable path (the board's open task on a PortCls
adapter whose subdevices the mixer holds open); if only the child does, the suspects are `dsppcm.sys`'s `DSPPCM_Pnp` and the
KMDF PDO's removal." **The codec fails too**, in the same way and in the same time: so it is the tree's disable path, and the
DSP's child is one instance of it, not the cause. The common factor of the four failures is an adapter whose KS subdevices
(topology and wave) the mixer holds open; the three successes have none.

**It is new against p3c3b's image**, where disable/enable cycles with the child present completed (the D0 re-entries of its
self-tests; the 22-cycle runs of p2b4 and p3c1). On this master (its PnP disable semantics are the new ones `TESTING.md`
describes) no cycle can be taken once the child exists: that is why `SelfTest = 2` had to be set before the one cycle in r5, and
why the cycle run cannot be repeated on this image as it was.

I did not read which component refuses — the adapter driver's `IRP_MN_QUERY_REMOVE_DEVICE`, the bus driver, the mixer's open
handles, or a user-mode veto — and I did not repeat the codec's row on a controller without the DSP drivers (the ICH9 controller
binds the same `hdaudbus.sys`, so it would not have separated the two).

### The C4a leftovers and the rest of TESTING.md's runs — measured

| run | measured | evidence |
|---|---|---|
| run 0: the first boot | **passes, four times** (U1) | `vm/measured-lines.txt` |
| run 1: `BootDsp = 1` + `Topology` | **exact, on three boots** (r1 at the first cycle, r5 at the one cycle, r2 and r3 at system boots): the `BootDsp = 1` line, the topology line (`4286 bytes (model 2288 bytes)`), the modules line, the `audio child` line, the four `endpoint 'Loopback'` lines, the four `registered as` lines; `boot ok after 5445–5896 us … 0 DSP interrupts, cleanup ok`; the Media list has `INTCDSP\PCM&…` `Started`; the Sound applet lists the endpoint on Playback and Recording (Ready) | `vm/expected-vs-measured.txt`; r1's `enum-media.txt`, r5's; `s8`, `s9` of r1 and r5 |
| run 1's self-test half (`SelfTest = 2`) | **sample-exact, three runs**: `4096 frames captured after 85 ms, offset 0 frames, max abs error 0, render rms 5794.253, capture rms 5794.253, ok` (16 bits); `… render rms 379742706.482, capture rms 379742706.482, ok` (24 and 32); `3 runs, 3 matched, 0 failed, 45 requests, 0 notifications, 0 timeouts, 0 DSP interrupts, ok`; `ran (0x00000000), the DSP is left running`. The model: 12 `ace_audio` lines, every pair identical, every line the driver's sine (`vm/rms-and-trace.txt`) | r5 |
| run 2: the stream | **not reached — skipped (D3)** | r5, r3 |
| run 3 (i): no topology | **as expected**: `topology: none selected (no override, no quirk, no _DSD name); the DSP is powered down, no audio endpoint`, `DSP power down from state ready: ok, cleanup ok, ADSPCS 0x00000000 (SPA 0, CPA 0)`; no `audio child` line, no `dsppcm.sys` line in the boot, no `INTCDSP\PCM` entry in the Media list | r4 |
| run 3 (ii): the disable attribution | **fails for all three (D4)** | r3, r1 |
| run 3 (iii) / run 4: `SelfTest = 0` at a system boot | **as expected**: `SelfTest = 0, UseInterrupts = 0, IpcTimeoutMs = 500 ms`; `boot ok after 5445 us … 0 DSP interrupts`; the topology line and the modules line; the child and the four registrations; **no self-test line**; clean S5. (At a cycle with `SelfTest = 0`: r1's first cycle, no self-test line.) | r2, r1 |

### Notes (E24–E32): the environment, the tools and my own faults

| # | note |
|---|---|
| E24 | **the data disk does not launch the apitest.** The p4c4b round's typed line, `%POUCHDRV%\dsploop_apitest.exe > %POUCHDRV%:\dsploop-out.txt`, is answered by this image's `cmd.exe` with `The system cannot find the path specified.` — three times (r1, r5, r4; in r4 as the guest's own text on the data disk, `x-launch-pouch.txt`; in r1 the errorlevel `3`, `ERROR_PATH_NOT_FOUND`, `dsploop-rc.txt`), although `dir` lists the exe there and `certutil` hashed it there in the same console. The line is echoed as typed. A copy of the same bytes on the system disk (`copy D:\dsploop_apitest.exe C:\`, hash equal) runs. Not examined further; the next round should copy the exe to the system disk and run it from there |
| E25 | p4c4b's `TESTING.md` and the inherited script carry the codec's instance id with one F too many (`…\4&AEFFD634&0&0001`); this guest lists `…\4&AEEFD634&0&0001` (the earlier images' logs: `aeefd634`). `vmcommon.sh` was corrected to the guest's spelling; with the old one the codec's row would have missed the device and read as a failure |
| E26 | `vmcommon.sh`'s `waitfor` is a pipeline that ends in `tee`: its status is always 0, so every `waitfor … || log "!! …"` of the p4c4b scripts is dead (the `!!` lines never print; waitline's own "not seen" line does). My `boot5.sh`'s launch check took its success branch on that false status — and the launch check itself was wrong, since a skip prints no driver line. `boot3.sh` uses its own `waitre` |
| E27 | **my own faults, all found in the logs.** In r5: `boot5.sh` stopped (its launch check passed falsely, E26); `boot5b.sh` typed the launch line but set no socket directory (only `start_vm` sets it), so its `livecap.py` died on connect and the Enter was never sent — stopped before it typed onto that line; `boot5c.sh` sent the Enter and finished the VM (its `wait` on a pid that was not its child returned at once; the VM shut down by itself, the S5 line is there). In r1: `boot1.sh` was stopped before its `s5` (the power button was never sent in that VM), and `postfail.sh` read the lists and typed the shutdown. A `pkill -f` of mine matched my own wrapper and killed that shell (the script with it, as intended). Two long one-line commands were refused by the command wrapper's quoting before they ran |
| E28 | the monitor serves one client at a time: a `screendump` sent through a second connection while `livecap.py` held its own was not executed (r5, 13:10:31: no file) |
| E29 | **six screenshots were read by me**, all of the console and the Sound applet, to learn what the image had done (r1: `diag1-during-dsploop`, `s7-selftest0`, `s8-sound-playback`; r5: `diag2-during-dsploop`, `p0-before-enter`, `s9-sound-recording`). The transcription of a screenshot is not reliable glyph by glyph (three readings of one console line gave three spellings of one word): where a text mattered it was taken from the data disk instead (r3, r4), and the screenshot readings are used for what the text said, not for its exact characters. The Sound applet's name column is cut in the screenshots, so whether it shows the whole name was not read |
| E30 | the data disk's drive letter is not fixed: `D:` at each first boot (r1, r5, r4) and `E:` at a later boot (r3). `boot3.sh`'s first launch record types `D:\…`, which in r3 was not the data disk; that record is **not** the data-disk launch of E24 (r4's is) |
| E31 | the image's update agent tried `https://libernt.com/api/update/…` once in each of four sessions (r1, r3, r4, r5: `finished with 0x80072ee7`). The VM has no network interface (`-nic none`); nothing left the host |
| E32 | the image prints `UBSAN:` lines of its storage path in every session (`fastfat/deviosup.c`, `classpnp/class.c`, `storport/pdo.c`); outside this checkpoint, recorded because they are in the logs |

### What the round did not run

The stream through the audio stack in every depth (D3); a `SelfTest = 2` system boot; any disable/enable cycle with the child
present (D4); the codec's row on a controller without the DSP drivers; upstream's form of the U1 fix. And, as before:
`UseInterrupts = 1` with the self-test, the refusal rows, the fault matrix, the cycle run, silicon; Meteor Lake on silicon; the
32-bit wrap (the plan's INFO_NEEDED).
