# DIVERGENCE — the p4c4b round (2026-11-26)

The C4 micro round on image p4c4b (`feat/audio-control-polish @ 0d90fbd22c9` on master `a81cf9e65cf`, the
tree of the published tip `7940c6d2deba`) against the model of `main 232bffb` (the binary `a894197d…`,
qtest 15/15 before the first VM run).

**The result in one paragraph.** The image does not get through its first boot in the VM. Every boot on
which an HDA codec is present bugchecks before the Setup wizard — `Stop code: 0x0000001E`,
`0xFFFFFFFFC0000005` at `ntoskrnl.exe + 0x17deb9` — on 11 of the 11 boots that got as far as swenum's line:
with the model and the round's data disk (r0a), with the model and no disk (r0b, r0c), with QEMU's own ICH9
controller and neither the model nor a DSP child (r0d), and again on the boot that first sees the audio
controller after a first boot without one (r1b). The one boot without an HDA controller was clean (r0e).
So **none of TESTING.md's runs was reached**: not the stream through the endpoint (`dsploop_apitest`), not
`SelfTest = 2` on this image, not the boot without a topology, not the disable attribution, not the
`SelfTest = 0` boot regression. **U1**, below, is the bugcheck, attributed from the image's own kernel
binary and from the memory of the paused VM: **upstream** — the kernel's PnP manager walking a device
stack that an upstream driver has left dangling — and **not** in the DSP driver, not in the bus driver,
not in the model. Nothing was tuned or fixed on this side; the model was not changed.

| # | finding | class | status |
|---|---|---|---|
| **U1** | the first boot bugchecks in the PnP manager's walk of a removed device's stack: `swenum.sys` deletes its bus device object on `IRP_MN_REMOVE_DEVICE` without detaching it, and the kernel's walk after the remove request reads it | **upstream**: kernel PnP (`ntos/io/pnpmgr/pnpstate.c`) with an upstream driver (`drivers/ksfilter/swenum/swenum.c`); what is new in this image's master is the trigger (the user-mode finish-install of the audio devices). Not the DSP driver, not `hdaudbus.sys`, not the model | **blocking, open.** 11 of 11 boots with an HDA codec; the image needs a fix (two places below) and this round a rerun |
| E22 | a first boot without the audio controller does not avoid U1 | environment | recorded: the first boot that sees the controller bugchecks the same way (r1b) |
| E23 | the round's data disk (the "pouch") | environment | not a factor: the same bugcheck with no disk at all (r0b, r0c) |

### U1 — the first-boot bugcheck, attributed

#### The lines

Every boot alike (`vm/measured-lines.txt`; r0a quoted, its timestamps as the guest printed them):

```
[   20.942457] (\base\services\umpnpmgr\rpcserver.c:6517) PNP_RegisterNotification(… 0000000A 'AudioSrv' …)
[   44.582805] (\drivers\ksfilter\ks\swenum.c:1518) KsCreateBusEnumObject Devices BusDeviceObject FFFF8180005D7AD0
The system has been stopped to keep it from damaging anything further.
Stop code: 0x0000001E
  Parameter 1: 0xFFFFFFFFC0000005
  Parameter 2: 0xFFFFF8007B4A3EB9
  Parameter 3: 0xFFFF8080004DC520
  Parameter 4: 0xFFFF8080004DBEE0
 #00 ntoskrnl.exe+0x17deb9
 #01 ntoskrnl.exe+0x17ddf1
 #02 ntoskrnl.exe+0x17a568
 #03 ntoskrnl.exe+0x17a074
 #04 ntoskrnl.exe+0x17e8e3
 #05 ntoskrnl.exe+0x17ac4d
 #06 ntoskrnl.exe+0xa124d
 #07 ntoskrnl.exe+0x30976d
 #08 ntoskrnl.exe+0x3120
 #09 ntoskrnl.exe+0x3125
RIP=fffff8007b4a3eb9 RSP=ffff8080004dc750 RBP=ffff8080004dcb50 EFL=00010246
RAX=c0c0c0c0c0c0c0c0 RBX=0000000000000000 RCX=0000000000000800
```

