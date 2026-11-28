#!/usr/bin/env python3
"""Compile and link E5c's data-disk tool setdefault.exe as the dsploop apitest is built
(<home>/libernt-build-logs/tools/build-dsploop.py: the Debug amd64 build's own flags of a C win32cui
executable, sdrwbench's compile and link commands, the apitests' libraries).  The sources are under
/tmp/e5c/setdef-src; the exe goes where the argument says.
"""
import os
import shlex
import subprocess
import sys

ROOT = "<home>/Projects/LiberNT"
OUT = ROOT + "/output-Clang-amd64-debug"
DIR = "/tmp/e5c/setdef-src"
SOURCES = ["setdefault.c"]
TARGET = sys.argv[1] if len(sys.argv) > 1 else "/tmp/e5c/setdef/setdefault.exe"
OBJDIR = "/tmp/e5c/setdef-obj"

def template(target):
    commands = subprocess.run(["ninja", "-t", "commands", target], cwd=OUT, capture_output=True, text=True, check=True).stdout
    last = commands.strip().split("\n")[-1]
    parts = [p.strip() for p in last.split("&&") if "clang" in p]
    return parts[0]

def strip_outputs(args):
    out, i = [], 0
    while i < len(args):
        a = args[i]
        if a in ("-o", "-MF", "-MT"):
            i += 2
            continue
        if a == "-c":
            i += 1
            continue
        if a.endswith(".obj") or a.endswith(".obj.d") or a.endswith(".o") or a.endswith(".c"):
            i += 1
            continue
        out.append(a)
        i += 1
    return out

compile_args = strip_outputs(shlex.split(template("base/applications/bench/sdrwbench/CMakeFiles/sdrwbench.dir/sdrwbench.c.obj")))
compile_args += ["-D_FORCENAMELESSUNION", "-D_FORCENAMELESSSTRUCT", "-DCONST_VTABLE="]
os.makedirs(OBJDIR, exist_ok=True)
rc = 0
objects = []
for src in SOURCES:
    obj = os.path.join(OBJDIR, src + ".o")
    r = subprocess.run(compile_args + ["-c", os.path.join(DIR, src), "-o", obj], cwd=OUT, capture_output=True, text=True)
    ok = r.returncode == 0 and "warning:" not in r.stderr
    rc |= r.returncode != 0
    print(("OK   " if ok else "FAIL ") + src + ("" if ok else "\n" + r.stderr[:6000]))
    objects.append(obj)

link_args = shlex.split(template("base/applications/bench/sdrwbench/sdrwbench.exe"))
out, i = [], 0
while i < len(link_args):
    a = link_args[i]
    if a == "-o":
        out += ["-o", TARGET]
        i += 2
        continue
    if a.endswith(".obj"):
        out += objects
        i += 1
        continue
    if a == "-Wl,--end-group":
        out += [os.path.join(OUT, lib) for lib in [
            "sdk/lib/3rdparty/libwine/libwine.a",
            "sdk/lib/uuid/libuuid.a",
            "dll/win32/ole32/CMakeFiles/libole32.dir/libole32.a",
            "dll/win32/ole32/CMakeFiles/libole32.dir/libole32_thunks.a",
            "dll/win32/advapi32/CMakeFiles/libadvapi32.dir/libadvapi32.a",
            "dll/win32/advapi32/CMakeFiles/libadvapi32.dir/libadvapi32_thunks.a",
        ]]
    out.append(a)
    i += 1
if rc == 0:
    os.makedirs(os.path.dirname(TARGET), exist_ok=True)
    r = subprocess.run(out, cwd=OUT, capture_output=True, text=True)
    sys.stderr.write(r.stderr)
    print("link rc=%d" % r.returncode)
    rc = r.returncode
    if rc == 0:
        r = subprocess.run([OUT + "/host-tools/bin/pefixup", "--checksum", TARGET], capture_output=True, text=True)
        sys.stderr.write(r.stderr)
        print("pefixup rc=%d" % r.returncode)
        r = subprocess.run(["<home>/.local/opt/rosbe/llvm/bin/llvm-readobj", "--coff-imports", TARGET], capture_output=True, text=True)
        print("\n".join(l.strip() for l in r.stdout.splitlines() if "Name:" in l))
sys.exit(rc)
