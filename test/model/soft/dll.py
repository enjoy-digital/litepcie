#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY reference models: Data Link Layer framing (PCIe Base 4.2.2.1) and DLLPs (3.4)."""

from litepcie.phy.soft.common   import STP, SDP, END, EDB
from litepcie.phy.soft.dll.dllp import dllp_bytes

from test.model.soft.crc import lcrc_bytes, dllp_crc_bytes

def tlp_frame(seq, tlp, nullified=False):
    """Lane Symbols of a framed TLP: STP, Sequence Number, TLP bytes, LCRC, END (EDB if nullified,
    with the LCRC inverted)."""
    seq_bytes = seq.to_bytes(2, "big")
    crc = lcrc_bytes(seq_bytes + tlp)
    if nullified:
        crc = bytes(b ^ 0xff for b in crc)
    symbols  = [(STP.value, 1)]
    symbols += [(b, 0) for b in seq_bytes + tlp + crc]
    symbols += [(EDB.value if nullified else END.value, 1)]
    return symbols

def dllp_frame(type, **fields):
    """Lane Symbols of a framed DLLP: SDP, 4 bytes, CRC, END."""
    payload = dllp_bytes(type, **fields)
    return [(SDP.value, 1)] + [(b, 0) for b in payload + dllp_crc_bytes(payload)] + [(END.value, 1)]

def dllp_value(type, **fields):
    """48-bit DLLP value (byte 0 on bits 7:0) with its CRC."""
    payload = dllp_bytes(type, **fields)
    return int.from_bytes(payload + dllp_crc_bytes(payload), "little")
