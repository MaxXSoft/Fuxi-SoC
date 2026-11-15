#!/usr/bin/env python3
"""Build a PS-only ZedBoard SD maintenance shell using upstream U-Boot SPL."""

import argparse
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def config_values(path):
    values = {}
    for line in path.read_text().splitlines():
        if line.startswith('CONFIG_') and '=' in line:
            key, value = line.split('=', 1)
            values[key] = value
        elif line.startswith('# CONFIG_') and line.endswith(' is not set'):
            values[line[2:-11]] = 'n'
    return values


def check_config(path):
    values = config_values(path)
    required = config_values(ROOT / 'software/flasher/zedboard.config')
    required.update({
        'CONFIG_SPL': 'y', 'CONFIG_SPL_MMC': 'y', 'CONFIG_SPL_FS_FAT': 'y',
        'CONFIG_SPL_FS_LOAD_PAYLOAD_NAME': '"u-boot.img"',
        'CONFIG_ZYNQ_QSPI': 'y', 'CONFIG_SPI_FLASH_SPANSION': 'y',
        'CONFIG_MMC_SDHCI_ZYNQ': 'y', 'CONFIG_ZYNQ_SERIAL': 'y',
        'CONFIG_HUSH_PARSER': 'y',
        'CONFIG_CMD_IMPORTENV': 'y',
    })
    for key, wanted in required.items():
        actual = values.get(key, 'n')
        if actual != wanted:
            raise RuntimeError(f'{key}: need {wanted}, got {actual}')
    persistent = [key for key, value in values.items()
                  if key.startswith('CONFIG_ENV_IS_IN_') and value == 'y']
    if persistent:
        raise RuntimeError(f'persistent environment must be disabled: {persistent}')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--cross-compile', default='arm-none-eabi-')
    p.add_argument('--jobs', type=int, default=min(os.cpu_count() or 1, 8))
    a = p.parse_args()

    source = ROOT / 'third_party/u-boot'
    if not (source / 'include/ctype.h').is_symlink():
        raise RuntimeError('U-Boot requires real symlinks; check out the submodule '
                           'with git core.symlinks=true before syncing it')

    out = ROOT / 'build/sd-flasher/u-boot'
    out.mkdir(parents=True, exist_ok=True)

    env = os.environ.copy()
    env.update(ARCH='arm', CROSS_COMPILE=a.cross_compile, DEVICE_TREE='zynq-zed',
               KBUILD_BUILD_USER='fuxi', KBUILD_BUILD_HOST='builder',
               # Stable build timestamp; this is the pinned v2026.04 commit date.
               SOURCE_DATE_EPOCH='1775498358', LOCALVERSION='')

    make = ['make', '-C', str(source), f'O={out}']
    subprocess.run(make + ['xilinx_zynq_virt_defconfig'], env=env, check=True)
    subprocess.run(['bash', str(source / 'scripts/kconfig/merge_config.sh'),
                    '-m', '-O', str(out), str(out / '.config'),
                    str(ROOT / 'software/flasher/zedboard.config')],
                   cwd=out, env=env, check=True)
    subprocess.run(make + ['olddefconfig'], env=env, check=True)

    check_config(out / '.config')

    subprocess.run(make + [f'-j{a.jobs}', 'all'], env=env, check=True)
    subprocess.run([str(out / 'tools/mkimage'), '-l', str(out / 'spl/boot.bin')], check=True)
    subprocess.run([str(out / 'tools/mkimage'), '-l', str(out / 'u-boot.img')], check=True)

    print(f'Raw SPL image: {out}/spl/boot.bin (package before copying to SD)')
    print(f'SD second stage: {out}/u-boot.img (also required)')


if __name__ == '__main__':
    main()
