# Mutation check of tests/qtest/intel-hda-ace-test.c (2026-11-27T18:16:06Z)

Model `e6fb5f25a` (tests/qtest: intel-hda-ace: the knobs that act while a strea); 57 mutations, one per row (ONLY=fault-(never-reply-running-all|crash-one-late): the rows whose name matches); a clean run is 16 cases.

| # | mutation | what it breaks | qtest result | red cases |
|---|---|---|---|---|
| 1 | fault-never-reply-running-all | never-reply-running=<type> drops the type's requests before a stream runs too (the stream condition gone) | KILLED | stream-faults (test line 1462) test_stream_faults: assertion failed (ipc(0, PPL_STATE(1, PPL_PAUSED)) == PPL_REPLY(IPC4_SET_PIPELINE_STATE, 0)): (822083584 == 3003121664) -- the run aborted there: cases 14-16 not evaluated |
| 2 | fault-crash-one-late | crash-during-stream=<n> crashes one reply late | KILLED | stream-faults (test line 1493) test_stream_faults: assertion failed (r4(ACE_XIDA) & ACE_BUSY == 0): (2147483648 == 0) -- the run aborted there: cases 14-16 not evaluated |

2 mutations: 2 killed (0 of them by an abort), **0 survived**, 0 not applied, 0 build failures.
