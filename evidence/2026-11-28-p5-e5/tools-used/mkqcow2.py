#!/usr/bin/env python3
"""A qcow2 v3 overlay with a backing file, written without qemu-img (none on this host): cluster_bits 16,
L1 table in cluster 1, the refcount table in cluster 2, refcount block 0 in cluster 3 (the four clusters
counted once), the backing file's name and format after the v3 header.
usage: mkqcow2.py <out> <backing> <virtual size>"""
import os
import struct
import sys

out, backing, size = sys.argv[1], sys.argv[2], int(sys.argv[3])
CB = 16
CS = 1 << CB
name = backing.encode()
header_len = 112
# header (112) + backing name + backing format extension (8 + 4 padded to 8) + end extension (8)
backing_off = header_len
pos = backing_off + len(name)
pos = (pos + 7) & ~7
ext_off = pos
pos += 8 + 8            # backing format ext: magic, length, "vpc\0" + 4 pad
end_off = pos
pos += 8
assert pos <= CS
l2_entries = CS // 8
l1_size = (size + (CS * l2_entries) - 1) // (CS * l2_entries)
assert l1_size <= l2_entries
l1_off = CS
rt_off = 2 * CS
rb_off = 3 * CS
hdr = struct.pack(">IIQIIQIIQQIIQQQQII",
                  0x514649FB, 3, backing_off, len(name), CB, size,
                  0, l1_size, l1_off, rt_off, 1,
                  0, 0,
                  0, 0, 0,
                  4, header_len)
img = bytearray(4 * CS)
img[0:len(hdr)] = hdr
img[backing_off:backing_off + len(name)] = name
img[ext_off:ext_off + 8] = struct.pack(">II", 0xE2792ACA, 4)
img[ext_off + 8:ext_off + 12] = b"vpc\0"
img[end_off:end_off + 8] = struct.pack(">II", 0, 0)
# the refcount table's first entry: block 0; block 0: clusters 0..3 counted once
struct.pack_into(">Q", img, rt_off, rb_off)
for c in range(4):
    struct.pack_into(">H", img, rb_off + 2 * c, 1)
with open(out, "wb") as f:
    f.write(img)
print("%s: %d bytes, backing %s, virtual %d bytes, l1_size %d" % (out, len(img), backing, size, l1_size))
