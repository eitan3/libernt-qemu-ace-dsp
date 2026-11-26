# Provenance — the p4c4b2 round (P3 checkpoint C4b, rerun, 2026-11-26)

Written by the simulator side (Tasker). The C4 micro round rerun on image p4c4b2 — p4c4b plus the swenum fix of U1 — against
the unchanged model of `main b8dcec7`: p4c4b's `TESTING.md` runs, the brief's runs 0 to 4. **The first boot passes** (U1 fixed:
four first boots, no stop line), `SelfTest = 2` is sample-exact on this image, the `SelfTest = 0` boot regression and the
no-topology boot are as expected; **the stream through the audio stack was not reached** (the apitest is skipped: the MMDevice
enumerator's endpoint names lose the word "Loopback" — `DIVERGENCE.md`, D3) and **a disable of any audio device fails once its
child exists** (D4: the C4a leftover re-recorded). Nothing was tuned or fixed on this side; the model was not changed.

The LiberNT tree was read only: its sources at `13ab35e3992` through `git show` (`dsploop.c`, `stream.cpp`, `audioif.c`,
`devenum.c`, `rpcserver.c`, `dsppcm.inf`) and `git log` for the upstream fix; nothing in it was edited.

VM time of this round: six QEMU launches, 3971 s (66.2 minutes) — more than the brief's estimate because two VMs spent most
of their time on what the image did not do (r1: 25 minutes, r5: 23 minutes).

## Image under test

`~/libernt-build-logs/test-audio-intel-sst-p4c4b2-a81cf9e65cf/` — `feat/audio-control-polish` at `13ab35e3992` on master
`a81cf9e65cf`: p4c4b's tree plus one commit, `[SWENUM] Detach the bus device object from the stack before deleting it`.
Verified with `sha256sum -c SHA256SUMS`, four of four OK (`image-check.txt`):

| file | bytes | sha256 |
|---|---|---|
| `LiberNT.iso` | 654061568 | `b27a002859927b854918f6179fd84871a558a04d999e7c106b224a08ecd97109` |
| `LiberNT.vhd` (dynamic, 80 GiB virtual) | 807766528 | `05daae7fd016a90ad9498a6a66cee71e11d090f13b79bd141c5a9aa17a88dc72` |
| `LiberNT.img` | 1610612736 | `82b817a910442ef181c6d759e931e2ab1266be164acaa19222212e24c22deda3` |
| `dsploop_apitest.exe` | 215040 | `b1b50f48229e7853dbd56c84ee01245b66ab19f500efcd6622bdf2e869d427d7` (p4c4b's, unchanged) |

Extracted from the ISO independently of the image directory's own gates (`bsdtar -x -f LiberNT.iso` into `/tmp`, hashed
there — `in-iso.txt`): the fifteen files with a record in the staging directory's `gates/in-iso.txt` are all **equal by hash and
size**, among them `swenum.sys` `36729a970dbc4c6767788b358ddc2d7eb86c9c14242db96bc4ae2beb1777baeb` (the file this image
changes), `intcdsp.sys` `66e10a507d4e…`, `hdaudbus.sys` `f4531d58c13e…`, `dsppcm.sys` `44094b486140…`, `hdaudio.sys`
`bcc0d474d7a3…`, `ntoskrnl.exe` `0838035dff18…`, `sof-arl-s.ri` `f37a055cefef…`, `sof-mtl.ri` `4f3fb3fc57d2…`,
`sof-ipc4-loopback.tplg` `0e002de8d92e…` and the three INFs; the six that differ from p4c4b are the six the staging record
says differ. Four more were hashed for the record with no staging record to compare (`hal.dll` `44c87a09686c…`, `cmd.exe`
`f4e8667145de…`, `certutil.exe` `20093d79b549…`, `pnputil.exe` `ec587976d179…`). The exe's hash was taken in the guest at
each use (`exe-hash.txt`: the same value). The desktop's watermark reads `feat/audio-control-polish.13ab35e.amd64.clang.2610-261126`
(`s8-sound-playback.png` of r1, `s9-sound-recording.png` of r5), the identity the staging directory names.

**U1 is fixed upstream as well.** Per the manager's message during this round: upstream fixed it independently in
`693821aba75` (the same `swenum` lines, the same `IoDetachDevice(PnpDeviceObject)` argument, and the remove request forwarded
down the stack first); the local commit was dropped as superseded. I confirmed in the tree, read only, that the commit is there:
`693821aba75 Ahmed ARIF 2026-11-26 11:26:01 +0100 [SWENUM][SETUPAPI_APITEST] Pass the remove request down and detach before
deleting the bus device`. **This image carries the local variant (`13ab35e3992`); the next image carries upstream's form, which
did not run here.**

## Model

- qemu-ace-dsp `main` at `b8dcec7`, the model unchanged: patches 0001–0020 on QEMU 11.1.3. No file of the model changed in
  this round (`git status`: only this evidence directory is new).
- The binary of record, not rebuilt: `build/qemu-system-x86_64` sha256
  `a894197dc0b040dd3d5a94d163e70dc631168e1d820b7a9468c2ecb83919e8bc`, `build/tests/qtest/intel-hda-ace-test` sha256
  `f335e5907c4f9f695e8e4de4f0350d95ef82325e5af63835a6f83ed513b94825`.
- qtest before the first VM run: **15/15**, rc=0, 2026-11-26T12:15:43Z (`vm/qtest-before-vm.txt`, its head
  `vm/qtest-before-vm.head.txt`).
- The model's trace: 1393 `ace_*` lines in the six VMs, **0 `ace_unexpected`**; 12 `ace_audio` lines, all in r5 (the three
  self-test runs); none in the apitest's runs, which never opened a stream.

