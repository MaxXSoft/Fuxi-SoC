#!/usr/bin/env python3
"""Host checks for package headers and fail-closed manual update sequencing.

The command stubs exercise the script's shell control flow, not Zynq hardware.
"""
import os
import hashlib
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'scripts'))
from flash_metadata import check_zynq_image, make_metadata
from package_sd_flasher import prepare_spl


def image():
    data = bytearray(0x800080)
    words = [0xaa995566, 0x584c4e58, 0, 0, 0x8c0, 4, 0, 0, 4, 0]
    struct.pack_into('<11I', data, 0x20, *words, ~sum(words) & 0xffffffff)
    data[0x800000:0x800008] = b'FUXISOC\0'
    return bytes(data)


class PackageTests(unittest.TestCase):
    def test_metadata_cli_needs_only_python(self):
        out = ROOT/'build/tests/sd-flasher'
        out.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=out) as temp:
            flash = Path(temp)/'flash.bin'
            flash.write_bytes(image())
            result = subprocess.run([sys.executable, str(ROOT/'scripts/flash_metadata.py'),
                                     str(flash)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(flash.with_suffix('.meta').read_text(), make_metadata(image()))
            result = subprocess.run([sys.executable, str(ROOT/'scripts/flash_metadata.py'),
                                     str(flash), '--output', str(flash)], capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(flash.read_bytes(), image())

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
                    make_metadata(bad)
        for bad in (good[:0x100], good[:0x800000], good + bytes(0x1000000)):
            with self.assertRaises(ValueError):
                make_metadata(bad)

    def run_update(self, flash, metadata=None, fail=''):
        metadata = make_metadata(flash) if metadata is None else metadata
        out = ROOT/'build/tests/sd-flasher'
        out.mkdir(parents=True, exist_ok=True)
        stubs = r'''
setenv() { if test "$#" -eq 1; then unset "$1"; else printf -v "$1" '%s' "$2"; fi; }
mmc() { echo "CALL mmc $*"; test "$FAIL" != "mmc-$1"; }
size() {
    echo "CALL size $*"
    test "$FAIL" != "size-$3" || return 1
    if test "$3" = flash.meta; then
        filesize=$META_SIZE
    else
        filesize=$IMAGE_SIZE
        test "$FAIL" != short-image || filesize=800000
        test "$FAIL" != oversized-image || filesize=1000001
    fi
}
fatload() {
    echo "CALL fatload $*"
    test "$FAIL" != "load-$4" || return 1
    if test "$4" = flash.meta; then filesize=$META_SIZE; else filesize=$IMAGE_SIZE; fi
    test "$5" = "$filesize" || return 1
    test "$FAIL" != "short-$4" || filesize=1
}
env() {
    echo "CALL env $*"
    test "$FAIL" != import || return 1
    test "$*" = "import -t -d 0x02100000 $META_SIZE fuxi_flash_size fuxi_flash_sha256" || return 1
    while IFS='=' read -r key value; do
        case "$key" in
            fuxi_flash_size|fuxi_flash_sha256) printf -v "$key" '%s' "$value";;
        esac
    done < "$META_PATH"
}
itest() { test "$((16#${1#0x}))" "$2" "$((16#${3#0x}))"; }
itest.l() {
    echo "CALL itest.l $*"
    case "$1" in
        '*0x10000020') actual=$HEADER0;;
        '*0x10000024') actual=$HEADER1;;
        '*0x10800000') actual=$PAYLOAD0;;
        '*0x10800004') actual=$PAYLOAD1;;
        *) return 1;;
    esac
    itest "$actual" -eq "$3"
}
hash() {
    echo "CALL hash $*"
    test "$*" = "-v sha256 0x10000000 $IMAGE_SIZE fuxi_flash_sha256" || return 1
    test "$FAIL" != hash && test "$fuxi_flash_sha256" = "$IMAGE_HASH"
}
sf() { echo "CALL sf $*"; test "$FAIL" != "sf-$1"; }
cmp.b() { echo "CALL cmp.b $*"; test "$FAIL" != compare; }
trap 'test "$bootcmd" = unchanged || exit 99' EXIT
'''
        script = stubs + (ROOT/'software/flasher/flash-fuxi.cmd').read_text()
        # Test an existing environment too: missing fields must not reuse it.
        initial = dict(os.environ, FAIL=fail, IMAGE_SIZE=f'{len(flash):x}',
                       IMAGE_HASH=hashlib.sha256(flash).hexdigest(),
                       META_SIZE=f'{len(metadata.encode()):x}', bootcmd='unchanged',
                       fuxi_flash_size=f'0x{len(flash):x}',
                       fuxi_flash_sha256=hashlib.sha256(flash).hexdigest())
        for key, offset in [('HEADER0', 0x20), ('HEADER1', 0x24),
                            ('PAYLOAD0', 0x800000), ('PAYLOAD1', 0x800004)]:
            initial[key] = hex(struct.unpack_from('<I', flash, offset)[0])
        with tempfile.TemporaryDirectory(dir=out) as temp:
            path = Path(temp)/'flash.meta'
            path.write_text(metadata)
            initial['META_PATH'] = str(path)
            return subprocess.run(['bash'], input=script,
                                  text=True, capture_output=True, env=initial)

    def test_one_script_accepts_different_images(self):
        first = image()
        second = first + b'another firmware version'
        third = bytearray(first)
        third[-1] ^= 1
        for flash in (first, second, third):
            with self.subTest(size=len(flash)):
                meta = make_metadata(flash)
                self.assertIn(f'fuxi_flash_size=0x{len(flash):x}\n', meta)
                self.assertIn(hashlib.sha256(flash).hexdigest(), meta)
                # Extra keys are data, not commands or environment overrides.
                result = self.run_update(flash, meta + 'bootcmd=changed\n')
                self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
                self.assertIn('FUXI_FLASH_VERIFY_PASS', result.stdout)
                self.assertIn(f'CALL sf update 0x10000000 0 {len(flash):x}', result.stdout)
                calls = ['CALL env ', 'CALL hash ', 'CALL itest.l ',
                         'CALL sf probe ', 'CALL sf update ', 'CALL sf read ', 'CALL cmp.b ']
                self.assertEqual([result.stdout.index(c) for c in calls],
                                 sorted(result.stdout.index(c) for c in calls))

    def test_manual_update_failure_paths(self):
        before_write = ['mmc-dev', 'mmc-rescan', 'size-flash.meta', 'load-flash.meta',
                        'short-flash.meta', 'import', 'size-flash.bin', 'short-image',
                        'oversized-image', 'load-flash.bin', 'short-flash.bin',
                        'hash', 'sf-probe']
        for fail in [''] + before_write + ['sf-update', 'sf-read', 'compare']:
            with self.subTest(fail=fail):
                result = self.run_update(image(), fail=fail)
                log = result.stdout
                if not fail:
                    self.assertEqual(result.returncode, 0, result.stderr + log)
                    self.assertIn('FUXI_FLASH_VERIFY_PASS', log)
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

    def test_stale_missing_or_corrupt_metadata_stops_before_write(self):
        flash = image()
        meta = make_metadata(flash)
        changed = bytearray(flash)
        changed[-1] ^= 1
        for invalid in ('', 'x'*513, meta.splitlines()[0] + '\n',
                        meta.splitlines()[1] + '\n',
                        meta.replace('0x800080', '0x800081'),
                        meta.replace('0x800080', '*0x10000000'),
                        make_metadata(changed), make_metadata(flash + b'new'),
                        meta.replace(hashlib.sha256(flash).hexdigest(), 'bad-digest')):
            result = self.run_update(flash, invalid)
            self.assertNotEqual(result.returncode, 0, result.stdout)
            self.assertIn('FAIL', result.stdout)
            self.assertNotIn('CALL sf ', result.stdout)
        # Even metadata with the correct digest cannot bless another image type.
        for offset in (0x20, 0x24, 0x800000, 0x800004):
            bad = bytearray(flash)
            bad[offset] ^= 1
            matching = meta.replace(hashlib.sha256(flash).hexdigest(),
                                    hashlib.sha256(bad).hexdigest())
            result = self.run_update(bad, matching)
            self.assertNotEqual(result.returncode, 0, result.stdout)
            self.assertIn('FUXI_FLASH_INPUT_HEADER_FAIL', result.stdout)
            self.assertNotIn('CALL sf ', result.stdout)


if __name__ == '__main__':
    unittest.main()
