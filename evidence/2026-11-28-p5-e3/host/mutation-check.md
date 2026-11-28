# Mutation check of tests/qtest/intel-hda-ace-test.c (2026-11-28T03:10:49Z)

Model `aad450422` (qtest: the one-channel change keeps the other channel at its); 61 mutations, one per row (ONLY=gain-: the rows whose name matches); a clean run is 18 cases.

| # | mutation | what it breaks | qtest result | red cases |
|---|---|---|---|---|
| 1 | gain-never-scales | the gain module forwards every sample untouched: a volume change is answered and does nothing | KILLED | audio-gain (test line 1509) check_capture_gain: assertion failed (labs((long)(capture - expected)) <= 1): (498813 <= 1) |
| 2 | gain-never-known | no module is the gain: its initialization's entry is not read and a volume change is refused | BUILD FAILED: build FAILED: ninja FAILED: [code=1] libsystem.a.p/hw_audio_intel-hda-ace.c.o  ../src/qemu-11.1.3/hw/audio/intel-hda-ace | - |

2 mutations: 1 killed (0 of them by an abort), **0 survived**, 0 not applied, 1 build failures.
