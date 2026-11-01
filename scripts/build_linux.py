#!/usr/bin/env python3
"""Build one Linux Image with both testbench and ZedBoard UARTs, using an existing source tree and initramfs."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess

root = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--source', type=Path, required=True, help='clean, unpacked Linux source tree')
p.add_argument('--config', type=Path, required=True, help='Fuxi-Linux base/resolved kernel config')
p.add_argument('--initramfs', type=Path, required=True, help='existing rootfs.cpio')
p.add_argument('--cross-compile', default=os.environ.get('CROSS_COMPILE', 'riscv64-linux-gnu-'))
p.add_argument('--jobs', type=int, default=8)
a = p.parse_args()
source, config, initramfs = (path.resolve() for path in (a.source, a.config, a.initramfs))
out = root/'build/linux'
out.mkdir(parents=True, exist_ok=True)
env = dict(os.environ, ARCH='riscv', CROSS_COMPILE=a.cross_compile)
subprocess.run(['bash', str(source/'scripts/kconfig/merge_config.sh'), '-m', '-O', str(out),
                str(config), str(root/'software/linux/zedboard.config')], cwd=source, env=env, check=True)
subprocess.run([str(source/'scripts/config'), '--file', str(out/'.config'), '--set-str',
                'INITRAMFS_SOURCE', str(initramfs)], check=True)
command = ['make', '-C', str(source), 'O='+str(out)]
subprocess.run([*command, 'olddefconfig'], env=env, check=True)
resolved = (out/'.config').read_text()
for required in ['CONFIG_ARCH_RV32I=y', 'CONFIG_SERIAL_8250_CONSOLE=y',
                 'CONFIG_SERIAL_XILINX_PS_UART=y', 'CONFIG_SERIAL_XILINX_PS_UART_CONSOLE=y',
                 'CONFIG_COMMON_CLK=y']:
    if required not in resolved.splitlines():
        raise SystemExit('Kernel configuration did not enable '+required)
subprocess.run([*command, '-j'+str(a.jobs), 'Image'], env=env, check=True)
shutil.copyfile(out/'arch/riscv/boot/Image', root/'build/Image')
print('Unified kernel: '+str(root/'build/Image'))
