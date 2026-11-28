#!/bin/bash
# READ-ONLY: locate the E5c code sites at 39e4bc940a5.
R=<home>/Projects/LiberNT
G="git --no-optional-locks -C $R"
T=39e4bc940a5
echo "== working tree == 39e4 for mmdevapi? (no output = identical)"
$G diff --stat $T -- dll/win32/mmdevapi
echo "== files in dll/win32/mmdevapi"
$G ls-tree --name-only $T dll/win32/mmdevapi/ | sed "s/^$T://"
echo "== get_prop_value / set_driver_prop_value / MMDevice_Create"
$G grep -n -E 'get_prop_value|set_driver_prop_value|MMDevice_Create\b' $T -- dll/win32/mmdevapi | sed "s/^$T://" | cut -c1-220
echo "== IOCTL_GETWAVECONNECTOR"
$G grep -n 'IOCTL_GETWAVECONNECTOR' $T -- . | sed "s/^$T://" | cut -c1-220
echo "== PKEY_AudioEndpoint_ in mmdevapi"
$G grep -n -E 'PKEY_AudioEndpoint_(FormFactor|PhysicalSpeakers|GUID|Supports_EventDrivenMode|JackSubType|Enumerator)' $T -- dll/win32/mmdevapi | sed "s/^$T://" | cut -c1-200 | head -60
echo "== devenum test in cmake"
$G grep -n -E 'mmdevapi\.devenum|devenum' $T -- '*.cmake' 'CMakeLists.txt' '*CMakeLists.txt' | sed "s/^$T://" | cut -c1-200 | head -30
