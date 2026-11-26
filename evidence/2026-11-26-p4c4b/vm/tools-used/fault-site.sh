#!/bin/bash
# fault-site.sh -- the binary evidence of the first-boot bugcheck of the p4c4b round, from the
# image's own ntoskrnl.exe: the faulting function, the frame above it that queued the removal,
# and the functions of the bugcheck's backtrace by the image's .pdata table.  Reads only.
#   fault-site.sh <ntoskrnl.exe> <out-file>
set -u
NTK="${1:?usage: fault-site.sh <ntoskrnl.exe> <out-file>}"
OUT="${2:?usage: fault-site.sh <ntoskrnl.exe> <out-file>}"
T=/tmp/qad-ev/p4c4b/tools
dis() { objdump -d --no-show-raw-insn --start-address="$1" --stop-address="$2" "$NTK" 2>/dev/null | tail -n +7 | cut -c1-110; }
{
    echo "# the binary evidence of the first-boot bugcheck (p4c4b), $(date -u +%FT%TZ)"
    echo "# Windows/system32/ntoskrnl.exe of LiberNT.iso (bsdtar -x -f LiberNT.iso Windows/system32/ntoskrnl.exe):"
    echo "#   $(stat -c %s "$NTK") bytes, sha256 $(sha256sum "$NTK" | cut -d' ' -f1)"
    echo "# objdump VMA = 0x400000 + RVA: the bugcheck text's 'ntoskrnl.exe + 0x<rva>' is the RVA. No symbols and no"
    echo "# DWARF in the image (nm: 0 lines; sections .debug_*: none): names below are from the tree's source"
    echo "# (ntos/io/pnpmgr/pnpstate.c at the image's tree) matched to the code, each match stated."
    echo
    echo "## the faulting function: RVA 0x17de60..0x17deea (PiSetStackRemovePending, pnpstate.c:1649-1670; its frame is 0x48 bytes,"
    echo "## its first argument is spilled to +0x40 and the device object of the loop to +0x30; DeviceObjectExtension is"
    echo "## at +0x138 of a device object, ExtensionFlags at +0x20 of the extension, AttachedDevice at +0x18)"
    echo "##   ntoskrnl.exe + 0x17deb9 = 'mov 0x20(%rax),%ecx' of the ELSE branch: ExtensionFlags &= ~DOE_REMOVE_PENDING, the"
    echo "##   Pending = FALSE walk (pnpstate.c:1665) -- not the '|=' of the surprise-removed walk (line 1663, +0x17dea2)"
    dis 0x57de60 0x57deea
    echo
    echo "## the frame that queued the removal: RVA 0x17e8ca..0x17e8e3 (PiRunDeviceAction, case PiActionRemoveDevice,"
    echo "## pnpstate.c:2127-2143: PiSetDevNodeState(DeviceNode, DeviceNodeAwaitingQueuedRemoval /* 0x30f */) then"
    echo "## PiDevNodeStateMachine(DeviceNode)); the backtrace's frame #04 returns to +0x17e8e3"
    dis 0x57e8ca 0x57e8e5
    echo
    echo "## the functions of the backtrace, by the image's .pdata (RUNTIME_FUNCTION) table (tools/pefuncs.py)"
    for a in 0x17deb9 0x17ddf1 0x17a568 0x17a074 0x17e8e3 0x17ac4d 0xa124d 0x30976d 0x3120; do
        python3 "$T/pefuncs.py" "$NTK" "$a" | head -1
    done
    echo
    echo "## the call sites of the functions of the walk (call rel32, by tools/pefuncs.py)"
    for a in 0x17de60 0x17def0 0x17dbf0; do
        python3 "$T/pefuncs.py" "$NTK" "$a" | head -2 | tail -1 | sed "s/^/   /"
    done
} > "$OUT" 2>&1
echo "wrote $OUT ($(wc -l < "$OUT") lines)"
