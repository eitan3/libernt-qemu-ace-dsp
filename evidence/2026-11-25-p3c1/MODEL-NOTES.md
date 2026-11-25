# MODEL-NOTES — the pipeline table (P3 C1, the model half, 2026-11-25)

What the model answers for the pipeline messages of plan §5.5, value by value, so
that C6 can replace each with the silicon's answer. **Every "model value" row is
unproven on hardware.** Plan-given rows are the contract (plan §5.4, §5.5, §8 C1,
R-G) and are not the model's to change. Model: `intel-hda-ace`, patches
0001–0014 on QEMU 11.1.3; qtest 12/12 (`qtest.txt`); the traces of every row below
are in `pipeline-trace.txt`; that the boot path before the pipeline messages did not
change is shown in `boot-path-diff.txt`.

## The messages the table accepts

Global messages (target bit 30 = 0): **create pipeline (17), set pipeline state
(19), delete pipeline (18)**. They are answered only while the firmware runs;
before that they get no reply, as every message did before.

| Message | Request as the plan's table lays it out | Reply shape |
|---|---|---|
| create pipeline (17) | primary: instance (23:16) \| priority (15:11) \| memory pages (10:0); extension: core (23:20) \| low-power flag (0) | `DONE \| reply \| 0 \| type 17 \| status`; extension 0 |
| set pipeline state (19) | primary: state (15:0) \| instance (23:16); extension: 0, or the multi-pipeline flag (0) | `DONE \| reply \| 0 \| type 19 \| status`; extension 0 |
| delete pipeline (18) | primary: instance (23:16); extension: 0 | `DONE \| reply \| 0 \| type 18 \| status`; extension 0 |

`DONE` is bit 31 (the register), `reply` bit 29, the target bit echoes the
request (0 here), the type bits 28:24 echo it, the status is bits 23:0 — the
reply shape the plan's §5.4 gives for every reply (plan-given).

## Every value the model chooses

