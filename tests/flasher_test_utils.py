"""Synthetic Zynq/Fuxi image shared by host and U-Boot sandbox tests."""

import struct


def image():
    data = bytearray(0x800080)
    words = [0xaa995566, 0x584c4e58, 0, 0, 0x8c0, 4, 0, 0, 4, 0]
    struct.pack_into('<11I', data, 0x20, *words, ~sum(words) & 0xffffffff)
    data[0x800000:0x800008] = b'FUXISOC\0'
    return bytes(data)
