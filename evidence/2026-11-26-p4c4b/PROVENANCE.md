# Provenance — the p4c4b round (P3 checkpoint C4b, 2026-11-26)

Written by the simulator side (Tasker). The C4 micro round on image p4c4b — TESTING.md's runs 1 to 4 with
the model of `main 232bffb`. **The image does not get through its first boot in the VM**: every boot on
which an HDA codec is present bugchecks before the Setup wizard (`DIVERGENCE.md`, U1), so none of TESTING.md's
runs was reached. What the round measured is that bugcheck: where it is in the image's own kernel binary,
what the faulting thread looked at (read from the paused VM), which device it concerns, and what it does and
does not depend on.

The LiberNT tree was read only: its sources as files (`sed`, `grep` under `<home>/Projects/LiberNT`, at
`7940c6d2deba`, the published tip with the image's tree content) and through git (`git show a81cf9e65cf:<path>`,
`git log`, `git merge-base --is-ancestor`); nothing in it was edited. Nothing in the model was changed. The
round continues a stopped one: its pre-flight (the image check, the qtest, two overlays) and its first VM (r0a)
stand; its boot scripts `boot1.sh` to `boot4.sh` were written and never reached their first wait.

Scope: the owner's ruling — a micro round. VM time of this round: six QEMU launches, 16.9 minutes.

## Image under test

`~/libernt-build-logs/test-audio-intel-sst-p4c4b-a81cf9e65cf/` — `feat/audio-control-polish` at
`0d90fbd22c9` (107 commits over master `a81cf9e65cf2c039d13dce7590d9049a0d6560c6`), built in
`output-Clang-amd64-debug`; the published tip with the identical tree is `7940c6d2deba029456aba06f5f660cd16866458b`
(the staging directory's `MEGAN-NOTE.txt`). Verified with `sha256sum -c SHA256SUMS`, four of four OK
(`image-check.txt`):

| file | bytes | sha256 |
|---|---|---|
| `LiberNT.iso` | 654075904 | `59e0cce88f0a7fdfd1438e01db3ce066eb074ffc2d701b56f42528fbb756c88b` |
| `LiberNT.vhd` (dynamic, 80 GiB virtual) | 807766528 | `220c401579a45c273848c9a80134a4405d015c77cd8e26f542009c933c653dba` |
| `LiberNT.img` | 1610612736 | `bd2f43eceae914e156deab0a04f5deac1cb1eaa21b17e607ef150c1bcb7817ae` |
| `dsploop_apitest.exe` | 215040 | `b1b50f48229e7853dbd56c84ee01245b66ab19f500efcd6622bdf2e869d427d7` |

Extracted from the ISO independently of the image directory's own gates (`bsdtar -x -f LiberNT.iso` into
`/tmp`, hashed there), the fourteen files each equal to `PROVENANCE.txt` and `gates/in-iso.txt` of the
staging directory (`in-iso.txt`): `intcdsp.sys` `b559a66c57ba…`, `hdaudbus.sys` `9f1eb00fa8d7…`,
`dsppcm.sys` `3ced786cb0e5…`, `hdaudio.sys` `c59862227d6f…`, the three INFs, `sof-arl-s.ri` `f37a055cefef…`,
`sof-mtl.ri` `4f3fb3fc57d2…`, `sof-ipc4-loopback.tplg` `0e002de8d92e…` and the rest.

Two files more were extracted the same way for the attribution of the bugcheck (the disassembly of the
faulting instruction, `fault-site.txt`):

| file in the ISO | bytes | sha256 |
|---|---|---|
| `Windows/system32/ntoskrnl.exe` | 10055680 | `17b1a0666b93a8f97fc3e318e061165c0a27a18d8697531e24fd59638782ce40` |
| `Windows/system32/hal.dll` | 4415488 | `2da93ed3df7b4c24796401cb3ae440350a221af65fd329e6e91de9d018cd4973` |

The image identifies itself on the serial line at every boot: `LiberNT 10.0 build 26100, 1 processor(s)`.

## Model

- qemu-ace-dsp `main` at `232bffb08e88`, the model unchanged since the p3c3 round: patches 0001–0020 on
  QEMU 11.1.3. One uncommitted change belongs to this round: `lib-run.sh`'s `EXTRA_DRIVES` (ten comment and
  code lines: more `-drive` arguments for a round's own data disk), written by the stopped round for its
  data disk and committed with this round's evidence.
- The binary of record, not rebuilt: `build/qemu-system-x86_64` sha256
  `a894197dc0b040dd3d5a94d163e70dc631168e1d820b7a9468c2ecb83919e8bc`, `build/tests/qtest/intel-hda-ace-test`
  sha256 `f335e5907c4f9f695e8e4de4f0350d95ef82325e5af63835a6f83ed513b94825`.
- qtest before the first VM run: **15/15**, rc=0, 2026-11-26T08:04:14Z (`vm/qtest-before-vm.txt`, its head
  `vm/qtest-before-vm.head.txt`).
