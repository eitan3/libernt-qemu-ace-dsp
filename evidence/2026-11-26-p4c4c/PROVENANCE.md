# Provenance — the p4c4c round (P3 close-out regression, 2026-11-26)

Written by the simulator side (Tasker). The regression round on image p4c4c — p4c4b2's branch after the P3 close-out
(six fix passes, 56 commits) on upstream master `f71e13cc154` — against the unchanged model of `main f1b0538`: TESTING.md's
groups A (boot and display), B (the stream), C (topology absent, cycles, PnP), the regression of the plan (22 cycles and the
20 fault rows), D (the user-mode fixes by eye) and E (triage). **The first boot passes on upstream's swenum fix, the stream
through the audio stack runs at all three depths sample-exact and GREEN under the gate rule, and `SelfTest = 2` is sample-exact
at a system boot and at a D0 entry**; the rest is in `DIVERGENCE.md` and the README's table. Nothing was tuned or fixed on this
side; the model was not changed.

The LiberNT tree was not read at all in this round (it was in use for another build; the brief made it off limits):
every line below is measured in the VM or read from the staging directory's records.

## Image under test

`libernt-build-logs/test-audio-intel-sst-p4c4c-ec8ce887b1b/` — `feat/audio-control-polish` at `ec8ce887b1b` (163 commits over
master `f71e13cc154`). Verified with `sha256sum -c SHA256SUMS`, four of four OK (`image-check.txt`):

| file | bytes | sha256 |
|---|---|---|
| `LiberNT.iso` | 655714304 | `6b5ef3cd56bc6feebd207fc85ba09fe9b9caa0aeb74badcd1e25fc3366a875bd` |
| `LiberNT.vhd` (dynamic, 80 GiB virtual) | 809864192 | `3933d4410010b9a7a303e2abdf46263314cadf2e3bf4664d2f1fd486f38bf02d` |
| `LiberNT.img` | 1610612736 | `dfe7ff2d273c08d8c69646bbb57e63a44f6aaaf8284615332f6e1383fdb4a45d` |
| `dsploop_apitest.exe` | 211968 | `3b6c1a607e50a0cbfaa148459985f4cb41e76cb4d9960c7b9f93c6ce05239b6b` |

Extracted from the ISO independently of the image directory's own gates (`bsdtar -x -f LiberNT.iso` into `/tmp`, hashed
there — `in-iso.txt`): the fifteen files with a record in the staging directory's `gates/in-iso.txt` are all **equal by hash**
— `intcdsp.sys` `35548fd30767…`, `hdaudbus.sys` `1c2754a06e6c…`, `dsppcm.sys` `64bcd5e9d5e3…`, `hdaudio.sys` `69e2fc3eb3af…`,
`swenum.sys` `3e12e60bbc26…` (upstream's), `wdmaud.sys` `5cc9aa7ec157…`, `mmdevapi.dll` `a8e3b7f60e6f…`, `mmsys.cpl` `f180480e5e6f…`,
`explorer.exe` `8df867a76e35…`, `SystemSettings.exe` `b8870fe3c4b7…`, `stobject.dll` `cd75b6677a72…`, `ntoskrnl.exe` `564c94a383ce…`,
`sof-arl-s.ri` `f37a055cefef…`, `sof-mtl.ri` `4f3fb3fc57d2…`, `sof-ipc4-loopback.tplg` `0e002de8d92e…`; seven more were hashed
for the record with no staging record to compare (the three INFs, `hal.dll` `1f05d5a1622b…`, `cmd.exe` `44ec7eb52e05…`,
`certutil.exe` `55128208e1bd…`, `pnputil.exe` `4839dc2762e2…`). The ISO's `ntoskrnl.exe` carries the identity string
`20261126-ec8ce88` (the staging record's); the desktop's watermark reads `feat/audio-control-polish.ec8ce88.amd64.clang.0521-261126`
(`vm/r0-firstboot-nodisk/s1-desktop-before-wizard.png`). The exe's hash was taken in the guest at each use (`exe-hash.txt`,
`x-certutil*.txt`: the same value, after the copy to the system disk too).

## Model

- qemu-ace-dsp `main` at `f1b0538`, the model unchanged: patches 0001–0020 on QEMU 11.1.3. No file of the model changed in
  this round (`git status`: only this evidence directory and the README are new).
- The binary of record, not rebuilt: `build/qemu-system-x86_64` sha256
  `a894197dc0b040dd3d5a94d163e70dc631168e1d820b7a9468c2ecb83919e8bc`, `build/tests/qtest/intel-hda-ace-test` sha256
  `f335e5907c4f9f695e8e4de4f0350d95ef82325e5af63835a6f83ed513b94825` — the p4c4b2 round's.
- qtest before the first VM run: **15/15**, rc=0, 2026-11-26T21:15:38Z (`vm/qtest-before-vm.txt`, its head
  `vm/qtest-before-vm.head.txt`).
- The model's trace: `ace_unexpected` **0** in every VM; `ace_audio` lines: 12 in VM 1 (the self-test), 3618 in VM 5 (the three
  stream runs), counted per VM in `vm/measured-lines.txt`.

