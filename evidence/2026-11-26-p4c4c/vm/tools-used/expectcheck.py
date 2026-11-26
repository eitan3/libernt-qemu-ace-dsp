#!/usr/bin/env python3
"""expectcheck.py -- TESTING.md's (p4c4c's) expected lines against what the p4c4c round measured.

   expectcheck.py <evidence-dir>/vm

Writes expected-vs-measured.txt there: one row per expected line or shape.  A fixed line is
looked up byte for byte (after the serial log's ANSI escapes, NULs and CRs were removed and
the guest's timestamp prefix) in every VM whose serial.txt exists; "RE:" rows are extended
regexes; "FILE:" rows count a substring in a named file of the VM directory (the text the
guest wrote to its data disk).  The apitest's summary lines are also given to the gate rule
(tools/apitest-gate.sh of the staging tooling) and its verdict is printed.
"""
import glob
import os
import re
import subprocess
import sys

GATE = os.path.expanduser('~/libernt-build-logs/tools/apitest-gate.sh')


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
    runs = sorted(os.path.basename(d) for d in glob.glob(os.path.join(vm, 'r*')) if os.path.isdir(d) and os.path.exists(os.path.join(d, 'serial.txt')))
    data = {r: serial(os.path.join(vm, r)) for r in runs}
    out = []
    w = out.append
    w('# TESTING.md (p4c4c\'s) expected lines against what the p4c4c round measured')
    w('# A fixed line is looked up as it is written (TESTING.md quotes it without the timestamp); "RE:" rows are extended regexes;')
    w('# "FILE:<name>:" rows count a substring in the named file of the VM directory (the text the guest wrote to its data disk).')
    w('# The VMs: ' + ', '.join(runs))
    w('# A count is the number of lines of that VM\'s serial log (or of the named file) that carry it.')
    w('')

    def table(title, rows):
        w('## ' + title)
        w('')
        w('| expected | ' + ' | '.join(runs) + ' |')
        w('|---|' + '---|' * len(runs))
        for label, item in rows:
            cells = []
            for r in runs:
                if item.startswith('FILE:'):
                    _, name, sub = item.split(':', 2)
                    n = text(os.path.join(vm, r), name).count(sub)
                elif item.startswith('RE_FILE:'):
                    _, name, pat = item.split(':', 2)
                    n = sum(1 for l in text(os.path.join(vm, r), name).split('\n') if re.search(pat, l))
                else:
                    n = count(data[r], item)
                cells.append('**%d**' % n if n else '0')
            w('| `%s` | %s |' % (label.replace('|', '\\|'), ' | '.join(cells)))
        w('')

    table('A1: the first boot (upstream\'s swenum fix in this image)', [
        ('swenum: KsCreateBusEnumObject Devices BusDeviceObject', 'KsCreateBusEnumObject Devices BusDeviceObject'),
        ('umpnpmgr: Safe removal: ROOT\\SYSTEM\\0000 (the step at which p4c4b bugchecked)', 'Safe removal: ROOT\\SYSTEM\\0000'),
        ('base\\setup\\libernt: Storage expansion not offered (the Setup phase)', 'Storage expansion not offered'),
        ('The system has been stopped (a bugcheck)', 'The system has been stopped'),
        ('Storport: a request ... timed out (the environment of the first launch)', 'Storport: a request'),
    ])
    table('A3 / B4: the system boot with BootDsp = 1 and the topology', [
        ("BootDsp = 1: the DSP is booted at the next D0 entry with 'sof-arl-s.ri'", "intcdsp.sys: BootDsp = 1: the DSP is booted at the next D0 entry with 'sof-arl-s.ri'"),
        ('boot ok after <us> ... attempt 1, 0 DSP interrupts, cleanup ok', 'RE:intcdsp\\.sys: boot ok after \\d+ us \\(clock \\d+ us\\): .*attempt 1, 0 DSP interrupts, cleanup ok'),
        ('firmware ready: version 2.15.0.1, ABI 1', 'intcdsp.sys: firmware ready: version 2.15.0.1, ABI 1'),
        ('E17: downlink mailbox 4096 bytes, uplink mailbox 4096 bytes', 'downlink mailbox 4096 bytes, uplink mailbox 4096 bytes'),
        ("topology 'sof-ipc4-loopback.tplg': ABI 3.29.1, 4286 bytes (model 2384 bytes), ... from the registry override",
         "intcdsp.sys: topology 'sof-ipc4-loopback.tplg': ABI 3.29.1, 4286 bytes (model 2384 bytes), 2 controls, 4 widgets, 2 edges, 1 pcm, 1 pipeline, 0 manifest items, from the registry override"),
        ("topology: modules copier → id 5, gain → id 7; endpoint 'Loopback' render+capture 48000 Hz 2 ch 16/24/32",
         "intcdsp.sys: topology: modules copier → id 5, gain → id 7; endpoint 'Loopback' render+capture 48000 Hz 2 ch 16/24/32"),
        ("audio child 'INTCDSP\\PCM&CTLR_VEN_8086&CTLR_DEV_7F50\\00' for pcm 'Loopback': 2 endpoints",
         "intcdsp.sys: audio child 'INTCDSP\\PCM&CTLR_VEN_8086&CTLR_DEV_7F50\\00' for pcm 'Loopback': 2 endpoints"),
        ("endpoint 'Loopback' render: registered as 'LoopbackTopo'", "dsppcm.sys: endpoint 'Loopback' render: registered as 'LoopbackTopo'"),
        ("endpoint 'Loopback' render: registered as 'LoopbackWave'", "dsppcm.sys: endpoint 'Loopback' render: registered as 'LoopbackWave'"),
        ("endpoint 'Loopback' capture: registered as 'LoopbackInTopo'", "dsppcm.sys: endpoint 'Loopback' capture: registered as 'LoopbackInTopo'"),
        ("endpoint 'Loopback' capture: registered as 'LoopbackInWave'", "dsppcm.sys: endpoint 'Loopback' capture: registered as 'LoopbackInWave'"),
    ])
    table('B4: the names complete in MMDevices (reg-mmdev.txt, the data disk)', [
        ("{026E516E-…},2 = 'Speakers - Intel SST Loopback' (DEVPKEY_DeviceInterface_FriendlyName)", 'FILE:reg-mmdev.txt:REG_SZ    Speakers - Intel SST Loopback'),
        ("{026E516E-…},2 = 'Microphone - Intel SST Loopback'", 'FILE:reg-mmdev.txt:REG_SZ    Microphone - Intel SST Loopback'),
        ("{A45C254E-…},14 = 'Speakers (Speakers - Intel SST Loopback)'", 'FILE:reg-mmdev.txt:Speakers (Speakers - Intel SST Loopback)'),
        ("{A45C254E-…},14 = 'Microphone (Microphone - Intel SST Loopback)'", 'FILE:reg-mmdev.txt:Microphone (Microphone - Intel SST Loopback)'),
        ('the legacy endpoints beside them: HD Audio Line out / Line in', 'FILE:reg-mmdev.txt:HD Audio Line'),
        ('a name cut at 31 characters (p4c4b2\'s D3: "Intel Smart Sound DS" / "Microphone - Intel Smart Sound ")', 'FILE:reg-mmdev.txt:Intel Smart Sound'),
    ])
    table("B5: the stream through the audio stack (dsploop-out.txt: LIBERNT_APITEST_REQUIRED=1, run from the system disk)", [
        ("the identity line, render: endpoint is of the DSP's PCM: filter ...intcdsp#pcm&ctlr_ven_8086&ctlr_dev_7f50...loopbacktopo",
         'FILE:dsploop-out.txt:endpoint is of the DSP\'s PCM: filter {2}.\\\\?\\intcdsp#pcm&ctlr_ven_8086&ctlr_dev_7f50#5&4d9fad45&0&00#{6994ad04-93ef-11d0-a3cc-00a0c9223196}\\loopbacktopo'),
        ("the identity line, capture: ...loopbackintopo",
         'FILE:dsploop-out.txt:endpoint is of the DSP\'s PCM: filter {2}.\\\\?\\intcdsp#pcm&ctlr_ven_8086&ctlr_dev_7f50#5&4d9fad45&0&00#{6994ad04-93ef-11d0-a3cc-00a0c9223196}\\loopbackintopo'),
        ("the legacy endpoint told apart: endpoint is not of the DSP's PCM: filter ...hdaudio#func_01...", 'FILE:dsploop-out.txt:endpoint is not of the DSP\'s PCM: filter {2}.\\\\?\\hdaudio#func_01'),
        ('16 valid bits: 48000 frames compared within 1 LSB, max abs error 0, offset <k>, ok (TESTING.md: "max abs error <= 1 LSB (tolerance 1)")',
         'RE_FILE:dsploop-out.txt:dsploop: 48000 frames compared within 1 LSB, max abs error 0, offset \\d+, ok'),
        ('24-in-32: 48000 frames compared within 0 LSB, max abs error 0, offset <k>, ok', 'RE_FILE:dsploop-out.txt:dsploop \\(24 valid in 32\\): 48000 frames compared within 0 LSB, max abs error 0, offset \\d+, ok'),
        ('32: 48000 frames compared within 0 LSB, max abs error 0, offset <k>, ok', 'RE_FILE:dsploop-out.txt:dsploop \\(32\\): 48000 frames compared within 0 LSB, max abs error 0, offset \\d+, ok'),
        ('dsploop: 3 of 3 depths compared', 'FILE:dsploop-out.txt:3 of 3 depths compared'),
        ('the summary: dsploop: <n> tests executed (0 marked as todo, 0 failures), 0 skipped.', 'RE_FILE:dsploop-out.txt:dsploop: \\d+ tests executed \\(0 marked as todo, 0 failures\\), 0 skipped\\.'),
        ('0 preconditions missing under the switch', 'FILE:dsploop-out.txt:0 preconditions missing (LIBERNT_APITEST_REQUIRED=1, a failure)'),
        ('the exit code 0 (dsploop-rc.txt: the whole text is 0)', 'RE_FILE:dsploop-rc.txt:^0\\s*$'),
        ('a skipped chunk (0 expected under the switch)', 'FILE:dsploop-out.txt:Tests skipped'),
    ])
    table("B5, the data disk's own launches (E24: x-launch-pouch.txt by the long name, x-launch-short.txt by dsploop.exe; no switch)", [
        ('x-launch-pouch.txt: 3 of 3 depths compared', 'FILE:x-launch-pouch.txt:3 of 3 depths compared'),
        ('x-launch-pouch.txt: max abs error 0 (three depths)', 'FILE:x-launch-pouch.txt:max abs error 0'),
        ('x-launch-short.txt: 3 of 3 depths compared', 'FILE:x-launch-short.txt:3 of 3 depths compared'),
        ('x-launch-short.txt: max abs error 0 (three depths)', 'FILE:x-launch-short.txt:max abs error 0'),
        ("VM 1's launch by the long name: 'The system cannot find the path specified.'", 'FILE:x-launch-pouch.txt:The system cannot find the path specified'),
        ("VM 1's copy by the long name: 'The system cannot find the path specified.'", 'FILE:x-b-copy.txt:The system cannot find the path specified'),
    ])
    table('B6: the FIFO constraint (the serial lines of the apitest)', [
        ("endpoint 'Loopback' render: pin created, 48000 Hz 2 ch <b> in <w> bits", "dsppcm.sys: endpoint 'Loopback' render: pin created, 48000 Hz"),
        ("endpoint 'Loopback' capture: pin created, 48000 Hz 2 ch <b> in <w> bits", "dsppcm.sys: endpoint 'Loopback' capture: pin created, 48000 Hz"),
        ('stream <t>: latency: fifo <F> bytes, dsp estimate <D> bytes', 'RE:intcdsp\\.sys: stream \\d+: latency: fifo \\d+ bytes, dsp estimate \\d+ bytes'),
    ])
    table("B7: SelfTest = 2 (three runs and the summary)", [
        ('16-bit: 4096 frames captured after <ms> ms, offset <k> frames, max abs error 0, render rms 5794.253, capture rms 5794.253, ok',
         'RE:loopback self-test: 4096 frames captured after \\d+ ms, offset \\d+ frames, max abs error 0, render rms 5794\\.253, capture rms 5794\\.253, ok$'),
        ('24- and 32-bit: ... render rms 379742706.482, capture rms 379742706.482, ok',
         'RE:loopback self-test: 4096 frames captured after \\d+ ms, offset \\d+ frames, max abs error 0, render rms 379742706\\.482, capture rms 379742706\\.482, ok$'),
        ('3 runs, 3 matched, 0 failed, <n> requests, 0 notifications, 0 timeouts, 0 DSP interrupts, ok',
         'RE:loopback self-test: 3 runs, 3 matched, 0 failed, \\d+ requests, 0 notifications, 0 timeouts, 0 DSP interrupts, ok$'),
        ('ran (0x00000000), the DSP is left running', 'loopback self-test: ran (0x00000000), the DSP is left running'),
        ("a run's failures (not captured / failed)", 'RE:loopback self-test: .*(not captured|, failed$)'),
    ])
    table('A3: SelfTest = 0 at a system boot (no self-test line expected)', [
        ('SelfTest = 0, UseInterrupts = 0, IpcTimeoutMs = 500 ms', 'intcdsp.sys: SelfTest = 0, UseInterrupts = 0, IpcTimeoutMs = 500 ms'),
        ('loopback self-test: (0 expected in a SelfTest = 0 boot)', 'loopback self-test:'),
    ])
    table("C8: no Topology", [
        ('topology: none selected (no override, no quirk, no _DSD name); the DSP is powered down, no audio endpoint',
         'intcdsp.sys: topology: none selected (no override, no quirk, no _DSD name); the DSP is powered down, no audio endpoint'),
        ('DSP power down from state ready', 'DSP power down from state ready'),
        ('lines that must be absent (0 expected in r2): audio child', 'intcdsp.sys: audio child'),
        ('lines that must be absent (0 expected in r2): dsppcm.sys:', 'dsppcm.sys:'),
        ('the Media list while there is no topology: INTCDSP\\PCM lines (0 expected)', 'FILE:enum-media.txt:INTCDSP\\PCM'),
    ])
    table('C9 and the regression of the plan: the disable/enable cycles (cycles.log)', [
        ('## cycle c8-none', 'FILE:cycles.log:## cycle c8-none '),
        ('## cycle c9a-alone, c9b-alone (the DSP device alone)', 'FILE:cycles.log:## cycle c9'),
        ('## cycle ac3-1 ... ac3-22 (the regression)', 'FILE:cycles.log:## cycle ac3-'),
        ("a cycle's boot line: intcdsp.sys: boot ok after", 'FILE:cycles.log:intcdsp.sys: boot ok after'),
        ("a cycle's bounded timeout (0 expected): boot ... timeout after", 'FILE:cycles.log:timeout after'),
        ('a cycle\'s disable not seen (0 expected)', 'FILE:cycles.log:disable not seen'),
        ('Safe removal: CSAUDIO (a completed disable of the DSP device)', 'Safe removal: CSAUDIO'),
    ])
    table('C10/C11: the PnP cycles with the child present (the serial lines)', [
        ('DisableDeviceInstance(CSAUDIO (every disable asked of the DSP device)', 'DisableDeviceInstance(CSAUDIO'),
        ('Safe removal: CSAUDIO (the completed ones)', 'Safe removal: CSAUDIO'),
        ("dsppcm.sys: endpoint ... registered as (four per enable with the topology)", "RE:dsppcm\\.sys: endpoint 'Loopback' .*: registered as"),
        ('streams: released for the power-down', 'streams: released for the power-down'),
        ('RestartDeviceInstance / the codec\'s restart (N5-05)', 'RE:RestartDevice'),
    ])
    table("C10/C11: pnputil's and net's own texts (the data disk)", [
        ("C10 (the service running): Failed to disable device: A device attached to the system is not functioning.", 'FILE:x-c10-disable.txt:A device attached to the system is not functioning'),
        ("C11 (the service stopped): Device disabled successfully (x-c11-1-disable.txt)", 'FILE:x-c11-1-disable.txt:disabled successfully'),
        ("C11: the child gone while disabled: INTCDSP\\PCM lines in x-c11-1-media-disabled.txt (0 expected)", 'FILE:x-c11-1-media-disabled.txt:INTCDSP\\PCM'),
        ("C11: the service stop's own text (x-svc-stop.txt: 'stopped successfully')", 'FILE:x-svc-stop.txt:stopped successfully'),
        ("N5-05 (the service stopped): x-n5-05.txt", 'FILE:x-n5-05.txt:LiberNT PnP Utility'),
        ("N5-05 (the service running): x-n5-05-running.txt", 'FILE:x-n5-05-running.txt:LiberNT PnP Utility'),
    ])
    table('What no VM may show, and the clean end', [
        ('The system has been stopped', 'The system has been stopped'),
        ('Stop code:', 'Stop code:'),
        ('clock stalled', 'clock stalled'),
        ('interrupt storm', 'interrupt storm'),
        ('Entering sleep state S5 (the clean end)', 'Entering sleep state S5'),
    ])

    w('## The gate rule on every apitest log (tools/apitest-gate.sh: --required for dsploop-out.txt, the switch was set; the data disk\'s launches without)')
    w('')
    w('| VM | log | the rule |')
    w('|---|---|---|')
    for r in runs:
        for name, req in (('dsploop-out.txt', True), ('x-launch-pouch.txt', False), ('x-launch-short.txt', False)):
            p = os.path.join(vm, r, name)
            if os.path.exists(p) and text(os.path.join(vm, r), name).strip():
                cmd = ['bash', GATE] + (['--required'] if req else []) + [p]
                res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True)
                w('| %s | %s | %s (rc=%d) |' % (r, name, res.stdout.strip().split(': ', 1)[-1].replace('|', '\\|'), res.returncode))
    w('')
    w('## The latency lines of the stream (B6) in full')
    w('')
    for r in runs:
        ls = [l for l in data[r] if 'latency: fifo' in l]
        if ls:
            w('- %s: %d lines; fifo values: %s; dsp estimates: %s' % (
                r, len(ls),
                ', '.join(sorted(set(re.search(r'fifo (\d+) bytes', l).group(1) for l in ls))),
                ', '.join(sorted(set(re.search(r'dsp estimate (\d+) bytes', l).group(1) for l in ls)))))
    w('')
    w('## What pnputil and net answered (x-*.txt, the data disk\'s text; the first 300 characters of each)')
    w('')
    w('| VM | file | text |')
    w('|---|---|---|')
    for r in runs:
        for f in sorted(glob.glob(os.path.join(vm, r, 'x-*.txt'))):
            t = re.sub(r'\s+', ' ', text(os.path.dirname(f), os.path.basename(f)).strip())
            t = t.replace('LiberNT PnP Utility ', '')
            w('| %s | %s | %s |' % (r, os.path.basename(f), t[:300].replace('|', '\\|')))
    open(os.path.join(vm, 'expected-vs-measured.txt'), 'w').write('\n'.join(out) + '\n')
    print('expected-vs-measured.txt: %d lines' % (len(out) + 1))


if __name__ == '__main__':
    main()
