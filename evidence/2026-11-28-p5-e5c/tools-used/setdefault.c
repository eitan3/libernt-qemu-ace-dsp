/*
 * setdefault.c -- E5c's data-disk tool: the user's default render endpoint set to the one whose
 * friendly name holds "Loopback" (the DSP's), through the store every LiberNT sound UI writes
 * (libernt/mmdevdefault.h); the render endpoints and their properties are printed for the record.
 * Built as the dsploop apitest is (build-setdefault.py: the build's own flags of a C win32cui).
 */

#include <windows.h>
#include <stdio.h>
#include <stddef.h>
#include <libernt/mmdevdefault.h>

#define RENDER_KEY L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\MMDevices\\Audio\\Render"

/* DEVPKEY_Device_FriendlyName, the device path key devenum.c asks the driver for, PKEY_AudioEndpoint_FormFactor and
 * PKEY_AudioEndpoint_PhysicalSpeakers (sdk/include/psdk/mmdeviceapi.idl) */
#define FRIENDLY_NAME L"{a45c254e-df1c-4efd-8020-67d146a850e0},14"
#define ADAPTER_PATH  L"{b3f8fa53-0004-438e-9003-51a46e139bfc},2"
#define FORM_FACTOR   L"{1da5d803-d492-4edd-8c23-e0c0ffee7f0e},0"
#define SPEAKERS      L"{1da5d803-d492-4edd-8c23-e0c0ffee7f0e},3"

/* Whether Text holds Part, without regard to case */
static BOOL contains(const WCHAR *text, const WCHAR *part)
{
    size_t i;

    for (; *text; text++)
    {
        for (i = 0; part[i]; i++)
        {
            WCHAR a = text[i], b = part[i];

            if (a >= L'A' && a <= L'Z')
                a += L'a' - L'A';
            if (b >= L'A' && b <= L'Z')
                b += L'a' - L'A';
            if (a != b)
                break;
        }
        if (!part[i])
            return TRUE;
    }
    return FALSE;
}

/* A REG_SZ or REG_DWORD value of a key, printed */
static void print_value(HKEY key, const WCHAR *name)
{
    BYTE data[512];
    DWORD type = 0, size = sizeof(data);
    LONG error;

    error = RegQueryValueExW(key, name, NULL, &type, data, &size);
    if (error != ERROR_SUCCESS)
    {
        printf("%ls: not set (%ld)\n", name, error);
        return;
    }
    if (type == REG_SZ)
    {
        if (size >= sizeof(data))
            size = sizeof(data) - sizeof(WCHAR);
        *(WCHAR *)(data + size) = 0;
        printf("%ls: REG_SZ %ls\n", name, (const WCHAR *)data);
    }
    else if (type == REG_DWORD && size >= sizeof(DWORD))
        printf("%ls: REG_DWORD %lu\n", name, *(const DWORD *)data);
    else
        printf("%ls: type %lu, %lu bytes\n", name, type, size);
}

int main(void)
{
    static const WCHAR match[] = L"Loopback";
    WCHAR endpoint[96] = L"{0.0.0.00000000}.";
    WCHAR path[96], name[200];
    HKEY root, key;
    DWORD index, type, size, count = 0, found = 0;
    LONG error;

    error = RegOpenKeyExW(HKEY_LOCAL_MACHINE, RENDER_KEY, 0, KEY_READ, &root);
    if (error != ERROR_SUCCESS)
    {
        printf("the Render key: error %ld\n", error);
        return 1;
    }

    for (index = 0;; index++)
    {
        size = 56;
        error = RegEnumKeyExW(root, index, path, &size, NULL, NULL, NULL, NULL);
        if (error == ERROR_NO_MORE_ITEMS)
            break;
        if (error != ERROR_SUCCESS || path[0] != L'{')
            continue;
        count++;
        lstrcatW(path, L"\\Properties");
        if (RegOpenKeyExW(root, path, 0, KEY_READ, &key) != ERROR_SUCCESS)
            continue;

        name[0] = 0;
        size = sizeof(name);
        type = 0;
        if (RegQueryValueExW(key, FRIENDLY_NAME, NULL, &type, (BYTE *)name, &size) != ERROR_SUCCESS || type != REG_SZ)
            name[0] = 0;
        name[sizeof(name) / sizeof(name[0]) - 1] = 0;

        /* the endpoint's id names the key: "{GUID}" without "\Properties" */
        path[lstrlenW(path) - 11] = 0;
        printf("%ls\n", path);
        print_value(key, FRIENDLY_NAME);
        print_value(key, ADAPTER_PATH);
        print_value(key, FORM_FACTOR);
        print_value(key, SPEAKERS);
        RegCloseKey(key);

        if (!found && contains(name, match))
        {
            lstrcatW(endpoint, path);
            found = 1;
        }
    }
    RegCloseKey(root);

    printf("render endpoints: %lu, the one named Loopback: %lu\n", count, found);
    if (!found)
        return 1;

    error = MMDevSetDefaultEndpoint(eRender, eConsole, endpoint);
    printf("DefaultOutput set to %ls: error %ld\n", endpoint, error);

    if (RegOpenKeyExW(HKEY_CURRENT_USER, MMDEV_DEFAULT_KEY, 0, KEY_READ, &key) == ERROR_SUCCESS)
    {
        print_value(key, L"DefaultOutput");
        RegCloseKey(key);
    }
    return error == ERROR_SUCCESS ? 0 : 1;
}
