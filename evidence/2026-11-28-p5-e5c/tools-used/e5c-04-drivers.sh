#!/bin/bash
# READ-ONLY (no edits, no builds): git grep with context at 39e4bc940a5.
R=<home>/Projects/LiberNT
G="git --no-optional-locks -C $R"
T=39e4bc940a5
s() { sed "s/^$T://" | cut -c1-${1:-210}; }
echo "== hdaudio: jack description handler"
$G grep -n -E 'KSPROPERTY_JACK_DESCRIPTION|KSJACK_DESCRIPTION|ConnectionType|GeoLocation|GenLocation|PortConnection|ChannelMapping|IsConnected' $T -- drivers/wdm/audio/drivers/hdaudio | s 210
echo "== hdaudio: config default decode"
$G grep -n -i -E 'config(uration)? ?default|DefaultDevice|PinConfig|CfgDefault|ConfigDefault|DefaultDevice|DeviceType|PortConnectivity|Color' $T -- drivers/wdm/audio/drivers/hdaudio/common.cpp drivers/wdm/audio/drivers/hdaudio/common.h drivers/wdm/audio/drivers/hdaudio/private.h drivers/wdm/audio/drivers/hdaudio/hda_verbs.h | s 210
echo "== dsppcm: jack description handler"
$G grep -n -E 'KSPROPERTY_JACK_DESCRIPTION|KSJACK_DESCRIPTION|ConnectionType|IsConnected|ChannelMapping' $T -- drivers/wdm/audio/drivers/dsppcm | s 210
echo "== EndpointFormFactor in the SDK"
$G grep -n -E 'EndpointFormFactor|RemoteNetworkDevice|UnknownDigitalPassthrough|UnknownFormFactor' $T -- sdk/include | s 210
echo "== PKEY_AudioEndpoint_ definitions"
$G grep -n -E 'DEFINE_PROPERTYKEY\(PKEY_AudioEndpoint_(FormFactor|PhysicalSpeakers|GUID|Supports_EventDrivenMode|JackSubType)' $T -- sdk/include | s 230
echo "== b3f8fa53"
$G grep -n -i 'b3f8fa53' $T -- sdk/include dll/win32/mmdevapi base shell | s 230
