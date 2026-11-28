# Mutation check of tests/qtest/intel-hda-ace-test.c (2026-11-28T03:12:55Z)

Model `aad450422` (qtest: the one-channel change keeps the other channel at its); 61 mutations, one per row (ONLY=gain-never-known: the rows whose name matches); a clean run is 18 cases.

| # | mutation | what it breaks | qtest result | red cases |
|---|---|---|---|---|
| 1 | gain-never-known | no module is the gain: its initialization's entry is not read and a volume change replaces its configuration | BUILD FAILED: build FAILED: ninja FAILED: [code=1] libsystem.a.p/hw_audio_intel-hda-ace.c.o  ../src/qemu-11.1.3/hw/audio/intel-hda-ace | - |

1 mutations: 0 killed (0 of them by an abort), **0 survived**, 0 not applied, 1 build failures.
