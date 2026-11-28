/*
 * The E5b walk probe: every call dsploop's walk makes, from the render endpoint of the DSP's PCM, with its
 * result: the endpoint's own topology, its connector, the part it is connected to, the parts incoming to and
 * outgoing from each, two levels deep; the volume node's control interface and its level property.
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

static const GUID AudioPropertySet = { STATIC_KSPROPSETID_Audio };
static const GUID VolumeNodeType = { STATIC_KSNODETYPE_VOLUME };

static int Depth;

static void ShowPart(const char *Tag, IPart *Part)
{
    UINT Id = ~0u, Count = ~0u, I;
    PartType Type = (PartType)-1;
    GUID Sub = GUID_NULL;
    LPWSTR Name = NULL, Gid = NULL;
    IPartsList *List = NULL;
    IConnector *Conn = NULL, *Peer = NULL;
    IPart *Item;
    HRESULT hr;

    IPart_GetLocalId(Part, &Id);
    hr = IPart_GetPartType(Part, &Type);
    IPart_GetSubType(Part, &Sub);
    hr = IPart_GetName(Part, &Name);
    IPart_GetGlobalId(Part, &Gid);
    trace("walkprobe: %*s%s: local id 0x%08x, type %d (0x%08lx), name %ls (0x%08lx), subtype %s, global id %ls\n",
          Depth * 2, "", Tag, Id, (int)Type, hr, Name ? Name : L"(null)", hr, wine_dbgstr_guid(&Sub), Gid ? Gid : L"(null)");
    CoTaskMemFree(Name);
    CoTaskMemFree(Gid);
    hr = IPart_EnumPartsIncoming(Part, &List);
    trace("walkprobe: %*s  EnumPartsIncoming: 0x%08lx\n", Depth * 2, "", hr);
    if (SUCCEEDED(hr))
    {
        if (SUCCEEDED(IPartsList_GetCount(List, &Count)))
            for (I = 0; I < Count; ++I)
                if (SUCCEEDED(IPartsList_GetPart(List, I, &Item)))
                {
                    Depth++;
                    ShowPart("incoming part", Item);
                    Depth--;
                    IPart_Release(Item);
                }
        IPartsList_Release(List);
    }
    hr = IPart_EnumPartsOutgoing(Part, &List);
    trace("walkprobe: %*s  EnumPartsOutgoing: 0x%08lx\n", Depth * 2, "", hr);
    if (SUCCEEDED(hr))
    {
        if (SUCCEEDED(IPartsList_GetCount(List, &Count)))
            for (I = 0; I < Count; ++I)
                if (SUCCEEDED(IPartsList_GetPart(List, I, &Item)))
                {
                    Depth++;
                    ShowPart("outgoing part", Item);
                    Depth--;
                    IPart_Release(Item);
                }
        IPartsList_Release(List);
    }
    if (SUCCEEDED(IPart_QueryInterface(Part, &IID_IConnector, (void **)&Conn)))
    {
        Name = NULL;
        hr = IConnector_GetDeviceIdConnectedTo(Conn, &Name);
        trace("walkprobe: %*s  GetDeviceIdConnectedTo: 0x%08lx %ls\n", Depth * 2, "", hr, Name ? Name : L"");
        CoTaskMemFree(Name);
        hr = IConnector_GetConnectedTo(Conn, &Peer);
        trace("walkprobe: %*s  GetConnectedTo: 0x%08lx\n", Depth * 2, "", hr);
        if (SUCCEEDED(hr))
        {
            if (SUCCEEDED(IConnector_QueryInterface(Peer, &IID_IPart, (void **)&Item)))
            {
                if (Depth < 2)
                {
                    Depth++;
                    ShowPart("connected to", Item);
                    Depth--;
                }
                else
                    trace("walkprobe: %*s    (its part not shown: the depth)\n", Depth * 2, "");
                IPart_Release(Item);
            }
            IConnector_Release(Peer);
        }
        IConnector_Release(Conn);
    }
    if (Type == Subunit && IsEqualGUID(&Sub, &VolumeNodeType))
    {
        IKsControl *Control = NULL;
        KSPROPERTY Request;
        LONG Level = 0x7fffffff;
        ULONG Returned = 0;

        hr = IPart_GetControlInterfaceCount(Part, &Count);
        trace("walkprobe: %*s  the volume node: GetControlInterfaceCount 0x%08lx count %u\n", Depth * 2, "", hr, Count);
        hr = IPart_Activate(Part, CLSCTX_INPROC_SERVER, &IID_IKsControl, (void **)&Control);
        trace("walkprobe: %*s  the volume node: Activate(IKsControl) 0x%08lx\n", Depth * 2, "", hr);
        if (SUCCEEDED(hr))
        {
            ZeroMemory(&Request, sizeof(Request));
            Request.Set = AudioPropertySet;
            Request.Id = KSPROPERTY_AUDIO_VOLUMELEVEL;
            Request.Flags = KSPROPERTY_TYPE_GET;
            hr = IKsControl_KsProperty(Control, &Request, sizeof(Request), &Level, sizeof(Level), &Returned);
            trace("walkprobe: %*s  the volume node: KsProperty(VOLUMELEVEL) 0x%08lx level %ld returned %lu\n", Depth * 2, "", hr, Level, Returned);
            IKsControl_Release(Control);
        }
    }
}

START_TEST(walkprobe)
{
    IMMDeviceEnumerator *Enumerator = NULL;
    IMMDeviceCollection *Collection = NULL;
    IMMDevice *Device = NULL;
    IDeviceTopology *Topology = NULL;
    IConnector *Connector = NULL;
    IPart *Part = NULL;
    LPWSTR Id = NULL, Peer = NULL;
    UINT Count = 0, I;
    DataFlow Flow = (DataFlow)-1;
    HRESULT hr;

    hr = CoInitializeEx(NULL, COINIT_MULTITHREADED);
    ok(hr == S_OK, "CoInitializeEx: 0x%08lx\n", hr);
    hr = CoCreateInstance(&CLSID_MMDeviceEnumerator, NULL, CLSCTX_ALL, &IID_IMMDeviceEnumerator, (void **)&Enumerator);
    ok(hr == S_OK, "Create enumerator: 0x%08lx\n", hr);
    hr = IMMDeviceEnumerator_EnumAudioEndpoints(Enumerator, eRender, DEVICE_STATE_ACTIVE, &Collection);
    IMMDeviceCollection_GetCount(Collection, &Count);
    trace("walkprobe: %u active render endpoints\n", Count);
    for (I = 0; I < Count; ++I)
    {
        if (FAILED(IMMDeviceCollection_Item(Collection, I, &Device)))
            continue;
        IMMDevice_GetId(Device, &Id);
        hr = IMMDevice_Activate(Device, &IID_IDeviceTopology, CLSCTX_INPROC_SERVER, NULL, (void **)&Topology);
        trace("walkprobe: endpoint %ls: Activate(IDeviceTopology) 0x%08lx\n", Id ? Id : L"", hr);
        if (SUCCEEDED(hr))
        {
            hr = IDeviceTopology_GetConnectorCount(Topology, &Count);
            trace("walkprobe:  GetConnectorCount 0x%08lx count %u\n", hr, Count);
            Count = ~0u;
            IDeviceTopology_GetSubunitCount(Topology, &Count);
            trace("walkprobe:  GetSubunitCount %u\n", Count);
            hr = IDeviceTopology_GetConnector(Topology, 0, &Connector);
            trace("walkprobe:  GetConnector(0) 0x%08lx\n", hr);
            if (SUCCEEDED(hr))
            {
                hr = IConnector_GetDataFlow(Connector, &Flow);
                trace("walkprobe:  GetDataFlow 0x%08lx flow %d\n", hr, (int)Flow);
                hr = IConnector_GetDeviceIdConnectedTo(Connector, &Peer);
                trace("walkprobe:  GetDeviceIdConnectedTo 0x%08lx %ls\n", hr, Peer ? Peer : L"");
                if (Peer && wcsstr(Peer, L"loopbacktopo"))
                {
                    hr = IConnector_QueryInterface(Connector, &IID_IPart, (void **)&Part);
                    trace("walkprobe:  QueryInterface(IPart) 0x%08lx\n", hr);
                    if (SUCCEEDED(hr))
                    {
                        ShowPart("the endpoint's connector", Part);
                        IPart_Release(Part);
                    }
                }
                CoTaskMemFree(Peer);
                Peer = NULL;
                IConnector_Release(Connector);
                Connector = NULL;
            }
            IDeviceTopology_Release(Topology);
            Topology = NULL;
        }
        CoTaskMemFree(Id);
        Id = NULL;
        IMMDevice_Release(Device);
        Device = NULL;
    }
    IMMDeviceCollection_Release(Collection);
    IMMDeviceEnumerator_Release(Enumerator);
    CoUninitialize();
}
