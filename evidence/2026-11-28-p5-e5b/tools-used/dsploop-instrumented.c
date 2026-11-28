/*
 * PROJECT:     LiberNT API tests
 * LICENSE:     GPL-3.0-or-later (https://spdx.org/licenses/GPL-3.0-or-later)
 * PURPOSE:     The loop through the DSP's endpoint in user mode: a 1 kHz tone rendered into the render endpoint of the DSP's PCM and captured from its capture endpoint in parallel through the audio stack, 48000 frames at 48 kHz stereo in 16 valid bits, then in 24 and 32 when the shared-mode engine takes them, compared from the first matching frame (plan §8 C4)
 * COPYRIGHT:   Copyright 2026 LiberNT contributors
 */

#include <apitest.h>
#include <apitest_expected.h>
#include <apitest_dspidentity.h>

#define COBJMACROS
#include <windows.h>
#include <objbase.h>
/* before the headers that name the GUIDs: they define them here, once */
#include <initguid.h>
#include <mmdeviceapi.h>
#include <audioclient.h>
#include <endpointvolume.h>
#include <mmreg.h>
#include <ks.h>
#include <ksmedia.h>
#include <devicetopology.h>
#include <conio.h>
#include <math.h>
#include <stdlib.h>
#include "compare.h"
#include "walk.h"

/* The KS identifiers the node reads use, as the mmdevapi apitests have theirs (devicetopology.c): the headers declare
 * these GUIDs by name but no library the test links defines them, so each is a constant of its own here */
static const GUID AudioPropertySet = { STATIC_KSPROPSETID_Audio };
static const GUID VolumeNodeType = { STATIC_KSNODETYPE_VOLUME };
static const GUID MuteNodeType = { STATIC_KSNODETYPE_MUTE };

#define DSPLOOP_RATE             48000
#define DSPLOOP_CHANNELS         2
/* one second of tone; the capture holds a second of latency before it as well */
#define DSPLOOP_FRAMES           48000
#define DSPLOOP_MAX_OFFSET       48000
#define DSPLOOP_CAPTURE_FRAMES   (DSPLOOP_FRAMES + DSPLOOP_MAX_OFFSET)
/* the capture's buffer and the render's, in 100 ns units: 200 ms and 100 ms, the loop's own latency kept small and known */
#define DSPLOOP_CAPTURE_BUFFER   2000000
#define DSPLOOP_RENDER_BUFFER    1000000
/* the wall-clock budget of a run, in milliseconds: the two seconds of audio with room for a slow guest */
#define DSPLOOP_RUN_MS           15000
/* how far upstream of the endpoint's connector the volume and mute nodes are looked for */
#define DSPLOOP_TOPOLOGY_DEPTH   8

/* A run's outcome */
#define DSPLOOP_OK               0
#define DSPLOOP_FAILED           1
#define DSPLOOP_SKIPPED          2

/*
 * Whether the endpoint is one of the DSP's PCM: the filter its first
 * connector leads to (the topology's, the PCM's subdevice) is named by the
 * PCM's identity in the device tree, not by a display name. The filter's id
 * is mmdevapi's: "{2}." and the KS interface path.
 */
static
BOOL
EndpointOfDspPcm(
    IMMDevice *Device)
{
    IDeviceTopology *Topology = NULL;
    IConnector *Connector = NULL;
    LPWSTR FilterId = NULL;
    BOOL Found = FALSE;
    HRESULT hr;

    hr = IMMDevice_Activate(Device, &IID_IDeviceTopology, CLSCTX_INPROC_SERVER, NULL, (void **)&Topology);
    if (FAILED(hr))
        return FALSE;
    hr = IDeviceTopology_GetConnector(Topology, 0, &Connector);
    if (SUCCEEDED(hr))
    {
        hr = IConnector_GetDeviceIdConnectedTo(Connector, &FilterId);
        IConnector_Release(Connector);
    }
    IDeviceTopology_Release(Topology);
    if (SUCCEEDED(hr) && FilterId)
    {
        Found = DspPcmIdentity(FilterId);
        trace("dsploop: endpoint %ls the DSP's PCM: filter %ls\n", Found ? L"is of" : L"is not of", FilterId);
        CoTaskMemFree(FilterId);
    }
    return Found;
}

#define DSPLOOP_VISITED_PARTS 32

/* The parts a walk entered, by their global ids */
typedef struct _VISITED_PARTS
{
    LPWSTR Ids[DSPLOOP_VISITED_PARTS];
    UINT Count;
} VISITED_PARTS;

static
void
VisitedFree(
    VISITED_PARTS *Visited)
{
    UINT I;

    for (I = 0; I < Visited->Count; ++I)
        CoTaskMemFree(Visited->Ids[I]);
    Visited->Count = 0;
}

