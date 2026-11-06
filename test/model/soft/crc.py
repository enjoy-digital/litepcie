#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY reference models: LCRC (PCIe Base 3.5.2.1) and DLLP CRC (3.4.1), bit-serial.

Bytes in transmission order, bits LSB first within a byte, all-ones seed, remainder complemented and
bit-reversed; the integer results have the first transmitted CRC byte in bits 7:0.
"""

from litepcie.phy.soft.dll.crc import LCRC_POLYNOM, LCRC_INIT, DLLP_CRC_POLYNOM, DLLP_CRC_INIT

def crc_remainder(width, polynom, init, data):
    """LFSR remainder (MSB-first register) of data bytes, bits entering LSB first."""
    mask  = (1 << width) - 1
    state = init
    for value in data:
        for i in range(8):
            feedback = ((value >> i) & 0x1) ^ ((state >> (width - 1)) & 0x1)
            state    = (state << 1) & mask
            if feedback:
                state ^= polynom
    return state

def crc_output(width, remainder):
    """Complemented, bit-reversed remainder: bit i of the result is ~remainder[width-1-i]."""
    out = 0
    for i in range(width):
        out |= ((~remainder >> (width - 1 - i)) & 0x1) << i
    return out

def lcrc(data):
    """LCRC of data (TLP Sequence Number bytes + TLP bytes) as an integer (first byte in bits 7:0)."""
    return crc_output(32, crc_remainder(32, LCRC_POLYNOM, LCRC_INIT, data))

def lcrc_bytes(data):
    """LCRC bytes in transmission order."""
    return lcrc(data).to_bytes(4, "little")

def dllp_crc(data):
    """DLLP CRC of the 4 DLLP bytes as an integer (first byte in bits 7:0)."""
    assert len(data) == 4
    return crc_output(16, crc_remainder(16, DLLP_CRC_POLYNOM, DLLP_CRC_INIT, data))

def dllp_crc_bytes(data):
    """DLLP CRC bytes in transmission order (DLLP bytes 4 and 5)."""
    return dllp_crc(data).to_bytes(2, "little")
