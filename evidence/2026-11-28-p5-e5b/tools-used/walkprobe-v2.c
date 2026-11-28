/*
 * The E5b walk probe, second form: dsploop's own walk (NodePartOfSubtype of dsploop.c, copied) run from the
 * render endpoint's connector in both directions, with each step it takes on the serial trace; then the same
 * calls one by one.
 */
#include <apitest.h>

#define COBJMACROS
#include <windows.h>
#include <objbase.h>
#include <initguid.h>
#include <mmdeviceapi.h>
#include <devicetopology.h>
#include <ks.h>
#include <ksmedia.h>
#include <wchar.h>

static const GUID VolumeNodeType = { STATIC_KSNODETYPE_VOLUME };
#define DSPLOOP_TOPOLOGY_DEPTH   8
#define DSPLOOP_VISITED_PARTS 32
typedef struct _VISITED_PARTS { LPWSTR Ids[DSPLOOP_VISITED_PARTS]; UINT Count; } VISITED_PARTS;

static BOOL VisitedPart(VISITED_PARTS *Visited, IPart *Part)
{
    LPWSTR Id = NULL; UINT I;
    if (FAILED(IPart_GetGlobalId(Part, &Id)) || !Id) { trace("walkprobe2:   GetGlobalId failed\n"); return FALSE; }
    for (I = 0; I < Visited->Count; ++I)
        if (!wcscmp(Visited->Ids[I], Id)) { trace("walkprobe2:   %ls: visited\n", Id); CoTaskMemFree(Id); return TRUE; }
    if (Visited->Count < DSPLOOP_VISITED_PARTS) Visited->Ids[Visited->Count++] = Id; else CoTaskMemFree(Id);
    return FALSE;
}

static UINT Steps;

