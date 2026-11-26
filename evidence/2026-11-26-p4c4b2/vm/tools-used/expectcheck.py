#!/usr/bin/env python3
"""expectcheck.py -- TESTING.md's (p4c4b's) expected lines against what the p4c4b2 round measured.

   expectcheck.py <evidence-dir>/vm

Writes expected-vs-measured.txt there: one row per expected line or shape.  A fixed line is
looked up byte for byte (after the serial log's ANSI escapes, NULs and CRs were removed and
the guest's timestamp prefix) in every VM whose serial.txt exists; a line with a variable is
an extended regex.  What the test program wrote is read from the VM directory's copy of the
data disk's text (dsploop-out.txt), what pnputil answered from attrib-*.txt.
"""
import glob
import os
import re
import sys


def serial(d):
    p = os.path.join(d, 'serial.txt')
    return [re.sub(r'^\[\s*[0-9.]+\] ', '', l.rstrip('\n')) for l in open(p, errors='replace')] if os.path.exists(p) else []


def text(d, name):
    p = os.path.join(d, name)
    return open(p, errors='replace').read().replace('\r', '') if os.path.exists(p) else ''


def count(lines, item):
    if item.startswith('RE:'):
        return sum(1 for l in lines if re.search(item[3:], l))
    return sum(1 for l in lines if item in l)