/* Whether a part was entered before; recorded when it was not */
static
BOOL
VisitedPart(
    VISITED_PARTS *Visited,
    IPart *Part)
{
    LPWSTR Id = NULL;
    UINT I;

    if (FAILED(IPart_GetGlobalId(Part, &Id)) || !Id)
        return FALSE;
    for (I = 0; I < Visited->Count; ++I)
    {
        if (!wcscmp(Visited->Ids[I], Id))
        {
            CoTaskMemFree(Id);
            return TRUE;
        }
    }
    if (Visited->Count < DSPLOOP_VISITED_PARTS)
        Visited->Ids[Visited->Count++] = Id;
    else
        CoTaskMemFree(Id);
    return FALSE;
}

/*
 * The level the driver answers, from the KS volume node of the endpoint's topology (N14-17, ruling (a)):
 * IAudioEndpointVolume::GetMasterVolumeLevel answers the scalar last set, as user mode maps it to
 * decibels (audiovolume.c endpoint_volume_db_from_scalar: the tray's 92 % is -7.68 dB), while the
 * node's step is the driver's (INTELDSP_VOLUME_STEP, 1 dB) and the stream runs at the step nearest
 * the request (-8.00 dB). The node's KSPROPERTY_AUDIO_VOLUMELEVEL answers that level, in 1/65536
 * decibels, as the tray reads it: through the topology's control interface, the node part's
 * IKsControl. The node is found by its subtype along the signal path from the endpoint's connector:
 * through the part a connector is connected to (the endpoint's connector to the filter's pin, a
 * bridge pin's to the next filter's) and the parts the signal reaches from a part, incoming to a
 * render endpoint's connector and outgoing from a capture endpoint's (walk.h DsploopWalkIncoming,
 * N15-20: the endpoint's connector is bridged to the topology filter's pin of the endpoint itself, the
 * jack's; the render topology's volume node is upstream of that pin: the wave's pin, the DAC node, the
 * bridge pin, the topology's wave pin, the node, the endpoint's pin; a capture endpoint's node is
 * downstream of its microphone pin). Each part is entered once.
 * A part without a control interface answers E_NOINTERFACE, and the caller falls back to the
 * endpoint's scalar with a line.
 */
static
HRESULT
NodePartOfSubtype(
    IPart *Part,
    REFGUID Subtype,
    BOOL Incoming,
    UINT Depth,
    VISITED_PARTS *Visited,
    _Out_ IPart **Found)
{
    IConnector *Connector = NULL, *Peer = NULL;
    IPartsList *List = NULL;
    IPart *Next;
    PartType Type;
    GUID Id;
    UINT Count = 0, I;
    HRESULT hr;

    LPWSTR Gid = NULL;
    *Found = NULL;
    IPart_GetGlobalId(Part, &Gid);
    trace("dbgwalk: depth %u %s part %ls\n", Depth, Incoming ? "incoming" : "outgoing", Gid ? Gid : L"(null)");
    CoTaskMemFree(Gid);
    if (Depth > DSPLOOP_TOPOLOGY_DEPTH || VisitedPart(Visited, Part))
        return HRESULT_FROM_WIN32(ERROR_NOT_FOUND);
    hr = IPart_GetPartType(Part, &Type);
    if (SUCCEEDED(hr) && Type == Subunit && SUCCEEDED(IPart_GetSubType(Part, &Id)) && IsEqualGUID(&Id, Subtype))
    {
        IPart_AddRef(Part);
        *Found = Part;
        return S_OK;
    }
    /* a connector leads on to the part it is connected to */
    if (SUCCEEDED(IPart_QueryInterface(Part, &IID_IConnector, (void **)&Connector)))
    {
        if (SUCCEEDED(IConnector_GetConnectedTo(Connector, &Peer)) &&
            SUCCEEDED(IConnector_QueryInterface(Peer, &IID_IPart, (void **)&Next)))
        {
            hr = NodePartOfSubtype(Next, Subtype, Incoming, Depth + 1, Visited, Found);
            IPart_Release(Next);
        }
        if (Peer)
            IConnector_Release(Peer);
        IConnector_Release(Connector);
        if (*Found)
            return S_OK;
    }
    /* and a part to the parts the signal reaches from it */
    hr = Incoming ? IPart_EnumPartsIncoming(Part, &List) : IPart_EnumPartsOutgoing(Part, &List);
    trace("dbgwalk: depth %u EnumParts%s 0x%08lx\n", Depth, Incoming ? "Incoming" : "Outgoing", hr);
    if (FAILED(hr))
        return HRESULT_FROM_WIN32(ERROR_NOT_FOUND);
    if (SUCCEEDED(IPartsList_GetCount(List, &Count)))
    {
        for (I = 0; I < Count && *Found == NULL; I++)
        {
            if (SUCCEEDED(IPartsList_GetPart(List, I, &Next)))
            {
                hr = NodePartOfSubtype(Next, Subtype, Incoming, Depth + 1, Visited, Found);
                IPart_Release(Next);
            }
        }
    }
    IPartsList_Release(List);
    return *Found != NULL ? S_OK : HRESULT_FROM_WIN32(ERROR_NOT_FOUND);
}

