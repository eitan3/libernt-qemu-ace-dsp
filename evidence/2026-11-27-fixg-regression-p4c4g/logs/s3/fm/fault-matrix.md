
## Checks beyond "bounded" (2026-11-27T14:53:19Z)

| row | the driver's terminal line | after N us | N' - N - M (us) | serial booting -> line (s) | observed - N (ms) | elapsed ok | bugcheck | hang | recovery |
|---|---|---|---|---|---|---|---|---|---|
| fm-abi=2 | boot ABI mismatch after 6834 us (clock 19516815 us): state failed, failed in FW_READY wait (ABI mismatch), ROM status 0x00000005 firmware entered, ROM | 6834 | 95 | 0.000 | -6.8 | yes | 0 | 0 | boot ok |
| fm-bad-tuples | boot bad IPC reply after 7659 us (clock 19798538 us): state failed, failed in configuring (bad IPC reply), ROM status 0x00000005 firmware entered, ROM | 7659 | 188 | 0.016 | 8.3 | yes | 0 | 0 | boot ok |
| fm-crash-notification | boot firmware crash after 6831 us (clock 20140795 us): state failed, failed in FW_READY wait (firmware crash), ROM status 0x00000005 firmware entered, | 6831 | 95 | 0.000 | -6.8 | yes | 0 | 0 | boot ok |
| fm-drop-requests | boot IPC reply timeout after 507028 us (clock 20395127 us): state failed, failed in configuring (IPC reply timeout), ROM status 0x00000005 firmware en | 507028 | 95 | 0.500 | -7.0 | yes | 0 | 0 | boot ok |
| fm-halt-fw=51 | boot ROM error after 6573 us (clock 19621947 us): state failed, failed in loading (ROM error), ROM status 0x8000002a ROM firmware code loaded, ROM err | 6573 | 187 | 0.016 | 9.4 | yes | 0 | 0 | boot ok |
| fm-halt-rom=43 | boot ROM error after 8336 us (clock 20160816 us): state failed, failed in ROM init (ROM error), ROM status 0x80000009 ROM purge boot, ROM error 0x0000 | 8336 | 95 | 0.000 | -8.3 | yes | 0 | 0 | boot ok |
| fm-halt-rom=44 | boot ROM error after 8336 us (clock 20033912 us): state failed, failed in ROM init (ROM error), ROM status 0x80000009 ROM purge boot, ROM error 0x0000 | 8336 | 95 | 0.000 | -8.3 | yes | 0 | 0 | boot ok |
| fm-ipc-status=5 | boot IPC error after 10111 us (clock 19077432 us): state failed, failed in configuring (IPC error), ROM status 0x00000005 firmware entered, ROM error  | 10111 | 750 | 0.000 | -10.1 | yes | 0 | 0 | boot ok |
| fm-never-ack | boot ROM init timeout after 1508901 us (clock 20719754 us): state failed, failed in ROM init (ROM init timeout), ROM status 0x00000000 init, ROM error | 1508901 | 94 | 1.516 | 7.1 | yes | 0 | 0 | boot ok |
| fm-never-enter | boot base firmware timeout after 3005267 us (clock 22495936 us): state failed, failed in loading (base firmware timeout), ROM status 0x0000002a ROM fi | 3005267 | 374 | 3.000 | -5.3 | yes | 0 | 0 | boot ok |
| fm-never-fwready | boot FW_READY timeout after 1007354 us (clock 20391953 us): state failed, failed in FW_READY wait (FW_READY timeout), ROM status 0x00000005 firmware e | 1007354 | 375 | 1.016 | 8.6 | yes | 0 | 0 | boot ok |
| fm-never-power | boot power-up timeout after 52063 us (clock 19293229 us): state failed, failed in powering up (power-up timeout), ROM status 0x00000000 init, ROM erro | 52063 | 188 | 0.047 | -5.1 | yes | 0 | 0 | boot ok |
| fm-never-ready | boot ROM status timeout after 909799 us (clock 20020142 us): state failed, failed in ROM init (ROM status timeout), ROM status 0x00000009 ROM purge bo | 909799 | 188 | 0.922 | 12.2 | yes | 0 | 0 | boot ok |
| fm-never-reply | boot IPC reply timeout after 507047 us (clock 20038016 us): state failed, failed in configuring (IPC reply timeout), ROM status 0x00000005 firmware en | 507047 | 93 | 0.500 | -7.0 | yes | 0 | 0 | boot ok |
| fm-none | boot ok after 6805 us (clock 19407519 us): state ready, failed in off (ok), ROM status 0x00000005 firmware entered, ROM error 0x00000000 unknown ROM e | 6805 | 375 | 0.000 | -6.8 | yes | 0 | 0 | boot ok |
| fm-none-scale0.001 | boot ROM error after 4786 us (clock 19381512 us): state failed, failed in loading (ROM error), ROM status 0xa0000005 firmware entered, ROM error 0x000 | 4786 | 93 | 0.016 | 11.2 | yes | 0 | 0 | boot ok |
| fm-none-scale1550 | boot power-up timeout after 52406 us (clock 19941619 us): state failed, failed in powering up (power-up timeout), ROM status 0x00000000 init, ROM erro | 52406 | 187 | 0.062 | 9.6 | yes | 0 | 0 | boot ok |
| fm-truncated-reply | boot truncated after 7445 us (clock 20128516 us): state failed, failed in configuring (truncated), ROM status 0x00000005 firmware entered, ROM error 0 | 7445 | 94 | 0.016 | 8.6 | yes | 0 | 0 | boot ok |
| fm-version-shift | boot version mismatch after 7456 us (clock 19949961 us): state failed, failed in configuring (version mismatch), ROM status 0x00000005 firmware entere | 7456 | 93 | 0.016 | 8.5 | yes | 0 | 0 | boot ok |
| fm-window-read-fail | boot ABI mismatch after 7163 us (clock 19793014 us): state failed, failed in FW_READY wait (ABI mismatch), ROM status 0x00000005 firmware entered, ROM | 7163 | 187 | 0.000 | -7.2 | yes | 0 | 0 | boot ok |

0 row(s) with a failed check.
