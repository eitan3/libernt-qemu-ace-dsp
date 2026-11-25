# MODEL-NOTES — the host gateways (P3 C3, the model half, 2026-11-25)

The C3 additions to `evidence/2026-11-25-p3c1/MODEL-NOTES.md`: what the model does with a stream,
value by value, so that C6 can replace each with silicon's answer. **Every "model value" row is
unproven on hardware.** Plan-given rows are the contract (plan §5.5, §5.6, §5.9, §5.10, §8 C3) and are
not the model's to change. Model: `intel-hda-ace`, patches 0001–0020 on QEMU 11.1.3 (src master
`46998f810`), binary `a894197d…`; qtest 15/15 (`qtest.txt`); the trace of one sequence is
`loopback-trace.txt`; the mutation rows `mutation-check.md`.

## The IPC sequence the model expects from the driver for one stream

The plan's §5.10 order as the qtest sends it (one pipeline, three widgets, two edges; the loopback
case sends steps 1–9 and 11–14 — the reset of step 10 is the pipeline table's, answered 0 since C1).  Every
request is the extension into `HFIPCXIDDY`, then the primary into `HFIPCXIDR` with bit 31 (BUSY); the
configuration of an init-instance is written into the downlink mailbox (BAR4 + 0x188000) first.
Every reply comes **50 µs** after the request (model value, unchanged) as `DONE | reply (bit 29) |
the request's target and type | status` in `HFIPCXIDA`, **extension 0** in `HFIPCXTDDY` (model value,
unchanged), and is acknowledged by writing `DONE` back.  The examples are the qtest's guest values
(copier = module 5, gain = module 7, pipeline 1, tags 2 and 3).

| Step | Message (type) | Extension | Primary (without BUSY) | Reply (status 0) |
|---|---|---|---|---|
| 1 | create pipeline (17) | 0 | `0x11010000`: instance 1 | `0xb1000000` |
| 2 | init instance (0), the host-output copier | `0x00010015`: pipeline 1, **21 dwords** | `0x40000005`: module 5, instance 0 | `0xe0000000` |
| 3 | init instance (0), the host-input copier | `0x00010015` | `0x40010005`: module 5, instance 1 | `0xe0000000` |
| 4 | init instance (0), the gain | `0x0001000a`: pipeline 1, 10 dwords | `0x40000007`: module 7, instance 0 | `0xe0000000` |
| 5 | bind (5): the primary names the **source**, the extension the **destination** | `0x00000007`: module 7, instance 0 | `0x45000005`: module 5, instance 0 | `0xe5000000` |
| 6 | bind (5) | `0x00010005` | `0x45000007` | `0xe5000000` |
| 7 | set pipeline state (19) | 0 | `0x13010003`: instance 1, paused | `0xb3000000` |
| 8 | set pipeline state (19) | 0 | `0x13010004`: instance 1, running | `0xb3000000` |
| — | the capture stream runs, then the render stream (SD_CTL: tag at bits 23:20, RUN bit 1) | | | no IPC: `gateway armed` in the trace |
| 9 | set pipeline state (19), on pause or stop | 0 | `0x13010003` | `0xb3000000` |
| 10 | set pipeline state (19), reset | 0 | `0x13010002` | `0xb3000000` |
| 11–13 | delete instance (11) × 3 | 0 | `0x4b000005`, `0x4b010005`, `0x4b000007` | `0xeb000000` |
| 14 | delete pipeline (18) | 0 | `0x12010000` | `0xb2000000` |

**Which message carries the stream tag:** the init-instance (or the large-config set that
re-configures the copier): word 17 of its configuration, the gateway node id = `type << 8 | tag − 1`
(type 0 for the host-output copier, 1 for the host-input one).  No other message names the stream;
the stream's own tag is the SD_CTL field of the controller.  Nothing else of the 21 words is judged
(see row 23).  The C2 builder's placeholder, index `0xff`, is accepted and means "no stream yet"
(row 24).

## Every value the model chooses (rows 23–44; 1–22 are in the C1 notes)