/* A KS property of the node of a subtype, read through the node part's control interface: the node is the part's */
static
HRESULT
ReadNodeProperty(
    IMMDevice *Device,
    REFGUID Subtype,
    ULONG PropertyId,
    _Out_writes_bytes_(Bytes) PVOID Value,
    ULONG Bytes)
{
    IDeviceTopology *Topology = NULL;
    IConnector *Connector = NULL;
    IPart *Part = NULL, *Node = NULL;
    IKsControl *Control = NULL;
    VISITED_PARTS Visited;
    KSPROPERTY Request;
    DataFlow Flow = In;
    ULONG Returned = 0;
    HRESULT hr;

    ZeroMemory(&Visited, sizeof(Visited));
    hr = IMMDevice_Activate(Device, &IID_IDeviceTopology, CLSCTX_INPROC_SERVER, NULL, (void **)&Topology);
    if (SUCCEEDED(hr))
    {
        hr = IDeviceTopology_GetConnector(Topology, 0, &Connector);
        if (SUCCEEDED(hr))
            hr = IConnector_GetDataFlow(Connector, &Flow);
        if (SUCCEEDED(hr))
            hr = IConnector_QueryInterface(Connector, &IID_IPart, (void **)&Part);
        if (Connector)
            IConnector_Release(Connector);
        IDeviceTopology_Release(Topology);
    }
    if (SUCCEEDED(hr))
    {
        /* the parts upstream of a render endpoint's connector (its data flow is in), downstream of a capture endpoint's */
        hr = NodePartOfSubtype(Part, Subtype, DsploopWalkIncoming(Flow == Out ? DsploopFlowOut : DsploopFlowIn), 0, &Visited, &Node);
        IPart_Release(Part);
    }
    VisitedFree(&Visited);
    if (SUCCEEDED(hr))
    {
        hr = IPart_Activate(Node, CLSCTX_INPROC_SERVER, &IID_IKsControl, (void **)&Control);
        IPart_Release(Node);
    }
    if (SUCCEEDED(hr))
    {
        ZeroMemory(&Request, sizeof(Request));
        Request.Set = AudioPropertySet;
        Request.Id = PropertyId;
        Request.Flags = KSPROPERTY_TYPE_GET;
        hr = Control->lpVtbl->KsProperty(Control, &Request, sizeof(Request), Value, Bytes, &Returned);
        if (hr != S_OK || Returned != Bytes)
            hr = FAILED(hr) ? hr : E_UNEXPECTED;
        Control->lpVtbl->Release(Control);
    }
    return hr;
}

/* The active endpoint of a flow that is one of the DSP's PCM */
static
HRESULT
FindEndpoint(
    IMMDeviceEnumerator *Enumerator,
    EDataFlow Flow,
    _Out_ IMMDevice **Device)
{
    IMMDeviceCollection *Collection = NULL;
    IMMDevice *Candidate;
    UINT Count = 0, I;
    HRESULT hr;

    *Device = NULL;
    hr = IMMDeviceEnumerator_EnumAudioEndpoints(Enumerator, Flow, DEVICE_STATE_ACTIVE, &Collection);
    if (FAILED(hr))
        return hr;
    if (SUCCEEDED(IMMDeviceCollection_GetCount(Collection, &Count)))
    {
        for (I = 0; I < Count && *Device == NULL; I++)
        {
            if (SUCCEEDED(IMMDeviceCollection_Item(Collection, I, &Candidate)))
            {
                if (EndpointOfDspPcm(Candidate))
                    *Device = Candidate;
                else
                    IMMDevice_Release(Candidate);
            }
        }
    }
    IMMDeviceCollection_Release(Collection);
    return *Device ? S_OK : HRESULT_FROM_WIN32(ERROR_NOT_FOUND);
}

