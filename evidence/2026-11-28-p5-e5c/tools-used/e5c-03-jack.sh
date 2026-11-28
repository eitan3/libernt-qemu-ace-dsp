#!/bin/bash
# READ-ONLY (no edits, no builds): git grep / git show at 39e4bc940a5 only.
R=<home>/Projects/LiberNT
G="git --no-optional-locks -C $R"
T=39e4bc940a5
s() { sed "s/^$T://" | cut -c1-${1:-200}; }
echo "== jack description / form factor in mmdevapi"
$G grep -n -E 'KSPROPERTY_JACK_DESCRIPTION|KSJACK_DESCRIPTION|EndpointFormFactor|KSPROPERTY_PIN_PHYSICALCONNECTION|KSPIN_PHYSICALCONNECTION' $T -- dll/win32/mmdevapi | s 190
echo "== jack description / form factor in drivers/wdm/audio (counts per file)"
$G grep -c -E 'KSPROPERTY_JACK_DESCRIPTION|KSJACK_DESCRIPTION|EndpointFormFactor' $T -- drivers/wdm/audio | s
echo "== config default / default device in drivers/wdm/audio (counts per file)"
$G grep -c -i -E 'config(uration)? ?default|DefaultDevice|PinConfig|CfgDefault|ConfigDefault' $T -- drivers/wdm/audio | s
echo "== wdmaud interface.h IOCTL list"
$G grep -n -E '^#define IOCTL_' $T -- drivers/wdm/audio/legacy/wdmaud/interface.h | s
echo "== wdmaud interface.h 430-520"
$G show $T:drivers/wdm/audio/legacy/wdmaud/interface.h | sed -n '430,520p'