## Host

A Linux VM with 4 logical CPUs and 31 GB of memory, QEMU's TCG without KVM, `/tmp` a tmpfs (16 GB) holding the live logs and
the extracted files; the overlays on the host's own disk. One VM at a time. **For the first twelve minutes of the round another
build ran on the same host** (`ninja -j 3` with three compiler processes: load average 4.4 on 4 CPUs); the one VM launched
during that time is kept as an environment record (`vm/r0a-firstboot-nodisk-hostloaded`), and every evidence VM ran after the
build had ended.

## The VM runs (UTC)

Every VM: q35, TCG, `-smp 1`, `ICOUNT=1` (`-icount shift=auto,align=off,sleep=off`, `tcg,thread=single`), `CDROM=none` (the
installed system boots from a qcow2 overlay over the p4c4c `LiberNT.vhd`), `TRACE=1`, `QTESTSOCK=1`, launched by `lib-run.sh`
through `vmcommon.sh`; the live logs under `/tmp/qad-ev/p4c4c/`, copied into this tree afterwards (`postrun.sh`). The guest
has no network interface (`-nic none`). `qemu-args.txt` and `command.txt` hold each VM's command line. Every VM is decided by
serial lines and by the text the guest wrote to its data disk; **screenshots were read by me** for A2 (the display: r0's s1–s4,
r1's s1–s3), for B4 (the Sound applet: r1's s8, s9) and for group D (listed in `DIVERGENCE.md`), never to decide a line.

