#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY Data Link Layer receiver (PCIe Base 3.5.3): TLPs from the lane words (RXFramer),
LCRC and sequence number checks, store-and-forward to the Transaction Layer, Ack/Nak scheduling,
received DLLPs, credits of the delivered TLPs."""

from migen import *

from litex.gen import *

from litex.soc.interconnect import stream

from litepcie.phy.soft.common           import lane_layout
from litepcie.phy.soft.dll.crc          import LCRC
from litepcie.phy.soft.dll.framing      import RXFramer
from litepcie.phy.soft.dll.buffer       import PacketBuffer
from litepcie.phy.soft.dll.flow_control import tlp_credits

# DLL RX -------------------------------------------------------------------------------------------

class DLLRX(LiteXModule):
    def __init__(self, depth=2048, packets=32):
        self.reset        = Signal()                          # i
        self.sink         = sink   = stream.Endpoint(lane_layout(4))   # i: lane words (L0).
        self.source       = source = stream.Endpoint([("data", 32)])   # o: TLPs (LCRC removed).
        self.dllp         = Signal(48) # o
        self.dllp_valid   = Signal()   # o (Pulse)
        self.ack_req      = Signal()   # o (Pulse): schedule an Ack (ack_seq).
        self.nak_req      = Signal()   # o (Pulse): schedule a Nak (ack_seq).
        self.ack_seq      = Signal(12) # o: NEXT_RCV_SEQ - 1.
        self.deliver      = Signal()   # o (Pulse): TLP delivered to the Transaction Layer.
        self.deliver_type = Signal(2)  # o
        self.deliver_data = Signal(9)  # o
        self.errors       = Signal(16) # o: LCRC/sequence/framing errors.

        # # #

        # Framing.
        self.framer = framer = RXFramer()
        self.comb += [
            sink.connect(framer.sink),
            self.dllp.eq(framer.dllp),
            self.dllp_valid.eq(framer.dllp_valid),
        ]

        # LCRC over the Sequence Number and the TLP DWs (the last DW is the received LCRC).
        self.lcrc = lcrc = LCRC(data_width=64, sizes=[4, 6])
        tlp = framer.tlp
        self.comb += [
            tlp.ready.eq(1),
            lcrc.ce.eq(tlp.valid & ~tlp.last),
            If(tlp.first,
                lcrc.data.eq(Cat(Constant(0, 4), tlp.seq[8:12], tlp.seq[0:8], tlp.data)),
                lcrc.bytes.eq(6),
            ).Else(
                lcrc.data.eq(tlp.data),
                lcrc.bytes.eq(4),
            ),
            lcrc.clear.eq(self.reset | (tlp.valid & tlp.last)),
        ]

        # Store-and-forward buffer, the TLP DWs delayed by one word (the LCRC DW is not stored).
        self.buffer = buffer = PacketBuffer([("fc_type", 2), ("fc_data", 9)], depth=depth, packets=packets)
        statements, dw0_type, dw0_data = tlp_credits(tlp.data)
        self.comb += statements
        fc_type  = Signal(2)
        fc_data  = Signal(9)
        prev_valid = Signal()
        prev_data  = Signal(32)
        prev_first = Signal()
        prev_seq   = Signal(12)
        lost       = Signal() # Word not accepted by the buffer.
        lost_r     = Signal() # Words lost in the current TLP: dropped at its end.
        self.sync += [
            If(self.reset | (tlp.valid & tlp.last) | framer.tlp_abort,
                lost_r.eq(0)
            ).Elif(lost,
                lost_r.eq(1)
            ),
            If(self.reset | (tlp.valid & tlp.last) | framer.tlp_abort,
                prev_valid.eq(0)
            ).Elif(tlp.valid,
                prev_valid.eq(1),
                prev_data.eq(tlp.data),
                prev_first.eq(tlp.first),
                If(tlp.first,
                    prev_seq.eq(tlp.seq),
                    fc_type.eq(dw0_type),
                    fc_data.eq(dw0_data),
                ),
            )
        ]
        self.comb += [
            buffer.sink.valid.eq(tlp.valid & prev_valid),
            buffer.sink.data.eq(prev_data),
            buffer.sink.first.eq(prev_first),
            buffer.sink.last.eq(tlp.last),
            buffer.sink.fc_type.eq(fc_type),
            buffer.sink.fc_data.eq(fc_data),
            lost.eq(buffer.sink.valid & ~buffer.sink.ready),
        ]

        # Checks at the LCRC DW.
        next_seq      = Signal(12)
        nak_scheduled = Signal()
        lcrc_ok       = Signal()
        seq_diff      = Signal(12)
        in_order      = Signal()
        duplicate     = Signal()
        accept        = Signal()
        bad           = Signal()
        end           = tlp.valid & tlp.last
        self.comb += [
            lcrc_ok.eq(Mux(tlp.edb, lcrc.value == ~tlp.data, lcrc.value == tlp.data)),
            seq_diff.eq(next_seq - prev_seq),
            in_order.eq(seq_diff == 0),
            duplicate.eq((seq_diff != 0) & (seq_diff < 2048)),
            accept.eq(end & prev_valid & lcrc_ok & ~tlp.edb & in_order & ~lost & ~lost_r),
            bad.eq(end & (~prev_valid | ~lcrc_ok | lost | lost_r | (~tlp.edb & ~in_order & ~duplicate))),
            buffer.abort.eq((end & (~accept | lost | lost_r)) | framer.tlp_abort),
            self.ack_seq.eq(next_seq - 1),
            self.ack_req.eq(accept | (end & lcrc_ok & ~tlp.edb & duplicate)),
            self.nak_req.eq((bad | framer.tlp_abort | framer.error) & ~nak_scheduled),
        ]
        self.sync += [
            If(self.reset,
                next_seq.eq(0),
                nak_scheduled.eq(0),
                self.errors.eq(0),
            ).Else(
                If(accept,
                    next_seq.eq(next_seq + 1),
                    nak_scheduled.eq(0),
                ),
                If(self.nak_req,
                    nak_scheduled.eq(1),
                    self.errors.eq(self.errors + 1),
                ),
            )
        ]

        # Transaction Layer delivery and credits.
        self.comb += [
            buffer.source.connect(source, omit={"fc_type", "fc_data"}),
            self.deliver.eq(source.valid & source.ready & source.last),
            self.deliver_type.eq(buffer.source.fc_type),
            self.deliver_data.eq(buffer.source.fc_data),
        ]
