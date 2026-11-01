#!/usr/bin/env python3
"""Build pinned upstream ZedBoard FSBL with this design's generated PS init."""
import argparse
from pathlib import Path
import shutil
import subprocess
import zipfile

root = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--xsa', type=Path, default=root/'build/fuxi_zedboard.xsa')
a = p.parse_args()
work = root/'build/fsbl/embeddedsw'
upstream = root/'third_party/embeddedsw'
# Keep generated BSPs and objects out of the dependency checkout.
for directory in ['lib', 'XilinxProcessorIPLib/drivers']:
    shutil.copytree(upstream/directory, work/directory, dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns('.git', '*.o', '__pycache__'))
fsbl = work/'lib/sw_apps/zynq_fsbl'
# Remove only our generated BSP; a fresh copy avoids stale compiler options.
shutil.rmtree(fsbl/'misc/ps7_cortexa9_0', ignore_errors=True)
with zipfile.ZipFile(a.xsa) as archive:
    for name in ('ps7_init.c', 'ps7_init.h'):
        matches = [n for n in archive.namelist() if Path(n).name == name]
        if len(matches) != 1:
            raise SystemExit(f'{a.xsa}: expected one generated {name}, got {matches}')
        (fsbl/'misc/zed'/name).write_bytes(archive.read(matches[0]))
shutil.copyfile(root/'software/fsbl/fsbl_hooks.c', fsbl/'src/fsbl_hooks.c')
subprocess.run(['make', '-C', str(fsbl/'src'), 'BOARD=zed', 'SHELL=/bin/bash',
                'CFLAGS=-Wall -Os -g -c -ffunction-sections -fdata-sections -DFSBL_DEBUG'], check=True)
shutil.copyfile(fsbl/'src/fsbl.elf', root/'build/fsbl/fsbl.elf')
subprocess.run(['arm-none-eabi-size', str(root/'build/fsbl/fsbl.elf')], check=True)
