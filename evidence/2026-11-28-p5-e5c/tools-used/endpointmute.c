/*
 * endpointmute.c -- E5c's data-disk tool: the mute of the user's default render endpoint set and read
 * back through IAudioEndpointVolume (the call the tray's button and the Volume tab make), on the
 * endpoint DefaultOutput names; the endpoint, the call's results and the mute before and after are
 * printed for the record.  Built as the dsploop apitest is (build-setdefault.py's way).
 */

#define COBJMACROS
#include <windows.h>
#include <objbase.h>
/* before the headers that name the GUIDs: they define them here, once */
#include <initguid.h>
#include <mmdeviceapi.h>
#include <endpointvolume.h>
#include <stdio.h>
#include <libernt/mmdevdefault.h>

int main(int argc, char **argv)
{
    IMMDeviceEnumerator *enumerator = NULL;
    IMMDevice *device = NULL;
    IAudioEndpointVolume *volume = NULL;
    WCHAR endpoint[96];
    DWORD type = 0, size = sizeof(endpoint);
    BOOL mute = argc > 1 && argv[1][0] == '1', before = 2, after = 2;
    HKEY key;
    HRESULT hr;

    if (RegOpenKeyExW(HKEY_CURRENT_USER, MMDEV_DEFAULT_KEY, 0, KEY_READ, &key) != ERROR_SUCCESS ||
        RegQueryValueExW(key, L"DefaultOutput", NULL, &type, (BYTE *)endpoint, &size) != ERROR_SUCCESS || type != REG_SZ)
    {
        printf("DefaultOutput: not read\n");
        return 1;
    }
    RegCloseKey(key);
    endpoint[sizeof(endpoint) / sizeof(endpoint[0]) - 1] = 0;
    printf("DefaultOutput: %ls\n", endpoint);
    printf("the call: IAudioEndpointVolume::SetMute(%u)\n", mute);

    hr = CoInitialize(NULL);
    if (FAILED(hr))
    {
        printf("CoInitialize: 0x%08lx\n", hr);
        return 1;
    }
    hr = CoCreateInstance(&CLSID_MMDeviceEnumerator, NULL, CLSCTX_INPROC_SERVER, &IID_IMMDeviceEnumerator, (void **)&enumerator);
    if (SUCCEEDED(hr))
        hr = IMMDeviceEnumerator_GetDevice(enumerator, endpoint, &device);
    if (SUCCEEDED(hr))
        hr = IMMDevice_Activate(device, &IID_IAudioEndpointVolume, CLSCTX_INPROC_SERVER, NULL, (void **)&volume);
    if (SUCCEEDED(hr))
        hr = IAudioEndpointVolume_GetMute(volume, &before);
    printf("before: mute %u (0x%08lx)\n", before, hr);
    if (SUCCEEDED(hr))
        hr = IAudioEndpointVolume_SetMute(volume, mute, NULL);
    printf("SetMute: 0x%08lx\n", hr);
    if (volume)
    {
        if (SUCCEEDED(hr))
            hr = IAudioEndpointVolume_GetMute(volume, &after);
        printf("after: mute %u (0x%08lx)\n", after, hr);
        IAudioEndpointVolume_Release(volume);
    }
    if (device)
        IMMDevice_Release(device);
    if (enumerator)
        IMMDeviceEnumerator_Release(enumerator);
    CoUninitialize();
    return SUCCEEDED(hr) && after == mute ? 0 : 1;
}
