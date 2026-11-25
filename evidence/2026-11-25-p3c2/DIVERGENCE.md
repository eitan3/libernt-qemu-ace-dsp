# DIVERGENCE — LiberNT `intcdsp.sys` (image p3c2, `feat/audio-control-polish @ 2285127b060`) against the ACE model: the VM half of C2, the micro round

The micro round of the owner's ruling (2026-11-25): this checkpoint's own acceptance plus one boot regression —
three VM boots, four DSP boots (`c2-acceptance.md` for every measured line). Classes: **driver** (the image's code),
**model** (qemu-ace-dsp), **environment** (this host and VM), **expectation** (the brief or TESTING.md says something
the driver does not do, by design). Nothing was fixed on this side; the LiberNT tree was read at the image's commit
only (`git show` / `git grep`, never a checkout).

**Adverse findings first.**

| id | class | finding | effect |
|---|---|---|---|
| T1 | driver | the topology summary line says `2288 bytes` where TESTING.md says the file's `4286 bytes`: it prints the size of the built model | wording / diagnosis; none on behaviour that the VM can see |
| X1 | environment, expectation | a disable/enable cycle is not a "second D0 entry that keeps the model": it is a new device object, which reads the file again by design; the kept-model line needs an S3 resume, which this VM cannot do | "no re-read beyond the first" is **not verified** |
| D4 | driver | **fixed on this image** | — |
| N9 | driver | **fixed on this image** | — |
| model | model | **no finding**: the binary is C1's, the boot block and the trace are p3c1's | — |

## T1 — the topology summary line's byte count is the built model's size, not the file's (driver; wording; no functional effect seen)

TESTING.md (b) promises, after `boot ok` and `ipc: link ready`:

```
intcdsp.sys: topology 'sof-ipc4-loopback.tplg': ABI 3.29.1, 4286 bytes, 2 controls, 4 widgets, 2 edges, 1 pcm, 1 pipeline, 0 manifest items, from the registry override
```

Measured, three times (run 3, run 4, the plain boot `r3b`), identically:

```
intcdsp.sys: topology 'sof-ipc4-loopback.tplg': ABI 3.29.1, 2288 bytes, 2 controls, 4 widgets, 2 edges, 1 pcm, 1 pipeline, 0 manifest items, from the registry override
```

With the byte count masked the line is TESTING.md's, character for character. The file is 4,286 bytes everywhere
it can be weighed: in the ISO (sha256 `0e002de8…5601`, `PROVENANCE.md`), on the installed system as the guest's own
console lists and hashes it (`r2-stage2-no-topology/topology-dir.png`: `4,286 sof-ipc4-loopback.tplg`, `certutil
-hashfile … SHA256` printing `0e002de8…65601`).

**The cause**, read in the tree at `2285127b060` (`drivers/wdm/audio/intcdsp/topology.c`, `IntcDspTopologyLoad`):

| line | what | `Bytes` after it |
|---|---|---|
| 363 | `Status = IntcDspReadFile(Path, &Data, &Bytes, INTCDSP_TOPOLOGY_MAX_BYTES);` | the file's size, 4286 |
| 373 | `Input.Size = Bytes;` | the builder is given the whole file |
| 376 | `Result = SoftplgModelMeasure(&Input, &Bytes, &Problem);` | **overwritten**: the measure's second parameter is `_Out_ SIZE_T* Bytes`, "the bytes the model of this topology needs" (`sdk/lib/drivers/audio/softplg/ipc4model.h`, the comment above the declaration; `ipc4model.c`: `*Bytes = ModelBytes(&Counts, &ReachWords);`) — 2288 |
| 390 | `Dev->TopologyBytes = Bytes;` | the model's size |
| 396 | the log line's `(ULONGLONG)Bytes` | the model's size is what the line prints |

**What it costs.** Nothing the VM can see in behaviour: the model is built from the whole file (`Input.Size` is set
before the overwrite) and the builder's counts are TESTING.md's (`2 controls, 4 widgets, 2 edges, 1 pcm, 1 pipeline,
0 manifest items`, the module ids). `Dev->TopologyBytes` is assigned in three places and read nowhere else in the
driver at this commit (`git grep TopologyBytes`: `intcdsp.h:107`, `intcdsp.c:524`, `topology.c:341`, `:390`). The cost
is in diagnosis: the one line meant to let a reader check the file the driver took against the directory names a
number no directory shows — on silicon too, where the topology lines are what the hardware stage adds to the model's.

**For the driver side** (not done here): keep the file's size in a variable of its own and print that, as
TESTING.md says; print the model's size as a second, labelled number if it is wanted; and decide which of the two
`TopologyBytes` is meant to hold. Then TESTING.md (b) and the line agree again. The brief's "10 formats" is not in
the line at all — the driver's format string has no such field — so that number stays the builder's internal count.

**How this side told a wrong number from a short read:** by the source (the builder's input size is set before the
measure) and by the counts; it did not observe the bytes the builder consumed (a guest read does not cross the
model).

## X1 — a disable/enable is not the "second D0 entry" that keeps the model (environment: no S3 in the VM; and the brief's premise)

**The expectation.** The brief's run 4: "the second D0 entry keeps the model (no re-read of the topology file beyond
the first) and prints the firmware line as `resident`". TESTING.md puts the line
`intcdsp.sys: topology 'sof-ipc4-loopback.tplg': resident, the model of the device's first boot` under **"Resume
with the override (R6)"** — "no second read of the file (the model is kept while the selection names the same file; a
changed selection is read and built at the next boot)" — and says of "Disable, Enable (or reboot)" only (b)'s two
lines.