| # | Item | The model's answer | Kind | Silicon (C6 fills) |
|---|---|---|---|---|
| 23 | Which module ids are copiers, and what of a configuration is read | the model does not know the ids (the driver resolves them from the image): a configuration of **21 words and up is a copier's** (10: a base configuration; 11–20: tracked without a gateway); of it are read the base configuration's buffer sizes and input audio format, and for a copier the output format of pin 0 and the gateway node id; the feature mask, the DMA buffer size, the gateway data length and the attributes are not read | model value (the plan's §5.6 gives the layout, not a rule for the model) | — |
| 24 | A copier initialised with the placeholder index `0xff` | tracked, **names no stream, nothing is forwarded** (the trace: `no host-output copier with a stream`); a later **large-config set** with a real index arms the gateway at once | model value (the placeholder is the driver's own value) | — |
| 25 | init-instance of an instance that exists | status **10** (`IPC4_RESOURCE_ID_EXISTS`), the existing instance untouched | model value | — |
| 26 | init-instance whose size exceeds the downlink mailbox (1024 dwords); large-config set of more than 4096 bytes or not a whole number of dwords | status **1** (`IPC4_ERROR_INVALID_PARAM`), nothing tracked | model value | — |
| 27 | A module table full (64 instances) | status **1** | model value (the limit is the model's: `ACE_MODEL_MAX_MODULES`) | — |
| 28 | bind, large-config set or delete-instance naming an instance that does not exist | status **9** (`IPC4_INVALID_RESOURCE_ID`); for a bind the trace says which end is missing | model value | — |
| 29 | A large-config set that is not one block (the first and the last flag both set) | status **7** (`IPC4_INVALID_REQUEST`): a configuration in several blocks is **not modelled** (a host copier's 84 bytes never need one) | model value | — |
| 30 | The parameter id of a large-config set | not judged (any value is accepted), traced | model value (the plan's table names the field, not the values) | — |
| 31 | Deleting an instance | the modules bound behind it are unbound with it | model value | — |
| 32 | Which module is "the sink" of a host-output copier | the first module in table order bound to take its output, then the one bound behind that, up to 16 bindings (copier → gain → copier is two), until a copier with a host-input gateway is found | model value | — |
| 33 | The pipeline a copier belongs to, and when the gateway runs | the pipeline id of the copier's init-instance extension; the gateway runs when **that** pipeline is RUNNING; the sink copier's pipeline is not checked | model value | — |
| 34 | The wire | the bytes the host-output gateway consumed are written **unchanged** into the host-input gateway's stream: the gain is unity, there is no latency — the driver's "offset k frames" is 0 on the model | model value (the plan's C5 configures the gain; pipeline latency is "not modelled in P3", §10.1) | — |
| 35 | A frame that changes across the pipeline (the host-output copier's input format and the host-input copier's output format differ in bytes per frame) | **not forwarded**: the gateway is not armed, the trace says `not modelled` (e.g. a 16-bit render against a 32-bit capture) | INFO_NEEDED 10 — the plan gives no conversion | — |
| 36 | What a period is | the run of descriptors from the stream's position to the end of the **next descriptor with the interrupt-on-completion bit**; when none has it, the whole cycle | plan-given in spirit (§5.9: interrupt on the last descriptor of each notification half); the "none" case is a model value | — |
| 37 | How long a period takes | `period bytes × 1e9 / (sampling frequency × frame bytes)` ns of virtual time, both from the copier's input audio format (48 kHz, 32-bit stereo: 384 000 bytes a second; 2048 bytes = 5.333 ms); **not** scaled by `x-delay-scale` | model value | — |
| 38 | The first period | one whole period after the last of: the pipeline RUNNING, both copiers configured and bound, the render stream running (the gateway arms whenever all hold, whichever came last: the qtest sends the plan's order, and its resume — the streams still running when the pipeline runs again — exercises the reverse) | model value | — |
| 39 | A capture stream that is not running while the render stream is | the period's bytes are **consumed and dropped**: the render position advances, the capture's does not, no capture interrupt, no capture `ace_audio` line (`its samples are dropped` in the armed line) | model value (INFO_NEEDED 9) | — |
| 40 | Which controller streams the gateways use | the render stream is the **output** stream (model indices 4–7) whose SD_CTL tag is the index + 1 and whose RUN bit is set; the capture stream the **input** stream (0–3) likewise; a stream stopped or reset behind the model's back ends or narrows the gateway at its next tick | model value (the model has four output and four input descriptors; INFO_NEEDED 12) | — |
| 41 | The cycle bound | the descriptor list, or the SPIB value when the host set a smaller one — as the loader stream is bounded; a cycle cut by SPIB restarts at the first descriptor | model value | — |
| 42 | The position | LPIB = the bytes moved since the cycle's start, wrapping to 0 at the cycle's end; the **position buffer's entry** (when DPLBASE is enabled) is written when a stream starts running and after every period; the **extended DMA-position register** (BAR0 + 0x1084 + 0x20 × index, read-only, the bus driver's `HDA_REG_VS_SDXDPIB`) reads the same value | the register's place is the bus driver's; **the mirror is a model value** (Megan's instruction of 2026-11-25; INFO_NEEDED 8) | — |
| 43 | The interrupts | a descriptor with the interrupt-on-completion bit, used up, sets the stream's completion bit (SD_CTL bit 26); INTSTS carries the stream's bit and the global bit when INTCTL enables them; the host clears it by writing 1 to it | plan-given (§5.9: interrupt-on-completion as for codec streams); the parent controller's implementation | — |
| 44 | A period that cannot be moved whole, or a descriptor whose DMA fails | what did move is reported (positions, interrupts, the `ace_audio` lines with the bytes moved), then **the gateway stops**, with a trace line saying why | model value | — |
| 45 | The lifetime of the module table and the gateways | with the pipeline table's: cleared at every firmware start, at power-off and at reset | model value (row 15 of the C1 notes) | — |

Untested rows — listed as model values and INFO_NEEDED, not as verified behaviour: 26, 27, 29 (the
odd-byte half), 31, 35, 41 (the smaller-SPIB case: the qtest sets SPIB to the buffer size), 44, and
row 40's clause on a stream reset behind the model's back (the qtest stops the render stream through
the run bit).  The rows the qtest exercises: 23, 24, 25, 28, 29 (the several-blocks half), 32, 33,
34, 36–40, 42, 43 (the `audio-loopback` case).

## The `ace_audio` line

One line per period and per stream — for the render stream (what the host sent) and the capture
stream (what the host will read back; the same bytes) — in the plan's §8 C3 shape:

```
ace_audio <tag> <bytes> rms <r> peak <p> first <s0> <s1> … <s7>
ace_audio 2 2048 rms 1000000.000 peak 1000000 first 1000000 -1000000 -1000000 1000000 1000000 -1000000 -1000000 1000000
```

`<tag>` is the stream's SD_CTL tag; `<bytes>` what moved in the period; `<r>` the RMS of the
period's samples with three decimals (model value: over all samples of the period, both channels);
`<p>` the largest magnitude; `<s0>…<s7>` the first eight samples, left and right interleaved.  A
sample is a signed 16-bit integer for a 16-bit container (word 1 of the copier's input format) and a
signed 32-bit one otherwise (24-in-32 included, left-justified as the host wrote it).  Beside them
the trace has `gateway armed (pipeline N): host-output copier 5.0 drains stream 2 into host-input
copier 5.1's stream 3; 384000 bytes a second` and `gateway stopped (pipeline N): <why>`.

## INFO_NEEDED — added for silicon (C6) and for the plan

9. Does the real firmware require the plan's trigger order (pipelines running before the streams
   run, the capture before the render), and what does it do with a host-input stream that is not
   running (row 39)?
10. The format conversion across the pipeline (a 16-bit host stream into a 32-bit pipeline and
    back): the model forwards only when the host-side frame sizes are equal (row 35).  Until silicon
    or the plan says otherwise, the driver's self-test at 16 and 24 bits should open both streams
    with the **same** container.
11. Is the copier re-configuration at prepare (a large-config set with the stream tag) needed on
    silicon, and with which parameter id (rows 24, 30)?
12. The real controller's stream pools and first tags (the plan's §7.1): the model has four output
    and four input descriptors (row 40).
13. The extended DMA-position register against the position buffer on silicon (row 42; the plan's
    INFO_NEEDED 8): the model makes them equal by construction.
14. Which module ids are copiers (row 23), and whether the real firmware judges a configuration by
    anything the model does not read (the feature mask, the attributes, the DMA buffer size).

Sources read for the layouts (cited in `intel-hda-ace-regs.h`): Linux
`include/sound/sof/ipc4/header.h` and `include/sound/hda_register.h` (the copies on the build host)
for the module-message extensions and `AZX_REG_VS_SDXDPIB_XBASE`; the LiberNT bus driver's
`hda_registers.h` at `d5e2a039be6` (`git show`, read-only) for the same register; the driver's
`sdk/lib/drivers/audio/softplg/ipc4model.{c,h}` at the same commit (`git show`) for the 21 words
the C2 builder produces (`SoftplgModelConfig`), to be sure the model parses what the driver sends.