static HRESULT NodePartOfSubtype(IPart *Part, REFGUID Subtype, BOOL Incoming, UINT Depth, VISITED_PARTS *Visited, IPart **Found)
{
    IConnector *Connector = NULL, *Peer = NULL;
    IPartsList *List = NULL;
    IPart *Next;
    PartType Type = (PartType)-1;
    GUID Id = GUID_NULL;
    UINT Count = 0, I;
    HRESULT hr;
    LPWSTR Gid = NULL;

    *Found = NULL;
    IPart_GetGlobalId(Part, &Gid);
    trace("walkprobe2: step %u depth %u %s: part %ls\n", ++Steps, Depth, Incoming ? "incoming" : "outgoing", Gid ? Gid : L"");
    CoTaskMemFree(Gid);
    if (Depth > DSPLOOP_TOPOLOGY_DEPTH || VisitedPart(Visited, Part))
        return HRESULT_FROM_WIN32(ERROR_NOT_FOUND);
    hr = IPart_GetPartType(Part, &Type);
    trace("walkprobe2:   GetPartType 0x%08lx type %d\n", hr, (int)Type);
    if (SUCCEEDED(hr) && Type == Subunit)
    {
        hr = IPart_GetSubType(Part, &Id);
        trace("walkprobe2:   GetSubType 0x%08lx %s\n", hr, wine_dbgstr_guid(&Id));
    }
    if (SUCCEEDED(hr) && Type == Subunit && SUCCEEDED(IPart_GetSubType(Part, &Id)) && IsEqualGUID(&Id, Subtype))
    {
        IPart_AddRef(Part);
        *Found = Part;
        return S_OK;
    }
    hr = IPart_QueryInterface(Part, &IID_IConnector, (void **)&Connector);
    trace("walkprobe2:   QI(IConnector) 0x%08lx\n", hr);
    if (SUCCEEDED(hr))
    {
        hr = IConnector_GetConnectedTo(Connector, &Peer);
        trace("walkprobe2:   GetConnectedTo 0x%08lx\n", hr);
        if (SUCCEEDED(hr) && SUCCEEDED(IConnector_QueryInterface(Peer, &IID_IPart, (void **)&Next)))
        {
            hr = NodePartOfSubtype(Next, Subtype, Incoming, Depth + 1, Visited, Found);
            IPart_Release(Next);
        }
        if (Peer) IConnector_Release(Peer);
        IConnector_Release(Connector);
        if (*Found) return S_OK;
    }
    hr = Incoming ? IPart_EnumPartsIncoming(Part, &List) : IPart_EnumPartsOutgoing(Part, &List);
    trace("walkprobe2:   EnumParts%s 0x%08lx\n", Incoming ? "Incoming" : "Outgoing", hr);
    if (FAILED(hr))
        return HRESULT_FROM_WIN32(ERROR_NOT_FOUND);
    if (SUCCEEDED(IPartsList_GetCount(List, &Count)))
    {
        trace("walkprobe2:   count %u\n", Count);
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

START_TEST(walkprobe)
{
    IMMDeviceEnumerator *Enumerator = NULL;
    IMMDeviceCollection *Collection = NULL;
    IMMDevice *Device = NULL;
    IDeviceTopology *Topology = NULL;
    IConnector *Connector = NULL;
    IPart *Part = NULL, *Node = NULL;
    VISITED_PARTS Visited;
    LPWSTR Id = NULL, Peer = NULL;
    UINT Count = 0, I;
    DataFlow Flow = (DataFlow)-1;
    HRESULT hr;

    ZeroMemory(&Visited, sizeof(Visited));
    hr = CoInitializeEx(NULL, COINIT_MULTITHREADED);
    hr = CoCreateInstance(&CLSID_MMDeviceEnumerator, NULL, CLSCTX_ALL, &IID_IMMDeviceEnumerator, (void **)&Enumerator);
    hr = IMMDeviceEnumerator_EnumAudioEndpoints(Enumerator, eRender, DEVICE_STATE_ACTIVE, &Collection);
    IMMDeviceCollection_GetCount(Collection, &Count);
    for (I = 0; I < Count; ++I)
    {
        if (FAILED(IMMDeviceCollection_Item(Collection, I, &Device))) continue;
        IMMDevice_GetId(Device, &Id);
        hr = IMMDevice_Activate(Device, &IID_IDeviceTopology, CLSCTX_INPROC_SERVER, NULL, (void **)&Topology);
        if (SUCCEEDED(hr))
        {
            hr = IDeviceTopology_GetConnector(Topology, 0, &Connector);
            if (SUCCEEDED(hr)) hr = IConnector_GetDataFlow(Connector, &Flow);
            if (SUCCEEDED(hr)) hr = IConnector_GetDeviceIdConnectedTo(Connector, &Peer);
            if (Peer && wcsstr(Peer, L"loopbacktopo"))
            {
                trace("walkprobe2: endpoint %ls: flow %d\n", Id, (int)Flow);
                hr = IConnector_QueryInterface(Connector, &IID_IPart, (void **)&Part);
                trace("walkprobe2: QI(IPart) 0x%08lx\n", hr);
                Steps = 0;
                hr = NodePartOfSubtype(Part, &VolumeNodeType, TRUE, 0, &Visited, &Node);
                trace("walkprobe2: the walk incoming: 0x%08lx, found %p\n", hr, Node);
                if (Node) { IPart_GetGlobalId(Node, &Peer); trace("walkprobe2:   the node %ls\n", Peer); CoTaskMemFree(Peer); IPart_Release(Node); Node = NULL; }
                {
                    UINT K; for (K = 0; K < Visited.Count; ++K) { trace("walkprobe2:   visited %ls\n", Visited.Ids[K]); CoTaskMemFree(Visited.Ids[K]); } Visited.Count = 0;
                }
                Steps = 0;
                hr = NodePartOfSubtype(Part, &VolumeNodeType, FALSE, 0, &Visited, &Node);
                trace("walkprobe2: the walk outgoing: 0x%08lx, found %p\n", hr, Node);
                if (Node) IPart_Release(Node);
                IPart_Release(Part);
            }
            CoTaskMemFree(Peer); Peer = NULL;
            if (Connector) IConnector_Release(Connector); Connector = NULL;
            IDeviceTopology_Release(Topology); Topology = NULL;
        }
        CoTaskMemFree(Id); Id = NULL;
        IMMDevice_Release(Device); Device = NULL;
    }
    IMMDeviceCollection_Release(Collection);
    IMMDeviceEnumerator_Release(Enumerator);
    CoUninitialize();
}
