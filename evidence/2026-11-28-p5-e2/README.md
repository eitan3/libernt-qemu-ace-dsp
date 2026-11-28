# P5 E2 — the VM round of the idle power-down and the boot at open (evidence/2026-11-28-p5-e2)

Round of 2026-11-28 on image **p5e2** (`test-audio-intel-sst-p5e2-b32d338494d`: LiberNT `feat/audio-control-polish`
at `b32d338494d`, E1c's `e48563fdfc4` plus E2's seven commits, on master `fc098016408`; its PROVENANCE.txt and
SHA256SUMS are in its staging directory). The model is `qemu-ace-dsp` `main` at `46b7480`, **unchanged by E2** (no
model change needed: the idle power-down and the boot at open use the boot and the power-down the model already
carries); its qtest binary of 23:26 the day before, qtest 17/17. The QEMU runs, one at a time, each bounded and
ended by the round itself; nothing here was driven on real hardware.

**The headline.** Row (a) passes on the final image: a D0 entry with `BootDsp = 1` and `BootAtStart` unset boots
nothing (its line says so), the topology file is parsed and the PCM child reported, the endpoints are listed, and
the first open boots the DSP (`boot at stream open: ok after 6 ms`). Row (b) passes: 16 dsploop runs with `DspIdleSec = 3`: each passes 3 of 3, boots at its first open (`boot at stream open: ok after 6 ms`, 16 of 16), and 3 s after its last close the DSP powers down by itself (`idle power down after 3 s`, 16 of 16; `DSP power down from state ready: ok`), 0 `recovered` lines, 0 timeouts. Row (c) is
shown as the absence of a power-down inside a run (one boot at open and one idle power-down per run). Row (d):
`cycles: 48 run, 48 ok, 0 timeouts` in the second half's VM (16 runs x 3 open -> run -> close), and with the fourth VM's baseline 3: 51 cycles, 51 ok, 0 timeouts on the final image. Rows (e), (f): **not run.** The 22-cycle matrix needs `BootAtStart = 1` made live, which in session takes a reboot (N12-09); the budget ended after the second half's script faulted at its summary line (N12-11), with (b)-(d) complete. The fourth VM's boot shows the D0 rule's default only. Left for the next conversation: one VM, about 20 minutes (`e2b-round.sh` from its (e) part, the two faults fixed). Three defects were found by the round and fixed in it (N12-01 by the
host case, N12-07 and N12-10 by the VM): the first three runs are their evidence.

## The commits (LiberNT; nothing pushed)