/* The tone's format at a count of valid bits: plain PCM at 16, extensible at 24 valid in a 32-bit word and at 32, as the endpoint's rule has them */
static
VOID
ToneFormat(
    WAVEFORMATEXTENSIBLE *Format,
    WORD ValidBits)
{
    WORD Container = ValidBits == 24 ? 32 : ValidBits;

    ZeroMemory(Format, sizeof(*Format));
    Format->Format.nChannels = DSPLOOP_CHANNELS;
    Format->Format.nSamplesPerSec = DSPLOOP_RATE;
    Format->Format.wBitsPerSample = Container;
    Format->Format.nBlockAlign = DSPLOOP_CHANNELS * Container / 8;
    Format->Format.nAvgBytesPerSec = DSPLOOP_RATE * Format->Format.nBlockAlign;
    if (ValidBits == 16)
    {
        Format->Format.wFormatTag = WAVE_FORMAT_PCM;
        return;
    }
    Format->Format.wFormatTag = WAVE_FORMAT_EXTENSIBLE;
    Format->Format.cbSize = sizeof(*Format) - sizeof(Format->Format);
    Format->Samples.wValidBitsPerSample = ValidBits;
    Format->dwChannelMask = SPEAKER_FRONT_LEFT | SPEAKER_FRONT_RIGHT;
    Format->SubFormat = KSDATAFORMAT_SUBTYPE_PCM;
}

/* One tone sample into the stream: a little-endian word, the valid bits at the top of a 32-bit word when there are 24 of them */
static
VOID
StoreSample(
    BYTE *At,
    WORD ValidBits,
    int32_t Sample)
{
    uint32_t Word = (uint32_t)(ValidBits == 24 ? Sample * 256 : Sample);

    At[0] = (BYTE)Word;
    At[1] = (BYTE)(Word >> 8);
    if (ValidBits != 16)
    {
        At[2] = (BYTE)(Word >> 16);
        At[3] = (BYTE)(Word >> 24);
    }
}

/* Count frames of the tone from First into the client's buffer */
static
VOID
StoreTone(
    BYTE *Data,
    UINT32 First,
    UINT32 Count,
    WORD ValidBits,
    UINT32 FrameBytes)
{
    UINT32 SampleBytes = FrameBytes / DSPLOOP_CHANNELS, N, C;

    for (N = 0; N < Count; N++)
    {
        for (C = 0; C < DSPLOOP_CHANNELS; C++)
            StoreSample(Data + (N * DSPLOOP_CHANNELS + C) * SampleBytes, ValidBits, DsploopToneSample(First + N, ValidBits));
    }
}

/* A stream the loop has open: its client, its event and its service */
typedef struct _DSPLOOP_STREAM
{
    IAudioClient *Client;
    HANDLE Event;
    IAudioRenderClient *Render;
    IAudioCaptureClient *Capture;
    /* the render buffer, in frames */
    UINT32 Capacity;
} DSPLOOP_STREAM;

/*
 * A shared-mode event-driven stream: the flags are the caller's, as the
 * sibling apitests open theirs (the render apitest lets the engine convert
 * the client's format; the capture apitest asks for the events alone). The
 * status of Initialize is the caller's to read: the engine's refusal of a
 * format is AUDCLNT_E_UNSUPPORTED_FORMAT.
 */
static
HRESULT
OpenClient(
    IMMDevice *Device,
    const WAVEFORMATEX *Format,
    REFERENCE_TIME Duration,
    DWORD Flags,
    REFIID ServiceId,
    _Out_ void **Service,
    _Out_ IAudioClient **Client,
    _Out_ HANDLE *Event)
{
    HRESULT hr;

    *Service = NULL;
    *Client = NULL;
    *Event = NULL;
    hr = IMMDevice_Activate(Device, &IID_IAudioClient, CLSCTX_ALL, NULL, (void **)Client);
    if (FAILED(hr))
        return hr;
    hr = IAudioClient_Initialize(*Client, AUDCLNT_SHAREMODE_SHARED, Flags | AUDCLNT_STREAMFLAGS_EVENTCALLBACK,
                                 Duration, 0, Format, NULL);
    if (FAILED(hr))
        goto Fail;
    *Event = CreateEventW(NULL, FALSE, FALSE, NULL);
    if (!*Event)
    {
        hr = E_OUTOFMEMORY;
        goto Fail;
    }
    hr = IAudioClient_SetEventHandle(*Client, *Event);
    if (FAILED(hr))
        goto Fail;
    hr = IAudioClient_GetService(*Client, ServiceId, Service);
    if (FAILED(hr))
        goto Fail;
    return S_OK;

Fail:
    if (*Event)
        CloseHandle(*Event);
    *Event = NULL;
    IAudioClient_Release(*Client);
    *Client = NULL;
    return hr;
}

static
VOID
CloseClient(
    IUnknown *Service,
    IAudioClient *Client,
    HANDLE Event)
{
    if (Service)
        IUnknown_Release(Service);
    if (Client)
        IAudioClient_Release(Client);
    if (Event)
        CloseHandle(Event);
}

