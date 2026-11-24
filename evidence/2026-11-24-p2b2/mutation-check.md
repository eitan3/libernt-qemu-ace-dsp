# Mutation check of tests/qtest/intel-hda-ace-test.c -- the FSR rows (2026-11-24T19:29:23Z)

| mutation | what it breaks | qtest result | red cases |
|---|---|---|---|
| fsr-entry-running | FW_ENTERED carries the running bit in the same instant (the single-instant model the LiberNT driver read as a halt) | KILLED | not ok /x86_64/intel-hda-ace/boot-handshake: assertion failed (r4(ACE_FSR) == FSR_FW_ENTERED): (2684354565 == 5); |
| fw-running-early | the firmware's status word written with FW_READY (the ROM's FW_ENTERED no longer readable for a host poll) | KILLED | not ok /x86_64/intel-hda-ace/boot-handshake: assertion failed (r4(ACE_FSR) == FSR_FW_ENTERED): (2684354565 == 5); |
| fsr-running | the firmware never writes its running status word: the FSR stays the ROM's after entry | KILLED | not ok /x86_64/intel-hda-ace/boot-handshake: assertion failed (r4(ACE_FSR) == FSR_RUNNING): (5 == 2684354565); |
restored: dirty 0; qtest on the restored model:
ok 1 /x86_64/intel-hda-ace/enumerate ok 2 /x86_64/intel-hda-ace/caps ok 3 /x86_64/intel-hda-ace/stock-controllers ok 4 /x86_64/intel-hda-ace/boot-handshake ok 5 /x86_64/intel-hda-ace/power-down ok 6 /x86_64/intel-hda-ace/irq-intx ok 7 /x86_64/intel-hda-ace/irq-msi ok 8 /x86_64/intel-hda-ace/faults 