| VM | evidence dir | wall (UTC) | how it ended | what it did |
|---|---|---|---|---|
| r0a | `vm/r0a-firstboot-nodisk-hostloaded` | 242 s, 21:17:30–21:21:31 | clean S5 (the power button, by hand after the script was stopped) | the no-disk first boot **launched while another build saturated the host**: Storport timeouts ×7, the volume opened read-only, `WL: Failed to initialize Gina`, the display `User Interface Failure`; the wizard not reached. **An environment record** (`DIVERGENCE.md`): not evidence about the image. Its overlay was discarded and made again for r0 |
| r0 | `vm/r0-firstboot-nodisk` | 345 s, 21:24:44–21:30:28 | clean S5 (the power button), rc=0 | **A1/A2 without the data disk**: swenum's line, `Safe removal: ROOT\SYSTEM\0000` 0.09 s later, the Setup wizard (`s1`), the desktop after the chords (`s2`–`s4`). `boot0.sh` was stopped by my own fault right after `start_vm` (E33); `boot0b.sh` took the VM over |
| r1 | `vm/r1-firstboot-stream-selftest2boot` | 739 s, 21:32:42–21:45:00 | clean S5 (the power button), rc=0 | **A1/A2 with the data disk**; `BootDsp = 1`, `Topology`, `SelfTest = 0` set; the guest rebooted: **the system boot with the topology (A3, B4, E17)**; **E24 on `D:`** (the launch and the copy refused); the names (`reg-mmdev.txt`), the lists; the Sound applet (`s8`, `s9`); **`SelfTest = 2` at a system boot (B7)**; `SelfTest = 0` set back |
| r5 | `vm/r5-plainboot-stream` | 285 s, 21:45:47–21:50:33 | clean S5 (the power button), rc=0 | on r1's overlay (A3 at a plain boot); the data disk probed by both names (**E24 on `E:`**: the launch by the long and the 8.3 name works, two full runs from the data disk); the copy to the system disk (hash equal); **the stream under `LIBERNT_APITEST_REQUIRED=1`: GREEN**; the latency lines (B6); the lists |
| r2 | `vm/r2-notopology-cycles` | 913 s, 21:52:27–22:07:39 | clean S5 (the power button), rc=0 | a fresh overlay's first boot (A1 once more); `BootDsp = 1`, no `Topology`; **C8** (the none-selected line and the power-down; the lists); **C9** (two cycles of the DSP device alone); **the 22-cycle regression** (`cycles.log`, `summary.txt`) |
| r3 | `vm/r3-topology-pnp-cycles` | 1131 s, 22:08:49–22:27:40 | clean S5 (the power button), rc=0 | a fresh overlay's first boot; `BootDsp = 1`, `Topology`, `SelfTest = 2`: **B7 at the D0 entry** and run 1's lines; `SelfTest = 0`; the lists; **C10** (refused); `net stop audiosrv`; **C11: refused with the service stopped** (the DSP device, the child, the codec); `net stop sysaudio`, refused again; **N5-05**; the Sound applet with the service stopped (`s5`). `boot3.sh` was stopped by me after the first refused disable with the service stopped (its cycles could only have waited); `boot3b.sh` took the VM over |
| fm | `vm/fm-<fault>/`, `vm/fault-matrix.md` | 1985 s in 20 launches, 22:30:06–23:04:50 (the pre-flight row first) | each row: the VM stopped by the tool after its recovery cycle | **the fault rows** on r2's overlay (`BootDsp = 1`, no topology): one boot per fault (`none`, the 17 faults, the two delay scales), the driver's terminal line, then a recovery cycle (`tools/cycle.sh`); `tools/fm-check.sh`: 0 rows with a failed check. The first attempt of the batch launched no VM (the copy of the tool had the project's path wrong: E33 e) |
| r4 | `vm/r4-byeye` | 2110 s, 23:05:14–23:40:24 | clean S5 (the power button, by hand), rc=0 | on r1's overlay (A3 at a plain boot); E16 with the service running (the same text as r3); **group D by eye** (D12 c measured; the rest not run: E45); `boot4end.sh` read no console and was stopped by my wrapper's cap |

## Overlays

Not committed; each under `disk/`, made by `make-overlay.sh` over the p4c4c `LiberNT.vhd`: `p4c4c-nodisk.qcow2` (r0; the first one, of r0a, was discarded and made again before r0), `p4c4c.qcow2` (r1, then r5, then r4),
`p4c4c-nt.qcow2` (r2, then the fault rows), `p4c4c-tp.qcow2` (r3). `p4c4c.qcow2` also holds the copy of the exe on the system disk
(`C:\dsploop_apitest.exe`, made in r5). The data disks (FAT16 "pouches" with the exe and the text the guest wrote) are not committed; their
text is in each VM's directory.

## The tools (`vm/tools-used/`)

The p4c4b2 round's scripts as the starting point, with the image directory, the log paths and the overlay names changed — and
these departures:

- `vmcommon.sh`: **`waitre`** (a serial-line wait whose status means what it says: the p4c4b2 round's `waitfor` is a pipeline
  that ends in `tee`, so its status is always 0 — its E26); **`cmd`** (a typed command whose own text goes to the data disk
  with the time its output took to arrive — nothing is read from a screenshot); `make-pouch.sh` carries the exe under its
  long name **and under the 8.3 name `dsploop.exe`** (the data disk's letter and names: `DIVERGENCE.md`, E24').
- `boot0.sh` (the no-disk first boot) and `boot0b.sh` (its take-over after `boot0.sh` was stopped by my own fault: E33);
  `boot1.sh` (the first boot with the data disk, the system boot with the topology, `SelfTest = 2` at a system boot);
  `boot5.sh` (the stream: the data disk probed by both names, the apitest under the required switch, the gate);
  `boot2.sh` (no topology: C8, the DSP device alone, the 22 cycles); `boot3.sh` (the topology: the D0-entry self-test, C10,
  C11 with the audio service stopped, the pin-open attempt, N5-05); `boot4.sh` and `step.sh` (group D by eye, step by step).
- `fault-matrix-p4c4c.sh`: the project's `tools/fault-matrix.sh` with one block changed (the recovery cycle's console is opened
  by `Win+R` as every console of this round) — `fault-matrix-p4c4c.diff`.