/*
 * One run: the capture opened and started first, into a ring; the render
 * opened, its buffer filled with the tone's first frames and started; then
 * each wake of either event is served until the ring is full or the budget
 * is spent. The tone is written once, DSPLOOP_FRAMES frames of it, and
 * nothing after it. The comparison (compare.h) and its lines end the run.
 */
static
int
RunLoop(
    IMMDevice *RenderDevice,
    IMMDevice *CaptureDevice,
    WORD ValidBits,
    uint32_t Gain,
    const char *Label)
{
    WAVEFORMATEXTENSIBLE Format;
    const WAVEFORMATEX *Wave = (const WAVEFORMATEX *)&Format;
    DSPLOOP_STREAM Render, Capture;
    DSPLOOP_MATCH Match;
    HANDLE Events[2];
    BYTE *Ring = NULL, *Data;
    UINT32 FrameBytes, Written = 0, Captured = 0, Next, Frames, Padding, Free, Take, First, Held;
    DWORD Flags, Deadline, Wait, Started = 0, Elapsed = 0;
    UINT64 DevicePosition, QpcPosition;
    HRESULT hr;
    /* the engine's dither at 16 valid bits, and under a gain the gain's rounding too: one unit more (DsploopToleranceAtGain) */
    int Tolerance = DsploopToleranceAtGain(ValidBits, Gain);
    int Result = DSPLOOP_FAILED;

    ZeroMemory(&Render, sizeof(Render));
    ZeroMemory(&Capture, sizeof(Capture));
    ToneFormat(&Format, ValidBits);
    FrameBytes = Wave->nBlockAlign;

    hr = OpenClient(CaptureDevice, Wave, DSPLOOP_CAPTURE_BUFFER, 0, &IID_IAudioCaptureClient, (void **)&Capture.Capture,
                    &Capture.Client, &Capture.Event);
    if (hr == AUDCLNT_E_UNSUPPORTED_FORMAT)
    {
        skip("dsploop%s: the shared-mode engine does not take the format for capture; the run is skipped\n", Label);
        return DSPLOOP_SKIPPED;
    }
    ok(hr == S_OK, "dsploop%s: capture: Initialize 0x%08lx\n", Label, hr);
    if (FAILED(hr))
        goto Done;
    hr = OpenClient(RenderDevice, Wave, DSPLOOP_RENDER_BUFFER,
                    AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM | AUDCLNT_STREAMFLAGS_SRC_DEFAULT_QUALITY,
                    &IID_IAudioRenderClient, (void **)&Render.Render, &Render.Client, &Render.Event);
    if (hr == AUDCLNT_E_UNSUPPORTED_FORMAT)
    {
        skip("dsploop%s: the shared-mode engine does not take the format for render; the run is skipped\n", Label);
        CloseClient((IUnknown *)Capture.Capture, Capture.Client, Capture.Event);
        return DSPLOOP_SKIPPED;
    }
    ok(hr == S_OK, "dsploop%s: render: Initialize 0x%08lx\n", Label, hr);
    if (FAILED(hr))
        goto Done;
    hr = IAudioClient_GetBufferSize(Render.Client, &Render.Capacity);
    ok(hr == S_OK && Render.Capacity != 0, "dsploop%s: render: GetBufferSize 0x%08lx, %u frames\n", Label, hr, Render.Capacity);
    if (FAILED(hr) || Render.Capacity == 0)
        goto Done;

    Ring = (BYTE *)calloc(DSPLOOP_CAPTURE_FRAMES, FrameBytes);
    ok(Ring != NULL, "dsploop%s: no room for the capture\n", Label);
    if (!Ring)
        goto Done;

    hr = IAudioClient_Start(Capture.Client);
    ok(hr == S_OK, "dsploop%s: capture: Start 0x%08lx\n", Label, hr);
    if (FAILED(hr))
        goto Done;
    /* the tone fills the render buffer before the stream starts, and no more than the run's frames */
    First = Render.Capacity < DSPLOOP_FRAMES ? Render.Capacity : DSPLOOP_FRAMES;
    hr = IAudioRenderClient_GetBuffer(Render.Render, First, &Data);
    ok(hr == S_OK, "dsploop%s: render: GetBuffer(%u) 0x%08lx\n", Label, First, hr);
    if (FAILED(hr))
        goto Stopped;
    StoreTone(Data, 0, First, ValidBits, FrameBytes);
    hr = IAudioRenderClient_ReleaseBuffer(Render.Render, First, 0);
    ok(hr == S_OK, "dsploop%s: render: ReleaseBuffer(%u) 0x%08lx\n", Label, First, hr);
    if (FAILED(hr))
        goto Stopped;
    Written = First;
    hr = IAudioClient_Start(Render.Client);
    ok(hr == S_OK, "dsploop%s: render: Start 0x%08lx\n", Label, hr);
    if (FAILED(hr))
        goto Stopped;

    Events[0] = Capture.Event;
    Events[1] = Render.Event;
    Started = GetTickCount();
    Deadline = Started + DSPLOOP_RUN_MS;
    while (Captured < DSPLOOP_CAPTURE_FRAMES && (LONG)(GetTickCount() - Deadline) < 0)
    {
        Wait = WaitForMultipleObjects(2, Events, FALSE, 100);
        ok(Wait == WAIT_OBJECT_0 || Wait == WAIT_OBJECT_0 + 1 || Wait == WAIT_TIMEOUT, "dsploop%s: wait %lu\n", Label, Wait);
        if (Wait == WAIT_OBJECT_0)
        {
            /* every packet that is ready goes into the ring, silence included; past the ring's end nothing more is read */
            for (;;)
            {
                if (Captured >= DSPLOOP_CAPTURE_FRAMES)
                    break;
                Next = 0;
                hr = IAudioCaptureClient_GetNextPacketSize(Capture.Capture, &Next);
                if (FAILED(hr) || Next == 0)
                    break;
                hr = IAudioCaptureClient_GetBuffer(Capture.Capture, &Data, &Frames, &Flags, &DevicePosition, &QpcPosition);
                if (FAILED(hr))
                    break;
                Take = Frames < DSPLOOP_CAPTURE_FRAMES - Captured ? Frames : DSPLOOP_CAPTURE_FRAMES - Captured;
                if (Flags & AUDCLNT_BUFFERFLAGS_SILENT)
                    ZeroMemory(Ring + (size_t)Captured * FrameBytes, (size_t)Take * FrameBytes);
                else
                    memcpy(Ring + (size_t)Captured * FrameBytes, Data, (size_t)Take * FrameBytes);
                hr = IAudioCaptureClient_ReleaseBuffer(Capture.Capture, Frames);
                if (FAILED(hr))
                    break;
                /* a packet cut by the ring's end is released whole: its frames past the end are not the run's */
                Captured += Take;
            }
            if (FAILED(hr))
                ok(hr == S_OK, "dsploop%s: capture: 0x%08lx after %u frames\n", Label, hr, Captured);
        }
        else if (Wait == WAIT_OBJECT_0 + 1 && Written < DSPLOOP_FRAMES)
        {
            /* the tone continues into the free frames of the buffer, and no further */
            hr = IAudioClient_GetCurrentPadding(Render.Client, &Padding);
            if (SUCCEEDED(hr))
            {
                Free = Padding < Render.Capacity ? Render.Capacity - Padding : 0;
                if (Free > DSPLOOP_FRAMES - Written)
                    Free = DSPLOOP_FRAMES - Written;
                if (Free != 0)
                {
                    hr = IAudioRenderClient_GetBuffer(Render.Render, Free, &Data);
                    if (SUCCEEDED(hr))
                    {
                        StoreTone(Data, Written, Free, ValidBits, FrameBytes);
                        hr = IAudioRenderClient_ReleaseBuffer(Render.Render, Free, 0);
                        if (SUCCEEDED(hr))
                            Written += Free;
                    }
                }
            }
            if (FAILED(hr))
                ok(hr == S_OK, "dsploop%s: render: 0x%08lx after %u frames\n", Label, hr, Written);
        }
    }
    Elapsed = GetTickCount() - Started;

Stopped:
    IAudioClient_Stop(Render.Client);
    IAudioClient_Stop(Capture.Client);
    trace("dsploop%s: %u frames of the tone rendered, %u frames captured in %lu ms\n", Label, Written, Captured, Elapsed);

    Held = Captured < DSPLOOP_CAPTURE_FRAMES ? Captured : DSPLOOP_CAPTURE_FRAMES;
    DsploopCompareAtGain(Ring, Held, DSPLOOP_CHANNELS, Wave->wBitsPerSample, ValidBits, DSPLOOP_FRAMES, DSPLOOP_MAX_OFFSET, Tolerance, Gain, &Match);
    if (!Match.Matched)
    {
        if (Match.FirstDifference == DSPLOOP_NO_DIFFERENCE)
            trace("dsploop%s: %u frames captured, too few to hold the tone's first cycle\n", Label, Held);
        else
            trace("dsploop%s: no frame within %u matches the tone's first cycle%s; from the first frame, first differing sample %u (channel %u): expected %d, captured %d\n",
                  Label, (UINT32)DSPLOOP_MAX_OFFSET, Gain != DSPLOOP_GAIN_UNITY ? " as the gain forwards it" : "", Match.FirstDifference, Match.Channel, Match.Expected, Match.Captured);
        ok(0, "dsploop%s: the tone was not captured (%u frames)\n", Label, Held);
    }
    else
    {
        trace("dsploop%s: %u frames compared within %d LSB, max abs error %I64d, offset %u%s%s\n", Label, Match.Compared, Tolerance, Match.MaxError, Match.Offset,
              Gain != DSPLOOP_GAIN_UNITY ? ", the expectation scaled by the gain" : "",
              Match.FirstDifference == DSPLOOP_NO_DIFFERENCE ? ", ok" : "");
        if (Match.FirstDifference != DSPLOOP_NO_DIFFERENCE)
            trace("dsploop%s: first sample beyond %d LSB %u after the offset (channel %u): expected %d, captured %d\n",
                  Label, Tolerance, Match.FirstDifference, Match.Channel, Match.Expected, Match.Captured);
        ok(Match.FirstDifference == DSPLOOP_NO_DIFFERENCE && Match.Compared == DSPLOOP_FRAMES,
           "dsploop%s: %u of %u frames compared within %d LSB, max abs error %I64d, first sample beyond it %u\n",
           Label, Match.Compared, (UINT32)DSPLOOP_FRAMES, Tolerance, Match.MaxError, Match.FirstDifference);
        if (Match.FirstDifference == DSPLOOP_NO_DIFFERENCE && Match.Compared == DSPLOOP_FRAMES)
            Result = DSPLOOP_OK;
    }

Done:
    free(Ring);
    CloseClient((IUnknown *)Render.Render, Render.Client, Render.Event);
    CloseClient((IUnknown *)Capture.Capture, Capture.Client, Capture.Event);
    return Result;
}

