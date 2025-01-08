#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2023 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

from migen import *

from litex.gen import *
from litex.gen.genlib.misc import WaitTimer

from litex.soc.interconnect import wishbone

from litepcie.common import *

# Helpers ------------------------------------------------------------------------------------------

def map_wishbone_dat(address, data, wishbone_dat, qword_aligned=False):
    return [
        If(qword_aligned,
            If(address[2],
                wishbone_dat.eq(data[:32])
            ).Else(
                wishbone_dat.eq(data[32:])
            )
        ).Else(
            wishbone_dat.eq(data[:32])
        )
    ]

# LitePCIeWishboneMaster ---------------------------------------------------------------------------

class LitePCIeWishboneMaster(LiteXModule):
    def __init__(self, endpoint,
        address_decoder = lambda a: 1,
        base_address    = 0x00000000,
        qword_aligned   = False):
        self.bus = self.wishbone = wishbone.Interface()

        # # #

        # Get Slave port from Crossbar.
        port = endpoint.crossbar.get_slave_port(address_decoder)

        # Wishbone Master FSM.
        self.fsm = fsm = FSM(reset_state="IDLE")
        fsm.act("IDLE",
            If(port.sink.valid & port.sink.first,
                If(port.sink.we,
                    NextState("DO-WRITE")
                ).Else(
                    NextState("DO-READ")
                )
            ).Else(
                port.sink.ready.eq(1)
            )
        )
        self.sync += [
            self.bus.sel.eq(0xf),
            self.bus.adr.eq(port.sink.adr[2:] + (base_address >> 2)),
            map_wishbone_dat(
                address       = port.sink.adr,
                data          = port.sink.dat,
                wishbone_dat  = self.bus.dat_w,
                qword_aligned = qword_aligned,
            ),
        ]
        fsm.act("DO-WRITE",
            self.bus.stb.eq(1),
            self.bus.we.eq(1),
            self.bus.cyc.eq(1),
            If(self.bus.ack,
                port.sink.ready.eq(1),
                NextState("IDLE")
            )
        )
        update_dat = Signal()
        fsm.act("DO-READ",
            self.bus.stb.eq(1),
            self.bus.we.eq(0),
            self.bus.cyc.eq(1),
            If(self.bus.ack,
                update_dat.eq(1),
                NextState("ISSUE-READ-COMPLETION")
            )
        )
        self.sync += [
            port.source.first.eq(1),
            port.source.last.eq(1),
            port.source.len.eq(1),
            port.source.err.eq(0),
            port.source.tag.eq(port.sink.tag),
            port.source.adr.eq(port.sink.adr),
            port.source.cmp_id.eq(endpoint.phy.id),
            port.source.req_id.eq(port.sink.req_id),
            If(update_dat,
                port.source.dat.eq(self.bus.dat_r)
            )
        ]
        fsm.act("ISSUE-READ-COMPLETION",
            port.source.valid.eq(1),
            If(port.source.ready,
                port.sink.ready.eq(1),
                NextState("IDLE")
            )
        )

class LitePCIeWishboneBridge(LitePCIeWishboneMaster): pass # initial name

# LitePCIeWishboneSlave ----------------------------------------------------------------------------

class LitePCIeWishboneSlave(LiteXModule):
    def __init__(self, endpoint, qword_aligned=False):
        self.bus = self.wishbone = wishbone.Interface()

        # # #

        # Timeout.
        self.timeout = timeout = WaitTimer(2**16)

        # Get Master port from Crossbar.
        port = endpoint.crossbar.get_master_port()

        # Wishbone Slave FSM.
        self.fsm = fsm = FSM(reset_state="IDLE")
        fsm.act("IDLE",
            If(self.bus.stb & self.bus.cyc,
                If(self.bus.we,
                    NextState("ISSUE-WRITE")
                ).Else(
                    NextState("ISSUE-READ")
                )
            )
        )
        self.comb += [
            port.source.channel.eq(port.channel),
            port.source.first.eq(1),
            port.source.last.eq(1),
            port.source.adr[2:].eq(self.bus.adr),
            port.source.req_id.eq(endpoint.phy.id),
            port.source.tag.eq(0),
            port.source.len.eq(1),
            port.source.dat.eq(self.bus.dat_w),
        ]
        fsm.act("ISSUE-WRITE",
            timeout.wait.eq(1),
            port.source.valid.eq(1),
            port.source.we.eq(1),
            If(port.source.ready | timeout.done,
                self.bus.ack.eq(1),
                self.bus.err.eq(timeout.done),
                NextState("IDLE")
            )
        )
        fsm.act("ISSUE-READ",
            timeout.wait.eq(1),
            port.source.valid.eq(1),
            port.source.we.eq(0),
            If(port.source.ready | timeout.done,
                NextState("RECEIVE-READ-COMPLETION")
            )
        )
        fsm.act("RECEIVE-READ-COMPLETION",
            timeout.wait.eq(1),
            port.sink.ready.eq(1),
            If((port.sink.valid & port.sink.first) | timeout.done,
                map_wishbone_dat(
                    address       = port.sink.adr,
                    data          = port.sink.dat,
                    wishbone_dat  = self.bus.dat_r,
                    qword_aligned = qword_aligned,
                ),
                self.bus.ack.eq(1),
                self.bus.err.eq(timeout.done),
                NextState("IDLE")
            )
        )
