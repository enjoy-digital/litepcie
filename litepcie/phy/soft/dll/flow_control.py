#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY Data Link Layer Flow Control (PCIe Base 3.3, 2.6.1): credit types of the TLPs,
transmitter credit gating (CREDIT_LIMIT/CREDITS_CONSUMED) and receiver credit allocation
(CREDITS_ALLOCATED), per type (Posted, Non-Posted, Completion), header (8 bits) and data (12 bits,
16-byte units) credits. Infinite credits are advertised with 0 header and 0 data credits in InitFC.
"""

from migen import *

from litex.gen import *

# TLP credit type ----------------------------------------------------------------------------------

FC_P, FC_NP, FC_CPL = 0, 1, 2

def tlp_credits(dw0):
    """(statements, fc_type, data_credits) from the TLP header DW0 (byte 0 on bits 7:0): Fmt
    (byte 0 [7:5]), Type (byte 0 [4:0]), Length (byte 2 [1:0], byte 3). Completions: Type 0101x.
    Posted: Memory Writes (Fmt 01x, Type 00000) and Messages (Type 10xxx). Non-Posted: others."""
    fmt    = dw0[5:8]
    type   = dw0[0:5]
    length = Cat(dw0[24:32], dw0[16:18]) # DWs, 0: 1024.
    has_data   = fmt[1]
    fc_type    = Signal(2)
    data       = Signal(9)
    statements = [
        If(type[1:5] == 0b0101,
            fc_type.eq(FC_CPL)
        ).Elif((has_data & (type == 0)) | (type[3:5] == 0b10),
            fc_type.eq(FC_P)
        ).Else(
            fc_type.eq(FC_NP)
        ),
        If(~has_data,
            data.eq(0)
        ).Elif(length == 0,
            data.eq(256)
        ).Else(
            data.eq((length + 3)[2:11])
        ),
    ]
    return statements, fc_type, data

# Flow Control TX ----------------------------------------------------------------------------------

class FlowControlTX(LiteXModule):
    """Transmitter credits: limits from the received InitFC/UpdateFC DLLPs, consumed on transmission.
    ok: the TLP (tlp_type, 1 header credit, tlp_data data credits) can be transmitted."""
    def __init__(self):
        self.reset    = Signal()   # i
        self.fc_type  = Signal(2)  # i: received FC DLLP type.
        self.fc_hdr   = Signal(8)  # i
        self.fc_data  = Signal(12) # i
        self.init     = Signal()   # i (Pulse): InitFC1/InitFC2 received.
        self.update   = Signal()   # i (Pulse): UpdateFC received.
        self.tlp_type = Signal(2)  # i
        self.tlp_data = Signal(9)  # i
        self.ok       = Signal()   # o
        self.consume  = Signal()   # i (Pulse)

        # # #

        self.limit_hdr     = limit_hdr     = Array(Signal(8)  for _ in range(3))
        self.limit_data    = limit_data    = Array(Signal(12) for _ in range(3))
        self.consumed_hdr  = consumed_hdr  = Array(Signal(8)  for _ in range(3))
        self.consumed_data = consumed_data = Array(Signal(12) for _ in range(3))
        self.infinite      = infinite      = Array(Signal()   for _ in range(3))

        for t in range(3):
            self.sync += [
                If(self.reset,
                    limit_hdr[t].eq(0),
                    limit_data[t].eq(0),
                    consumed_hdr[t].eq(0),
                    consumed_data[t].eq(0),
                    infinite[t].eq(0),
                ).Else(
                    If((self.init | self.update) & (self.fc_type == t),
                        limit_hdr[t].eq(self.fc_hdr),
                        limit_data[t].eq(self.fc_data),
                    ),
                    If(self.init & (self.fc_type == t),
                        infinite[t].eq((self.fc_hdr == 0) & (self.fc_data == 0))
                    ),
                    If(self.consume & (self.tlp_type == t),
                        consumed_hdr[t].eq(consumed_hdr[t] + 1),
                        consumed_data[t].eq(consumed_data[t] + self.tlp_data),
                    ),
                )
            ]

        # Gating: CREDIT_LIMIT - (CREDITS_CONSUMED + needed) mod 2^N <= 2^(N-1).
        hdr_diff  = Signal(8)
        data_diff = Signal(12)
        self.comb += [
            hdr_diff.eq(limit_hdr[self.tlp_type] - (consumed_hdr[self.tlp_type] + 1)),
            data_diff.eq(limit_data[self.tlp_type] - (consumed_data[self.tlp_type] + self.tlp_data)),
            self.ok.eq(infinite[self.tlp_type] | ((hdr_diff <= 128) & (data_diff <= 2048))),
        ]

# Flow Control RX ----------------------------------------------------------------------------------

class FlowControlRX(LiteXModule):
    """Receiver credits: initial credits (advertised in InitFC: the receive buffer capacity) and
    CREDITS_ALLOCATED incremented as TLPs are delivered to the Transaction Layer. changed[t] is set
    when the allocated credits of a type change (UpdateFC to send), cleared by sent."""
    def __init__(self, p_hdr, p_data, np_hdr, np_data, cpl_hdr=0, cpl_data=0):
        self.reset        = Signal()  # i
        self.deliver      = Signal()  # i (Pulse): TLP delivered to the Transaction Layer.
        self.deliver_type = Signal(2) # i
        self.deliver_data = Signal(9) # i
        self.sent         = Signal()  # i (Pulse): UpdateFC sent for sent_type.
        self.sent_type    = Signal(2) # i
        self.changed      = Signal(3) # o

        # # #

        initial = [(p_hdr, p_data), (np_hdr, np_data), (cpl_hdr, cpl_data)]
        self.initial_hdr    = [hdr  for hdr, data in initial]
        self.initial_data   = [data for hdr, data in initial]
        self.infinite       = [(hdr == 0) and (data == 0) for hdr, data in initial]
        self.allocated_hdr  = allocated_hdr  = Array(Signal(8,  reset=hdr)  for hdr, data in initial)
        self.allocated_data = allocated_data = Array(Signal(12, reset=data) for hdr, data in initial)
        for t in range(3):
            self.sync += [
                If(self.reset,
                    allocated_hdr[t].eq(self.initial_hdr[t]),
                    allocated_data[t].eq(self.initial_data[t]),
                    self.changed[t].eq(0),
                ).Else(
                    If(self.deliver & (self.deliver_type == t),
                        allocated_hdr[t].eq(allocated_hdr[t] + 1),
                        allocated_data[t].eq(allocated_data[t] + self.deliver_data),
                        self.changed[t].eq(not self.infinite[t]),
                    ).Elif(self.sent & (self.sent_type == t),
                        self.changed[t].eq(0)
                    )
                )
            ]