## Host

A Linux VM with 4 logical CPUs and 31 GB of memory, QEMU's TCG without KVM, `/tmp` a tmpfs (16 GB) holding the live logs and
the extracted files. One VM at a time.

## The VM runs (UTC)

Every VM: q35, TCG, `-smp 1`, `ICOUNT=1` (`-icount shift=auto,align=off,sleep=off`, `tcg,thread=single`), `CDROM=none` (the
installed system boots from a disk overlay over the p4c4b2 `LiberNT.vhd`), `TRACE=1`, `QTESTSOCK=1`, launched by `lib-run.sh`
through `vmcommon.sh`; the live logs under `/tmp/qad-ev/p4c4b2/`, copied into this tree afterwards (`postrun.sh`). The guest
has no network interface (`-nic none`). `qemu-args.txt` and `command.txt` hold each VM's command line. Every VM is decided by
serial lines and by the text the guest wrote to its data disk; **six screenshots were read by me** (three of r1, three of r5;
listed under E29 in `DIVERGENCE.md`) to learn what the image had done, none to drive.

| VM | evidence dir | wall (UTC) | how it ended | what it did |
|---|---|---|---|---|
| r0b | `vm/r0b-firstboot-nodisk` | 168 s, 12:19:44–12:22:32 | clean S5 (the ACPI power button), rc=0 | **the first boot with no data disk** (run 0's no-disk variant): swenum's line, `Safe removal: ROOT\SYSTEM\0000`, the Setup phase; the wizard closed by chords |
| r1 | `vm/r1-firstboot-cycle-dsploop-selftest2` | 1515 s, 12:23:39–12:48:54 | `shutdown -s -t 0` typed in a second console → `Entering sleep state S5` in 6 s, rc=0 | **the first boot with the data disk**; `BootDsp = 1` and `Topology` set; the first cycle (run 1's lines); the lists; **the apitest's typed line did not launch the test**; `SelfTest = 2` and the second cycle: **the disable failed**; the Sound applet (screenshots). `boot1.sh` was stopped by me at 12:43 (before its `s5`); `postfail.sh` then: the second console, the device lists, the shutdown |
| r5 | `vm/r5-firstboot-cycle-selftest2-dsploop-live` | 1368 s, 12:50:50–13:13:38 | clean S5 (the power button), rc=0 | a fresh overlay's first boot; **`SelfTest = 2` set before the one cycle**: the self-test and run 1's lines at the same D0 entry; `SelfTest = 0`; the lists; the apitest: the data-disk line did not launch it, **the copy on the system disk ran it: skipped**; the Sound applet (screenshots). `boot5.sh` (stopped 13:00:39), `boot5b.sh` (stopped 13:06:52), `boot5c.sh` |
| r2 | `vm/r2-plainboot-selftest0` | 77 s, 13:15:31–13:16:48 | clean S5 (the power button), rc=0 | the **`SelfTest = 0` system boot** with the topology kept (run 4) |
| r3 | `vm/r3-plainboot-attribution` | 537 s, 13:17:42–13:26:39 | clean S5 (the power button), rc=0 | a plain boot; **the apitest again from the system disk (skipped again)**; the MMDevices registry read; **the disable attribution**: the child alone, the codec, the DSP device |
| r4 | `vm/r4-freshboot-notopology` | 306 s, 13:29:12–13:34:18 | clean S5 (the power button), rc=0 | a fresh overlay's first boot; `BootDsp = 1`, no `Topology`: **the no-topology cycle** (run 3a); the data-disk launch's text on the data disk |

Six QEMU launches, six guest boots, no reboot. Four first boots (r0b without the data disk; r1, r5, r4 with it): each prints
swenum's line, then `Safe removal: ROOT\SYSTEM\0000` 0.16–0.44 s later, then swenum's line again and the Setup phase; no
stop line in any log. Nine starts of the DSP device (nine settings lines): four with `BootDsp = 0` (probe only) and five DSP
boots, each `boot ok after … 0 DSP interrupts, cleanup ok`. One self-test of three runs (r5). Six clean S5s. No `clock
stalled`, `interrupt storm`, `Work queue` or bugcheck line; 0 `ace_unexpected`. The lines per VM: `vm/measured-lines.txt`;
TESTING.md's expected lines against them: `vm/expected-vs-measured.txt`.

## Overlays

Not committed; each under `disk/`, made by `make-overlay.sh` over the p4c4b2 `LiberNT.vhd`: `p4c4b2-nodisk.qcow2` (r0b),
`p4c4b2.qcow2` (r1, then r2), `p4c4b2-st2.qcow2` (r5, then r3), `p4c4b2-fresh.qcow2` (r4). `p4c4b2-st2.qcow2` also holds the copy of the exe that r5 made on the system disk (`C:\dsploop_apitest.exe`; r3 found it there).

## The tools (`vm/tools-used/`)

p4c4b's scripts, as the brief asked, with the image directory, the log paths and the overlay names changed — and these
departures, each forced by something this image showed:

- `vmcommon.sh`: the image directory and the paths; the default overlay `p4c4b2`; **the codec's instance id corrected** to
  `…\4&AEEFD634&0&0001` as this guest lists it (p4c4b's `TESTING.md` and the script had `AEFFD634`, one F too many; the earlier
  images' logs carry the codec as `aeefd634`: E25).
- `boot1.sh` (p4c4b's, the sourcing path alone differs): ran in r1 up to its Sound applet screenshots.
- `boot2.sh`, `boot4.sh` (p4c4b's; the sourcing path and `boot4.sh`'s overlay name differ; `boot4.sh` has one command more,
  the data-disk launch's text to the data disk).
- `boot3.sh` (p4c4b's with changes): every `pnputil` command's own text goes to the data disk and the time it returned is read
  from there (not from a screenshot); a command that does not return ends the sequence; the apitest is launched from the system
  disk (the data-disk line is recorded for its text alone); the MMDevices registry is read to the data disk; a serial-line wait
  whose status means what it says (`waitre`; see E26).
- `boot5.sh` (new): `boot1.sh`'s flow with the order changed — `SelfTest = 2` before the one cycle — because a cycle after run
  1's cycle cannot bring the D0 entry the self-test needs (D4); the apitest's launch read from the serial log.
- `boot5b.sh`, `boot5c.sh` (new): the take-overs of r5 after `boot5.sh` and `boot5b.sh` were stopped (E27): the launch from the
  system disk under the live read, the rest of the flow.
- `boot0.sh` (new): the no-disk first boot. `postfail.sh` (new): r1 after its script was stopped.
- `preflight.sh` (p4c4b's with the image directory and the staging record's format): the images, the in-ISO hashes, the qtest.
- `make-pouch.sh`, `collect.sh` (p4c4b's; the paths), `livecap.py` (p4c4b's, unchanged: it ran once with the right address, in
  `boot5c.sh`, and found no latency line), `postrun.sh` (new), `measured.sh`, `expectcheck.py`, `rms-and-trace.sh`, `stats.sh`
  (new: the derived files), `ace-audio-check.py` (the p3c3b round's, unchanged).

## Layout of the round's evidence (`evidence/2026-11-26-p4c4b2/`)

| file | what |
|---|---|
| `image-check.txt`, `in-iso.txt` | the images verified in the staging directory; nineteen in-ISO files hashed from an independent extraction, fifteen against the staging record |
| `DIVERGENCE.md` | the result: U1 fixed; D3 and D4; the C4a leftovers; the notes; what was not run |
| `vm/qtest-before-vm.txt`, `vm/qtest-before-vm.head.txt` | the qtest before the first VM run: 15/15 |
| `vm/measured-lines.txt` | per VM: the round's counts and the lines that matter, cut from the raw serial log |
| `vm/expected-vs-measured.txt` | TESTING.md's expected lines, each counted in every VM; the test program's and pnputil's own texts |
| `vm/rms-and-trace.txt` | the model's `ace_audio` lines of the self-test against the driver's sine (the p3c3b checker) |
| `vm/tools-used/` | the round's scripts |
| `vm/r0b-…`, `vm/r1-…`, `vm/r2-…`, `vm/r3-…`, `vm/r4-…`, `vm/r5-…` | one directory a VM: `serial.log` (raw), `serial.txt` (ANSI escapes, NULs and CRs removed), `driver.log` (the script's own log with host times), `driver-lines.txt`, `lib-run.out`, `command.txt`, `qemu-args.txt`, `start.txt`, `end.txt`, `qemu-dbg.log.gz` (the trace), `ace-trace.txt`, `ace-audio-lines.txt`, the text the guest wrote to its data disk, the screenshots, `contents.txt` (what was kept) |

Serial lines end in CR LF in `serial.log`; they are quoted without the tail.

## Not done in this round

- Nothing was tuned or fixed on either side: the model is `b8dcec7`; the driver is the image's; the kernel is the image's.
- **The stream through the audio stack was not reached** (`DIVERGENCE.md`, D3): no `pin created` line, no `latency: fifo` line,
  so no `dsploop: 48000 frames compared …` line at any depth, no negotiated engine buffer or period to hold against the FIFO
  constraint, no live read of a descriptor list, no `ace_audio` line of the apitest.
- `SelfTest = 2` was taken at one D0 entry only (three runs), not at a system boot: a system boot with `SelfTest = 2` was not run.
- The disable attribution has no row that completes with the child present (D4); which component refuses the query-remove was
  not read. The codec's row was not repeated on a controller without the DSP drivers.
- As before: `UseInterrupts = 1` with the self-test, the refusal rows, the fault matrix, the cycle run (blocked by D4 once the
  child exists), silicon; Meteor Lake on silicon; the 32-bit wrap (the plan's INFO_NEEDED).
- Upstream's form of the U1 fix (`693821aba75`) did not run: this image has the local variant.
