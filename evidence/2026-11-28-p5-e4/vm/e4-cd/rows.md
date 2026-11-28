# E4 step 0 on p5e3 (the unchanged image ae97c6a7a3e), VM e4-cd, 2026-11-28 06:18-06:47 +02:00

The overlay p5e3.qcow2 as the E3 round left it (SelfTest = 3, BootDsp = 1, DspIdleSec = 3, the loopback
topology); the boot's self-test 6 runs matched, its three gain rows counted 3 by the script's own `ok$` count
(vmcommon.sh's norm strips the CR now: N13-10), the DSP down by idle at guest 11.3 s.

| row | what | the lines / the screen | result |
|---|---|---|---|
| (c) | the system volume keys (2 % a step) and the mute key, "Speakers - Intel SST Loopback" made the default render device in mmsys.cpl's Playback page (19, 20-setdefault) | `gain: -2.00 dB, mute 0, kept until the DSP runs the PCM again`, `-4.00`, `-6.00`, `-8.00`, then `gain: -8.00 dB, mute 1, kept ...`; the OSD at 92 (26-osd), the muted OSD (27-osd-muted) | **PASS**: every key one line, the dB and the mute as the key asks |
| (c) | mmsys.cpl's Volume tab | its slider and mute are mixer device 0's: "Speakers (HD Audio Line out)" (11-volume-tab); the DSP's endpoint has no slider in that applet; sndvol32 (12, 13) would not take the keyboard | **NOT the DSP's** (a finding, N14) |
| (d1) | the level -8 dB kept through the idle power-down (the DSP down by idle since the boot) | `boot ok after 5452 us`, `boot at stream open: ok after 6 ms`, `gain: -8.00 dB, mute 0`; dsploop: `no frame within 48000 matches the tone's first cycle ... the tone was not captured (96000 frames)`, 0 of 3 | **PASS** by the lines: the level re-sent at the open, the stream at that level (dsploop compares against the unscaled tone) |
| (d2) | the level back at unity by the keys (`gain: 0.00 dB, mute 0, kept ...`), the idle power-down, the next open | `boot at stream open: ok after 6 ms`, `gain: 0.00 dB, mute 0`; dsploop: three rows `48000 frames compared within 0/1 LSB, max abs error 0`, `3 of 3 depths compared`, `1294 tests executed (0 marked as todo, 0 failures), 0 skipped` | **PASS** |

Not driven: the mute flag across an idle power-down (unmuted before (d1)); the self-test after an idle
power-down (it runs at a D0 entry alone on this image).
