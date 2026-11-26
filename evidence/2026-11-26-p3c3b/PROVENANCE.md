# Provenance — the p3c3b round (P3 C3, the micro rerun, 2026-11-26)

Written by the simulator side (Tasker). The C3 rerun on the fixed image: the loopback self-test of image
p3c3b against the model of `main 9f6d31c` — TESTING.md's runs 1, 1b, 2 and 3 — with D1 and D2 of the
p3c3 round measured fixed. The LiberNT tree was read through git only (`git grep`, `git show`,
`git rev-parse` at `1619498f85e`: the sine table and the compare of `stream.c`, for the rms check); nothing
in it was edited. Nothing in the model was changed.

Scope: the owner's ruling — a micro round: 3–4 VM boots, no fault matrix, no cycle run.

## Image under test

`~/libernt-build-logs/test-audio-intel-sst-p3c3b-d8f3a5bc81e/` — `feat/audio-control-polish` at
`1619498f85e9b155a39eb5ea88789a7eeee2d2b5` (95 commits over master
`d8f3a5bc81e5f409ad90c725a503fdaa91b672db`), built in `output-Clang-amd64-debug`. Verified with
`sha256sum -c SHA256SUMS` in the staging directory, three of three OK (`image-check.txt`):

| file | bytes | sha256 |
|---|---|---|
| `LiberNT.iso` | 643706880 | `a3c8fe73361be20e2d2e122c0c77f7c0d5fd29aae41f0b5fa35b25107093e168` |
| `LiberNT.vhd` (dynamic, 80 GiB virtual) | 797278208 | `cd2ca58e47c3c7f7f02a509754462281efb010d2b46e440af7fa36aee96cb508` |
| `LiberNT.img` | 1610612736 | `abd8fef66295cc81eba7a8e6ebe91c5d4849a99f38addda9ea751d8c020394b3` |

Extracted from the ISO independently of the image directory's own gates (`bsdtar -xf LiberNT.iso` into
`/tmp`, hashed there), each equal to `PROVENANCE.txt` and `gates/in-iso.txt` of the staging directory
(`in-iso.txt`):

| file in the ISO | bytes | sha256 |
|---|---|---|
| `Windows/system32/drivers/intcdsp.sys` | 315392 | `633354e6f142c527b19e3b4451e8890e0ee73b4792ae3743462188457ef46988` |
| `Windows/system32/drivers/hdaudbus.sys` | 262144 | `13ba7ecdfd80b90f4306461e56965cd679fc277ce2413a5bd8bfe729dbde8b88` |
| `Windows/system32/drivers/hdaudio.sys` | 225280 | `24889058843d340237fc1068d4fd68da6955cdcf1d862d7a81b0d8548fd59384` |
| `Windows/inf/intcdsp.inf` | 6368 | `32f3d6a106723fb3e5ef44e9129ba569804d0c39cf6a40735480c97f4b60ded5` |
| `Windows/inf/hdaudbus.inf` | 12526 | `a6d5c33ab40aec261fe69c0f219a61e41b1aec92dbf7d0cb83f8f6b1ec68079f` |
| `Windows/system32/drivers/intel/sof/sof-arl-s.ri` | 1158164 | `f37a055cefef26bbe14906ec6cd5fe5532c2a4419de87612d8b45b45dc647c6e` |
| `Windows/system32/drivers/intel/sof-tplg/sof-ipc4-loopback.tplg` | 4286 | `0e002de8d92e94f9f961a94a72674750f42d21afbdea09a2f6f6ee7196965601` |

The image identifies itself in the guest: the desktop's watermark
`feat/audio-control-polish.1619498.amd64.clang.5522-251126` names the build tip. The console's banner
reads `LiberNT [Version 0.4.17-amd64-dev 20261125-dc8c4a7]`: that is `cmd.exe`'s own version string in this
ISO (`10.0.26100.1 (0.4.17-amd64-dev 20261125-dc8c4a7)`, read from the extracted file), a binary the build
did not relink — the banner names the p3c3 build's published tip, not this image's (E18).

