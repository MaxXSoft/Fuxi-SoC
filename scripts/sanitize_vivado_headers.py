#!/usr/bin/env python3
"""Work around Vivado 2025.2 spilling Linux os-release text out of HDL comments.

Only known os-release assignments in a generated file's first 12 lines, following
its Host comment, are changed. No RTL statements or installed tools are edited.
"""

from pathlib import Path
import re
import sys

count = 0
for root in sys.argv[1:]:
    for path in Path(root).rglob('*'):
        if path.suffix not in ('.v', '.sv', '.vhd', '.vhdl'):
            continue

        lines = path.read_text(encoding='latin-1').splitlines(keepends=True)
        marker = '--' if path.suffix in ('.vhd', '.vhdl') else '//'
        in_host = False
        changed = False
        for i, line in enumerate(lines[:12]):
            if line.startswith(marker + 'Host'):
                in_host = True
            elif in_host and re.match(r'^(VERSION_ID|VERSION_CODENAME|VERSION|NAME|ID)=', line):
                lines[i] = marker + line
                changed = True
            elif in_host:
                in_host = False
        if changed:
            path.write_text(''.join(lines), encoding='latin-1')
            count += 1

print(f'Normalized OS metadata comments in {count} generated HDL files')