0.2 to 0.5 s of guest time after swenum's line (32 to 52 s into the boot); before the wizard, before any
console. The drivers under test are untouched by it: at every boot `BootDsp = 0: probe only`, the six BAR4
reads, 6 `ace_*` lines and 0 `ace_unexpected`; `dsppcm.sys` never loads.

#### Where the faulting instruction is — the image's own `ntoskrnl.exe` (`fault-site.txt`)

`ntoskrnl.exe + 0x17deb9` is `mov 0x20(%rax),%ecx` in the function at RVA `0x17de60–0x17deea`:

```
57dead:  mov  0x30(%rsp),%rax        ; Device, the object of the loop
57deb2:  mov  0x138(%rax),%rax       ; Device->DeviceObjectExtension
57deb9:  mov  0x20(%rax),%ecx        ; <- faults: the extension's ExtensionFlags
57debc:  and  $0xfffffffb,%ecx       ; ~DOE_REMOVE_PENDING (0x4)
57debf:  mov  %ecx,0x20(%rax)
57dec4:  mov  0x30(%rsp),%rax
57dec9:  mov  0x18(%rax),%rax        ; Device = Device->AttachedDevice
```

That is `IoGetDevObjExtension(Device)->ExtensionFlags &= ~DOE_REMOVE_PENDING` — `ntos/io/pnpmgr/pnpstate.c:1665`,
the **`Pending = FALSE`** statement of `PiSetStackRemovePending` (lines 1651–1670). It is not the `|=`
statement of line 1663 (the surprise-removed walk, at `+0x17dea2`): the line number the stopped round
handed over, 1665, is right; the statement it named is the other one. `RAX = c0c0c0c0c0c0c0c0`:
`Device->DeviceObjectExtension` was read out of freed pool (its fill after a free) — the loop is looking at a
device object that has been deleted.

`PiSetStackRemovePending(…, FALSE)` has one caller: `PiSendRemoval`, after the `IRP_MN_REMOVE_DEVICE` it sent
down the stack (line 1745). The frame's return address confirms it: `[RSP+0x48]`, read in the paused VM, is
`0xfffff8007b4a3df1` = base `0xfffff8007b326000` + `0x17ddf1`, the instruction after that call. The backtrace,
by the image's `.pdata` table and the call sites in its code:

| frame | RVA | function of the image `[begin, end)` | what it is |
|---|---|---|---|
| #00 | 0x17deb9 | `[0x17de60, 0x17deea)` | `PiSetStackRemovePending`: line 1665 |
| #01 | 0x17ddf1 | `[0x17dbf0, 0x17de5c)` | `PiSendRemoval`: `PiSetStackRemovePending(DeviceNode->PhysicalDeviceObject, FALSE)` (line 1745) |
| #02 | 0x17a568 | `[0x17a3f0, 0x17a614)` | `PiProcessRemoval`: `PiSendRemoval(DeviceNode, Surprise)` (line 1887). The same function holds the image's only other call of `PiSetStackRemovePending(…, TRUE)` (its `+0x17a57b`: line 1893), the call of `PiStackIsOpen` (`+0x17a5c1`: `PiCloseRemovedNode`, inlined) and a call to itself (`+0x17a498`: the children) |
| #03 | 0x17a074 | `[0x179f20, 0x17a15a)` | `PiDevNodeStateMachine`: its two calls of the function above (`+0x17a06f`, `+0x17a088`) are the two `DeviceNodeAwaitingQueued…` cases: `PiProcessRemoval(Node, FALSE, FALSE)` |
| #04 | 0x17e8e3 | `[0x17e560, 0x17e969)` | `PiRunDeviceAction`: the instruction after `PiDevNodeStateMachine(DeviceNode)`, in `case PiActionRemoveDevice` — the image has there `mov $0x30f,%edx; call PiSetDevNodeState; call PiDevNodeStateMachine` (lines 2140–2143) |
| #05 | 0x17ac4d | `[0x17aa80, 0x17ac52)` | the work routine that calls `PiRunDeviceAction`: `PiDeviceActionWorker` (the only caller-less function with that call) |
| #06–#09 | 0xa124d, 0x30976d, 0x3120, 0x3125 | `[0xa1030, 0xa1322)`, `[0x3095e0, 0x3097a0)`, `[0x30e4, 0x3125)` | the worker thread and the thread's start: not named |

