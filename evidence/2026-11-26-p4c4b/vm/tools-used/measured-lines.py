#!/usr/bin/env python3
"""measured-lines.py -- the serial lines of the p4c4b round that carry the finding, per VM run and per guest
boot, from the collected serial.txt files (ANSI escapes, NULs and CRs already removed).

   measured-lines.py <out-file> <run-name>=<serial.txt> ...

A boot begins at the loader's "Pcr = " line (printed once a boot).  Kept per boot: the bus driver's
audio-path line and the DSP driver's settings line (the configuration), AudioSrv's notification
registration, swenum's bus device object line, the bugcheck's lines (stop code, the four parameters,
the backtrace, RIP and RAX), the HAL's reset, and for a boot that lives the first-boot setup's lines
and the sleep state.
"""
import re
import sys

KEEP = re.compile(r"hdaudbus\.sys: audio path|intcdsp\.sys: SelfTest = |'AudioSrv'|KsCreateBusEnumObject|"
                  r"First-boot setup lists|Storage expansion not offered|The system has been stopped|Stop code:|"
                  r"\s+Parameter [1-4]:|Backtrace:|#\d\d ntoskrnl|\] RIP=|\] RAX=|Dumping memory to storage:   0%|"
                  r"HAL: ACPI reset|Entering sleep state")


def main():
    out = [sys.argv[1]]
    lines = []
    for arg in sys.argv[2:]:
        name, path = arg.split('=', 1)
        lines.append('## %s' % name)
        boot = 0
        with open(path, errors='replace') as f:
            for i, l in enumerate(f, 1):
                l = l.rstrip('\n')
                if 'Pcr = ' in l:
                    boot += 1
                    lines.append('')
                    lines.append('### boot %d (serial.txt line %d)' % (boot, i))
                if boot and KEEP.search(l):
                    lines.append('%5d: %s' % (i, l.strip()[:230]))
        lines.append('')
    with open(out[0], 'w') as f:
        f.write('\n'.join(lines) + '\n')
    print('wrote %s: %d lines' % (out[0], len(lines)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
