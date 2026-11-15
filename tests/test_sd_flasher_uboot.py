#!/usr/bin/env python3
"""Check the real U-Boot parser/hash path with host-file SD and RAM-backed QSPI.

Requires a native sandbox U-Boot (512 MiB RAM, old Hush, hostfs, hash/SHA-256,
legacy scripts, env import and memory commands) and its sibling u-boot.dtb.
No physical SD card or Flash is accessed. Logs remain under ignored build/.
"""

import argparse
import hashlib
from pathlib import Path
import subprocess

from test_sd_flasher import image
from flash_metadata import make_metadata


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--uboot', type=Path, required=True)
    parser.add_argument('--mkimage', type=Path, required=True)
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[1]
    work = root / 'build/tests/uboot-flasher'
    work.mkdir(parents=True, exist_ok=True)
    uboot = args.uboot.resolve()
    mkimage = args.mkimage.resolve()
    source = (root / 'software/flasher/flash-fuxi.cmd').read_text()

    original = image()
    base_meta = make_metadata(original)
    changed = bytearray(original)
    changed[-1] ^= 1
    cases = [
        ('baseline', original, base_meta, None),
        ('different-size', original + b'test', make_metadata(original + b'test'), None),
        ('different-hash', changed, make_metadata(changed), None),
        ('stale-hash', changed, base_meta, 'HASH'),
        ('missing-hash', original, base_meta.splitlines()[0] + '\n', 'HASH'),
        ('wrong-size', original + b'test', base_meta, 'SIZE'),
    ]

    for name, flash, meta, error in cases:
        (work / 'flash.bin').write_bytes(flash)
        (work / 'flash.meta').write_text(meta + 'bootcmd=changed\n')

        # Keep all guards, env import, SHA-256, header checks and cmp.b unchanged.
        # Host files replace SD reads, and RAM copies replace QSPI accesses.
        script = source.replace('mmc dev 0 && mmc rescan', 'true')
        script = script.replace('size mmc 0:1 flash.meta',
                                f'setenv filesize {len((work / "flash.meta").read_bytes()):x}')
        script = script.replace('size mmc 0:1 flash.bin', f'setenv filesize {len(flash):x}')
        script = script.replace('fatload mmc 0:1 0x02100000 flash.meta',
                                f'load hostfs - 0x02100000 {work}/flash.meta')
        script = script.replace('fatload mmc 0:1 0x10000000 flash.bin',
                                f'load hostfs - 0x10000000 {work}/flash.bin')
        script = script.replace('sf probe 0:0', 'echo SANDBOX_QSPI_PROBE')
        script = script.replace('sf update 0x10000000 0', 'cp.b 0x10000000 0x14000000')
        script = script.replace('sf read 0x12000000 0', 'cp.b 0x14000000 0x12000000')
        (work / 'test.cmd').write_text(script)
        subprocess.run([str(mkimage), '-A', 'arm', '-T', 'script', '-C', 'none',
                        '-n', 'test', '-d', str(work / 'test.cmd'), str(work / 'test.scr')],
                       check=True, stdout=subprocess.DEVNULL)

        # Preload old values to verify that importing a missing hash removes it.
        command = (f'setenv bootcmd unchanged; setenv fuxi_flash_size 0x{len(original):x}; '
                   f'setenv fuxi_flash_sha256 {hashlib.sha256(original).hexdigest()}; '
                   f'load hostfs - 0x02000000 {work}/test.scr; '
                   'if source 0x02000000; then echo SCRIPT_STATUS=0; '
                   'else echo SCRIPT_STATUS=1; fi; printenv bootcmd')
        result = subprocess.run([str(uboot), '-d', str(uboot.with_name('u-boot.dtb')),
                                 '-c', command], capture_output=True, text=True, timeout=30)
        log = result.stdout + result.stderr
        (work / f'{name}.log').write_text(log)

        assert 'bootcmd=unchanged' in log, log
        if error:
            assert f'FUXI_FLASH_INPUT_{error}_FAIL' in log, log
            assert 'FUXI_FLASH_VERIFY_PASS' not in log and 'SANDBOX_QSPI_PROBE' not in log, log
            assert 'SCRIPT_STATUS=1' in log, log
        else:
            assert 'FUXI_FLASH_VERIFY_PASS' in log and 'SCRIPT_STATUS=0' in log, log
        print(f'{name}: PASS')


if __name__ == '__main__':
    main()