#### What the thread was looking at — the paused VM (`vm/device-stack-readings.txt`)

The VM was stopped within a millisecond of the bugcheck's register line and its memory read through the
monitor (reads only). The read is checked against the image by the return address above. `[RSP+0x40]` is the
function's first argument, the PDO; `[RSP+0x30]` the object of the loop:

| | r0b | r0c | r0d (ICH9) |
|---|---|---|---|
| the PDO (`[RSP+0x40]`) | `ffff8180006865f0` | `ffff8180006835f0` | `ffff8180006ee370` |
| its first qword: Type 3, Size `0x160` | `0000000001600003` | the same | the same |
| its driver object's name | (not followed) | `\Driver\PnpManager` | `\Driver\PnpManager` |
| its `AttachedDevice` (`+0x18`) = the object of the loop (`[RSP+0x30]`) | `ffff818000686850` | `ffff818000683850` | `ffff8180006ee5d0` |
| that object's 0x150 bytes | all `c0c0c0c0c0c0c0c0` | the same | the same |
| swenum's own `BusDeviceObject` in the same boot's serial line | `FFFF818000686850` | `FFFF818000683850` | `FFFF8180006EE5D0` |
| the node's instance path (read at `+0xe0`) | — | — | `ROOT\SYSTEM\0000` |
| the node's service (read at `+0xf0`) | `swenum` | `swenum` | `swenum` |
| the node's State / PreviousState (`+0x50`, `+0x54`) | — | `0x30f` / `0x308` | `0x30f` / `0x308` |
| its state history (`+0x58`, 11 entries, `StateHistoryEntry` 11) | — | `301 302 303 304 305 306 307 308 30c 30d 308` | the same |
| its `Problem` (`+0xc0`) | — | `0` | `0` |

The offsets are the image's `DEVICE_NODE` and `DEVOBJ_EXTENSION` (`sdk/include/ndk/iotypes.h` of its tree;
its `PoIrpManager` member is a 32-byte `PO_IRP_MANAGER` by value, which puts `State` at `+0x50`);
every field and list of the node's first 0x200 bytes lies where the header puts it (the three lists of
`+0x128`, `+0x138`, `+0x148` point at themselves). The states are the header's: `0x308` `Started`, `0x30c`
`EnumeratePending`, `0x30d` `EnumerateCompletion`, `0x30f` `DeviceNodeAwaitingQueuedRemoval` (iotypes.h:587).

#### Which device, whose code, in what order

