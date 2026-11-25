# N1 and the payload bounds: what the model did on a malformed image, before and after (2026-11-25T09:39:11Z)
#
# Two defects of the ROM's judgement of the streamed image (patches 0015-0018 fix them):
#
# - **N1** (Megan's go of 2026-11-25): `ace_rom_judge()` read six words of the image without looking at the
#   result -- the directory's entry count, the ADSP.man entry's offset, the manifest's vendor and magic, a module
#   segment's flags and file offset. gcc warned on every build for the last two ("may be used uninitialized").
# - **The bounds of a payload read could wrap** (found while fixing N1, beyond its wording; its own patch): the check
#   was `off + 4 > payload_len` in 32-bit arithmetic, and the offsets are the image's own -- the guest streams the
#   image. An offset just under 2^32 passed it, and the read went four gigabytes past the stream: **the emulator died
#   on a SIGSEGV** (section 3).
#
# Models: old = patches 0001-0014 (the model of `main` 4bb8022, `build/qemu-system-x86_64` 646ff226...); fixed = the
# model with patches 0015-0018. The probe ran the qtest case `short-stream` once per cut with a temporary filter in
# the test (removed before the commit) and printed the model's FSR and ROM error after the stream:
# `OBSERVE cut=<bytes of the stream>: FSR <value> ROMERR <value> (expected state 0x.. code ..)`.
#
## 1. A stream that ends inside a structure (N1)

The test image: the directory at 0 (its entry count at 4), the ADSP.man entry at 20 (its offset at +12), the manifest at
0x40 (vendor +16, magic +28), the firmware header at 0x2000, the module entry at 0x2034 (segment flags at +80, file
offset at +88). The stream is cut just before the word. What the ROM answered:

| cut | the word not in the stream | expected (halt, state, code) | the OLD model | the fixed model |
|---|---|---|---|---|
| 4 | the directory's entry count | 0x09, 43 | FSR 0x80000009 ROMERR 43 | FSR 0x80000009 ROMERR 43 |
| 32 | the ADSP.man entry's offset | 0x25, 43 | FSR 0x80000025 ROMERR 43 | FSR 0x80000025 ROMERR 43 |
| 0x50 | the manifest's vendor | 0x26, 44 | FSR 0x80000026 ROMERR 44 | FSR 0x80000026 ROMERR 44 |
| 0x5c | the manifest's magic | 0x26, 44 | FSR 0x80000026 ROMERR 44 | FSR 0x80000026 ROMERR 44 |
| 0x2084 | a segment's flags (and so its file offset) | 0x28, 43 | FSR 0x00000005 ROMERR 0 | FSR 0x80000028 ROMERR 43 |
| 0x2090 | nothing: the file offset ends at 0x2090, it is inside this stream | the existing rule: 0x28, 42 | FSR 0x80000028 ROMERR 42 | 0x28, 42 by the same rule (seen in the first run of the fixed model; that transcript was overwritten by the 0x2088 run, so no line is kept) |
| 0x2088 | the segment's file offset (its flags read) | 0x28, 43 | not run | FSR 0x80000028 ROMERR 43 |

Read so: on the old model the two cuts where a word of the stack decided (4, 32) reached the expected
verdict *by accident* (the word happened to be zero), and the two manifest cuts fail closed because the
word kept its previous value. The cut at **0x2084 was accepted as a firmware: `FSR 0x00000005` is
FW_ENTERED, the ROM error 0** -- an image of 8324 bytes, four bytes of a module entry and no module,
booted. The cut at 0x2090 is not an N1 case at all: the file offset is inside that stream, and the
existing rule ("the segment lies outside the stream") answered 42, as it should. On the fixed model every
cut halts in the state of the structure with its code (a model value each: `MODEL-NOTES.md`, rows 17–20).

The trace of the fixed model names the word it could not read (`ROM rule <name>: 0`):
`partition directory entries`, `ADSP.man entry offset`, `manifest vendor word`, `manifest magic word`,
`module segment flags`, `module segment file offset` -- one line per cut in the qtest transcript
`qtest-0001-018.txt.gz`.

## 2. The qtest case `short-stream` on the old model