**Measured** (`r2-stage2-no-topology/cycle2-override-lines.txt`): the second cycle's disable prints `DSP power down
from state ready: …`; its enable prints `intcdsp.sys: loaded for the Intel audio DSP child`, the probe lines,
`firmware … read`, `BootDsp = 1: …`, one settings line, `firmware … resident`, the boot block (`boot ok after 5366 us
… 0 DSP interrupts`), `ipc: link ready`, then the summary line again — `ABI 3.29.1, 2288 bytes, … from the registry
override` — and the modules line. Not `resident, the model of the device's first boot`.

**Why, in the source** (`topology.c:329–335`): the resident model is `Dev->TopologyModel`, the device's own:

```c
/* the model of the device's first boot stands while the selection names the same file: a resume reads nothing again (R6) */
if (Dev->TopologyModel != NULL && Selection.Name != NULL && DspTopologyNameValid(Selection.Name) &&
    strncmp(Dev->TopologyName, Selection.Name, sizeof(Dev->TopologyName)) == 0)
{
    IntcDspLog("topology '%s': resident, the model of the device's first boot\n", Dev->TopologyName);
```

A disable/enable builds a new device object — the log shows it (`loaded for the Intel audio DSP child`, the probe
lines, the firmware line's `read`) — so there is no model to keep and the file is read again. That is the design
the comment states: the kept model is for a resume, with the same device object. The firmware line differs only in
where the resident copy lives: the loader's image is the driver's (hence `read` then `resident` at every D0 entry
that boots — N6, as in C1), the topology model is the device's.

**So:**

- against TESTING.md: no divergence — (b)'s "exactly these two lines" after a disable/enable is what was measured,
  three times;
- against the brief's run 4: the premise does not hold for a disable/enable. The firmware line does say `resident`
  (the second of the pair), there is one settings line per entry, but **"no re-read beyond the first" is not shown**,
  and cannot be shown in this VM: the kept-model line needs an S3 resume, which the VM does not have.
- what remains open, and where it can be closed: on silicon — sleep and resume with the override in place; expect
  `firmware … resident`, the boot block, `topology 'sof-ipc4-loopback.tplg': resident, the model of the device's
  first boot`, the modules line, and no summary line.
- what this side cannot observe at all: whether the file is read. The summary line is the driver's own statement;
  the gap between `ipc: link ready` and the summary line (3.0 ms of guest time in both cycles, 15.6 ms at the plain
  boot) does not tell a read from a kept model.

"Released before any other" (the other half of the tip commit's title) was not exercised: it needs a changed or
removed selection — TESTING.md (c)'s rows and "Turning it off", outside this round's scope.

## D4 and N9 — measured fixed

- **D4** (p3c1: the power-down line named the state *after* the power-down, always `off`). Every power-down of a
  booted DSP in this round says `DSP power down from state ready: ok, cleanup ok, ADSPCS 0x00000000 (SPA 0, CPA 0)`:
  three — run 2's fail-safe, run 4's disable, the S5 at the end of VM 2. No line says `from state off`. Run 3's
  disable printed no power-down line at all: the DSP was off already (the fail-safe had powered it down), which is
  the correct reading of "the state the power-down came from".
- **N9** (p3c1: the settings line twice per start). `intcdsp.sys: SelfTest = 0, UseInterrupts = 0, IpcTimeoutMs = 500
  ms` — 6 lines for 6 device starts: run 1's 1 (p3c1: 2), VM 2's 3 (its start and two enables), the plain boot's 1;
  each after `BootDsp = …: …` and before the firmware line of the D0 entry.

## The model — no finding

The binary is the C1 round's (`be8667eb…`, rebuilt from the series on `main d2dc604`; qtest 14/14 before the first
boot). On four DSP boots: the boot block identical to p3c1 `a2-stage2-boot`'s (timings aside), `0 DSP interrupts`
each, 0 `1 DSP interrupts`, 0 `clock stalled`, 0 `interrupt storm`, 0 `ace_unexpected`; the model's registers before
and after each cycle identical to p3c1 `ac3-cycles`' readings. The device trace of the first boot is p3c1 a2's 106
`ace_*` lines with two reads added — one more poll of `HFIPCXIDA` / `HFIPCXTDR` between `firmware entered` and the
FW_READY notification (`trace-regression.txt`). The topology path adds no model access: after the FW_CONFIG reply's
acknowledgement (`r2-stage2-no-topology/ace-trace.txt`, line 106) the next access is the power-down's (line 107). The
IPC traffic of each DSP boot is the transport's only — purge request and reply, the FW_READY notification, the
config-get request and its `FW_CONFIG` reply — no pipeline message (C3 sends those). N5 stands as in C1
(`HFINTIPPTR 0xffffffff` still on the three `subsystem powered` lines; the mask at ROM ready is where the pointer
answers).

## Environment notes (not driver divergences)

- **E5 (carried from C1) — `after N us` is TCG execution time on this host.** `boot ok after 6477 µs` at VM 2's
  start, `5366`, `5366`, `5370 µs` in the cycles and the plain boot; end clock − start clock − N = 322 µs at the
  boot-time start and 80–86 µs on the other three — C1's pattern (a boot-time start costs more, no budget is near).
- **E6 (carried) — the first-boot wizard's third page** again "lists 11 components" (`oobe.c:1097` in the serial
  log) and is again closed with `tab tab ret`, `ret`, `tab tab tab ret`.