/*
 * The hold (N12-03): DSPLOOP_HOLD's seconds, 0 when unset or not a number.
 * With it the test opens its render pin and holds it, initialized and never
 * started, until a key or the seconds: the stream is allocated the whole
 * time, so the idle power-down (E2) has nothing to time, and the close
 * ends it; the three runs are not made then.
 */
static
DWORD
HoldSeconds(
    void)
{
    CHAR Text[16];
    DWORD Chars = GetEnvironmentVariableA("DSPLOOP_HOLD", Text, sizeof(Text));

    return Chars > 0 && Chars < sizeof(Text) ? (DWORD)atoi(Text) : 0;
}

/* One render pin open and not running: the client initialized, the service asked, nothing started; held until a key or the seconds, then closed */
static
VOID
HoldPin(
    IMMDevice *Render,
    DWORD Seconds)
{
    WAVEFORMATEXTENSIBLE Format;
    IAudioRenderClient *Service = NULL;
    IAudioClient *Client = NULL;
    HANDLE Event = NULL;
    DWORD Started, Held;
    BOOL Key = FALSE;
    HRESULT hr;

    ToneFormat(&Format, 16);
    hr = OpenClient(Render, (WAVEFORMATEX *)&Format, DSPLOOP_RENDER_BUFFER, 0, &IID_IAudioRenderClient, (void **)&Service, &Client, &Event);
    ok(hr == S_OK, "dsploop hold: render: Initialize 0x%08lx\n", hr);
    if (FAILED(hr))
        return;
    Started = GetTickCount();
    trace("dsploop hold: the render client initialized, its pin open and not started; holding up to %lu s, a key ends it\n", Seconds);
    while (GetTickCount() - Started < Seconds * 1000)
    {
        Sleep(100);
        if (_kbhit())
        {
            Key = TRUE;
            (void)_getch();
            break;
        }
    }
    Held = GetTickCount() - Started;
    trace("dsploop hold: released after %lu ms (%s); the pin closes\n", Held, Key ? "a key" : "the timeout");
    CloseClient((IUnknown *)Service, Client, Event);
}