def main():
    vm = sys.argv[1]
    runs = sorted(os.path.basename(d) for d in glob.glob(os.path.join(vm, 'r*')) if os.path.isdir(d))
    data = {r: serial(os.path.join(vm, r)) for r in runs}
    out = []
    w = out.append
    w('# TESTING.md (p4c4b\'s) expected lines against what the p4c4b2 round measured')
    w('# A fixed line is looked up as it is written (TESTING.md quotes it without the timestamp); "RE:" rows are extended regexes.')
    w('# The VMs: ' + ', '.join(runs))
    w('# A count is the number of lines of that VM\'s serial log that carry it.')
    w('')

    def table(title, rows):
        w('## ' + title)
        w('')
        w('| expected | ' + ' | '.join(runs) + ' |')
        w('|---|' + '---|' * len(runs))
        for label, item in rows:
            cells = []
            for r in runs:
                if data[r]:
                    n = count(data[r], item)
                    cells.append('**%d**' % n if n else '0')
                else:
                    cells.append('(not run)')
            w('| `%s` | %s |' % (label.replace('|', '\\|'), ' | '.join(cells)))
        w('')

    table('Run 0: the first boot (U1 fixed)', [
        ('swenum: KsCreateBusEnumObject Devices BusDeviceObject', 'KsCreateBusEnumObject Devices BusDeviceObject'),
        ('umpnpmgr: Safe removal: ROOT\\SYSTEM\\0000 (the removal that bugchecked on p4c4b)', 'Safe removal: ROOT\\SYSTEM\\0000'),
        ('base\\setup\\libernt: Storage expansion not offered', 'Storage expansion not offered'),
        ('The system has been stopped (a bugcheck)', 'The system has been stopped'),
    ])
    table('Run 1: BootDsp = 1 + Topology = sof-ipc4-loopback.tplg', [
        ("BootDsp = 1: the DSP is booted at the next D0 entry with 'sof-arl-s.ri'",
         "intcdsp.sys: BootDsp = 1: the DSP is booted at the next D0 entry with 'sof-arl-s.ri'"),
        ("topology 'sof-ipc4-loopback.tplg': ABI 3.29.1, 4286 bytes (model 2288 bytes), ... from the registry override",
         "intcdsp.sys: topology 'sof-ipc4-loopback.tplg': ABI 3.29.1, 4286 bytes (model 2288 bytes), 2 controls, 4 widgets, 2 edges, 1 pcm, 1 pipeline, 0 manifest items, from the registry override"),
        ("topology: modules copier → id 5, gain → id 7; endpoint 'Loopback' render+capture 48000 Hz 2 ch 16/24/32",
         "intcdsp.sys: topology: modules copier → id 5, gain → id 7; endpoint 'Loopback' render+capture 48000 Hz 2 ch 16/24/32"),
        ("audio child 'INTCDSP\\PCM&CTLR_VEN_8086&CTLR_DEV_7F50\\00' for pcm 'Loopback': 2 endpoints",
         "intcdsp.sys: audio child 'INTCDSP\\PCM&CTLR_VEN_8086&CTLR_DEV_7F50\\00' for pcm 'Loopback': 2 endpoints"),
        ("endpoint 'Loopback' render: 3 formats in 2 data ranges, -6291456..0 in 1/65536 dB by 65536",
         "dsppcm.sys: endpoint 'Loopback' render: 3 formats in 2 data ranges, -6291456..0 in 1/65536 dB by 65536"),
        ("endpoint 'Loopback' capture: 3 formats in 2 data ranges, -6291456..0 in 1/65536 dB by 65536",
         "dsppcm.sys: endpoint 'Loopback' capture: 3 formats in 2 data ranges, -6291456..0 in 1/65536 dB by 65536"),
        ("endpoint 'Loopback' render: registered as 'LoopbackTopo'", "dsppcm.sys: endpoint 'Loopback' render: registered as 'LoopbackTopo'"),
        ("endpoint 'Loopback' render: registered as 'LoopbackWave'", "dsppcm.sys: endpoint 'Loopback' render: registered as 'LoopbackWave'"),
        ("endpoint 'Loopback' capture: registered as 'LoopbackInTopo'", "dsppcm.sys: endpoint 'Loopback' capture: registered as 'LoopbackInTopo'"),
        ("endpoint 'Loopback' capture: registered as 'LoopbackInWave'", "dsppcm.sys: endpoint 'Loopback' capture: registered as 'LoopbackInWave'"),
        ("boot ok after <us> ... attempt 1, 0 DSP interrupts, cleanup ok", 'RE:intcdsp\\.sys: boot ok after \\d+ us \\(clock \\d+ us\\): .*attempt 1, 0 DSP interrupts, cleanup ok'),
        ("firmware ready: version 2.15.0.1, ABI 1", 'intcdsp.sys: firmware ready: version 2.15.0.1, ABI 1'),
        ("none of: not registered / not started / no audio interface / no endpoint / is not well-formed",
         'RE:not registered|not started|no audio interface|no endpoint|is not well-formed'),
    ])
    table("TESTING.md's run 2: SelfTest = 2 (its three runs and the summary)", [
        ('16-bit: 4096 frames captured after <ms> ms, offset <k> frames, max abs error 0, render rms 5794.253, capture rms 5794.253, ok',
         'RE:loopback self-test: 4096 frames captured after \\d+ ms, offset \\d+ frames, max abs error 0, render rms 5794\\.253, capture rms 5794\\.253, ok$'),
        ('24- and 32-bit: ... render rms 379742706.482, capture rms 379742706.482, ok',
         'RE:loopback self-test: 4096 frames captured after \\d+ ms, offset \\d+ frames, max abs error 0, render rms 379742706\\.482, capture rms 379742706\\.482, ok$'),
        ('3 runs, 3 matched, 0 failed, <n> requests, 0 notifications, 0 timeouts, 0 DSP interrupts, ok',
         'RE:loopback self-test: 3 runs, 3 matched, 0 failed, \\d+ requests, 0 notifications, 0 timeouts, 0 DSP interrupts, ok$'),
        ('ran (0x00000000), the DSP is left running', 'loopback self-test: ran (0x00000000), the DSP is left running'),
        ("a run's failures (not captured / failed)", 'RE:loopback self-test: .*(not captured|, failed$)'),
    ])
    table("TESTING.md's run 1, the stream: the lines of the apitest (the serial log)", [
        ("endpoint 'Loopback' capture: pin created, 48000 Hz 2 ch <b> in <w> bits", "dsppcm.sys: endpoint 'Loopback' capture: pin created, 48000 Hz"),
        ("endpoint 'Loopback' render: pin created, 48000 Hz 2 ch <b> in <w> bits", "dsppcm.sys: endpoint 'Loopback' render: pin created, 48000 Hz"),
        ('stream <t>: latency: fifo <F> bytes, dsp estimate <D> bytes', 'RE:intcdsp\\.sys: stream \\d+: latency: fifo \\d+ bytes, dsp estimate \\d+ bytes'),
    ])
    table("TESTING.md's run 3 (i): no Topology, from a fresh boot", [
        ('topology: none selected (no override, no quirk, no _DSD name); the DSP is powered down, no audio endpoint',
         'intcdsp.sys: topology: none selected (no override, no quirk, no _DSD name); the DSP is powered down, no audio endpoint'),
        ('lines that must be absent (0 expected in r4): audio child', 'intcdsp.sys: audio child'),
        ('lines that must be absent (0 expected in r4): dsppcm.sys:', 'dsppcm.sys:'),
    ])
    table("TESTING.md's run 3 (iii) and the brief's run 4: SelfTest = 0 at a system boot", [
        ('SelfTest = 0, UseInterrupts = 0, IpcTimeoutMs = 500 ms', 'intcdsp.sys: SelfTest = 0, UseInterrupts = 0, IpcTimeoutMs = 500 ms'),
        ('boot ok after <us> ... attempt 1, 0 DSP interrupts, cleanup ok', 'RE:intcdsp\\.sys: boot ok after \\d+ us \\(clock \\d+ us\\): .*attempt 1, 0 DSP interrupts, cleanup ok'),
        ("the topology line (with the Topology value kept)", "intcdsp.sys: topology 'sof-ipc4-loopback.tplg': ABI 3.29.1, 4286 bytes (model 2288 bytes)"),
        ('lines that must be absent at a SelfTest = 0 boot (0 in r2, r3, r4; r1 asked for none, r5 ran SelfTest = 2): loopback self-test:', 'loopback self-test:'),
    ])
    table('The disable attribution (TESTING.md\'s run 3 (ii)): the serial lines of a completed disable', [
        ('Safe removal: INTCDSP (the child alone)', 'Safe removal: INTCDSP'),
        ('Safe removal: HDAUDIO (the codec)', 'Safe removal: HDAUDIO'),
        ('Safe removal: CSAUDIO (the DSP device)', 'Safe removal: CSAUDIO'),
        ('DisableDeviceInstance(CSAUDIO (every disable asked of the DSP device)', 'DisableDeviceInstance(CSAUDIO'),
        ('DisableDeviceInstance(INTCDSP', 'DisableDeviceInstance(INTCDSP'),
        ('DisableDeviceInstance(HDAUDIO', 'DisableDeviceInstance(HDAUDIO'),
    ])
    table('What no VM may show', [
        ('The system has been stopped', 'The system has been stopped'),
        ('Stop code:', 'Stop code:'),
        ('clock stalled', 'clock stalled'),
        ('interrupt storm', 'interrupt storm'),
        ('Entering sleep state S5 (the clean end)', 'Entering sleep state S5'),
    ])
    w('## What the test program wrote (the data disk\'s text, copied into each VM directory)')
    w('')
    w('| VM | dsploop-out.txt | dsploop-rc.txt |')
    w('|---|---|---|')
    for r in runs:
        o = text(os.path.join(vm, r), 'dsploop-out.txt').strip().replace('\n', ' / ')
        c = text(os.path.join(vm, r), 'dsploop-rc.txt').strip()
        if o or c:
            note = ''
            if r.startswith('r1-') and c.strip() == '3' and not o:
                note = ' (ERROR_PATH_NOT_FOUND: the errorlevel of the command line that did not launch the test)'
            w('| %s | %s |%s |' % (r, o.replace('|', '\\|') or '(empty: 0 bytes)', c.replace('|', '\\|') + note))
    w('')
    w('## What pnputil answered (attrib-*.txt, the data disk\'s text)')
    w('')
    w('| VM | file | text |')
    w('|---|---|---|')
    for r in runs:
        for f in sorted(glob.glob(os.path.join(vm, r, 'attrib-*.txt'))):
            t = re.sub(r'\s+', ' ', text(os.path.dirname(f), os.path.basename(f)).strip())
            t = t.replace('LiberNT PnP Utility ', '')
            w('| %s | %s | %s |' % (r, os.path.basename(f), t.replace('|', '\\|')))
    w('')
    w('## The launch of the apitest from the data disk (x-launch-pouch.txt: the guest\'s own text)')
    w('')
    for r in runs:
        t = text(os.path.join(vm, r), 'x-launch-pouch.txt').strip()
        if t:
            w('- %s: `%s`' % (r, t))
    open(os.path.join(vm, 'expected-vs-measured.txt'), 'w').write('\n'.join(out) + '\n')
    print('expected-vs-measured.txt: %d lines' % (len(out) + 1))


if __name__ == '__main__':
    main()
