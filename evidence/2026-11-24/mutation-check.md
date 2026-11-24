# Mutation check of tests/qtest/intel-hda-ace-test.c (2026-11-24T10:45:14Z)

| # | mutation | what it breaks | qtest result | red cases |
|---|---|---|---|---|
| 3 | fsr-order | the ROM walk emits FW_LOADING_DONE before FW_CODE_TO_IMR | KILLED | not ok /x86_64/intel-hda-ace/boot-handshake - ERROR:../src/qemu-11.1.3/tests/qtest/intel-hda-ace-test.c:325:firmware_ready: assertion failed (r4(ACE_FSR) & 0x00ffffff == walk[i]): (41 == 40) |
| 4 | fsr-running | FW_ENTERED without the running bit, module ROM | KILLED | not ok /x86_64/intel-hda-ace/boot-handshake - ERROR:../src/qemu-11.1.3/tests/qtest/intel-hda-ace-test.c:330:firmware_ready: assertion failed (r4(ACE_FSR) == FSR_RUNNING): (5 == 2684354565) |
| 6 | tag-mask | the purge request's tag field read as bits 15:9 | KILLED | not ok /x86_64/intel-hda-ace/boot-handshake - ERROR:../src/qemu-11.1.3/tests/qtest/intel-hda-ace-test.c:470:test_boot_handshake: assertion failed (r0(HDA_ST_LPIB(OUT4)) == IMG_LEN - IMG_PAYLOAD): (0 == 36864) |
| 7 | cpd-length | the partition directory header length misread | KILLED | not ok /x86_64/intel-hda-ace/boot-handshake - ERROR:../src/qemu-11.1.3/tests/qtest/intel-hda-ace-test.c:322:firmware_ready: assertion failed (r4(ACE_FSR) == (0x5u << 24) | 0x25): (2147483685 == 83886117) |
| 8 | ame-magic | the module entry magic wrong | KILLED | not ok /x86_64/intel-hda-ace/boot-handshake - ERROR:../src/qemu-11.1.3/tests/qtest/intel-hda-ace-test.c:322:firmware_ready: assertion failed (r4(ACE_FSR) == (0x5u << 24) | 0x25): (2147483688 == 83886117) |
| 9 | rom-control-target | ROM control detected by the type bit alone (module messages too) | KILLED | not ok /x86_64/intel-hda-ace/boot-handshake - ERROR:../src/qemu-11.1.3/tests/qtest/intel-hda-ace-test.c:475:test_boot_handshake: assertion failed (reply == IPC4_REPLY_DONE_OK): (0 == 3774873600) |
| 10 | running-guard | the FW_READY step skipped once the firmware runs | KILLED | not ok /x86_64/intel-hda-ace/boot-handshake - ERROR:../src/qemu-11.1.3/tests/qtest/intel-hda-ace-test.c:333:firmware_ready: assertion failed (r4(ACE_XTDR) == NOTIFY_FW_READY): (0 == 2600992768) |
| 13 | personality-id | the default personality's PCI id | **SURVIVED** | - |
| 16 | core-before-subsys | a core request made before the subsystem is up is dropped | KILLED | not ok /x86_64/intel-hda-ace/boot-handshake - ERROR:../src/qemu-11.1.3/tests/qtest/intel-hda-ace-test.c:274:power_up: assertion failed (r4(ACE_DSP2CXCTL) & ACE_DSP2CXCTL_CPA == ACE_DSP2CXCTL_CPA): (0 == 256) |
| 17 | reply-dir |  (status \& ACE_IPC4_REPLY_STATUS_MASK),/                  (status \& ACE_IPC4_REPLY_STATUS_MASK),/|the reply's direction bit missing | NOT APPLIED (sed matched nothing) | - |
| 18 | abi-fault | the abi= fault not applied to the register block | KILLED | not ok /x86_64/intel-hda-ace/faults - ERROR:../src/qemu-11.1.3/tests/qtest/intel-hda-ace-test.c:667:check_fault: assertion failed (r4(ACE_WIN0 + ACE_FW_ABI_VER) == f->win0_abi): (1 == 2) |
| 19 | init-done-delay | INIT_DONE 200 us early | KILLED | not ok /x86_64/intel-hda-ace/boot-handshake - ERROR:../src/qemu-11.1.3/tests/qtest/intel-hda-ace-test.c:289:rom_ready: assertion failed (r4(ACE_FSR) == 0x09): (1 == 9) |
| 20 | fw-ready-delay | FW_READY 100 us early | KILLED | not ok /x86_64/intel-hda-ace/irq-intx - ERROR:../src/qemu-11.1.3/tests/qtest/intel-hda-ace-test.c:585:check_irq: assertion failed (r4(ACE_XTDR) == 0): (2600992768 == 0) |
| 21 | purge-tag-plus | the purge tag off by one | KILLED | not ok /x86_64/intel-hda-ace/boot-handshake - ERROR:../src/qemu-11.1.3/tests/qtest/intel-hda-ace-test.c:470:test_boot_handshake: assertion failed (r0(HDA_ST_LPIB(OUT4)) == IMG_LEN - IMG_PAYLOAD): (0 == 36864) |
| 22 | win0-mirror | window 0 no longer mirrors the FSR | KILLED | not ok /x86_64/intel-hda-ace/faults - ERROR:../src/qemu-11.1.3/tests/qtest/intel-hda-ace-test.c:666:check_fault: assertion failed (r4(ACE_WIN0) == f->win0): (0 == 42) |

The rows above marked NOT APPLIED were redone with exact string replacement (the sed expressions had lost to quoting):

| mutation | what it breaks | qtest result | red cases |
|---|---|---|---|
| ack-sense | the host's acknowledgement of a notification never clears BUSY | KILLED | /x86_64/intel-hda-ace/boot-handshake - |
| done-polarity | the DONE bit is never cleared by the host | KILLED | /x86_64/intel-hda-ace/boot-handshake - |
| spib-cut | SPIB ignored: the ROM consumes the whole buffer | KILLED | /x86_64/intel-hda-ace/faults - |
| irq-gating | the busy interrupt enable ignored | KILLED | /x86_64/intel-hda-ace/irq-intx - |
| powered-down | x-powered-down-value ignored | KILLED | /x86_64/intel-hda-ace/power-down - |
| version-stream | the reply's version hardcoded instead of read from the stream | KILLED | /x86_64/intel-hda-ace/boot-handshake - |
| delay-scale | x-delay-scale ignored | KILLED | /x86_64/intel-hda-ace/faults - |
| reply-dir | the reply's direction bit missing | KILLED | /x86_64/intel-hda-ace/boot-handshake - |

8 redone, 0 survived. The one survivor of the first table (personality-id) is an equivalent mutant: the class default is overwritten by the personality in realize.
