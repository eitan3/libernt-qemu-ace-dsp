# P5-H — the first real session on the machine with the real DSP: a 30-minute checklist

Image: `LiberNT.iso` / `.vhd` / `.img` of `test-audio-p5final-9f023b460cc` (LiberNT identity `20261128-nt10.0-045-3158-g9f023b4`:
`feat/audio-control-polish` at `b7274b3e004` plus the one commit that bakes the settings into the INF: `BootDsp = 1`,
`SelfTest = 3`, `Topology = sof-ipc4-loopback.tplg`, `BootAtStart = 0`, `DspIdleSec = 0`). Nothing in this file is a
result: every line below is the driver's own format, read from its source and from the simulator's logs of this image; the
figures the simulator prints (`after 5525 us`, `16 pipelines`, `platform 288`) are the model's and **will differ on
silicon** -- the pass criteria are the words, not the numbers.

**Before the clock starts** (not counted): the stick or disk written from the image; a camera; the machine on its power
adapter; nothing else plugged into its USB ports. The clock: 30 minutes from the power button.

**The log:** the kernel writes its boot log to `C:\lastboot.log` on the boot volume (a bugcheck's log goes there too:
"Crash log saved to lastboot.log on the boot volume"). The driver's lines are all prefixed `intcdsp.sys:` or
`dsppcm.sys:`; the timestamps in square brackets are guest seconds since the boot. After a sleep/wake the same file
keeps growing (a wake is not a boot), so one copy at the end holds every item -- copy it to the USB stick at the end of
(d) and at the very end (a second copy costs 10 seconds and saves the session if (d) goes wrong).