- `preflight.sh` (the staging record's format of p4c4c), `postrun.sh`, `measured.sh`, `expectcheck.py`, `collect-tools.sh`.
- Unchanged from the project: `tools/cycle.sh` (every disable/enable cycle: the pnputil lines typed, the model's registers
  read over qtest before and after), `tools/waitline.sh`, `tools/guest.sh`, `tools/mon.py`, `tools/qtest.py`.

## Layout of the round's evidence (`evidence/2026-11-26-p4c4c/`)

| file | what |
|---|---|
| `image-check.txt`, `in-iso.txt` | the images verified in the staging directory; twenty-two in-ISO files hashed from an independent extraction, fifteen against the staging record |
| `DIVERGENCE.md` | the result: what closed, what was found, with its class; the notes; what was not run |
| `vm/qtest-before-vm.txt`, `vm/qtest-before-vm.head.txt` | the qtest before the first VM run: 15/15 |
| `vm/measured-lines.txt` | per VM: the round's counts and the lines that matter, cut from the raw serial log |
| `vm/expected-vs-measured.txt` | TESTING.md's expected lines, each counted in every VM; the gate rule on every apitest log; the latency lines; pnputil's and net's own texts |
| `vm/fault-matrix.md` | the 20 fault rows with their recovery cycles; `fm-<fault>/` each row's serial log, command line and trace excerpt |
| `vm/tools-used/` | the round's scripts |
| `vm/r0-…`, `vm/r1-…`, `vm/r5-…`, `vm/r2-…`, `vm/r3-…`, `vm/r4-…`, `vm/r0a-…` | one directory a VM: `serial.log` (raw), `serial.txt` (ANSI escapes, NULs and CRs removed), `driver.log` (the script's own log with host times), `driver-lines.txt`, `cycles.log` (the cycles' VMs), `lib-run.out`, `command.txt`, `qemu-args.txt`, `start.txt`, `end.txt`, `qemu-dbg.log.gz` (the trace), `ace-trace.txt`, `ace-audio-lines.txt`, the text the guest wrote to its data disk, the screenshots, `contents.txt` (what was kept) |

Serial lines end in CR LF in `serial.log`; they are quoted without the tail.

## Not done in this round

In all: **27 QEMU launches** (the seven named VMs and the twenty fault rows), **29 guest boots** (r1 had three), **7750 s of VM time — 129 minutes**
(within the brief's 2.5 hours); 75 settings lines for 75 device starts of the DSP (the 18 fault rows that end in a failed boot included), 51 `boot ok`
lines (the fault rows' 20 recovery cycles and their `none` row among them), **0 `The system has been stopped`, 0 `Stop code`, 0 `clock stalled`, 0
`interrupt storm`, 0 `Work queue` lines and 0 `ace_unexpected`** in any VM of the round; seven clean S5s (the fault rows were stopped by the tool, as
always).

- Nothing was tuned or fixed on either side: the model is `f1b0538`; the driver is the image's; the kernel is the image's.
- **The C11 path is not reached**: a disable with the child present is refused with the audio service running and with it stopped (`DIVERGENCE.md`,
  C10, C11): no cycle with the child, no pin open across a cycle, no power-down with streams built.
- Of group D only D12 c ran (`DIVERGENCE.md`, group D); the registry read of the changed format and the end-of-VM probe of the veto's holder did not (E45).
- The live read of the descriptor lists during the apitest's runs (the p4c4b round's `livecap.py`): not run.
- As before: `UseInterrupts = 1`, the refusal rows of the topology selection, silicon; Meteor Lake on silicon; the 32-bit wrap (the plan's INFO_NEEDED).
