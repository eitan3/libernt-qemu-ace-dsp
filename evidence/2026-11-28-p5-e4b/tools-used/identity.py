#!/usr/bin/env python3
# identity.py -- the image's identity: ntoskrnl.exe's string (8-bit), the drivers' version strings (UTF-16),
# and the in-ISO binaries against the build tree's (E4's gates/identity.txt).
import hashlib
import os
import re
import sys

iso_dir, build_tree = sys.argv[1], sys.argv[2]
os.chdir(iso_dir)

data = open("Windows/system32/ntoskrnl.exe", "rb").read()
m = re.search(rb"20[0-9]{6}-nt10\.0-[0-9]+-[0-9]+-g[0-9a-f]+\.libernt", data)
print("ntoskrnl.exe identity string (unique):")
print(m.group(0).decode() if m else "(none found)")

print("the version strings (UTF-16) of the drivers:")
files = ["drivers/intcdsp.sys", "drivers/dsppcm.sys", "drivers/hdaudbus.sys", "drivers/hdaudio.sys", "mmdevapi.dll", "mmsys.cpl"]
for f in files:
    raw = open("Windows/system32/" + f, "rb").read()
    found = "(no string)"
    for parity in (0, 1):
        text = raw[parity:].decode("utf-16-le", "replace")
        with_identity = re.search(r"[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ \([^)]*libernt[^)]*\)", text)
        version = re.search(r"(?<![0-9.])10\.0\.26100\.1(?![0-9])", text)
        if with_identity:
            found = (version.group(0) + " " if version else "") + with_identity.group(0)
            break
        if version:
            found = version.group(0)
    print("  %s: %s" % (f, found))

print()
print("--- in-ISO vs the build tree")
pairs = [
    ("Windows/system32/drivers/intcdsp.sys", "drivers/wdm/audio/intcdsp/intcdsp.sys"),
    ("Windows/system32/drivers/dsppcm.sys", "drivers/wdm/audio/drivers/dsppcm/dsppcm.sys"),
    ("Windows/system32/drivers/hdaudbus.sys", "drivers/wdm/audio/hdaudbus/hdaudbus.sys"),
    ("Windows/system32/drivers/hdaudio.sys", "drivers/wdm/audio/drivers/hdaudio/hdaudio.sys"),
    ("Windows/system32/mmdevapi.dll", "dll/win32/mmdevapi/mmdevapi.dll"),
    ("Windows/system32/mmsys.cpl", "dll/cpl/mmsys/mmsys.cpl"),
]
ok = 0
for in_iso, in_tree in pairs:
    a = hashlib.sha256(open(in_iso, "rb").read()).hexdigest()
    b = hashlib.sha256(open(os.path.join(build_tree, in_tree), "rb").read()).hexdigest()
    if a == b:
        ok += 1
        print("%s: identical to the build tree (%d bytes, sha256 %s...)" % (in_iso, os.path.getsize(in_iso), a[:16]))
    else:
        print("%s: DIFFERS from the build tree" % in_iso)
print("method: bsdtar -x of the ISO; the identity string 8-bit in ntoskrnl.exe; %d of %d identical; the count in the string is the branch's absolute commit count" % (ok, len(pairs)))
