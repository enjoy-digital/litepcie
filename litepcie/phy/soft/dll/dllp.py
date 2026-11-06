#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY Data Link Layer Packets (PCIe Base 3.4): formats, encoder (CRC appended) and decoder
(CRC checked).

A DLLP is 4 bytes followed by its 16-bit CRC (byte 4: CRC bits 7:0 first), framed by SDP/END on the
lane. Fields (byte 0 first, bits numbered within each byte):
- Ack/Nak: byte 0 type (00h Ack, 10h Nak), byte 2 [3:0] AckNak_Seq_Num[11:8], byte 3 [7:0].
- InitFC1/InitFC2/UpdateFC-P/NP/Cpl: byte 0 [7:4] type, [2:0] VC ID; byte 1 [5:0] HdrFC[7:2];
  byte 2 [7:6] HdrFC[1:0], [3:0] DataFC[11:8]; byte 3 DataFC[7:0].
- PM_Enter_L1 20h, PM_Enter_L23 21h, PM_Active_State_Request_L1 23h, PM_Request_Ack 24h.
Bytes are on dllp[8*i:8*(i+1)] (byte 0 first), as on the lane.
"""

from migen import *

from litex.gen import *

from litepcie.phy.soft.dll.crc import DLLPCRC

# Types --------------------------------------------------------------------------------------------

DLLP_ACK            = 0x00
DLLP_NAK            = 0x10
DLLP_PM_ENTER_L1    = 0x20
DLLP_PM_ENTER_L23   = 0x21
DLLP_PM_ASR_L1      = 0x23
DLLP_PM_REQUEST_ACK = 0x24
DLLP_VENDOR         = 0x30
DLLP_INITFC1_P      = 0x40
DLLP_INITFC1_NP     = 0x50
DLLP_INITFC1_CPL    = 0x60
DLLP_UPDATEFC_P     = 0x80
DLLP_UPDATEFC_NP    = 0x90
DLLP_UPDATEFC_CPL   = 0xa0
DLLP_INITFC2_P      = 0xc0
DLLP_INITFC2_NP     = 0xd0
DLLP_INITFC2_CPL    = 0xe0

FC_TYPES = {"p": 0, "np": 1, "cpl": 2} # Credit types (byte 0 [5:4] of the FC DLLPs).

def dllp_bytes(type, seq=0, hdr_fc=0, data_fc=0, vc=0):
    """4 DLLP bytes (Python model)."""
    if type in [DLLP_ACK, DLLP_NAK]:
        return bytes([type, 0, (seq >> 8) & 0xf, seq & 0xff])
    if type & 0xc0: # Flow Control (InitFC1 4x-6x, UpdateFC 8x-Ax, InitFC2 Cx-Ex).
        return bytes([
            (type & 0xf0) | (vc & 0x7),
            (hdr_fc >> 2) & 0x3f,
            ((hdr_fc & 0x3) << 6) | ((data_fc >> 8) & 0xf),
            data_fc & 0xff,
        ])
    return bytes([type, 0, 0, 0])

# Encoder ------------------------------------------------------------------------------------------

class DLLPEncoder(LiteXModule):
    """DLLP (48 bits: 4 bytes + CRC) from its fields (combinatorial)."""
    def __init__(self):
        self.type    = Signal(8)  # i
        self.seq     = Signal(12) # i (Ack/Nak)
        self.hdr_fc  = Signal(8)  # i (FC)
        self.data_fc = Signal(12) # i (FC)
        self.vc      = Signal(3)  # i (FC)
        self.dllp    = Signal(48) # o

        # # #

        payload = Signal(32)
        fc      = self.type[6] | self.type[7] # InitFC1 (4x-6x), UpdateFC (8x-Ax), InitFC2 (Cx-Ex).
        self.comb += [
            payload[0:8].eq(Mux(fc, Cat(self.vc, Constant(0, 1), self.type[4:8]), self.type)),
            payload[8:16].eq(Mux(fc, Cat(self.hdr_fc[2:8], Constant(0, 2)), 0)),
            payload[16:24].eq(Mux(fc, Cat(self.data_fc[8:12], Constant(0, 2), self.hdr_fc[0:2]), Cat(self.seq[8:12], Constant(0, 4)))),
            payload[24:32].eq(Mux(fc, self.data_fc[0:8], self.seq[0:8])),
        ]
        self.crc = crc = DLLPCRC()
        self.comb += [
            crc.data.eq(payload),
            self.dllp.eq(Cat(payload, crc.value)),
        ]

# Decoder ------------------------------------------------------------------------------------------

class DLLPDecoder(LiteXModule):
    """Fields of a received DLLP (48 bits), crc_ok when the CRC matches (combinatorial)."""
    def __init__(self):
        self.dllp    = Signal(48) # i
        self.crc_ok  = Signal()   # o
        self.type    = Signal(8)  # o (FC: [7:4] type, [3:0] cleared; VC in vc)
        self.seq     = Signal(12) # o
        self.hdr_fc  = Signal(8)  # o
        self.data_fc = Signal(12) # o
        self.vc      = Signal(3)  # o
        self.fc      = Signal()   # o: Flow Control DLLP (InitFC1/InitFC2/UpdateFC).
        self.fc_type = Signal(2)  # o: 0: P, 1: NP, 2: Cpl.
        self.ack     = Signal()   # o
        self.nak     = Signal()   # o
        self.init1   = Signal()   # o: InitFC1.
        self.init2   = Signal()   # o: InitFC2.
        self.update  = Signal()   # o: UpdateFC.

        # # #

        payload = self.dllp[0:32]
        byte    = lambda i: payload[8*i:8*(i+1)]
        self.crc = crc = DLLPCRC()
        self.comb += [
            crc.data.eq(payload),
            self.crc_ok.eq(crc.value == self.dllp[32:48]),
            self.fc.eq(byte(0)[6] | byte(0)[7]),
            self.type.eq(Mux(self.fc, Cat(Constant(0, 4), byte(0)[4:8]), byte(0))),
            self.vc.eq(byte(0)[0:3]),
            self.fc_type.eq(byte(0)[4:6]),
            self.seq.eq(Cat(byte(3), byte(2)[0:4])),
            self.hdr_fc.eq(Cat(byte(2)[6:8], byte(1)[0:6])),
            self.data_fc.eq(Cat(byte(3), byte(2)[0:4])),
            self.ack.eq(self.crc_ok & (byte(0) == DLLP_ACK)),
            self.nak.eq(self.crc_ok & (byte(0) == DLLP_NAK)),
            self.init1.eq(self.crc_ok & self.fc & (byte(0)[6:8] == 0b01) & (byte(0)[4:6] != 0b11)),
            self.init2.eq(self.crc_ok & self.fc & (byte(0)[6:8] == 0b11) & (byte(0)[4:6] != 0b11)),
            self.update.eq(self.crc_ok & (byte(0)[6:8] == 0b10) & (byte(0)[4:6] != 0b11)),
        ]
