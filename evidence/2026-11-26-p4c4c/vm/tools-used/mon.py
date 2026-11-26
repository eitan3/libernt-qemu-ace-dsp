#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# qemu-ace-dsp: human-monitor (HMP) commands over the VM's unix socket.
#
#   mon.py <monitor.sock> 'screendump /path/shot.png format=png' ['info status' ...]
#   mon.py <monitor.sock> type "reg add HKLM\\... /v BootDsp /d 1 /f"   (one sendkey per character)
#   mon.py <monitor.sock> key ctrl-alt-delete                            (one chord)
#
# This work is licensed under the terms of the GNU GPL, version 2 or later.
# See the COPYING file in the top-level directory.
import os
import socket
import sys
import time


def connect(path):
    s = socket.socket(socket.AF_UNIX)
    s.connect(path)
    s.settimeout(1.5)
    try:
        s.recv(4096)  # the banner
    except OSError:
        pass
    return s


def hmp(s, cmd, wait=0.0, timeout=1.5):
    s.sendall((cmd + '\n').encode())
    if wait:
        time.sleep(wait)
    out = b''
    s.settimeout(timeout)
    try:
        # the monitor answers a command with its output followed by a new
        # prompt: stop there instead of waiting for the socket timeout
        while True:
            chunk = s.recv(65536)
            if not chunk:
                break
            out += chunk
            if out.rstrip().endswith(b'(qemu)'):
                break
    except socket.timeout:
        pass
    text = out.decode(errors='replace')
    # the monitor echoes the command (readline): keep only what follows the
    # last prompt, i.e. the command's own output
    return text.rsplit('(qemu) ', 1)[-1].strip()


# QEMU key names for the characters a command line needs (shift chords for
# the punctuation the US layout puts on the number row and the quote key).
KEYS = {
    ' ': 'spc', '\n': 'ret', '\t': 'tab', '\\': 'backslash', '/': 'slash',
    '.': 'dot', ',': 'comma', '-': 'minus', '=': 'equal', ';': 'semicolon',
    "'": 'apostrophe', '`': 'grave_accent', '[': 'bracket_left',
    ']': 'bracket_right', '_': 'shift-minus', '"': 'shift-apostrophe',
    ':': 'shift-semicolon', '*': 'shift-8', '?': 'shift-slash',
    '+': 'shift-equal', '@': 'shift-2', '#': 'shift-3', '%': 'shift-5',
    '&': 'shift-7', '(': 'shift-9', ')': 'shift-0', '<': 'shift-comma',
    '>': 'shift-dot', '|': 'shift-backslash', '!': 'shift-1', '$': 'shift-4',
    '^': 'shift-6', '~': 'shift-grave_accent', '{': 'shift-bracket_left',
    '}': 'shift-bracket_right',
}


def key_for(ch):
    if ch.isupper():
        return 'shift-' + ch.lower()
    return KEYS.get(ch, ch)


def type_text(s, text, hold=None, delay=None):
    # per key: hold ms and the pause after it, both from the environment
    # (GUEST_TYPE_HOLD, GUEST_TYPE_DELAY); the PS/2 queue holds 256 bytes, so
    # a guest under TCG keeps up at ~100 ms per key
    hold = int(os.environ.get('GUEST_TYPE_HOLD', 20)) if hold is None else hold
    delay = float(os.environ.get('GUEST_TYPE_DELAY', 0.1)) if delay is None else delay
    for ch in text:
        hmp(s, 'sendkey %s %d' % (key_for(ch), hold))
        time.sleep(delay)


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    s = connect(sys.argv[1])
    args = sys.argv[2:]
    if args[0] == 'type':
        type_text(s, args[1])
        print('typed %d characters' % len(args[1]))
        return 0
    if args[0] == 'key':
        for chord in args[1:]:
            print('--- sendkey %s\n%s' % (chord, hmp(s, 'sendkey ' + chord)))
        return 0
    for cmd in args:
        wait = 1.5 if cmd.startswith('screendump') else 0.4
        print('--- %s\n%s' % (cmd, hmp(s, cmd, wait)))
    s.close()
    return 0


if __name__ == '__main__':
    sys.exit(main())