- The model's trace: 6 `ace_*` lines and 0 `ace_unexpected` on every boot that had the model (the driver's
  probe reads alone: `BootDsp = 0` at every boot, the DSP never booted, `dsppcm.sys` never loaded), 18 in
  the three-boot VMs r0b and r0c (`qemu-dbg.log` of each); 0 `ace_*` lines in r0d and r0e, which have no
  model.

## Host

A Linux VM with 4 logical CPUs and 31 GB of memory, QEMU's TCG without KVM, `/tmp` a tmpfs (16 GB) holding
the live logs and the extracted files. One VM at a time.

## The VM runs (UTC)

Every VM: q35, TCG, `-smp 1`, `ICOUNT=1` (`-icount shift=auto,align=off,sleep=off`, `tcg,thread=single`),
`CDROM=none` (the installed system boots from a disk overlay), `TRACE=1`, `QTESTSOCK=1`, launched by
`lib-run.sh` through `vmcommon.sh`; the live logs under `/tmp/qad-ev/p4c4b/`, copied into this tree
afterwards. `qemu-args.txt` and `command.txt` hold each VM's command line. **Nothing was typed into any
guest**: every VM of this round ended before its Setup wizard, and its script decided by serial lines
alone (a bounded wait for a line, or `bugpause.py`, which polls the serial log and stops the VM within a
millisecond of the bugcheck's register line). No screenshot was taken or read.

| VM | evidence dir | wall | how it ended | what it did |
|---|---|---|---|---|
| r0a | `vm/r0a-firstboot-crash-with-disk` | 77 s, 08:14:39–08:15:56Z | QEMU exited at the bugcheck's reset (`-no-reboot`), rc=0 | the stopped round's VM 1: the fresh overlay `p4c4b` with the data disk (the "pouch": a FAT16 disk carrying `dsploop_apitest.exe`, `pouch-made.out`). The first boot bugchecked at 44.8 s; the run directory was renamed by the stopped round, which had meant it as run 1 to 4 |
| r0b | `vm/r0b-firstboot-nodisk` | 249 s, 08:57:25–09:01:34Z | the monitor's `quit` (the guest stood at its third bugcheck), rc=0 | **no data disk**, a fresh overlay `p4c4b-probe`, `REBOOT=1`: three boots, three bugchecks alike. The read primitive checked, the first boot's bugcheck read (`bugread.txt`), the second too (`bugread-2.txt`) |
| r0c | `vm/r0c-firstboot-nodisk-read` | 227 s, 09:08:02–09:11:49Z | the monitor's `quit`, rc=0 | the same overlay and configuration; the read following the PDO (`bugread.txt`: the PDO's driver object, the device node's instance path and state) |
| r0d | `vm/r0d-firstboot-ich9` | 242 s, 09:24:18–09:28:20Z | the monitor's `quit`, rc=0 | **QEMU's own ICH9 HDA controller** (`HDA=ich9`, the same `hda-duplex` codec): no ACE model, no DSP child (`ADSP child not created on PCI 8086:293e … not an ACE-era Intel controller`, `audio path LegacyHdaOnly`). A fresh overlay `p4c4b-ich9`. Three boots, three bugchecks alike; the first read with the instance path verbatim |
| r0e | `vm/r0e-firstboot-nohda` | 99 s, 09:28:39–09:30:18Z | **clean S5**, rc=0 | **no audio controller at all** (`HDA=none`). A fresh overlay `p4c4b-fresh`. The first boot went through its Setup phase — `First-boot setup lists 11 components` at 77.0 s, `Storage expansion not offered` at 77.7 s — with no `KsCreateBusEnumObject` line and no bugcheck |
| r1b | `vm/r1b-secondboot-ace-dsploop-selftest2` | about 115 s, 09:35:03–09:37:00Z | stopped by me: the job killed, the VM gone with it (no `end.txt`) | the workaround attempt: the `p4c4b-fresh` overlay of r0e (its first boot without audio) booted **with** the model and the data disk, to run `boot1b.sh` (the stopped round's run 1 and 2 script, its first wait shortened). The boot — the first that saw the audio controller — bugchecked the same way at 37.4 s; with `REBOOT=1` the next boot began and was stopped |

Six QEMU launches, 1011 s (16.9 minutes) of wall time. 15 guest boots; 11 of them bugchecked, every one at
`ntoskrnl.exe + 0x17deb9` (`Stop code: 0x0000001E`, `Parameter 1: 0xFFFFFFFFC0000005`, `RAX=c0c0c0c0c0c0c0c0`),
and no boot that got as far as swenum's `KsCreateBusEnumObject` line with an HDA codec present did anything
else (r0a 1, r0b 3, r0c 3, r0d 3, r1b 1). The other four boots: r0e, the one boot without a codec, has
neither the line nor the bugcheck; r0c's and r0d's last boots were cut short by the `quit` before the
line; r1b's second boot had the line and was stopped within a second of it. The lines per boot:
`vm/measured-lines.txt`.

## Overlays

Not committed; each under `disk/`, made by `make-overlay.sh` over the p4c4b `LiberNT.vhd`: `p4c4b.qcow2`
(r0a), `p4c4b-probe.qcow2` (r0b, r0c), `p4c4b-ich9.qcow2` (r0d), `p4c4b-fresh.qcow2` (r0e, then r1b). No
registry value of the image was touched: no console was ever opened. The overlays of the bugchecked boots
hold the crash dumps the guest wrote (`KD: Memory dump saved successfully`, about 200 MB each).

## The tools of the attribution (`vm/tools-used/`)

- `bugpause.py`: one monitor connection; polls the serial log; `stop`s the VM within a millisecond of a
  needle. With `CHECK=<images>` it first validates the monitor's read (`HMP x`) while the VM stands stopped
  early in the boot: the 16 bytes at CS:RIP and at RIP+16 must be found in the image's `ntoskrnl.exe` or
  `hal.dll`, with one page-aligned base common to both reads (r0c, r0d, r0e: `0xfffff8007b326000` both
  only and found nothing — a fault of the check, not of the read). Recorded as the files have it: r0c
  listed the candidate bases of both reads, `0xfffff8007b326000` (the kernel's) among them each time, but
  its verdict line says `CHECK failed` (the script then demanded identical candidate lists); r0d's check
  computed both reads and then died in a fault of the script's own KPCR report before printing a
  verdict; r0e's passed outright, `0xfffff8007b326000` the one candidate of both reads.
  only and found nothing — a fault of the check, not of the read).
- `bugread.py`: with the VM paused at the bugcheck, reads the faulting thread's stack above the RSP the
  bugcheck text printed, the device objects of the walk, and scans for `UNICODE_STRING` pairs; reads only.
  What it relies on of the image: `[RSP+0x48]` is the return address into the image after the call of the
  faulting function (it was exactly that in r0b, r0c and r0d: `0xfffff8007b4a3df1` = base `0x…7b326000` +
  `0x17ddf1`), `[RSP+0x40]` the function's first argument (the PDO), `[RSP+0x30]` the device object of the
  loop, a device object's `AttachedDevice` at `+0x18` and `DeviceObjectExtension` at `+0x138`.
- `pefuncs.py`, `fault-site.sh`: the functions of the backtrace by the image's `.pdata` table and the
  disassembly of the two places of the kernel the attribution quotes (`fault-site.txt`).
- `probe-nodisk.sh`: the script of r0b to r0e (`RUN`, `OVERLAY`, `HDA` in its environment).

## Layout of the round's evidence (`evidence/2026-11-26-p4c4b/`)

| file | what |
|---|---|
| `image-check.txt`, `in-iso.txt` | the images verified in the staging directory; fourteen in-ISO files hashed from an independent extraction (the stopped round's pre-flight) |
| `DIVERGENCE.md` | the result: U1, the first-boot bugcheck attributed; what was not run |
| `fault-site.txt` | the image's `ntoskrnl.exe`: the faulting function and the frame that queued the removal disassembled, the functions of the backtrace by `.pdata` |
| `vm/qtest-before-vm.txt`, `vm/qtest-before-vm.head.txt` | the qtest before the first VM run: 15/15 |
| `vm/measured-lines.txt` | per VM and per boot: the configuration's lines, swenum's line, the bugcheck's lines, the reset — and r0e's clean lines |
| `vm/device-stack-readings.txt` | from the three paused reads: the device object of the walk, the PDO's fields, the device node's fields and strings |
| `vm/tools-used/` | the round's throwaway scripts: `vmcommon.sh`, `probe-nodisk.sh`, `boot1.sh` to `boot4.sh` and `boot1b.sh`, `bugpause.py`, `bugread.py`, `pefuncs.py`, `fault-site.sh`, `measured-lines.py`, `collect.sh`, the stopped round's `livecap.py`, `make-pouch.sh`, `preflight.sh` |
| `vm/r0a-…`, `vm/r0b-…`, `vm/r0c-…`, `vm/r0d-…`, `vm/r0e-…`, `vm/r1b-…` | one directory a VM: `serial.log` (raw), `serial.txt` (ANSI escapes, NULs and CRs removed), `driver.log` (the script's own log with host times), `lib-run.out`, `command.txt`, `qemu-args.txt`, `start.txt`, `end.txt` (where there is one), `qemu-dbg.log`, `bugpause-*.out`, `bugread*.txt`, `contents.txt` (what was kept) |

Serial lines end in CR LF in the logs; they are quoted without the tail.

## Not done in this round

- Nothing was tuned or fixed on either side: the model is `232bffb` (with `lib-run.sh`'s launcher change);
  the driver is the image's; the kernel is the image's.
- Not reached: TESTING.md's runs 1 to 4 (the stream through the endpoint, `SelfTest = 2` on this image) and
  its run 3 (the three leftovers of C4a: the boot without a topology, the disable attribution, the
  `SelfTest = 0` boot regression). The wizard was never closed, `BootDsp = 1` never set, `dsploop_apitest.exe`
  never ran (the pouch was made and hashed twice: `pouch-made.out` of r0a and r1b).
- Not read: which user-mode component asked for the removal (two callers in the tree fit, `DIVERGENCE.md`);
  the crash dumps the guest wrote; the reason the driver database's device is removed and restarted at its
  first installation.