| # | Item | The model's answer | Kind | Silicon (C6 fills) |
|---|---|---|---|---|
| 1 | A pipeline asked to run while it is not paused | status **5** ("invalid resource state" in the plan's words); the pipeline does not move | **plan-given** (§5.5, §8 C1) | — |
| 2 | The plan's self-test order: created → paused → running → paused → reset → delete | status 0 at every step | **plan-given** (§8 C1 Driver row, §5.10) | — |
| 3 | The state a newly created pipeline is tracked in | `uninitialized` (IPC4 state 1) — internal; the model has no GET_PIPELINE_STATE | model value | — |
| 4 | Every transition other than "to running": e.g. paused → paused, running → running, reset → end-of-stream, any → uninitialized | accepted (status 0) and tracked: the plan gives one rule only, so the model judges nothing else | model value (the plan is silent: INFO_NEEDED 2) | — |
| 5 | Deleting a pipeline that is not in the reset state (created, paused, running) | accepted (status 0), the entry removed | model value | — |
| 6 | set-state or delete for an instance id that is not in the table (never created, or deleted) | status **9** (`IPC4_INVALID_RESOURCE_ID`) | model value | — |
| 7 | create for an instance id that is already in the table | status **10** (`IPC4_RESOURCE_ID_EXISTS`); the existing entry is untouched | model value | — |
| 8 | create with instance id 0 | status **1** (`IPC4_ERROR_INVALID_PARAM`); id 0 is never tracked | model value; the plan's R-G only says the driver avoids 0 (INFO_NEEDED 3) | — |
| 9 | create with an instance id past the pipeline count (17 and up) | status **1**; the valid ids are 1 to 16 | model value ("16 pipelines" is the plan's [MODEL]) | — |
| 10 | set-state with a state the ABI does not have (0, or 6 and up) | status **1** | model value | — |
| 11 | set-state with the multi-pipeline flag (extension bit 0) | status **7** (`IPC4_INVALID_REQUEST`): the form is valid IPC4 but is **not modelled** (the plan's driver sends one pipeline per message); the table is untouched | model value | — |
| 12 | A module-space message (target bit 1) whose type number is 17, 18 or 19 | not a pipeline message: status **2** (`IPC4_UNKNOWN_MESSAGE_TYPE`), as every module message the model does not handle | model value (unchanged behaviour) | — |
| 13 | The reply's delay after the request | 50 µs (the FW_CONFIG reply's delay, `ACE_US_IPC_REPLY`, scaled by `x-delay-scale`) | model value (existing) | — |
| 14 | The reply's extension register (`HFIPCXTDDY`) | 0 | model value | — |
| 15 | When the table is emptied | at every firmware start (the moment the ROM enters the firmware), at core power-off, at subsystem power-off and at device reset: a re-booted firmware finds no pipeline (the plan's recovery re-boots "from scratch", §5.8) | model value | — |
| 16 | The acknowledgement of a reply | clears DONE only; the register keeps the reply's message bits (the qtest masks DONE) | existing behaviour, unchanged | — |

## The two new faults, as the plan names them

| Fault | What the model does | Kind |
|---|---|---|
| `ipc-status=<n>:<type>` | the replies of that one IPC4 message type (bits 28:24 of the primary) carry status `n`; every other type answers its own status. **The table is still updated as the message says** — the fault replaces the status only | plan-given name; the side effect is a model value |
| `never-reply=<type>` | the requests of that one type are dropped: no reply, ever, and the table is untouched (the firmware "never got it"); every other type is answered. A dropped request leaves nothing pending: the next request is answered normally | plan-given name; the side effects are model values |
| `ipc-status=<n>` (existing) | every reply carries `n` — unchanged | unchanged |
| `never-reply` (existing) | every request is dropped — unchanged | unchanged |
| the `<type>` of either fault | matched on the 5-bit type field alone, whatever the target bit (so `never-reply=1` drops the FW_CONFIG request, a module type 1; the purge request of the boot, a global type 1, is not on this path and is still acknowledged) | model value |
| a bad value (`ipc-status=5:32`, `never-reply=`, `never-reply=abc`, `ipc-status=5:19:1`) | refused when the property is set (`intel-hda-ace: fault '…': '…' is not a message type (0 to 31)`); the fault in place before is kept — checked on the command line and over QMP at run time (`fault-values.txt`) | model value |

In the trace every replied message carries its decoded type and status:
`IPC reply type 19 (set-pipeline-state) status 0: pipeline 1: paused -> running`,
an injected status says so, and a dropped request is
`IPC request dropped (set-pipeline-state) primary 0x13010003 ext 0x00000000`.

## INFO_NEEDED — for silicon (C6) and for the plan

1. **The name of status 5.** The plan writes "status 5 (invalid resource state)".
   SOF's `src/include/ipc4/error_status.h` (BSD-3; read at tag `v2.12.1` and at
   `main`, 2026-11-25) names value 5 `IPC4_BAD_STATE` and value 12
   `IPC4_INVALID_RESOURCE_STATE`. The model answers the plan's **number**; which
   code the real firmware returns for an illegal pipeline transition is unproven.
2. The firmware's real transition table beyond "paused before running" (row 4),
   and the state a new pipeline is really in (row 3).
3. Whether instance id 0 is really invalid (R-G), and the real pipeline limit.
4. The real answers to rows 6–11 (the numbers come from the ABI's error list, not
   from an observation of the firmware).
5. The reply delay (row 13) and the reply extension (row 14) on silicon.
6. **A notation conflict in the plan.** §8 C1's VM acceptance line uses
   `fault=ipc-status=19:17` and expects "`set pipeline state (19) … status 5`".
   Under the plan's own definition (`ipc-status=<n>:<type>`) that fault means
   *status 19 for create pipeline (17)*. To obtain the quoted line the driver's
   run must use **`ipc-status=5:19`** (status 5 for set-state) — or the plan's
   line is corrected. The model implements the definition, not the example.

Sources read for the numbers (cited in `intel-hda-ace-regs.h`): Linux
`include/sound/sof/ipc4/header.h` (the copy of 6.18.60 on the build host: types
17/18/19, states 0–5, the field shifts and masks — all as the plan's table) and
the SOF error list named above. No driver source was read.
