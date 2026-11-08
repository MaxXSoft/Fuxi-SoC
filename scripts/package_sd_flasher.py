#!/usr/bin/env python3
"""Package a manually invoked, image-bound QSPI update on a FAT32 SD card."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import zipfile

from build_sd_flasher import check_config

ROOT = Path(__file__).resolve().parents[1]


def check_zynq_image(data):
    if len(data) < 0x8c0:
        raise ValueError('truncated Zynq boot image')
    words = struct.unpack_from('<11I', data, 0x20)
    if words[:2] != (0xaa995566, 0x584c4e58) or sum(words) & 0xffffffff != 0xffffffff:
        raise ValueError('invalid Zynq boot header or checksum')
    if words[4] < 0x8c0 or words[5] == 0 or words[4] + words[5] > len(data):
        raise ValueError('invalid Zynq first-stage bounds')


def prepare_spl(data):
    data = bytes(data)
    if len(data) < 0x8c0:
        raise ValueError('truncated SPL image')
    offset, size = struct.unpack_from('<2I', data, 0x30)
    # v2026.04 mkimage records the complete output file size as the load size,
    # including its 0x8c0 header. Supply the declared tail as zero padding so
    # BootROM never needs to read past EOF. Keep the upstream header/code intact.
    if offset == 0x8c0 and size == len(data) and size <= 0x30000:
        data += bytes(offset)
    check_zynq_image(data)
    if size > 0x30000:
        raise ValueError('SPL exceeds the 192 KiB BootROM load limit')
    return data


def render_script(flash):
    check_zynq_image(flash)
    if not 0x800058 <= len(flash) <= 0x1000000:
        raise ValueError('Fuxi Flash image must fit bank 0 and include the payload')
    if flash[0x800000:0x800008] != b'FUXISOC\0':
        raise ValueError('expected Fuxi payload at Flash offset 8 MiB')
    template = (ROOT/'software/flasher/flash-fuxi.cmd.in').read_text()
    return template.replace('@SIZE@', hex(len(flash))).replace(
        '@SHA256@', hashlib.sha256(flash).hexdigest())


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--flash', type=Path, default=ROOT/'build/flash/flash.bin')
    a = p.parse_args()
    work = ROOT/'build/sd-flasher'
    uboot = work/'u-boot'
    out = work/'sdcard'
    check_config(uboot/'.config')
    flash = a.flash.read_bytes()
    script = render_script(flash)
    boot = prepare_spl((uboot/'spl/boot.bin').read_bytes())
    out.mkdir(parents=True, exist_ok=True)
    # An old boot.scr could trigger unrelated commands in a different U-Boot.
    if (out/'boot.scr').exists():
        raise ValueError('remove stale boot.scr from the package output first')
    (out/'BOOT.BIN').write_bytes(boot)
    subprocess.run([str(uboot/'tools/mkimage'), '-l', str(out/'BOOT.BIN')], check=True)
    shutil.copyfile(uboot/'u-boot.img', out/'u-boot.img')
    (out/'flash.bin').write_bytes(flash)
    (out/'flash-fuxi.cmd').write_text(script)
    env = dict(os.environ, SOURCE_DATE_EPOCH='1775498358')
    subprocess.run([str(uboot/'tools/mkimage'), '-A', 'arm', '-T', 'script',
                    '-C', 'none', '-n', 'Fuxi QSPI update', '-d',
                    str(out/'flash-fuxi.cmd'), str(out/'flash-fuxi.scr')],
                   env=env, check=True)
    shutil.copyfile(ROOT/'docs/sd-flasher.md', out/'README.md')
    shutil.copyfile(uboot/'.config', out/'u-boot.config')
    shutil.copyfile(ROOT/'third_party/u-boot/Licenses/README', out/'U-Boot-LICENSES.txt')
    shutil.copyfile(ROOT/'third_party/u-boot/Licenses/gpl-2.0.txt', out/'GPL-2.0.txt')
    names = ['BOOT.BIN', 'u-boot.img', 'flash.bin', 'flash-fuxi.cmd',
             'flash-fuxi.scr', 'README.md', 'u-boot.config',
             'U-Boot-LICENSES.txt', 'GPL-2.0.txt']
    hashes = {n: hashlib.sha256((out/n).read_bytes()).hexdigest() for n in names}
    (out/'SHA256SUMS').write_text(''.join(f'{v}  {n}\n' for n, v in hashes.items()))
    (work/'manifest.json').write_text(json.dumps({
        'u_boot_version': (uboot/'include/config/uboot.release').read_text().strip(),
        'flash_size': len(flash), 'flash_offset': 0,
        'sha256': hashes, 'hardware_validation': 'not performed',
    }, indent=2) + '\n')
    archive = work/'zedboard-sd-flasher.zip'
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as z:
        for name in names + ['SHA256SUMS']:
            z.write(out/name, name)
    print(f'{archive}: copy its contents to the first FAT32 partition, not raw sectors')


if __name__ == '__main__':
    main()