1. The device is **`ROOT\SYSTEM\0000`**, the root-enumerated software bus whose service is `swenum` — the
   "Plug & Play Software Bus Enumerator". Its PDO is the PnP manager's (`\Driver\PnpManager`); its FDO is
   `swenum.sys`'s: `SwAddDevice` creates it and `KsCreateBusEnumObject(L"SW", FDO, PDO, NULL,
   &KSMEDIUMSETID_Standard, L"Devices")` attaches it over the PDO and prints the line of the boot.
2. The kernel starts the node (its history: `Uninitialized → … → Started`); swenum invalidates its relations
   at the end of `KsCreateBusEnumObject` (`EnumeratePending → EnumerateCompletion → Started`).
3. A **removal is queued**: `PiRunDeviceAction`'s `case PiActionRemoveDevice` sets `AwaitingQueuedRemoval`
   and runs `PiDevNodeStateMachine`, whose case for that state calls `PiProcessRemoval(Node, FALSE, FALSE)`;
   the node has no child and is not waiting for closes, so `PiSendRemoval(Node, FALSE)` sends
   `IRP_MN_REMOVE_DEVICE` down the stack — to swenum's FDO first.
4. **swenum's answer** (`drivers/ksfilter/swenum/swenum.c:158–161`, `SwDispatchPnp`):
   `if (MinorFunction == IRP_MN_REMOVE_DEVICE) { /* delete the device */ IoDeleteDevice(DeviceObject); }`
   — it deletes its own bus device object and **the file has no `IoDetachDevice` at all**; the PDO's
   `AttachedDevice` keeps the pointer. `IoDeleteDevice` (`ntos/io/iomgr/devobj.c`) frees the object at once
   (nothing references it, nothing is attached above it) and does not unlink it from the stack either.
5. Back in `PiSendRemoval`: `PiSetStackRemovePending(PDO, FALSE)` walks `PDO → PDO->AttachedDevice` and reads
   the freed object: `0x1E`, `0xC0000005`, `RAX = c0c0…`.

**The removal's source.** `PiActionRemoveDevice` is queued by three things in the kernel: `PlugPlayControlQueryAndRemoveDevice`
(`ntos/io/pnpmgr/pnpevent.c:620`: what user mode's `CM_Query_And_Remove_SubTree` is; query-remove first, then the
remove action), the uninstall of an already-removed root device (`pnpcontrol.c:473`: needs state `Removed`),
and the debugger's driver reload. The node was `Started`: the first. In the tree's user-mode code two callers
fit the first boot of an audio device — setupapi's `RestartDevice` (`dll/win32/setupapi/devinst.c:6762–6800`: on
a `DN_STARTED` node with `RestartStarted`, `CM_Query_And_Remove_SubTree_ExW`, then
`CM_Setup_DevNode_Ex(…, CM_SETUP_DEVNODE_READY)`) and NEWDEV's `UpdateDriverForPlugAndPlayDevicesW`
(`dll/win32/newdev/newdev.c:379–385`). **Which of them ran was not read**: the kernel side is established by
the backtrace and the state, the user-mode caller is inferred from the code paths that remain.

#### What it depends on — measured

| configuration | VM | boots | result |
|---|---|---|---|
| the model (`intel-hda-ace` + `hda-duplex`), the data disk attached | r0a | 1 | bugcheck at 44.8 s |
| the model, **no data disk** | r0b, r0c | 3 + 3 | bugcheck on all 6 |
| **QEMU's ICH9 controller**, the same codec: no model, no DSP child (`ADSP child not created on PCI 8086:293e … not an ACE-era Intel controller`, `audio path LegacyHdaOnly … DSP absent`) | r0d | 3 | bugcheck on all 3, the same node read |
| **no audio controller at all** | r0e | 1 | **no bugcheck**: `First-boot setup lists 11 components`, `Storage expansion not offered`, no `KsCreateBusEnumObject` line, clean S5 |
| r0e's overlay booted again **with** the model (the workaround of E22) | r1b | 1 | bugcheck at 37.4 s |

So it is **not the data disk, not the model, not the DSP driver** (r0d has none of them), and not a line of
the codec's own enumeration: what it needs is an HDA codec being **installed into a system that has not
seen it** — the audio devices' first installation, and the finish-install in user mode that follows it.

#### What is old and what is new in this image's master (git)

- The kernel's walk is not new: `PiSetStackRemovePending` came with `7da418e9c39` ("Remove a surprise-removed
  device after its last close", 2026-11-11), which `git merge-base --is-ancestor` finds already in p3c3b's
  master `d8f3a5bc81e` — the image whose first boots were clean.
- swenum's remove path is not new either (its file has one commit: the Git conversion).
- **New in this image's master, absent from p3c3b's:** `82783d979f9` ("Finish installing audio devices in
  user mode": the configurations of MEDIA-class INFs get `CONFIGFLAG_FINISH_INSTALL`, AudioSrv starts
  automatically), `f833d2a22fb` ("Restart a started device when UpdateDriverForPlugAndPlayDevices reinstalls
  its driver") and `4ac7807a0e4` ("Leave a disabled device down when its stack would be built"). The visible
  sign of the first is `PNP_RegisterNotification(… 'AudioSrv' …)` at 20.9 to 31.4 s of every boot of this image
  (r0e's too); the removal of the software-bus node follows swenum's line by 0.2–0.5 s.

**So U1 is an old driver defect that the new first-boot install now meets.** It is in a device-removal path,
as p4c4a's "disable does not complete" was, but **not in our audio child**: the node is the PnP software bus,
the code is swenum's and the kernel's.

#### The two places a fix could go (for the next conversation; nothing was changed here)

1. **The root cause, in `swenum.sys`** — `SwDispatchPnp`, `drivers/ksfilter/swenum/swenum.c:158–161`: detach
   before deleting, `IoDetachDevice(PnpDeviceObject)` then `IoDeleteDevice(DeviceObject)`. `PnpDeviceObject`
   is the object the FDO was attached over (what `IoAttachDeviceToDeviceStack` returned), and
   `IoDetachDevice(lower)` unlinks the device above it: the standard remove sequence of a function driver.
2. **Or a defensive kernel change**: `IoDeleteDevice` (`ntos/io/iomgr/devobj.c`) unlinking a device object
   from the device it is attached to, or `PiSetStackRemovePending`'s walk stopping at a deleted object. Either
   protects every driver that forgets; neither is a substitute for the first.

Either needs a rebuilt image. This round's scripts for the runs are written and never ran: `boot1.sh` (first
boot, runs 1 and 2), `boot2.sh`–`boot4.sh` (the leftovers), in `vm/tools-used/`; `boot1b.sh` differs from
`boot1.sh` in its run name and first wait only.

#### What was not established

- The user-mode caller of the removal (two candidates above).
- Why the finish-install removes a device the kernel already started from the driver database, and what it
  does after: the two commits' messages describe the mechanism, not this device.
- r1b's bugcheck: the same instruction and the same sequence; its stack was not read.
- r0a's stack was not read (that VM was gone before the tools existed; its swenum line names `FFFF8180005D7AD0`,
  an object no read has seen).
- The crash dumps the guest wrote (one per bugcheck, about 200 MB, in the overlays) were not opened.
- `#06` of the backtrace (the worker thread's function) is not named.

### E22 — the workaround that does not hold

The clean boot of r0e suggested one: do the first boot without the audio controller and attach the model from
the second boot on. r1b tried it on r0e's own overlay: the first boot that sees the controller bugchecks the
same way (`vm/r1b-…/serial.txt`). There is no configuration of this VM in which the image reaches its desktop
with an audio device: the runs of this image cannot be taken in the VM until the image is fixed.

### E23 — the data disk

The round's data disk (a FAT16 image carrying `dsploop_apitest.exe`, attached as a second drive) was the
stopped round's suspect for the crash of r0a. It is not a factor: the same bugcheck with no disk attached
(r0b, r0c). The vvfat variant of the brief was therefore not run: with no disk the boot is not clean, so the
variant would not have told anything more.

### What the round did not run

TESTING.md's run 1 (the endpoint and the stream), run 2 (`SelfTest = 2` on this image), run 3 (the three
leftovers of C4a) — blocked by U1. And, as before: `UseInterrupts = 1` with the self-test, the refusal rows,
the fault matrix, the cycle run, silicon; Meteor Lake on silicon; the 32-bit wrap (the plan's INFO_NEEDED).
