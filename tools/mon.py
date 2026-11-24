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


def hmp(s, cmd, wait=0.4):
    s.sendall((cmd + '\n').encode())
    time.sleep(wait)
    out = b''
    try:
        while True:
            out += s.recv(65536)
    except socket.timeout:
        pass
    return out.decode(errors='replace').strip()


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


def type_text(s, text, hold=40):
    for ch in text:
        hmp(s, 'sendkey %s %d' % (key_for(ch), hold), wait=0.03)
        time.sleep(0.02)


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
