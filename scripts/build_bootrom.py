#!/usr/bin/env python3
"""Build a freestanding RV32 Boot ROM with LLVM or a RISC-V GCC toolchain."""
import argparse
import os
from pathlib import Path
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--cc', default=os.environ.get('RISCV_CC', 'clang'))
p.add_argument('--objcopy', default=os.environ.get('RISCV_OBJCOPY', 'llvm-objcopy'))
p.add_argument('--ld', default=os.environ.get('RISCV_LD'))
a = p.parse_args()
out = ROOT / 'build/bootrom'
out.mkdir(parents=True, exist_ok=True)
src = ROOT / 'software/bootrom'
lz4 = ROOT / 'third_party/lz4/lib'
flags = ['-march=rv32imac_zicsr_zifencei', '-mabi=ilp32', '-Os', '-g', '-ffreestanding',
         '-fno-builtin', '-ffunction-sections', '-fdata-sections', '-fno-stack-protector',
         '-Wall', '-Wextra', '-Werror', '-I'+str(src), '-I'+str(lz4),
         '-DLZ4_FREESTANDING=1', '-DLZ4_memcpy=memcpy', '-DLZ4_memmove=memmove', '-DLZ4_memset=memset',
         '-include', str(src/'memory.h')]
if 'clang' in Path(a.cc).name:
    flags += ['--target=riscv32-unknown-elf']
objects = []
for path in [src/'start.S', src/'main.c', src/'image.c', src/'memory.c', lz4/'lz4.c']:
    obj = out/(path.stem+'.o')
    subprocess.run([a.cc, *flags, '-c', str(path), '-o', str(obj)], check=True)
    objects.append(str(obj))
link = [a.cc, *flags, '-nostdlib', '-Wl,--gc-sections,--build-id=none', '-Wl,-T,'+str(src/'link.ld'),
        '-Wl,-Map,'+str(out/'bootrom.map')]
if a.ld:
    link.append(('--ld-path=' if 'clang' in Path(a.cc).name else '-fuse-ld=')+a.ld)
subprocess.run([*link, *objects, '-o', str(out/'bootrom.elf')], check=True)
subprocess.run([a.objcopy, '-O', 'binary', str(out/'bootrom.elf'), str(out/'bootrom.bin')], check=True)
body = (out/'bootrom.bin').read_bytes()
if len(body) > 0x3e00:
    raise SystemExit('Boot ROM exceeds 16 KiB')
image = bytes(0x200) + body
image += bytes(0x4000-len(image))
words = struct.unpack('<4096I', image)
(out/'bootrom.coe').write_text('memory_initialization_radix=16;\nmemory_initialization_vector=\n'+
                              ',\n'.join(f'{w:08x}' for w in words)+';\n')
(out/'bootrom.mem').write_text(''.join(f'{w:08x}\n' for w in words))
print(f'Boot ROM: {len(body)} bytes of code/constant data; 16 KiB initialized BRAM')