With the case committed as it is (the six cuts in order, the observation line removed) and run against the
model of `main` 4bb8022, the case stops at its first red assertion, the cut at 0x2084:

    not ok /x86_64/intel-hda-ace/short-stream (test line 1051:check_short_stream: assertion failed (r4(ACE_FSR) == ACE_BUSY | state): (5 == 2147483688)

## 3. The wrapped offset: the emulator died (old model)

The ADSP.man entry's offset field of the test image set to 0xfffffffe, so that the read of the manifest
header would wrap its bounds check. The qtest case `wrapped-offset` on the old model -- libqtest's own
report at the end of the run:

    Broken pipe
    libqtest.c:210: kill_qemu() detected QEMU death from signal 11 (Segmentation fault) (core dumped)
    timeout: the monitored command dumped core

The last trace lines before it (the judge had read the directory; the next read is the manifest header):

    ace_state state rom-ready -> loading
    ace_fsr FSR state 0x25 wait 0x5 module 0 halted 0
    ace_payload_check ROM rule partition directory: 1

The crash record of the emulator (systemd-coredump, the run of 2026-11-25):

               PID: 313322 (qemu-system-x86)
            Signal: 11 (SEGV) si_code: SEGV_MAPERR
         Timestamp: Wed 2026-11-25 10:11:28 IST (1h 27min ago)
      Command Line: ./qemu-system-x86_64 -qtest unix:/tmp/qtest-313115.sock -qtest-log /dev/null -chardev socket,path=/tmp/qtest-313115.qmp,id=char0 -object monitor-qmp,id=qm
           Storage: /var/lib/systemd/coredump/core.qemu-system-x86.1000.f0bb69f25cd74c5a9d48443b0f8b85cf.313322.1795594288000000.zst (present)
      Size on Disk: 975.3K

The faulting frames (gdb on the core, read at 08:13Z of 2026-11-25 against the binary that produced it -- the
14-patch model, `build/qemu-system-x86_64` sha256 646ff226...; re-read in section 5 against a rebuild of it):

    #0  0x000055f22817bcf8 in ace_rom_judge (s=<optimized out>) at ../src/qemu-11.1.3/hw/audio/intel-hda-ace.c:656
    #1  ace_stream_run (d=<optimized out>, idx=<optimized out>, running=<optimized out>) at ../src/qemu-11.1.3/hw/audio/intel-hda-ace.c:1163
    #2  0x000055f228174496 in intel_hda_set_st_ctl (d=0x55f236f885d0, reg=0x55f228ab4fc0 <regtab+14336>, old=<optimized out>) at ../src/qemu-11.1.3/hw/audio/intel-hda.c:516

`intel-hda-ace.c:656` of that model is the read of the manifest header at the offset the directory
entry names (the accessor inlined into `ace_rom_judge()`).

## 4. The fixed model on the same images

With patches 0017/0018 the same two images are refused like any other of their kind (qtest case
`wrapped-offset`, green in `qtest.txt`): the wrapped manifest offset as a manifest header that cannot be
read (`LOAD_CSE_MAN_TO_IMR`, 44), and a segment whose end wraps (file offset 0xfffff000 with one page) as a
segment outside the stream (`LOAD_FW_CODE_TO_IMR`, 42).

## 5. The crash record re-read after the mutation run (2026-11-25T09:39:11Z)

The 14-patch model was rebuilt from its patches (`PATCHDIR` with 0001-0014, `build.sh`). At the time of
this re-read `build/qemu-system-x86_64` is that rebuild, byte-identical to the binary that crashed in
section 3 (before the final 18-patch build replaced it):

    sha256 646ff22682bf74ad7230d5dd4f16a64b68079846740756c6abb7604954b7b99a

The core read against it, `gdb -batch -ex "bt 3"`:

```
#0  0x000055f22817bcf8 in ace_rom_judge (s=<optimized out>) at ../src/qemu-11.1.3/hw/audio/intel-hda-ace.c:656
#0  0x000055f22817bcf8 in ace_rom_judge (s=<optimized out>) at ../src/qemu-11.1.3/hw/audio/intel-hda-ace.c:656
#1  ace_stream_run (d=<optimized out>, idx=<optimized out>, running=<optimized out>) at ../src/qemu-11.1.3/hw/audio/intel-hda-ace.c:1163
#2  0x000055f228174496 in intel_hda_set_st_ctl (d=0x55f236f885d0, reg=0x55f228ab4fc0 <regtab+14336>, old=<optimized out>) at ../src/qemu-11.1.3/hw/audio/intel-hda.c:516
```

The same three frames as in section 3 (gdb prints the innermost frame twice on this core).
