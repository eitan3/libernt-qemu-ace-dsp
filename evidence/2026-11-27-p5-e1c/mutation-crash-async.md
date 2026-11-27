# Mutation check of tests/qtest/intel-hda-ace-test.c (2026-11-27T21:16:21Z)

Model `61174d3c3` (qtest: the crash-async row reads the pending bit); 59 mutations, one per row (ONLY=fault-crash-async: the rows whose name matches); a clean run is 17 cases.

| # | mutation | what it breaks | qtest result | red cases |
|---|---|---|---|---|
| 1 | fault-crash-async-silent | crash-async=<ms>: the exception is never posted (the timer returns before it) | KILLED | crash-async (test line 1532) test_crash_async: assertion failed (r4(ACE_XTDR) == NOTIFY_EXCEPTION): (453509120 == 2601123840) -- the run aborted there: cases 15-17 not evaluated |
| 2 | fault-crash-async-answers | crash-async=<ms>: the firmware answers requests after its exception | KILLED | crash-async (test line 1541) test_crash_async: assertion failed (r4(ACE_XIDA) & ACE_BUSY == 0): (2147483648 == 0) -- the run aborted there: cases 15-17 not evaluated |

2 mutations: 2 killed (0 of them by an abort), **0 survived**, 0 not applied, 0 build failures.