## Model

- qemu-ace-dsp `main` at `9f6d31c`, unchanged since the p3c3 round: patches 0001–0020 on QEMU 11.1.3,
  `src/qemu-11.1.3` clean at `v11.1.3-20-g46998f810`.
- The binary of record, not rebuilt: `build/qemu-system-x86_64` sha256
  `a894197dc0b040dd3d5a94d163e70dc631168e1d820b7a9468c2ecb83919e8bc`, `build/tests/qtest/intel-hda-ace-test`
  sha256 `f335e5907c4f9f695e8e4de4f0350d95ef82325e5af63835a6f83ed513b94825`.
- qtest before the first VM run: **15/15**, rc=0, 2026-11-25T23:17:22Z–23:17:31Z (`vm/qtest-before-vm.txt.gz`).

## Host

A 4-vCPU Linux VM with 31 GB of memory, otherwise idle (load average 0.09 before the first boot), QEMU's
TCG without KVM, `/tmp` a tmpfs (the live logs).

## The VM runs (UTC)

Every VM: q35, TCG, `-smp 1`, `ICOUNT=1` (`-icount shift=auto,align=off,sleep=off`, `tcg,thread=single`),
`CDROM=none` (the installed system boots from the disk overlay), `TRACE=1`, `QTESTSOCK=1`, one VM at a
time, launched by `lib-run.sh` through `vmcommon.sh`; the live logs under `/tmp/qad-ev/p3c3b/`, copied
into this tree afterwards (`qemu-dbg.log` gzipped per VM). `qemu-args.txt` and `command.txt` hold each
VM's command line. Each VM was driven by one unattended script from its start to its S5: the guest's
console is opened with the shell's `Win+R` hotkey (`IDHK_RUN`, `base/shell/explorer/traywnd.cpp:3370`)
and `cmd.exe`, never through the Start menu; the commands are typed by `tools/guest.sh`; every wait is a
bounded wait for a serial line; the VM is ended by the monitor's `system_powerdown` (the ACPI power
button). No screenshot was read to decide anything; the screenshots are the record.

| VM | evidence dir | wall | how it ended | what it measured |
|---|---|---|---|---|
| 1 | `vm/r1-firstboot-set-live` | 223 s, 23:29:53–23:33:36Z | clean S5, rc=0 | the fresh overlay's first boot (`BootDsp = 0`); the wizard closed by chords at 23:31:40–23:32:02Z; `BootDsp = 1`, `Topology`, `SelfTest = 2` set; **run 1 and run 2 at a D0 cycle** (the self-test's three runs). No live read: my first tool read the PCI configuration space through q35's ECAM window, which is not mapped unless a guest enables the MCH's PCIEXBAR, and refused on the zeros (E15) |
| 2 | `vm/r2-plainboot-live-then-selftest0` | 193 s, 23:42:41–23:45:54Z | clean S5, rc=0 | **run 1 and run 2 at a system boot**; the self-test again at a D0 cycle; then `SelfTest = 0`: **run 3 at a D0 cycle with `Topology` kept** and, the value deleted, **without it** (`cycles.log`). No live read: two faults of my tool (E15) |
| 3 | `vm/r3-plainboot-selftest0-then-live` | 468 s, 23:52:22–00:00:10Z | clean S5 after a resume, rc=0 | **run 3 at a system boot without `Topology`**; then `Topology` and `SelfTest = 2` set and a D0 cycle: **run 1b's readings at 16 bits** (taken from the VM while my tool had left it paused, `salvage-paused16.out`) **and at 24 and 32 bits** (the resumed run, `livecap-resume.out`), run 1 again. 323 s of its wall (23:54:34–00:00:07Z) the VM stood paused (E15) |
| 4 | `vm/r4-plainboot-regression-and-live` | 292 s, 00:14:33–00:19:25Z | clean S5, rc=0 | booted with `SelfTest = 2` (run 1 again); `SelfTest = 0` set and the guest rebooted (`shutdown -r -t 0`, `REBOOT=1`): **run 3 at a system boot with `Topology` kept**; then `SelfTest = 2` and a D0 cycle with **the live read through all six stops** (`livecap.out`): run 1b again |

