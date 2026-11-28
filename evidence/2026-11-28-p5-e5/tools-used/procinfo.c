/*
 * procinfo.c -- E5's data-disk tool for LEG-1's leak row: the handle count of every process whose
 * image name holds the argument (without regard to case), read with GetProcessHandleCount; the
 * process list is the toolhelp snapshot.  Typed as a short line (`hc <part>`), the output goes to
 * the data disk by hc.cmd.  Built as the dsploop apitest is (build-procinfo.py).
 */

#include <windows.h>
#include <tlhelp32.h>
#include <stdio.h>

/* tlhelp32.h declares Process32First alone; the A/W-less Process32Next is kernel32's export (kernel32.spec) */
BOOL WINAPI Process32Next(HANDLE snapshot, LPPROCESSENTRY32 entry);

/* Whether Text holds Part, without regard to case */
static BOOL contains(const char *text, const char *part)
{
    size_t i;

    for (; *text; text++)
    {
        for (i = 0; part[i]; i++)
        {
            char a = text[i], b = part[i];

            if (a >= 'A' && a <= 'Z')
                a += 'a' - 'A';
            if (b >= 'A' && b <= 'Z')
                b += 'a' - 'A';
            if (a != b)
                break;
        }
        if (!part[i])
            return TRUE;
    }
    return FALSE;
}

int main(int argc, char **argv)
{
    const char *part = argc > 1 ? argv[1] : "";
    HANDLE snapshot, process;
    PROCESSENTRY32 entry;
    DWORD handles = 0, matched = 0;

    snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snapshot == INVALID_HANDLE_VALUE)
    {
        printf("the process snapshot: error %lu\n", GetLastError());
        return 1;
    }
    entry.dwSize = sizeof(entry);
    if (Process32First(snapshot, &entry))
    {
        do
        {
            if (!contains(entry.szExeFile, part))
                continue;
            matched++;
            process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, entry.th32ProcessID);
            if (process && GetProcessHandleCount(process, &handles))
                printf("%lu %s handles %lu\n", entry.th32ProcessID, entry.szExeFile, handles);
            else
                printf("%lu %s handles: error %lu\n", entry.th32ProcessID, entry.szExeFile, GetLastError());
            if (process)
                CloseHandle(process);
        } while (Process32Next(snapshot, &entry));
    }
    CloseHandle(snapshot);
    printf("processes matching '%s': %lu\n", part, matched);
    return 0;
}
