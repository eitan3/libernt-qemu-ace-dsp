
| knob | at open | fault during stream | the pin told | release | the pin's free | the run | the second run |
|---|---|---|---|---|---|---|---|
| never-reply-running=19 | 1 | fault during stream 1: reply timeout after 500 ms | 6 | release: 2 streams let go, 2 buffers held for their pins, 2 tags back | 6 | dsploop: 1300 tests executed (0 marked as todo, 0 failures), 0 skipped. | PASS |
| crash-during-stream=1 | 1 | **none** | 0 | **none** | 0 | dsploop: 1297 tests executed (0 marked as todo, 0 failures), 0 skipped. | PASS |
| crash-during-stream=2 | 1 | **none** | 0 | **none** | 0 | dsploop: 1300 tests executed (0 marked as todo, 0 failures), 0 skipped. | PASS |
| crash-async=500 | 1 | fault during stream 1: firmware crash with no request outstanding, read at a stream's period | 2 | release: 2 streams let go, 2 buffers held for their pins, 2 tags back | 2 | dsploop: 329 tests executed (0 marked as todo, 2 failures), 0 skipped. | PASS |