| # | item | the clock | what to do | photograph |
|---|---|---|---|---|
| a | boot and the self-test on a real DSP | 0–5 min | power on, boot from the stick, go through the first-boot Setup's three pages (Next, Skip, Cancel), wait for the desktop; open a console (Win+R, `cmd`) and read its banner; open the Sound page (Playback and Recording tabs) | the console's banner (it names the image's build); the Playback tab; the Recording tab |
| b | D0i3 and DX | — | nothing to do on this image (below) | — |
| c | one sleep/wake with a stream open | 5–10 min | in the Sound page select `Speakers (Intel SST Loopback)` and make it the default device (Set Default); start a sound playing (a music file looping); Start → Turn Off Computer → **Stand By** (S3); wake with the power button | the Sound page after the device was set; the screen 10 s after the wake |
| d | about five sleep/wake cycles and a 15-minute stream | 10–30 min | four more sleep/wake cycles with the sound playing, about a minute apart (one of them by **Hibernate** (S4) if the dialog offers it, Stand By for the others); then let the sound play for 15 minutes untouched | the screen at the 15-minute mark |
| e | the pipeline delay | — | nothing to do on this image (below) | — |
| f | the telemetry crash dump | — | nothing to do on this image (below) | — |

## (a) boot + the self-test on a real DSP

**Pass lines, in this order, in `C:\lastboot.log`:**

```
intcdsp.sys: BootDsp = 1: the DSP boots at the first stream open with '<the firmware file the controller's record names>' (BootAtStart = 1: at every D0 entry)     (the simulator's controller names 'sof-arl-s.ri')
intcdsp.sys: SelfTest = 3, UseInterrupts = 0, IpcTimeoutMs = 500 ms, BootAtStart = 0, DspIdleSec = 0 s
intcdsp.sys: booting: firmware 'ADSPFW' 2.15.0.1, <N> payload bytes in <N> descriptors on stream 1, BAR4 <address>, clock <N> us at <N> Hz
intcdsp.sys: boot ok after <N> us (clock <N> us): state ready, failed in off (ok), ROM status 0x00000005 firmware entered, ROM error 0x00000000 ..., attempt 1, <N> DSP interrupts, cleanup ok, ADSPCS 0x<...>
intcdsp.sys: firmware ready: version <a.b.c.d>, ABI 1, ROM implementation <...> platform <N>, ROM info 0x<...>, downlink mailbox <N> bytes, uplink mailbox <N> bytes, trace log <N> bytes, <N> pipelines, <N> libraries, context save <N>, <N> tuples
intcdsp.sys: ipc: link ready, polled, 500 ms per message
intcdsp.sys: topology 'sof-ipc4-loopback.tplg': ABI 3.29.1, 4286 bytes (model 2384 bytes), 2 controls, 4 widgets, 2 edges, 1 pcm, 1 pipeline, 0 manifest items, from the registry override
intcdsp.sys: loopback self-test: endpoint 'Loopback', 48000 Hz 2 ch 16-bit, render stream 1, capture stream 1, 4096 frames
intcdsp.sys: loopback self-test: 4096 frames captured after <N> ms, offset <N> frames, max abs error 0, render rms <r>, capture rms <r>, ok      (six times: 16, 24 and 32 bits, then the three again at -6 dB)
intcdsp.sys: loopback self-test: the gain step, three depths at -6.00 dB (gain 0x4026e73d)
intcdsp.sys: loopback self-test: 6 runs, 6 matched, 0 failed, <N> requests, 0 notifications, 0 timeouts, <N> DSP interrupts, ok
intcdsp.sys: loopback self-test: ran (0x00000000), the DSP is left running
intcdsp.sys: audio child 'INTCDSP\PCM&CTLR_VEN_8086&CTLR_DEV_7F50\00' for pcm 'Loopback': 2 endpoints
dsppcm.sys: endpoint 'Loopback' render: registered as 'LoopbackTopo'
dsppcm.sys: endpoint 'Loopback' capture: registered as 'LoopbackInTopo'
```
(the four `registered as` lines follow: `LoopbackTopo`, `LoopbackInTopo`, `LoopbackWave`, `LoopbackInWave`.)

**What the screen must show:** the Sound page's Playback tab lists `Speakers (Intel SST Loopback)` and the codec's
`HD Audio Line out`; the Recording tab lists `Microphone (Intel SST Loopback)` and the codec's line in.

**Fail lines (any one of them stops the session; photograph the screen, copy `C:\lastboot.log`, send both):**

```
intcdsp.sys: boot ROM error after <N> us (...)                                  the ROM refused the firmware: the line names the ROM error
intcdsp.sys: boot <step> timeout after <N> us (...)                             the firmware did not come up at <step>
intcdsp.sys: boot firmware crash after <N> us (...)                             the firmware crashed before FW_READY
intcdsp.sys: DSP power down from state ready: ... right after `firmware ready`, with no `audio child` line   the boot's fail-safe: no topology the firmware can run
intcdsp.sys: loopback self-test: <N> frames not captured: <N> of <N> periods after <N> ms (0x<...>), failed
intcdsp.sys: loopback self-test: ... max abs error <N> ... mismatch at frame <N>   the loop does not match on this silicon
intcdsp.sys: loopback self-test: ran (0x<status>), the DSP is powered down
intcdsp.sys: clock stalled ...  |  DSP interrupt storm: ...  |  Fatal System Error  |  The system has been stopped
BootDsp = 1: <reason>, probe only                                               the settings did not reach the driver
```
On silicon the boot may take longer than the model's: the pass is `boot ok ... state ready` whatever its `after <N> us`.

**Send:** `C:\lastboot.log` (the whole file) and the three photographs.

## (b) what the firmware advertises for D0i3 and DX

**This image prints nothing that shows it.** The driver's `firmware ready:` line carries the version, the ABI, the ROM's
implementation, the mailbox sizes, the pipeline and library limits, `context save` and the tuple count -- the
configuration the firmware's FW_READY reply gives the tree's loader (`FWLOAD_FW_CONFIG`: version, mailboxes, trace log,
`MaxPipelines`, `MaxLibraries`, `ContextSave`, tuples) -- and no capability flags for D0i3 (`SOF_IPC4_MOD_SET_D0IX`, the
message the tree's sofipc can build and the driver never sends) or for per-core DX. The firmware registers the driver
reads at the boot (`SOFIPC4_FW_REGS`: `State`, `CurrentFState`, `WakeTickPeriod`, `ActivePipelines`,
`SlaveCoreStatus[8]`, ...) are not printed either.

**The one line a P5-H checkpoint should add** -- INFO_NEEDED: which field of the firmware's reply (or of
`SOFIPC4_FW_REGS`) carries the D0i3/DX capability on the real firmware is not in the pinned headers; the checkpoint is
one `IntcDspLog` of that field after `firmware ready:`, named by the firmware's documentation. Nothing to do on this
image for (b): the session's `C:\lastboot.log` is the input that decides it (the firmware's version and tuple count on
silicon tell which firmware document applies).

## (c) one sleep/wake with a stream open

**Do:** in the Sound page select `Speakers (Intel SST Loopback)` and press Set Default (a click, no typing); play a
sound (a music file looping). Start → Turn Off Computer → Stand By (S3); wake with the power button.

**Pass lines, in this order:**

