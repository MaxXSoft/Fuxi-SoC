#!/usr/bin/env python3
"""Host checks for package headers and fail-closed manual update sequencing.

The command stubs exercise the script's shell control flow, not Zynq hardware.
"""
import os
from pathlib import Path
import struct
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'scripts'))
from package_sd_flasher import check_zynq_image, prepare_spl, render_script


def image():
    data = bytearray(0x800080)
    words = [0xaa995566, 0x584c4e58, 0, 0, 0x8c0, 4, 0, 0, 4, 0]
    struct.pack_into('<11I', data, 0x20, *words, ~sum(words) & 0xffffffff)
    data[0x800000:0x800008] = b'FUXISOC\0'
    return bytes(data)


class PackageTests(unittest.TestCase):
    def test_spl_padding_covers_declared_bootrom_read(self):
        data = bytearray(image()[:0x900])
        struct.pack_into('<I', data, 0x34, len(data))
        struct.pack_into('<I', data, 0x40, len(data))
        words = struct.unpack_from('<10I', data, 0x20)
        struct.pack_into('<I', data, 0x48, ~sum(words) & 0xffffffff)
        padded = prepare_spl(data)
        check_zynq_image(padded)
        self.assertEqual(padded[:len(data)], data)
        self.assertEqual(padded[len(data):], bytes(0x8c0))
        self.assertEqual(prepare_spl(padded), padded)
        with self.assertRaises(ValueError):
            prepare_spl(data[:-1])

    def test_reject_wrong_image_or_corrupt_header(self):
        good = image()
        check_zynq_image(good)
        for offset in (0x20, 0x24, 0x34, 0x48, 0x800000):
            with self.subTest(offset=offset):
                bad = bytearray(good)
                bad[offset] ^= 1
                with self.assertRaises(ValueError):
                    render_script(bad)
        for bad in (good[:0x100], good[:0x800000], good + bytes(0x1000000)):
            with self.assertRaises(ValueError):
                render_script(bad)

    def test_manual_update_failure_paths(self):
        stubs = r'''
mmc() { echo "CALL mmc $*"; test "$FAIL" != "mmc-$1"; }
size() {
    echo "CALL size $*"
    test "$FAIL" != size || return 1
    filesize=800080
    test "$FAIL" != wrong-size || filesize=800081
}
fatload() {
    echo "CALL fatload $*"
    test "$FAIL" != load || return 1
    filesize=800080
    test "$FAIL" != short-load || filesize=800079
}
itest() { test "$((16#${1#0x}))" -eq "$((16#${3#0x}))"; }
hash() { echo "CALL hash $*"; test "$FAIL" != hash; }
sf() { echo "CALL sf $*"; test "$FAIL" != "sf-$1"; }
cmp.b() { echo "CALL cmp.b $*"; test "$FAIL" != compare; }
'''
        script = stubs + render_script(image())
        before_write = ['mmc-dev', 'mmc-rescan', 'size', 'wrong-size', 'load',
                        'short-load', 'hash', 'sf-probe']
        for fail in [''] + before_write + ['sf-update', 'sf-read', 'compare']:
            with self.subTest(fail=fail):
                result = subprocess.run(['bash'], input=script, text=True,
                                        capture_output=True,
                                        env=dict(os.environ, FAIL=fail))
                log = result.stdout
                if not fail:
                    self.assertEqual(result.returncode, 0, result.stderr + log)
                    self.assertIn('FUXI_FLASH_VERIFY_PASS', log)
                    calls = ['CALL hash ', 'CALL sf probe ', 'CALL sf update ',
                             'CALL sf read ', 'CALL cmp.b ']
                    self.assertEqual([log.index(c) for c in calls],
                                     sorted(log.index(c) for c in calls))
                else:
                    self.assertNotEqual(result.returncode, 0, log)
                    self.assertNotIn('FUXI_FLASH_VERIFY_PASS', log)
                    self.assertIn('FAIL', log)
                if fail in before_write:
                    self.assertNotIn('CALL sf update ', log)
                if fail in before_write + ['sf-update']:
                    self.assertNotIn('CALL sf read ', log)
                if fail in before_write + ['sf-update', 'sf-read']:
                    self.assertNotIn('CALL cmp.b ', log)


if __name__ == '__main__':
    unittest.main()
