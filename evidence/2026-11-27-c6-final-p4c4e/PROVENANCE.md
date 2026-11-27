# Evidence 2026-11-27-c6-final-p4c4e — the final pass of the owner's session on image p4c4e

What this is: the owner's session exactly as the run book says, in **one unbroken sequence on one
stick** (vm1: Boot 1 with the wizard, the restarts through Task Manager, `savelog 1` … `savelog 4`,
`run-dsploop`, Turn Off), then the export boot (vm1x), the freeze case (vm2) and the one diagnostic
VM with a serial port for `shutdown.exe` (vm3). Image p4c4e: `LiberNT.img` sha256
`5ec399b2dac0771019d8f94dce0d0784ca7a432067d759c1a6ad3e0816f6ee71`, identity
`20261127-nt10.0-045-2746-g182677f` (the desktop watermark reads `182677f`),
`BOOTLOADER_DEBUG_PORT=FILE,SCREEN`; the stage's `SHA256SUMS` verified before the start.

Conditions: **no serial port** in vm1, vm1x and vm2 (no `-serial`, so the loader does not add
`DEBUGPORT=COM1`), vm3 with `-serial file:serial.log` (the only one; its serial log shows the
loader adding `DEBUGPORT=COM1` in front of `DEBUGPORT=FILE,SCREEN`), one QEMU at a time, `-smp 1`,
`-nic none`, 2 GB RAM, q35, pure TCG with `-icount shift=auto,align=off,sleep=off` on
`tcg,thread=single` (as every evidence run), the ACE HDA model + hda-duplex, the screen read
through the monitor's `screendump` only, every key through the monitor's `sendkey`. No build, no
network; the LiberNT tree was neither read nor written (everything below comes from the guest).

## The sticks
- Stick A: `disk/c6-stick-p4c4e.img` (not committed), a 4 GiB raw file with `LiberNT.img` at
  offset 0 — what DD mode writes onto a larger stick. The image part's sha256 equals the source's;
  MBR, entry 1 `start=2048 size=131072 type=ef bootable`, entry 2 `start=133120 size=3012608
  type=7` (`logs/s0/s0-stick-sfdisk-d.txt`). "Expand drive C: now" was chosen on Boot 1.
- Stick B: `disk/c6-stickB-p4c4e.img` (not committed), FAT32, 256 MiB, MBR, one partition at
  sector 2048, carrying the deliverable `kit` folder (`kit/`, 9 files: the eight kit files and
  `KIT-SHA256SUMS`; `dsploop_apitest.exe` = p4c4e's, sha256 `d079489e…`, read back from the disk
  before the start: `logs/s0/s0-pouch-made.txt`). It stays attached for the whole session, as the
  owner's spare stick does; the guest names it `D:`.

## Directories
- `vm1/` — the session: 5 boots of the stick (Boot 1; the boot with `stage1`; the DSP power-up
  boot with `savelog 2` and `stage2`; the self-test boot with `savelog 3`, the Sound panel and
  `stage3`; the stream boot with `run-dsploop`, `savelog 4` and Turn Off). `driver.log` = every
  key, every line typed and every screenshot with its host time; `qemu-dbg.log.gz` = the
  `-d cpu_reset,guest_errors` log (6 CPU resets: 2 of the power-on, 1 per restart; none for the
  Turn Off, which ends in QEMU exiting).
- `vm1x/` — the export boot of the same two sticks: `copy /y C:\logs\*.* D:\` (the run book's
  step 32 fallback), then Task Manager → Turn Off so the FAT write is flushed.
- `vm2/` — the freeze case: `system_reset` (what the power button does to a running system), the
  early `system_reset` 45 s later with the kernel's text screen showing, the stick booting on,
  `savelog 9`, the export, Turn Off.
- `vm3/` — `shutdown -r -t 0` with a serial port; `serial.log` is the port's log (the kernel's
  shutdown sequence, then the boot manager again); closed through the monitor's `quit`.
- `logs/s0/` — the sticks' partition tables and the four VMs' start lines.
- `logs/s5/` — the exports of the session, as the host read them from stick B after the clean
  Turn Off: `boot1 … boot4.txt`, `boot2 … boot4-prev.txt`, `dsploop.txt`, the gate's output
  (`gate.txt`), the per-boot figures (`stats.txt`), the recount of the p4c4d logs
  (`intcdsp-counts.txt`), the per-source-file comparison with p4c4d (`cmp-vs-p4c4d.txt`) and the
  driver lines side by side (`dspdiff-*.txt`). The raw exports (`boot<n>.log`, 270,336 bytes
  each, NUL-padded) are left out: the `.txt` files are the same bytes without the NUL padding.
- `logs/s6/` — the freeze case's exports: `boot9-prev.txt` (the boot that was cut) and `boot9.txt`.
- `tools-used/` — the scripts exactly as run: `c6-run.sh` (the launcher; `SERIAL=` adds the port),
  `c6.sh` (one key / one screenshot / one monitor command; `pw` types the password from a file),
  `console.sh`, `tm-restart.sh`, `signin.sh`, `winr.sh`, `clear-components.sh`, `early-shots.sh`,
  `f6-reset.sh`, `f7-observe.sh`, `wait-exit.sh`, `make-pouch.sh`, `logstats.sh`, `cmplogs.sh`,
  `dspdiff.sh`, `crop.py` (crops and enlarges a screenshot, no image library on the host),
  `assemble.sh`; `lines-*.txt` are the console lines.

## Screenshots
vm1: 53 PNGs are committed (66 were taken) — every wizard page in its default state and after the owner's keys, the console
after each command, the Sound panel's two tabs, the Task Manager menu with the item highlighted
before each Enter, the kernel's text screens of every reboot, the sign-in screens, the stream
test's result. The desktop frames are about 0.8 MB each. Omitted as near-duplicates (they were
taken and are listed in `driver.log`): `b1-06`, `b1-09`, `b1-12`, `b1r-early-02/03`, `b2-05`,
`b2-06`, `b2-09`, `b2r-early-01…03` and `08`, `b3-01`, `b3-07`, `b3r-early-01…04`, `b4-01`, `b4-02`,
`b4r-early-01…04`, and the `z-` crops not listed. vm1x: 4, vm2: 37 (the per-3-s and per-5-s series
around the two hard resets), vm3: 11.

## The password
The rehearsal account's password was generated on the host into a file (`/tmp/c6f/.pw`, mode 600)
at the setup and typed from it by the tool; it is not in any log (`driver.log` reads `type <typed>`),
and the screenshots show dots.

## What was not done
No build; no network; the LiberNT tree was not touched. F8 (the recovery path of the run book,
S7) was not rehearsed. `shutdown.exe` was not tried on p4c4e **without** a serial port (the
stall is the p4c4d rehearsal's evidence, S2 and S4; on p4c4e it was only shown to work **with** a
port). The cause of the 89 `ipstats_reactos.c` lines of Boot 1 was not looked up in the tree.
The vision model's reading of the screenshots is cited as "the screen shows"; every decision
rests on the text the guest wrote to stick B.

Privacy: the machine is "the test machine"; no brand, model, serial or IP; paths are normalised
by `normalise-evidence.sh`.
