#!/usr/bin/env python3
"""Exercise the actual ROM C parser/decoder with packed and corrupt host images."""

import ctypes
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('pack_image', ROOT / 'scripts/pack_image.py')
packer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(packer)


class Segment(ctypes.Structure):
    _fields_ = [(name, ctypes.c_uint32) for name in
                ('address', 'offset', 'packed_size', 'unpacked_size', 'crc32', 'codec')]


class Header(ctypes.Structure):
    _fields_ = [('magic', ctypes.c_char * 8), ('version', ctypes.c_uint32),
                ('crc32', ctypes.c_uint32), ('segments', Segment * 3)]


class ImageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        out = ROOT / 'build/tests'
        out.mkdir(parents=True, exist_ok=True)
        library = out / ('image.dylib' if sys.platform == 'darwin' else 'image.so')
        subprocess.run([os.environ.get('HOST_CC', 'cc'), '-O2', '-shared', '-fPIC',
                        '-I' + str(ROOT / 'third_party/lz4/lib'),
                        str(ROOT / 'software/bootrom/image.c'),
                        str(ROOT / 'third_party/lz4/lib/lz4.c'), '-o', str(library)], check=True)

        cls.lib = ctypes.CDLL(str(library))
        cls.lib.image_validate.argtypes = [ctypes.POINTER(Header)]
        cls.lib.image_unpack.argtypes = [ctypes.POINTER(Segment), ctypes.c_void_p, ctypes.c_void_p]

        cls.images = [b'OpenSBI' * 300, bytes(range(256)) * 4096, b'DTB data' * 50]
        cls.blob = packer.pack(cls.images)

    def header(self):
        return Header.from_buffer_copy(self.blob)

    def refresh_crc(self, header):
        header.crc32 = 0
        header.crc32 = zlib.crc32(bytes(header))

    def test_roundtrip(self):
        h = self.header()
        self.assertEqual(self.lib.image_validate(ctypes.byref(h)), 0)
        for s, expected in zip(h.segments, self.images):
            output = ctypes.create_string_buffer(s.unpacked_size)
            data = self.blob[s.offset:s.offset + s.packed_size]
            self.assertEqual(self.lib.image_unpack(ctypes.byref(s), data, output), 0)
            self.assertEqual(output.raw, expected)

    def test_raw_roundtrip(self):
        blob = packer.pack(self.images, compress=False)
        h = Header.from_buffer_copy(blob)
        self.assertEqual(self.lib.image_validate(ctypes.byref(h)), 0)
        for s, expected in zip(h.segments, self.images):
            output = ctypes.create_string_buffer(s.unpacked_size)
            self.assertEqual(s.codec, 0)
            self.assertEqual(self.lib.image_unpack(ctypes.byref(s),
                                                   blob[s.offset:s.offset + s.packed_size],
                                                   output), 0)
            self.assertEqual(output.raw, expected)

    def test_header_corruption(self):
        for offset in range(88):
            changed = bytearray(self.blob[:88])
            changed[offset] ^= 1
            h = Header.from_buffer_copy(changed)
            self.assertNotEqual(self.lib.image_validate(ctypes.byref(h)), 0)

    def test_bounds_and_layout(self):
        for field, value in [('address', 0x87000000), ('offset', 0xfffffff0),
                             ('packed_size', 0xffffffff), ('unpacked_size', 0x7000000),
                             ('codec', 2), ('offset', 0), ('packed_size', 0), ('unpacked_size', 0)]:
            h = self.header()
            setattr(h.segments[1], field, value)
            self.refresh_crc(h)
            self.assertNotEqual(self.lib.image_validate(ctypes.byref(h)), 0, (field, value))

    def test_corrupt_and_truncated_block(self):
        h = self.header()
        s = h.segments[1]
        output = ctypes.create_string_buffer(s.unpacked_size)
        bad = b'\xff' * s.packed_size
        self.assertNotEqual(self.lib.image_unpack(ctypes.byref(s), bad, output), 0)

        s.packed_size -= 1
        self.assertNotEqual(self.lib.image_unpack(ctypes.byref(s),
                                                  self.blob[s.offset:s.offset + s.packed_size],
                                                  output), 0)

    def test_packer_rejects_overflow(self):
        with self.assertRaises(ValueError):
            packer.pack([b'A', b'B' * 0x800000, b'C'], compress=False)


if __name__ == '__main__':
    unittest.main()
