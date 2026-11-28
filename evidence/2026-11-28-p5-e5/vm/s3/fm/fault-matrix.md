
## Checks beyond "bounded" (2026-11-28T17:07:10Z)

| row | the driver's terminal line | after N us | N' - N - M (us) | serial booting -> line (s) | observed - N (ms) | elapsed ok | bugcheck | hang | recovery |
|---|---|---|---|---|---|---|---|---|---|
| fm-abi=2 | boot ABI mismatch after 7413 us (clock 18859310 us): state failed, failed in FW_READY wait (ABI mismatch), ROM status 0x00000005 firmware entered, ROM | 7413 | 202 | 0.000 | -7.4 | yes | 0 | 0 | boot ok |
| fm-bad-tuples | boot bad IPC reply after 7524 us (clock 19776082 us): state failed, failed in configuring (bad IPC reply), ROM status 0x00000005 firmware entered, ROM | 7524 | 101 | 0.000 | -7.5 | yes | 0 | 0 | boot ok |
| fm-crash-notification | boot firmware crash after 6897 us (clock 19112812 us): state failed, failed in FW_READY wait (firmware crash), ROM status 0x00000005 firmware entered, | 6897 | 101 | 0.000 | -6.9 | yes | 0 | 0 | boot ok |
| fm-drop-requests | boot IPC reply timeout after 507061 us (clock 20697913 us): state failed, failed in configuring (IPC reply timeout), ROM status 0x00000005 firmware en | 507061 | 101 | 0.516 | 8.9 | yes | 0 | 0 | boot ok |
| fm-halt-fw=51 | boot ROM error after 6350 us (clock 20664067 us): state failed, failed in loading (ROM error), ROM status 0x8000002a ROM firmware code loaded, ROM err | 6350 | 101 | 0.000 | -6.3 | yes | 0 | 0 | boot ok |
| fm-halt-rom=43 | boot ROM error after 8400 us (clock 21187985 us): state failed, failed in ROM init (ROM error), ROM status 0x80000009 ROM purge boot, ROM error 0x0000 | 8400 | 101 | 0.000 | -8.4 | yes | 0 | 0 | boot ok |
| fm-halt-rom=44 | boot ROM error after 8400 us (clock 19448262 us): state failed, failed in ROM init (ROM error), ROM status 0x80000009 ROM purge boot, ROM error 0x0000 | 8400 | 101 | 0.000 | -8.4 | yes | 0 | 0 | boot ok |
| fm-ipc-status=5 | boot IPC error after 7523 us (clock 21132344 us): state failed, failed in configuring (IPC error), ROM status 0x00000005 firmware entered, ROM error 0 | 7523 | 102 | 0.016 | 8.5 | yes | 0 | 0 | boot ok |
| fm-never-ack | boot ROM init timeout after 1509079 us (clock 21699459 us): state failed, failed in ROM init (ROM init timeout), ROM status 0x00000000 init, ROM error | 1509079 | 102 | 1.500 | -9.1 | yes | 0 | 0 | boot ok |
| fm-never-enter | boot base firmware timeout after 3004771 us (clock 21854590 us): state failed, failed in loading (base firmware timeout), ROM status 0x0000002a ROM fi | 3004771 | 203 | 3.000 | -4.8 | yes | 0 | 0 | boot ok |
| fm-never-fwready | boot FW_READY timeout after 1006686 us (clock 20089154 us): state failed, failed in FW_READY wait (FW_READY timeout), ROM status 0x00000005 firmware e | 1006686 | 101 | 1.000 | -6.7 | yes | 0 | 0 | boot ok |
| fm-never-power | boot power-up timeout after 52527 us (clock 20329085 us): state failed, failed in powering up (power-up timeout), ROM status 0x00000000 init, ROM erro | 52527 | 102 | 0.047 | -5.5 | yes | 0 | 0 | boot ok |
| fm-never-ready | boot ROM status timeout after 909455 us (clock 20990383 us): state failed, failed in ROM init (ROM status timeout), ROM status 0x00000009 ROM purge bo | 909455 | 101 | 0.906 | -3.5 | yes | 0 | 0 | boot ok |
| fm-never-reply | boot IPC reply timeout after 506998 us (clock 19888679 us): state failed, failed in configuring (IPC reply timeout), ROM status 0x00000005 firmware en | 506998 | 102 | 0.500 | -7.0 | yes | 0 | 0 | boot ok |
| fm-none | boot ok after 5530 us (clock 20093287 us): state ready, failed in off (ok), ROM status 0x00000005 firmware entered, ROM error 0x00000000 unknown ROM e | 5530 | 101 | 0.000 | -5.5 | yes | 0 | 0 | boot ok |
| fm-none-scale0.001 | boot ROM error after 4845 us (clock 21211981 us): state failed, failed in loading (ROM error), ROM status 0xa0000005 firmware entered, ROM error 0x000 | 4845 | 101 | 0.000 | -4.8 | yes | 0 | 0 | boot ok |
| fm-none-scale1550 | boot power-up timeout after 52141 us (clock 19317190 us): state failed, failed in powering up (power-up timeout), ROM status 0x00000000 init, ROM erro | 52141 | 202 | 0.062 | 9.9 | yes | 0 | 0 | boot ok |
| fm-truncated-reply | boot truncated after 7531 us (clock 19740403 us): state failed, failed in configuring (truncated), ROM status 0x00000005 firmware entered, ROM error 0 | 7531 | 101 | 0.000 | -7.5 | yes | 0 | 0 | boot ok |
| fm-version-shift | boot version mismatch after 7534 us (clock 20363270 us): state failed, failed in configuring (version mismatch), ROM status 0x00000005 firmware entere | 7534 | 101 | 0.016 | 8.5 | yes | 0 | 0 | boot ok |
| fm-window-read-fail | boot ABI mismatch after 6906 us (clock 19939999 us): state failed, failed in FW_READY wait (ABI mismatch), ROM status 0x00000005 firmware entered, ROM | 6906 | 100 | 0.000 | -6.9 | yes | 0 | 0 | boot ok |

0 row(s) with a failed check.
