# qemu-ace-dsp — a QEMU device model of the Intel ACE 1.0 audio DSP (`intel-hda-ace`)

A QEMU variant of the stock `intel-hda` controller that adds the ACE audio DSP
of the Intel Arrow Lake-S/HX "Smart Sound Technology BUS" function
(`8086:7f50`): the DSP bar (BAR4) with the ACE 1.0 register block, the
processing-capabilities (PP) and software-position-in-buffer (SPB) capabilities
in the controller's BAR0, the ROM boot handshake, the code-loader stream
consumer, the IPC4 receive/reply path and the controller-level interrupt.

It exists so that the real LiberNT image runs the real `intcdsp.sys` (the
P2b driver of the `CSAUDIO\ADSP` child) in a VM without the target laptop.
It proves the kernel glue under real timing with the real firmware bytes; it
never proves the silicon's true ROM, its undocumented checks, signature
enforcement, powered-down read behaviour or real timings (the plan's §1).

The project is a **patch series against the pinned QEMU 11.1.3** (never a
fork) plus the scripts that build, run and observe the VM. Design and
acceptance: `../p2c-qemu-ace-dsp-plan.md`.

## Licence

**GPL-2.0-or-later.** `COPYING` is QEMU's; every new file carries QEMU's header
text and the SPDX id. The model's behaviour is **re-derived** from the plan's
§4.1 prose, the P2a/P2b NOTES (facts), the SOF documentation and the cited ABI
headers (Linux `mtl.h`/`hda.h` under the plan directory's `LICENSING.md` rule 7:
own declarations, one citation per definition, zero pasted text; SOF's BSD-3
headers with attribution). Nothing was copied from the GPL-3 LiberNT tree and
nothing flows back into it. Each commit names the sources studied.

## Layout

| Path | What |
|---|---|
| `fetch.sh` | downloads `qemu-11.1.3.tar.xz` (sha256 pinned) into `src/`, makes the git baseline `v11.1.3`; fetches the OVMF blobs into `firmware/` |
| `build.sh` | `git am patches/*.patch` onto a clean `v11.1.3` → configure → ninja; time in `build/TIME.txt` |
| `patches/` | the series (0001 …): internal header, capability chain, hooks, the device, the qtest, the docs |
| `run.sh` | the VM with the model: q35, TCG, `-smp 1`, OVMF, `intel-hda-ace,addr=1b.0` + `hda-duplex`, serial → file |
| `run-control.sh [ich9\|none]` | the regression control: QEMU's `ich9-intel-hda` (8086:293e) or no HDA device |
| `snapshot.sh` | PNG screenshot through the monitor socket |
| `set-fault.sh` | inject a run-time fault through QMP (`qom-set … fault <name>`) |
| `lib-run.sh`, `tools/` | the launcher and the monitor/QMP helpers |
| `evidence/<date>/` | serial logs, traces and screenshots of every acceptance run |

## Build and run

```sh
./fetch.sh            # once: ~30 MB download, sha256 checked
./build.sh            # first build on the CachyOS VM: 140 s wall (4 jobs), see build/TIME.txt
./run-control.sh      # gate-(a) control: the four hdaudbus.sys lines for 8086:293e
TRACE=1 WAIT=240 STOP_ON='BootDsp = 0' ./run.sh     # stage 1: probe only
```

Requirements: a Linux box with gcc, ninja, python3, glib/pixman development
files; no root (QEMU configures its own meson); no system QEMU. Build only
under `/home` (the build tree is ≈ 2 GB and `/tmp` is a tmpfs).

## The model's chosen values (replaced by the owner's checklist as windows allow)

Every value the hardware ABI does not dictate is a named property and is printed
as "(model value)" in the trace and in the README. Column "Target machine" is filled
from the laptop checklist (`refs/step0/OWNER-CHECKLIST.md`); "—" means not yet
observed.

| Value | Model | Property | Target machine |
|---|---|---|---|
| PCI ID / revision / class | `8086:7f50`, rev `0x10`, `0403` prog-if `0x80` | `personality` | `8086:7f50` (FINDINGS §1) |
| BAR0 | 0x4000 | — | — |
| BAR4 | 0x200000 (2 MB) | `x-bar4-size` | — (checklist 1) |
| LLCH → PP → SPB | 0x14 = 0x0180 → PP (id 3, ver 1, next 0x700) → SPB (id 4, ver 1, next 0) | compile-time | — (checklist 5) |
| `HFINTIPPTR` | 0x00000120 (INTEN at BAR4 + 0x1120) | compile-time | — (checklist 5) |
| Powered-down reads | 0 | `x-powered-down-value` | — (checklist 5) |
| Timers | CPA 100/200 µs, ack 100 µs, INIT_DONE 500 µs, FW_ENTERED 2 ms, FW_READY 200 µs, reply 50 µs, CPA-off 50 µs | `x-delay-scale` | — (checklist 6/7) |
| ROM info | `0x0120315A` | compile-time | — |
| Mailboxes | 4096 / 4096 bytes | compile-time | — |
| Interrupt | MSI or INTx, auto | `msi=auto\|on\|off` | — (checklist 7) |

## Acceptance (plan §6.8)

- **AC1** qtest passes; mutation check recorded — C5.
- **AC2** VM stage 1 (probe only) — see `evidence/`.
- **AC3** VM stage 2 (`BootDsp=1`) — see `evidence/`.
- **AC4** fault matrix — C4.
- **AC5** this README + the scripts reproduce AC2–AC4 from a clean checkout.

The evidence index with every run is kept at the end of this file.