```
dsppcm.sys: endpoint 'Loopback' render: pin created, 48000 Hz 2 ch <N> in <N> bits       the stream opened
intcdsp.sys: gain: 0.00 dB, mute 0                                                      (or the level the slider is at)
at sleep:
intcdsp.sys: streams: released for the power-down; nothing is sent until the next stream open or D0 entry
intcdsp.sys: DSP power down from state ready: ok, cleanup ok, ADSPCS 0x00000000 (SPA 0, CPA 0)
at wake (a D0 entry; with SelfTest = 3 it boots and runs the self-test again):
intcdsp.sys: SelfTest = 3, UseInterrupts = 0, IpcTimeoutMs = 500 ms, BootAtStart = 0, DspIdleSec = 0 s
intcdsp.sys: booting: firmware 'ADSPFW' ...
intcdsp.sys: boot ok after <N> us (...): state ready, ...
intcdsp.sys: firmware ready: version ...
intcdsp.sys: loopback self-test: 6 runs, 6 matched, 0 failed, ..., ok
intcdsp.sys: loopback self-test: ran (0x00000000), the DSP is left running
the stream after the wake:
dsppcm.sys: endpoint 'Loopback' render: pin created, ...                                 the stream opened again
intcdsp.sys: gain: <level> dB, mute 0
```
The two lines at sleep are what tells that the **power-down** path ran; the settings line, `booting:`, `boot ok` and the
self-test's two lines at wake are what tells that the **re-boot** path ran. If the firmware wants a different ordering
(a power state kept, a ROM handshake skipped), the first sign is a wake that prints `booting:` without a `boot ok`, or
one that prints neither -- both are the finding this item is for.

**Fail lines:** `DSP power down from state <other>: <not ok>`; at wake `boot <step> timeout`, `boot ROM error`,
`boot firmware crash`, `boot at stream open failed: the DSP is not ready after the boot (0x<...>); no stream is taken`,
the stream's open refused (`0xc00000a3`), no sound after the wake, a bugcheck (`Fatal System Error`).

**Send:** `C:\lastboot.log` and the two photographs.

## (d) about five sleep/wake cycles and a 15-minute stream

**Do:** four more sleep/wake cycles with the sound playing, about a minute apart (one of them by Hibernate (S4) if the
dialog offers it, Stand By for the others); then let the sound play for 15 minutes untouched.

**Pass:** the sound is there after every wake and at the 15-minute mark; in `C:\lastboot.log`: five times the two lines
of (c) at sleep and five times the settings line, `booting:`, `boot ok after ... state ready` and the self-test's
`6 runs, 6 matched, 0 failed ... ok` and `ran (0x00000000), the DSP is left running` at wake; **0** `reply timeout`,
**0** `fault during stream`, **0** `boot at stream open failed`, **0** `clock stalled`, **0** `Fatal System Error`;
the stream's `pin created` lines once per wake, and no `gain:` line other than the level you set.

**Fail:** any count above zero, a wake without its `boot ok`, a stutter or a silence after a wake (photograph the
screen and note the cycle).

**Send:** `C:\lastboot.log` and the photograph at the 15-minute mark.

## (e) the pipeline delay from the firmware's registers

**Not on this image: INFO_NEEDED.** The driver prints today only its own estimate at a stream's latency query:

```
intcdsp.sys: stream 1: latency: fifo 257 bytes, dsp estimate 2496 bytes (the copier's gateway buffer and the PCM's module buffers)
```
-- an estimate (the copier's gateway buffer and the PCM's module buffers), not a reading of the firmware's registers.
The registers the tree's headers know (`SOFIPC4_FW_REGS`) carry no delay field, and no message of the pinned IPC4
headers is read for it. The one line a checkpoint should add -- a `IntcDspLog` of the pipeline's delay as the firmware
reports it, next to the `latency:` line, to compare with the stream test's `offset <N> frames` -- needs the firmware's
register or message that carries it, which is INFO_NEEDED (not in the pinned headers, not to be guessed). The (a) log's
`offset <N> frames` of the six self-test runs is the measured side, already collected.

## (f) the telemetry crash dump

**Plainly: without a way to provoke a firmware exception on the real hardware, this needs its own checkpoint.** This
image does not decode the firmware's telemetry: the driver reads no telemetry channel, and nothing captures the
exception's payload. What it does today on a firmware exception is the recovery path of E1, and these are the lines a
crash on silicon would leave (the simulator's `crash-async` row of E1c):

```
intcdsp.sys: ipc: firmware crash with no request outstanding, read at a stream's period; the link is faulted
intcdsp.sys: fault during stream 1: firmware crash with no request outstanding, read at a stream's period
intcdsp.sys: streams: released after the fault; nothing is sent until the next stream open or D0 entry
at the next open:
intcdsp.sys: recovered: open ok after <N> ms
```
(a crash before FW_READY, at the boot, is `boot firmware crash after <N> us (...): state failed, failed in FW_READY wait
(firmware crash), ...`; a request that is never answered is `ipc: <request> reply timeout after <N> us; the link is
faulted`.) If a crash happens on its own during (c) or (d), photograph the screen, note the minute, and send the log:
that is the real-hardware reading of the exception line, which the telemetry checkpoint (a fault injection in the
firmware or the model's `crash-notification` knob, decoded on the machine) will build on. Do not try to provoke one in
this session.

## The end of the session

Copy `C:\lastboot.log` to the USB stick; send it with the photographs: (a) three, (c) two, (d) one, plus any fail
screen. The pass of the session is (a) complete, (c) and (d) with their counts at zero, the sound there at the
15-minute mark; (b), (e) and (f) are readings and INFO_NEEDED items for the next checkpoint, not passes of this one.