- **E7 (C1) — not reproduced.** C1's console banner named the checkpoint's start commit while the desktop's
  watermark named the build tip; here both name `2285127` (`LiberNT [Version 0.4.17-amd64-dev 20261125-2285127]`,
  `feat/audio-control-polish.2285127.amd64.clang.4715-251126`).
- **E8 (this host) — the first-boot wizard and the console keep C1's timings**: the shell's `Program Manager`
  line at 78.9 s of guest time on the first boot and at 35.0 s on the plain one (C1's b1: 36.8 s); the console
  up 10 s after `cmd`. The vision read of the screenshots is not character-exact: `certutil`'s hash was read back
  from `topology-dir.png` with two digits uncertain in its middle; the screenshot is the record, not the
  transcription.

## Tooling

No tool of the repository changed. The console steps were driven by throwaway scripts under `/tmp`, described here so
the runs can be repeated: one that types each line of a file into the guest's console followed by `ret` (6 s
apart) and takes a screenshot, one that types `shutdown -s -t 0` and waits (bounded) for QEMU to exit, and the
comparison that produced the verdicts of `c2-acceptance.md` (`grep -Fx` of TESTING.md's code-block lines against the
measured ones). The key sequences and the commands are in `PROVENANCE.md` and `c2-acceptance.md`. One call of the
host's command tool was lost to its wrapper shell (fish: an apostrophe inside `bash -c '…'` ends the string) before
anything ran; script files avoid it.

## Not run in this round

TESTING.md (b)'s resume (R6) and its resident topology line; (c) the refusal rows; "Turning it off"; `SelfTest = 1`
with the topology; (d) the VirtualBox regression; the fault matrix and the cycle run (before C6); silicon; the
`_DSD` path (no `_DSD` names on this VM's controller: the fail-safe line says `no _DSD name`); the WIM medium
(`BOOTLOADER_WIM_RAMDISK` is off in this image: the file-based medium ran).