Four QEMU launches, five guest boots (VM 4 rebooted), 19.6 minutes of wall time in all (1176 s). 10 DSP
boots (`boot ok … attempt 1, 0 DSP interrupts` on 10 of 10), 6 self-tests of three runs each (18 runs, all
captured), 11 settings lines for 11 device starts, 0 `clock stalled`, 0 `interrupt storm`, 0 `Work queue`,
0 bugcheck, 0 `Fatal System Error`, 0 `ace_unexpected` in the four traces, four clean S5s. The counts with
their exact-match checks: `vm/expected-vs-measured.txt`.

## Overlays and registry

- `disk/p3c3b.qcow2`: a fresh qcow2 overlay over the p3c3b `LiberNT.vhd` (`make-overlay.sh`, backing format
  vpc), made at 23:21Z; VM 1 is its first boot. Not committed.
- Under `HKLM\SYSTEM\CurrentControlSet\Services\intcdsp\Settings`, set in the guest's console with
  `reg add … /f` and read back from the driver's own settings line at the next device start (every value
  is on the serial log as `SelfTest = N, UseInterrupts = 0, IpcTimeoutMs = 500 ms` and `BootDsp = 1: …`;
  `s4-reg-add.png` of VM 1 shows the three answers `reg: The operation completed successfully`):
  - VM 1: `BootDsp` REG_DWORD 1, `Topology` REG_SZ `sof-ipc4-loopback.tplg`, `SelfTest` REG_DWORD 2;
  - VM 2: `SelfTest` REG_DWORD 0, then `Topology` deleted;
  - VM 3: `Topology` set again, `SelfTest` REG_DWORD 2; the `SelfTest` REG_DWORD 0 typed afterwards went
    into the paused VM and did not land (E15, E19);
  - VM 4: `SelfTest` REG_DWORD 0 (kept by the reboot), then REG_DWORD 2 for the live cycle, then 0 again.
  - The overlay is left with `BootDsp = 1`, `Topology = sof-ipc4-loopback.tplg`, `SelfTest = 0`.
- The device was disabled and enabled with `pnputil /disable-device` / `/enable-device` of
  `CSAUDIO\ADSP&CTLR_VEN_8086&CTLR_DEV_7F50\4&aeefd634&0&1000000000` (`tools/cycle.sh` for VM 2's two
  regression cycles; the typed commands for the live cycles).
- The first-boot Setup wizard's three pages were closed by the chords of the earlier rounds (`tab tab ret`,
  `ret`, `tab tab tab ret`), 15 s after its last serial line.

## The live reads (run 1b)

