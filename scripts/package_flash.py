#!/usr/bin/env python3
"""Create BOOT.BIN (FSBL+PL) and a bank-0 Flash image; does not program hardware."""
import argparse
from pathlib import Path
import subprocess

from flash_metadata import make_metadata

root = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--fsbl', type=Path, default=root/'build/fsbl/fsbl.elf')
p.add_argument('--bitstream', type=Path, default=root/'build/fuxi_zedboard.bit')
p.add_argument('--payload', type=Path, default=root/'build/payload.bin')
p.add_argument('--bootgen', default='bootgen')
a = p.parse_args()
out = root/'build/flash'
out.mkdir(parents=True, exist_ok=True)
# Copy inputs to stable, relative, whitespace-free BIF paths.
for name, path in [('fsbl.elf', a.fsbl), ('system.bit', a.bitstream)]:
    (out/name).write_bytes(path.read_bytes())
(out/'boot.bif').write_text('the_ROM_image:\n{\n  [bootloader] fsbl.elf\n  system.bit\n}\n')
subprocess.run([a.bootgen, '-arch', 'zynq', '-image', 'boot.bif', '-o', 'BOOT.BIN', '-w', 'on'], cwd=out, check=True)
boot = (out/'BOOT.BIN').read_bytes()
payload = a.payload.read_bytes()
if len(boot) > 0x800000 or len(payload) > 0x800000:
    raise SystemExit('BOOT.BIN or payload overlaps its 8 MiB Flash allocation')
flash = boot + b'\xff'*(0x800000-len(boot)) + payload
metadata = make_metadata(flash)
(out/'flash.bin').write_bytes(flash)
(out/'flash.meta').write_text(metadata)
print(f'{out}/flash.bin: {0x800000+len(payload)} bytes, program at Flash offset 0')
print(f'{out}/flash.meta: copy alongside flash.bin for the SD flasher')
