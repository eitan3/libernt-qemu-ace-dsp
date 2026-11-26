#!/bin/bash
# stack-readings.sh -- vm/device-stack-readings.txt of the p4c4b evidence: the preface that says what the
# paused reads show, then the outputs of bugread.py as the three VMs produced them (raw).
#   stack-readings.sh <evidence-dir>/vm
set -u
V="${1:?usage: stack-readings.sh <evidence-dir>/vm}"
{
cat <<'EOF'
# The device stack at the bugcheck, read from the paused VM (r0b, r0c, r0d: each VM's first and second read)
#
# Tools: bugpause.py (stops the VM within a millisecond of the bugcheck's register line) and bugread.py
# (reads the faulting thread's memory), both in tools-used/.  Reads only: HMP `x` of virtual memory.
# Below the preface: the outputs of bugread.py as they were produced, unedited.
#
# What a read shows.  Offsets are the image's own (sdk/include/ndk/iotypes.h of the image's tree; a
# PNP_DEVNODE_STATE is a 4-byte enum whose values are the header's: 0x301 Uninitialized, 0x302 Initialized,
# 0x303 DriversAdded, 0x304 ResourcesAssigned, 0x305 StartPending, 0x306 StartCompletion, 0x307 StartPostWork,
# 0x308 Started, 0x30c EnumeratePending, 0x30d EnumerateCompletion, 0x30f AwaitingQueuedRemoval, ...).
#
#  [RSP+0x48]  the return address into the image after the call of the faulting function:
#              r0b, r0c, r0d: fffff8007b4a3df1 = base 0xfffff8007b326000 + 0x17ddf1 -- the instruction after
#              `call PiSetStackRemovePending` at the FALSE call site (pnpstate.c:1745): the bytes read
#              are the image's own (fault-site.txt)
#  [RSP+0x40]  the PDO, the function's first argument: first qword 0000000001600003 (Type 3, a device
#              object; Size 0x160), DriverObject (+0x08) whose DriverName is '\Driver\PnpManager' -- a
#              root-enumerated device; NextDevice (+0x10) the next root PDO; DeviceObjectExtension at
#              +0x138, which follows the device object in the same allocation
#  [RSP+0x30]  the device object the loop is looking at = the PDO's AttachedDevice (+0x18): 0x150 bytes
#              all c0c0c0c0c0c0c0c0 (freed pool).  It is the BusDeviceObject that swenum's own serial line
#              names in the same boot: r0b FFFF818000686850, r0c FFFF818000683850, r0d FFFF8180006EE5D0
#              (measured-lines.txt)
#  PDO->DeviceObjectExtension: +0x00 Type 0x0d, +0x08 the PDO, +0x20 ExtensionFlags 0x800, +0x28 the node
#  the node (DEVICE_NODE): +0x10 Parent (0xffff81803ed61100, the root node, the same address in r0c and
#              r0d), +0x20 Level 1, +0x50 State, +0x54 PreviousState, +0x58 StateHistory[20], +0xa8
#              StateHistoryEntry, +0xb8 Flags, +0xc0 Problem, +0xc8 PhysicalDeviceObject, +0xe0 InstancePath
#              (UNICODE_STRING), +0xf0 ServiceName (UNICODE_STRING), +0x128/+0x138/+0x148 three empty
#              (self-pointing) lists
#
#   VM   [RSP+0x30]        PDO                node               State / PreviousState / history (11 entries)         InstancePath               ServiceName
#   r0b  ffff818000686850   ffff8180006865f0  ffff81803f752280  (the node seen through a stack pointer only:        (not read)                  'swenum' (+0xf0)
#                                                             parent ffff81803ed61100; its state not dumped)
#   r0c  ffff818000683850   ffff8180006835f0  ffff81803f741280  0x30f / 0x308 / 301 302 303 304 305 306 307 308 30c 30d 308  Length 32 (string not read)  'swenum'
#   r0d  ffff8180006ee5d0   ffff8180006ee370  ffff81803f745880  0x30f / 0x308 / 301 302 303 304 305 306 307 308 30c 30d 308  'ROOT\SYSTEM\0000'           'swenum'
#
#  In r0c and r0d: StateHistoryEntry 0xb (11 entries), Flags 0x30, Problem 0.
#
#  So: the node is ROOT\SYSTEM\0000, the root-enumerated software bus whose service is swenum
#  (hivesys.inf: the swenum service, boot-start); it was Started, enumerated (swenum's own
#  IoInvalidateDeviceRelations), Started again, and is AwaitingQueuedRemoval; its PDO (the PnP
#  manager's) has swenum's bus device object still attached above it, and that object is freed.
#
#  The node is NOT the DSP child (INTCDSP\PCM&..., never started at these boots: BootDsp = 0, dsppcm.sys
#  not loaded) and NOT the codec (HDAUDIO\FUNC_01&...): the ICH9 VM r0d, which has no ACE model and no DSP
#  child, shows the same node and the same picture.
EOF
for r in r0b-firstboot-nodisk r0c-firstboot-nodisk-read r0d-firstboot-ich9; do
    for f in bugread.txt bugread-2.txt; do
        [ -f "$V/$r/$f" ] || continue
        echo
        echo "################################################################################"
        echo "## $r/$f"
        echo "################################################################################"
        cat "$V/$r/$f"
    done
done
} > "$V/device-stack-readings.txt" 2>&1
echo "wrote $V/device-stack-readings.txt ($(wc -l < "$V/device-stack-readings.txt") lines)"
