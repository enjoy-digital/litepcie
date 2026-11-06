#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY Data Link Layer transmitter (PCIe Base 3.5.2): TLPs from the Transaction Layer
through the retry buffer, LCRC appended, framed with the DLLPs on the lane words."""

from migen import *

from litex.gen import *

from litex.soc.interconnect import stream

from litepcie.phy.soft.common      import lane_layout
from litepcie.phy.soft.dll.crc     import LCRC
from litepcie.phy.soft.dll.framing import TXFramer, seq_symbols
from litepcie.phy.soft.dll.retry   import ReplayBuffer

# DLL TX -------------------------------------------------------------------------------------------

class DLLTX(LiteXModule):
    def __init__(self, depth=1024, descriptors=16, replay_timer=375):
        self.reset      = Signal() # i
        self.enable     = Signal() # i: TLPs transmission allowed (DL_Active).
        self.sink       = sink   = stream.Endpoint([("data", 32)])  # i: TLPs from the TL.
        self.source     = source = stream.Endpoint(lane_layout(4))  # o: lane words.
        self.dllp       = Signal(48) # i
        self.dllp_valid = Signal()   # i (Level)
        self.dllp_ready = Signal()   # o (Pulse)

        # # #

        self.replay = replay = ReplayBuffer(depth=depth, descriptors=descriptors, replay_timer=replay_timer)
        self.comb += [
            replay.reset.eq(self.reset),
            replay.enable.eq(self.enable),
            sink.connect(replay.sink),
        ]

        # LCRC appended after the last DW.
        self.lcrc = lcrc = LCRC(data_width=64, sizes=[4, 6])
        self.framer = framer = TXFramer()
        tlp  = framer.tlp
        self.fsm = fsm = FSM(reset_state="DATA")
        fsm.act("DATA",
            replay.source.connect(tlp, omit={"last", "edb"}),
            tlp.last.eq(0),
            tlp.edb.eq(0),
            lcrc.ce.eq(replay.source.valid & replay.source.ready),
            If(replay.source.valid & replay.source.ready & replay.source.last,
                NextState("LCRC")
            )
        )
        fsm.act("LCRC",
            tlp.valid.eq(1),
            tlp.last.eq(1),
            tlp.data.eq(lcrc.value),
            If(tlp.ready,
                lcrc.clear.eq(1),
                NextState("DATA")
            )
        )
        self.comb += [
            If(replay.source.first,
                lcrc.data.eq(Cat(seq_symbols(replay.source.seq), replay.source.data)),
                lcrc.bytes.eq(6),
            ).Else(
                lcrc.data.eq(replay.source.data),
                lcrc.bytes.eq(4),
            ),
            If(self.reset, lcrc.clear.eq(1)),
        ]

        # DLLPs.
        self.comb += [
            framer.dllp.eq(self.dllp),
            framer.dllp_valid.eq(self.dllp_valid),
            self.dllp_ready.eq(framer.dllp_ready),
            framer.source.connect(source),
        ]
