#!/usr/bin/env python3
"""Pack raw OpenSBI FW_JUMP, Linux Image, and DTB into the Boot ROM image ABI."""

import argparse
import ctypes
import os
from pathlib import Path
import struct
import subprocess
import sys
import zlib

from image_layout import (ADDRESSES, HEADER_SIZE, LIMITS, MAGIC, PAYLOAD_LIMIT,
                          PAYLOAD_OFFSET, SCRATCH_SIZE, VERSION)

ROOT = Path(__file__).resolve().parents[1]


def codec_library():
    out = ROOT / 'build/host'
    out.mkdir(parents=True, exist_ok=True)
    lib = out / ('liblz4.dylib' if sys.platform == 'darwin' else 'liblz4.so')
    sources = [ROOT / 'third_party/lz4/lib' / name for name in ('lz4.c', 'lz4hc.c')]
    if not lib.exists() or any(p.stat().st_mtime > lib.stat().st_mtime for p in sources):
        subprocess.run([os.environ.get('HOST_CC', 'cc'), '-O2', '-shared', '-fPIC',
                        *map(str, sources), '-o', str(lib)], check=True)

    result = ctypes.CDLL(str(lib))
    result.LZ4_compressBound.argtypes = [ctypes.c_int]
    result.LZ4_compress_HC.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int,
                                       ctypes.c_int, ctypes.c_int]
    return result


def pack(images, compress=True):
    images = tuple(images)
    if len(images) != len(ADDRESSES):
        raise ValueError(f'exactly {len(ADDRESSES)} images are required')
    lib = codec_library() if compress else None
    chunks = []
    records = []
    offset = HEADER_SIZE
    for index, data in enumerate(images):
        if not data or len(data) > LIMITS[index]:
            raise ValueError(f'segment {index}: empty or too large for its DDR allocation')

        packed, codec = data, 0
        if lib:
            buf = ctypes.create_string_buffer(lib.LZ4_compressBound(len(data)))
            size = lib.LZ4_compress_HC(data, buf, len(data), len(buf), 12)
            if not size:
                raise ValueError('LZ4 compression failed')
            if size < len(data):
                packed, codec = buf.raw[:size], 1

        if len(packed) > SCRATCH_SIZE:
            raise ValueError(f'segment {index}: packed data exceeds the scratch buffer')
        aligned = (offset + 3) & ~3
        chunks.append(bytes(aligned - offset))
        offset = aligned
        records.append(struct.pack('<6I', ADDRESSES[index], offset, len(packed), len(data),
                                   zlib.crc32(data), codec))
        chunks.append(packed)
        offset += len(packed)

    if offset > PAYLOAD_LIMIT:
        raise ValueError(f'payload exceeds Flash bank 0 allocation ({PAYLOAD_LIMIT} bytes)')

    header = MAGIC + struct.pack('<2I', VERSION, 0) + b''.join(records)
    header = header[:12] + struct.pack('<I', zlib.crc32(header)) + header[16:]
    return header + b''.join(chunks)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--opensbi', type=Path, required=True)
    p.add_argument('--linux', type=Path, required=True, help='uncompressed RISC-V Image')
    p.add_argument('--dtb', type=Path, required=True)
    p.add_argument('--output', type=Path, default=ROOT / 'build/payload.bin')
    p.add_argument('--raw', action='store_true',
                   help=f'disable LZ4 (still subject to {PAYLOAD_LIMIT} byte payload limit)')
    a = p.parse_args()

    images = [path.read_bytes() for path in (a.opensbi, a.linux, a.dtb)]
    result = pack(images, not a.raw)

    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_bytes(result)
    print(f'{a.output}: {len(result)} bytes; Flash offset 0x{PAYLOAD_OFFSET:08x}')


if __name__ == '__main__':
    main()