`livecap.py` (`vm/tools-used/`): one process and one monitor connection; it polls the serial log and, the
moment a driver line appears, stops the VM (the monitor acknowledges the `stop` in 13–16 ms while the guest
is mostly halted, in 0.5–1 ms while the self-test keeps it busy; where the streams were not yet running the
VM is let run 20 ms and stopped again until they are — so each 16-bit first-line reading shows one period
moved), takes the model's BAR0 from the monitor's
`info pci` (checked against the `0x81000000` the bus driver's own line names for BAR4), reads the eight
stream descriptors and their descriptor lists over qtest, saves the pages the lists name with the monitor's
`pmemsave` (one page more at each end of a window), compares the capture's pages with the render's byte for
byte, and continues the VM. Reads only, from the guest's side. At every later stop the windows of the
earlier stops are saved again, so the capture of a finished run is read after its two periods. BAR0 was
`0x81210000` in every VM (32-bit memory, 0x4000 bytes; `GCAP 0x4401`, `VMIN/VMAJ 0x00/0x01`, global
`CTL 0x00000101`); the lists of the two streams at `0x3f21000` (render) and `0x3f1d000` (capture).

A stop lands wherever the guest is when it takes effect, and the stream format says which run was live:
`fmt 0x0011` is the 16-bit run, `0x0031` the 24-bit, `0x0041` the 32-bit. Under icount a halted vCPU lets
the guest's clock run on, so the 85 ms of a run can pass in some 20 ms of host time; in VM 4 the stops
labelled 24 and 24end found the 32-bit run (`fmt 0x0041`), and the 24-bit lists are read at the stop after
the 16-bit run and in VM 3's resumed run. The tables: `vm/live-reads.txt`; every list page's first frames
against the sine: `vm/live-reads-pages.txt`.

## The rms check

`vm/rms-and-trace.txt`: the exact rms of the driver's sine over a period's frames and over the whole buffer
(`rms-check.py`), the driver's own arithmetic reproducing its printed figures (`driver-rms.py`), and every
`ace_audio` line of the four VMs against the sine (`ace-audio-check.py`: the eight samples a line prints,
its rms to a thousandth, its peak, and each pair's identity).

## Layout of the round's evidence (`evidence/2026-11-26-p3c3b/`)

| file | what |
|---|---|
| `image-check.txt`, `in-iso.txt` | the three images verified in the staging directory; the seven in-ISO files hashed from an independent extraction |
| `DIVERGENCE.md` | the result, D1 and D2 measured fixed, the rms note, the item for C6, the environment notes |
| `vm/qtest-before-vm.txt.gz` | the qtest before the first VM run: 15/15 |
| `vm/measured-lines.txt`, `vm/expected-vs-measured.txt` | the driver's lines of the four VMs in one file; their counts against TESTING.md's expected lines |
| `vm/live-reads.txt`, `vm/live-reads-pages.txt` | the live reads as tables; their pages against the sine |
| `vm/rms-and-trace.txt` | the sine's rms, the driver's arithmetic, every `ace_audio` line checked |
| `vm/tools-used/` | the throwaway scripts of the round: the four boot scripts and their shared part, `livecap.py`, `salvage.py` (the reading of the paused VM), the checks and the file makers |
| `vm/r1-firstboot-set-live` | VM 1: `s1`–`s5` (desktop, wizard closed, console, the three `reg add` answers, after the self-test), `livecap*.out` (the refused read) |
| `vm/r2-plainboot-live-then-selftest0` | VM 2: `cycles.log` (run 3 at a D0 cycle, both `Topology` states), `cycle-*.out`, `s1`–`s4` |
| `vm/r3-plainboot-selftest0-then-live` | VM 3: `salvage-paused16.out` (16-bit lists, pages, the capture after one period), `livecap-resume.out` (the 24-bit and 32-bit stops, the capture after each run), the `*.bin` windows, `s1`–`s4` |
| `vm/r4-plainboot-regression-and-live` | VM 4: `livecap.out` (the six stops), the `*.bin` windows, `s1`–`s4` |
| in every run dir | `serial.log`, `qemu-dbg.log.gz` (the whole trace), `ace-trace.txt` (the decoded lines), `ace-audio-lines.txt`, `driver-lines.txt`, `selftest-lines.txt`, `driver.log` (the script's own log with host times), `lib-run.out`, `command.txt`, `qemu-args.txt`, `start.txt`, `end.txt`, `contents.txt` |

Serial lines end in CR LF in the logs; they are quoted without the tail.

## Not done in this round

- Nothing was tuned or fixed on either side: the model is `9f6d31c`; the driver is the image's.
- Not run: `UseInterrupts = 1` with the self-test (TESTING.md's run 4, not a gate); TESTING.md (c)'s
  refusal rows; the fault matrix; the cycle run; silicon.
- Not measured: the capture of the 32-bit run's last page in VM 3 (the render's page was freed before the
  stop landed; VM 4's last stop has all eight). The 24-bit capture's state right after its run comes from
  VM 3 alone.
- `tools/mon.py` prints nothing for a monitor command that has output (it keeps the text after the last
  prompt, which is always empty): harmless for the `sendkey` and `screendump` it is used for, not fixed
  here (E15).
