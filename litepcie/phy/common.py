#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2020 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

from migen import *
from migen.genlib.cdc import MultiReg

from litepcie.common import *

# AXISRX128BAligner --------------------------------------------------------------------------------

class AXISRX128BAligner(Module):
    def __init__(self):
        self.sink   = sink   = stream.Endpoint(phy_layout(128))
        self.source = source = stream.Endpoint(phy_layout(128))
        self.first_dword = Signal(2)

        # # #

        dat_last = Signal(64, reset_less=True)
        be_last  = Signal(8, reset_less=True)
        self.sync += [
            If(sink.valid & sink.ready,
                dat_last.eq(sink.dat[64:]),
                be_last.eq( sink.be[8:]),
            )
        ]

        self.submodules.fsm = fsm = FSM(reset_state="ALIGNED")
        fsm.act("ALIGNED",
            sink.connect(source, omit={"first"}),
            # If "first" on DWORD2 and "last" on the same cycle, switch to UNALIGNED.
            If(sink.valid & sink.last & sink.first & (self.first_dword == 2),
                source.be[8:].eq(0),
                If(source.ready,
                    NextState("UNALIGNED")
                )
            )
        )
        fsm.act("UNALIGNED",
            sink.connect(source, omit={"first", "dat", "be"}),
            source.dat.eq(Cat(dat_last, sink.dat)),
            source.be.eq( Cat(be_last,  sink.be)),
            # If "last" and not "first" on the same cycle, switch to ALIGNED.
            If(sink.valid & sink.last & ~sink.first,
                source.be[8:].eq(0),
                If(source.ready,
                    NextState("ALIGNED")
                )
            )
        )
