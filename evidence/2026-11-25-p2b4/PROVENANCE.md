# Provenance — the p2b4 round (2026-11-25)

Written by the simulator side before the first VM run. Nothing in the LiberNT tree was touched.

## Image under test

`~/libernt-build-logs/test-audio-intel-sst-p2b4-f2bf7a98990/` — `feat/audio-control-polish` published as
`b392065b2cf` (76 commits over master `f2bf7a98990`; built from `24b0394e1e0`, identical tree content
per `MEGAN-NOTE.txt`). Verified with `sha256sum -c SHA256SUMS`:

| file | sha256 | check |
|---|---|---|
| `bootcd.iso` | `f4c4636d5e135150021f43de35ab0286b14713c21e8def024899d2484d50b9e8` | OK |
| `LiberNT.vhd` | `8e079736612f8478cc2c027d93f05a7ac2a003a7ff0ae35f52cbe6abadacd08d` | OK |
| `LiberNT.img` | `586a9d1f2318b6c3c00c56d140a2c15ef7bdb7b1c63e152f0db8dc1bf3293b03` | OK |

`intcdsp.sys` and `hdaudbus.sys` extracted from the ISO with `bsdtar` and hashed (=
`PROVENANCE.txt` of the image dir):

| file in the ISO | sha256 |
|---|---|
| `Windows/system32/drivers/intcdsp.sys` | `41bd140577feaa82a9c5bcf6b1d9a23f761526a002e12a4b71831c1fa474ef0c` |
| `Windows/system32/drivers/hdaudbus.sys` | `4683e5ffeed379ee208da34bdcb477a6fb25f609f3f5467b7da062f635e4991a` |

## Model

- qemu-ace-dsp `main` at `b139810` (patches 0001–0010 applied on QEMU 11.1.3; `build/applied-patches.txt`
  lists the ten commits, the last two being 0009/0010 — the unpowered `HFINTIPPTR` reads all ones).
- `build/qemu-system-x86_64` sha256 `a6a4371b911a787991fed57857fb438c225996bae65cecd667b69b7f14b48766`
  (built 2026-11-25 02:09, after the source of `b139810`; not rebuilt in this round).
- qtest before the first VM run: 9/9 (`qtest.txt`: enumerate, caps, stock-controllers, boot-handshake,
  power-down, intipptr, irq-intx, irq-msi, faults).
- Every VM run: q35, TCG, `-smp 1`, `ICOUNT=1` (`-icount shift=auto,align=off,sleep=off`,
  `tcg,thread=single`), logs on tmpfs (`/tmp/qad-ev/…`) copied into this tree afterwards.

## Overlay

`disk/p2b4.qcow2`: a fresh qcow2 overlay over the p2b4 `LiberNT.vhd` (`make-overlay.sh`, backing
format vpc, 80 GiB virtual). The packaged `qemu-img` the script falls back to was unpacked again under
`/tmp/p2c-qemu` with `refs/p2c/gate-a/fetch-qemu.sh` (the gate-(a) procedure: 18 packages, each SHA-256
checked against the pacman sync database) because `/tmp` was lost with the host restart and the
self-built tree has no tools (`--disable-tools`).

## Layout of this evidence tree

| run | what |
|---|---|
| `a1-stage1-firstboot` | the first boot of the fresh overlay: the first-boot wizard, the stage-1 probe lines (`BootDsp = 0`), `BootDsp=1` set, clean S5 — this boot turns the overlay into the stage-2 overlay |
| `a2-stage2-boot` | a plain boot of the stage-2 overlay: the full stage-2 line sequence with the `interrupts …` lines |
| `a4-second-boot` | one disable/enable cycle in one VM: the second boot has no new `firmware … bytes, ok` line (R6) |
| `ac3-cycles` | AC3: 22 disable/enable cycles in one VM |
| `fm-<fault>` | one boot per fault of the matrix, each followed by a recovery cycle (Task C; `bad-tuples` and `truncated-reply` are also Task A3) |