| # | commit | what |
|---|---|---|
| 1 | `d65407ae609` | [INTCDSP] the two settings `BootAtStart` and `DspIdleSec` (REG_DWORD, the INF's default 0) read at every D0 entry and logged; the INF's comment block |
| 2 | `e7c7ffcaa5e` | [INTCDSP] the D0 rule (D2): a D0 entry boots only for `BootAtStart = 1` or a self-test; otherwise the topology file is parsed (`IntcDspTopologyParse`) and the child reported, the first open boots; the firmware's limits checked at the boot that runs the model (`IntcDspTopologyCheck`) |
| 3 | `0eb24375b91` | [HOSTTESTS] the manager's idle power-down: the pure decision, the timer through operations, the work item's second decision, the public teardown poll (N8-02); host cases (i24)–(i26), the mutation rows |
| 4 | `d4abe81d861` | [INTCDSP] the driver's idle power-down: the device's timer, its DPC (the work item alone), the work item, the operations wired |
| 5 | `5553a84dff0` | [SOFIPC][HOSTTESTS] the poll sets the IPC enables again in the interrupt mode after a non-crash notification (N11-03); host row in (f) |
| 6 | `2ae53f1a201` | [INTCDSP] the first open boots on a device whose D0 entry never booted (found by the first run: N12-07) |
| 7 | `b32d338494d` | [INTCDSP][HOSTTESTS] the manager reads the driver's clock before the first boot, so the first open's line carries its time (found by the second run: N12-10); host row in (i25), m22 |

## The round table

| row | the VM | the setting | what the log shows | the run | result |
|---|---|---|---|---|---|
| (a) | `e2-round-fourth` | `BootDsp = 1`, `BootAtStart` unset | after the disable/enable cycle: `D0 entry: the DSP is not booted (BootAtStart = 0); the first stream open boots it`, `topology 'sof-ipc4-loopback.tplg': ABI 3.29.1 ...` (parsed, no firmware limits asked), `audio child 'INTCDSP\PCM&...': 2 endpoints`, dsppcm `registered as 'LoopbackTopo'/'LoopbackWave'/'LoopbackInTopo'/'LoopbackInWave'`; booting 0, boot ok 0 | baseline: PASS (3 of 3, 1303 tests, 0 failures) | **PASS**: the first open `boot at stream open: ok after 6 ms`, booting 1, no boot line at the entry |
| (b) | `e2b-round` | `DspIdleSec = 3` | 16 x `idle power down after 3 s`, each followed by the next run's `boot at stream open: ok after 6 ms` (16 of 16); `recovered` 0; `release: 0 streams let go` each | 16 runs, 16 PASS (3 of 3 each) | **PASS** (the plan's 10: 16) |
| (c) | `e2b-round` | `DspIdleSec = 3` | per run: exactly 1 boot at open and 1 idle power-down, none between a run's three loops (the pin's stream allocated, running or not) | 16 runs | **shown** as the absence inside a run; a pin held open across the idle time without running is host case (i25) (N12-03) |
| (d) | `e2b-round` | `DspIdleSec = 3` | render opens 48 (16 x 3), timeouts 0 | `cycles: 48 run, 48 ok, 0 timeouts` (+ the fourth VM's 3: 51/51) | **PASS** |
| (e) | - | `BootAtStart = 1`, no topology | - | - | **NOT RUN** (left; N12-09, N12-11) |
| (f) | - | `BootAtStart = 1` | - | - | **NOT RUN** (left) |

## The VMs

| VM | the image | what it ran | how it ended |
|---|---|---|---|
| `e2-round-first` | `5553a84dff0` | the whole flow as first written | row (a) **failed**: the first open refused `0xc00000a3` with no boot (N12-07); stopped by hand after the baseline |
| `e2-round-second` | `2ae53f1a201` | the whole flow | row (a) passed but the first open's line had no time (N12-10); the `DspIdleSec` cycle's disable refused (N12-09); stopped by hand |
| `e2-round-third` | `b32d338494d` | the whole flow, the settings by a reboot | row (a) passed with the time; the reboot ended the VM (`REBOOT=0`, N12-11) |
| `e2-round-fourth` | `b32d338494d` | the whole flow, `REBOOT=1` | row (a) passed; the reboot came back but the script waited for a line this image never prints (N12-11); stopped by hand |
| `e2b-bootcheck` | `b32d338494d` | the second half's boot | the console check called twice with one label (N12-11); ended by the script |
| `e2b-round` | `b32d338494d` | the second half: a later boot, rows (b), (c), (d) | the script faulted at its summary line after (b)-(d) (N12-11); the launcher stopped the VM; 0 stop lines, 0 fatal, 0 kdb |

## The lines (from the final image's runs; the whole of them in `vm/<run>/e2-lines.txt` and `driver.log`)

```
(a) e2-round-fourth:
  [ 1039.926650] intcdsp.sys: D0 entry: the DSP is not booted (BootAtStart = 0); the first stream open boots it
  [ 1039.926650] intcdsp.sys: topology 'sof-ipc4-loopback.tplg': ABI 3.29.1, 4286 bytes (model 2384 bytes), ...
  [ 1039.926650] intcdsp.sys: audio child 'INTCDSP\PCM&CTLR_VEN_8086&CTLR_DEV_7F50\00' for pcm 'Loopback': 2 endpoints
  [ 1102.095755] intcdsp.sys: boot at stream open: ok after 6 ms
(b) e2b-round:
  [    8.813245] intcdsp.sys: SelfTest = 0, UseInterrupts = 0, IpcTimeoutMs = 500 ms, BootAtStart = 0, DspIdleSec = 3 s
  [  657.062710] intcdsp.sys: boot at stream open: ok after 6 ms
  [  666.209730] intcdsp.sys: idle power down after 3 s
  [  666.209730] intcdsp.sys: DSP power down from state ready: ok, cleanup ok, ADSPCS 0x00000000 (SPA 0, CPA 0)
  [  727.034568] intcdsp.sys: boot at stream open: ok after 6 ms
  [  736.224865] intcdsp.sys: idle power down after 3 s
  ... 16 pairs; 0 recovered: open ok lines; 0 boot at stream open failed lines
```

## Gates of the tip `b32d338494d` (the staging directory's `gates/`)

sofipc 7273 checks, 0 failures, 0 warnings (E1c's 6946 + (i24), (i25), (i26) and (f)'s interrupt-mode row); the four
audio drivers built with 0 warnings; the kmtest compile check 17/17 with 0 warnings; qtest 17/17; the image built rc 0,
0 compiler warnings, its six audio binaries identical to the build tree's (identity `20261127-nt10.0-045-2914-gb32d338`).
The mutation rows, each reverted after its run: m12 7, m13 6, m14 20, m15 8 and an abort, m16 5, m16c 5, m17 3, m18 3,
m19 2, m20 7, m21 5 red, m22 an abort (`gates/host-mutations.txt`).
The audio host-test list 14/14 (run after the last VM ended).

## Privacy

The DMI lines scrubbed (`tools-used/scrub-dmi.sh`), the paths normalised and the account's login name replaced in
listing lines (`normalise-evidence.sh`, ruling 4: prose keeps the name); `tools-used/verify.sh` counts: credential variable name (must be 0; tools-used excluded): 0;raw DMI string (must be 0; tools-used excluded): 0;home path: 0;login name (must be 0; tools-used excluded): 0 files, 0 lines;
`tools-used/` holds the scripts as they ran (their own patterns excluded from the counts).

## N11-05 (E1b's `pouch/`), a forward change

E1b's tree (`evidence/2026-11-27-p5-e1b/vm/`) listed a `pouch/` under each VM that it never held. The texts were
still in that round's scratch; each was checked against the tree's own `pouch-sha256.txt` (all OK) and copied in:
`e1b-round` 134, `e1b-attempt1` 8, `e1b-attempt2` 19, `e1b-attempt3` 14, `e1b-attempt4` 21 texts, the exe left out.
No history was rewritten. This tree's own `pouch/` directories are copied by its collect script (`collect-e2.sh`).

## Tools used

`tools-used/`: `vmcommon.sh` and `make-pouch.sh` (the E1c round's, the paths and the image changed; `REBOOT=1`,
a guest reboot reboots), `e2-run.sh`/`e2-round.sh` (the whole flow as first written: the settings made live by
disable/enable cycles), `e2b-run.sh`/`e2b-round.sh` (the second half: a later boot of the overlay, the settings made
live by a reboot), `collect.sh` (E1c's), `collect-e2.sh`, `scrub-dmi.sh`, `verify.sh`.
