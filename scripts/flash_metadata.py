#!/usr/bin/env python3
"""Validate a Fuxi Flash image and write its SD flasher length/SHA-256 sidecar."""

import argparse
import hashlib
from pathlib import Path
import struct


def check_zynq_image(data):
    if len(data) < 0x8c0:
        raise ValueError('truncated Zynq boot image')
    words = struct.unpack_from('<11I', data, 0x20)
    if words[:2] != (0xaa995566, 0x584c4e58) or sum(words) & 0xffffffff != 0xffffffff:
        raise ValueError('invalid Zynq boot header or checksum')
    if words[4] < 0x8c0 or words[5] == 0 or words[4] + words[5] > len(data):
        raise ValueError('invalid Zynq first-stage bounds')


def make_metadata(flash):
    check_zynq_image(flash)
    if not 0x800058 <= len(flash) <= 0x1000000:
        raise ValueError('Fuxi Flash image must fit bank 0 and include the payload')
    if flash[0x800000:0x800008] != b'FUXISOC\0':
        raise ValueError('expected Fuxi payload at Flash offset 8 MiB')
    return (f'fuxi_flash_size=0x{len(flash):x}\n'
            f'fuxi_flash_sha256={hashlib.sha256(flash).hexdigest()}\n')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('flash', type=Path)
    p.add_argument('--output', type=Path, help='default: input path with .meta suffix')
    a = p.parse_args()

    output = a.output or a.flash.with_suffix('.meta')
    if output.resolve() == a.flash.resolve():
        p.error('metadata output must differ from the Flash image')

    output.write_text(make_metadata(a.flash.read_bytes()))
    print(output)


if __name__ == '__main__':
    main()
