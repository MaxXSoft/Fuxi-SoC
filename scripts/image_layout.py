"""Shared image layout for the host tools and generated ROM C/assembly header."""

import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
LAYOUT = json.loads((ROOT / 'software/bootrom/image_layout.json').read_text())
MAGIC = struct.pack('8s', LAYOUT['magic'].encode('ascii'))
VERSION = LAYOUT['version']
SEGMENTS = LAYOUT['segments']
ADDRESSES = tuple(int(s['address'], 0) for s in SEGMENTS)
LIMITS = tuple(int(s['limit'], 0) for s in SEGMENTS)
HEADER_SIZE = struct.calcsize('<8sII') + len(SEGMENTS) * struct.calcsize('<6I')
FLASH_BANK_SIZE = int(LAYOUT['flash_bank_size'], 0)
PAYLOAD_OFFSET = int(LAYOUT['payload_offset'], 0)
PAYLOAD_LIMIT = FLASH_BANK_SIZE - PAYLOAD_OFFSET
FLASH_MIN_SIZE = PAYLOAD_OFFSET + HEADER_SIZE
SCRATCH_ADDRESS = int(LAYOUT['scratch_address'], 0)
SCRATCH_SIZE = int(LAYOUT['scratch_size'], 0)


def write_header(path):
    """Generate only preprocessor definitions so start.S can include them too."""
    values = {
        'IMAGE_VERSION': VERSION,
        'IMAGE_SEGMENTS': len(SEGMENTS),
        'IMAGE_HEADER_SIZE': HEADER_SIZE,
        'FLASH_PAYLOAD_OFFSET': PAYLOAD_OFFSET,
        'FLASH_PAYLOAD_LIMIT': PAYLOAD_LIMIT,
        'SCRATCH_ADDRESS': SCRATCH_ADDRESS,
        'SCRATCH_SIZE': SCRATCH_SIZE,
    }
    for segment, address, limit in zip(SEGMENTS, ADDRESSES, LIMITS):
        name = segment['name'].upper()
        values[name + '_ADDRESS'] = address
        values[name + '_LIMIT'] = limit

    lines = ['// Generated from software/bootrom/image_layout.json; do not edit.',
             '#ifndef FUXISOC_BOOTROM_IMAGE_LAYOUT_H_',
             '#define FUXISOC_BOOTROM_IMAGE_LAYOUT_H_', '',
             '#define IMAGE_MAGIC ' + json.dumps(LAYOUT['magic'])]
    lines.extend(f'#define {name} 0x{value:08x}' for name, value in values.items())
    for suffix in ('ADDRESS', 'LIMIT'):
        names = ', '.join(s['name'].upper() + '_' + suffix for s in SEGMENTS)
        macro = 'IMAGE_ADDRESSES' if suffix == 'ADDRESS' else 'IMAGE_LIMITS'
        lines.append(f'#define {macro} {{{names}}}')
    lines += ['', '#endif  // FUXISOC_BOOTROM_IMAGE_LAYOUT_H_', '']
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text('\n'.join(lines))
