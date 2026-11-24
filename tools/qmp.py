#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# qemu-ace-dsp: QMP commands over the VM's unix socket (used by set-fault.sh).
#
#   qmp.py <qmp.sock> qom-set /machine/peripheral/ace fault never-reply
#   qmp.py <qmp.sock> qom-set /machine/peripheral/ace x-delay-scale 1.6
#   qmp.py <qmp.sock> qom-get /machine/peripheral/ace fault
#   qmp.py <qmp.sock> query-status
#
# Commands are given as "execute" followed by their arguments in the order of
# their QMP schema (the common qom-set/qom-get/query-* shapes); the value of a
# qom-set is sent as a JSON number when it reads as one, else as a string.
#
# This work is licensed under the terms of the GNU GPL, version 2 or later.
# See the COPYING file in the top-level directory.
import json
import socket
import sys

ARG_ORDER = {
    'qom-set': ['path', 'property', 'value'],
    'qom-get': ['path', 'property'],
    'device_add': None,
}


def json_value(text):
    try:
        return int(text)
    except ValueError:
        pass
    try:
        return float(text)
    except ValueError:
        pass
    return text


def recv_until(s, tag):
    out = b''
    while True:
        chunk = s.recv(65536)
        if not chunk:
            break
        out += chunk
        for line in out.split(b'\n'):
            if line.strip():
                try:
                    obj = json.loads(line)
                except ValueError:
                    continue
                if obj.get('return') is not None or 'error' in obj:
                    return obj
        if not chunk:
            break
    return {'error': {'class': 'SocketClosed', 'desc': out.decode(errors='replace')}}


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    s = socket.socket(socket.AF_UNIX)
    s.connect(sys.argv[1])
    s.settimeout(5)
    s.recv(65536)  # greeting
    s.sendall(b'{"execute":"qmp_capabilities"}\n')
    recv_until(s, 'return')
    rc = 0
    argv = sys.argv[2:]
    while argv:
        execute = argv.pop(0)
        args = {}
        order = ARG_ORDER.get(execute)
        if order is None:
            while argv and '=' in argv[0]:
                k, v = argv.pop(0).split('=', 1)
                args[k] = json_value(v)
        else:
            for name in order:
                if not argv:
                    break
                args[name] = json_value(argv.pop(0))
        msg = {'execute': execute}
        if args:
            msg['arguments'] = args
        s.sendall((json.dumps(msg) + '\n').encode())
        rep = recv_until(s, 'return')
        print(json.dumps(msg), '->', json.dumps(rep))
        if 'error' in rep:
            rc = 1
    return rc


if __name__ == '__main__':
    sys.exit(main())