START_TEST(dsploop)
{
    /* 16 valid bits is the run the plan asks for; 24 in a 32-bit word and 32 follow when the shared-mode engine takes them */
    static const struct
    {
        WORD ValidBits;
        const char *Label;
    } Runs[] =
    {
        { 16, "" },
        { 24, " (24 valid in 32)" },
        { 32, " (32)" }
    };
    IMMDeviceEnumerator *Enumerator = NULL;
    IMMDevice *Render = NULL, *Capture = NULL;
    HRESULT hr;
    unsigned I;
    UINT RunsCompared = 0;
    int Result;
    BOOL Held = FALSE;
    /* the gain the DSP forwards the PCM's streams at: the volume node's level and the mute node's state as the driver keeps them (N14-02, N14-17) */
    IAudioEndpointVolume *Volume = NULL;
    float LevelDb = 0.0f;
    BOOL Mute = FALSE;
    LONG Level = 0;
    BOOL NodeLevel = FALSE;
    uint32_t Gain = DSPLOOP_GAIN_UNITY;

    hr = CoInitializeEx(NULL, COINIT_MULTITHREADED);
    ok(SUCCEEDED(hr), "CoInitializeEx: 0x%08lx\n", hr);
    if (FAILED(hr))
        return;
    hr = CoCreateInstance(&CLSID_MMDeviceEnumerator, NULL, CLSCTX_ALL, &IID_IMMDeviceEnumerator, (void **)&Enumerator);
    ok(hr == S_OK, "Create enumerator: 0x%08lx\n", hr);
    if (FAILED(hr))
        goto Done;
    hr = FindEndpoint(Enumerator, eRender, &Render);
    if (FAILED(hr))
    {
        apitest_missing("dsploop: no active render endpoint of the DSP's PCM (" DSPPCM_ID_TEXT "; 0x%08lx)\n", hr);
        goto Done;
    }
    hr = FindEndpoint(Enumerator, eCapture, &Capture);
    if (FAILED(hr))
    {
        apitest_missing("dsploop: no active capture endpoint of the DSP's PCM (" DSPPCM_ID_TEXT "; 0x%08lx)\n", hr);
        goto Done;
    }
    /* the level the stream starts at is the node's, in 1/65536 decibels, the driver's own answer (N14-17); a topology without control interfaces leaves the endpoint's scalar, in decibels as user mode maps it and rounded back, which at a coarse step is not the level the stream runs at */
    hr = ReadNodeProperty(Render, &VolumeNodeType, KSPROPERTY_AUDIO_VOLUMELEVEL, &Level, sizeof(Level));
    if (hr == S_OK)
        hr = ReadNodeProperty(Render, &MuteNodeType, KSPROPERTY_AUDIO_MUTE, &Mute, sizeof(Mute));
    if (hr == S_OK)
    {
        NodeLevel = TRUE;
        LevelDb = (float)Level / 65536.0f;
    }
    else
    {
        trace("dsploop: the volume node's level is not reachable through the topology's control interface (0x%08lx): the endpoint's scalar instead\n", hr);
        hr = IMMDevice_Activate(Render, &IID_IAudioEndpointVolume, CLSCTX_ALL, NULL, (void **)&Volume);
        if (SUCCEEDED(hr))
        {
            hr = IAudioEndpointVolume_GetMasterVolumeLevel(Volume, &LevelDb);
            if (SUCCEEDED(hr))
                hr = IAudioEndpointVolume_GetMute(Volume, &Mute);
            IAudioEndpointVolume_Release(Volume);
        }
        if (hr == S_OK)
            Level = (LONG)floorf(LevelDb * 65536.0f + 0.5f);
    }
    ok(hr == S_OK, "dsploop: the endpoint's volume node 0x%08lx\n", hr);
    if (hr == S_OK)
        Gain = DsploopGainWord(Level, Mute);
    trace("dsploop: the volume node: %.2f dB (level %ld, %s), mute %d: the expectation scaled by the gain 0x%08x, the tolerance %d LSB\n",
          LevelDb, Level, NodeLevel ? "the driver's level" : "the scalar last set, the node unreachable",
          Mute, Gain, DsploopToleranceAtGain(16, Gain));
    /* the hold (N12-03): one pin open and not running, the runs not made, their count not judged */
    if (HoldSeconds() != 0)
    {
        Held = TRUE;
        HoldPin(Render, HoldSeconds());
        goto Done;
    }
    for (I = 0; I < ARRAY_SIZE(Runs); I++)
    {
        Result = RunLoop(Render, Capture, Runs[I].ValidBits, Gain, Runs[I].Label);
        RunsCompared += Result == DSPLOOP_OK;
        /* the plan's stop rule: a run that does not match ends the test at its first differing sample; a format the engine refuses is a skip, counted by the harness */
        if (Result == DSPLOOP_FAILED)
        {
            trace("dsploop: stopped after the run above, the plan's stop rule\n");
            break;
        }
    }

Done:
    if (Capture)
        IMMDevice_Release(Capture);
    if (Render)
        IMMDevice_Release(Render);
    if (Enumerator)
        IMMDeviceEnumerator_Release(Enumerator);
    CoUninitialize();
    /* the count is the program's own: a run the engine refused, or that failed, leaves it below three; under the expected switch that is a failure as well; the hold made no run and is not counted */
    if (Held)
        return;
    if (ApitestRequired())
        ok(RunsCompared == 3, "dsploop: %u of 3 depths compared\n", RunsCompared);
    ApitestSummary("dsploop", RunsCompared, 3, "depths compared");
}
