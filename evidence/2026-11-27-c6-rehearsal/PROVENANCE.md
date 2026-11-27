# Evidence 2026-11-27-c6 — the rehearsal of the first real session (image p4c4d, no serial port)

What this is: the rehearsal of the owner's first session on the IMG layout of image p4c4d
(`LiberNT.img`, sha256 a29a9c7b…, `BOOTLOADER_DEBUG_PORT=FILE,SCREEN`), on the test host's
simulator, under the conditions the test machine imposes: **no serial port** (no `-serial`, so
the loader does not add `DEBUGPORT=COM1`), one QEMU at a time, `-smp 1`, `-nic none`,
`-icount shift=auto,align=off,sleep=off` on `tcg,thread=single` (as every evidence run: the guest
clock and the model's timers advance together; it works without a serial log), the screen read
through the monitor's `screendump` only, every key through the monitor's `sendkey`.

## The stick
A 4 GiB raw file (`disk/c6-stick-p4c4d.img`, not committed) with `LiberNT.img` at offset 0 — what
DD mode writes onto a larger stick (the system partition has free space after it, as on the
owner's 64 GB stick). The image is **MBR, not GPT** (`label: dos`, LBA1 all zeros): entry 1
`start=2048 size=131072 type=ef bootable` (the ESP), entry 2 `start=133120 size=3012608 type=7`
(NTFS). The brief said GPT; the gate file `img-partitions.txt` and this rehearsal say MBR.
`logs/s0-*.txt`. A second stick (`disk/c6-stick-s8.img`) was written the same way for S8.

## The data disk
`tools-used/make-pouch-c6.sh`: a 32 MiB FAT16 MBR disk carrying the kit files in once (the owner
copies `kit\` from Windows instead); afterwards the guest wrote its exports onto it and the host
read them with mtools while the VM ran. Nothing was launched from it.

## Directories
- `vm1/` — the first stick, boots 1–4 and the restart stall (driver.log = every key with its
  host time; qemu-dbg.before-reset.log = the -d cpu_reset,guest_errors log up to the stall: 2
  resets = the power-on resets, none after `restart`).
- `vm2/` — the same stick, S6: a cold boot, `system_reset` at t+64 s (the desktop was already
  up: still a hard reset of a running system), then two more resets 45 s apart (the early one
  in the kernel's text screen). qemu-dbg.log.gz ends with 5 resets.
- `vm3/` — the second stick, S8 (the owner's real Boot 1 with "Expand now" and an account).
- `logs/s1 … s8/` — the exports the guest wrote: `bootN.log` (raw, with the NUL filler an
  untrimmed log carries), `bootN.txt` (NULs stripped), the `enum-*`, `settings-*`, `dir-*`
  lists, `dsploop.txt`, `gate.txt`; `s0-*.txt`, `s8-stick-sfdisk-d-*.txt`.
- `tools-used/` — the scripts of this rehearsal exactly as run (`c6-run.sh` the launcher,
  `c6.sh` one key / one screenshot / one monitor command, `console.sh` types a file of lines,
  `early-shots.sh`, `tm-restart.sh`, `s6-freeze.sh`, `s6b-early-reset.sh`,
  `clear-components.sh`, `make-pouch-c6.sh`, `kit-crlf.sh`; `lines-*.txt` the console lines).

## Screenshots
34 PNGs are committed — the frames the report cites (every wizard page with its default state,
the kernel's text screens of a serial-less boot, the console, the Sound panel, the sign-in
screen, the components page). Omitted as near-duplicates: about 100 more desktop/text frames
(the per-second series of the reboots); they were taken and read, and the `driver.log` of each
VM lists every frame with its host time and size.

## What was not done
No build of any kind; the LiberNT tree was read only. No network. One QEMU at a time. No
diagnostic pass with a serial port was run (the brief allowed one). S7 was not rehearsed.
The vision model's reading of the screenshots is cited as "the screen shows"; the text the
guest wrote to the data disk is what every decision rests on.

Privacy: the machine is "the test machine"; the simulator host is described generically; no
brand, model, serial or IP. Paths are normalised by `normalise-evidence.sh`.
