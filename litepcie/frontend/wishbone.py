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
    if qword_aligned:
        return If(address[2],
            wishbone_dat.eq(data[:32])
        ).Else(
            wishbone_dat.eq(data[32:64])
        )
    else:
        return wishbone_dat.eq(data[:32])

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

        wb_done           = Signal()
        completion_adr    = Signal.like(port.sink.adr)
        completion_tag    = Signal.like(port.sink.tag)
        completion_req_id = Signal.like(port.sink.req_id)
        completion_dat    = Signal.like(port.source.dat)
        completion_err    = Signal()

        self.comb += [
            wb_done.eq(self.bus.ack | self.bus.err),
            port.source.first.eq(1),
            port.source.last.eq(1),
            port.source.end.eq(1),
            port.source.len.eq(1),
            port.source.err.eq(completion_err),
            port.source.tag.eq(completion_tag),
            port.source.adr.eq(completion_adr),
            port.source.cmp_id.eq(endpoint.phy.id),
            port.source.req_id.eq(completion_req_id),
            port.source.dat.eq(completion_dat),
        ]

        # Wishbone Master FSM.
        self.fsm = fsm = FSM(reset_state="IDLE")
        fsm.act("IDLE",
            If(port.sink.valid & port.sink.first,
                NextValue(completion_tag,    port.sink.tag),
                NextValue(completion_adr,    port.sink.adr),
                NextValue(completion_req_id, port.sink.req_id),
                NextValue(completion_err,    0),
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
            If(wb_done,
                port.sink.ready.eq(1),
                NextState("IDLE")
            )
        )
        fsm.act("DO-READ",
            self.bus.stb.eq(1),
            self.bus.we.eq(0),
            self.bus.cyc.eq(1),
            If(wb_done,
                NextValue(completion_err, self.bus.err),
                If(self.bus.ack,
                    NextValue(completion_dat, self.bus.dat_r)
                ).Else(
                    NextValue(completion_dat, 0)
                ),
                NextState("ISSUE-READ-COMPLETION")
            )
        )
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
    def __init__(self, endpoint, address_width=32, data_width=32, addressing="word", qword_aligned=False):
        assert data_width == 32
        self.bus = self.wishbone = wishbone.Interface(
            address_width = address_width,
            data_width    = data_width,
            addressing    = addressing,
        )

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
        ashift = {"byte" : 0, "word" : 2}[addressing]
        self.comb += [
            port.source.channel.eq(port.channel),
            port.source.first.eq(1),
            port.source.last.eq(1),
            port.source.adr[ashift:].eq(self.bus.adr),
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
                If(~timeout.done & ~port.sink.err,
                    map_wishbone_dat(
                        address       = port.sink.adr,
                        data          = port.sink.dat,
                        wishbone_dat  = self.bus.dat_r,
                        qword_aligned = qword_aligned,
                    )
                ),
                self.bus.ack.eq(1),
                self.bus.err.eq(timeout.done | (port.sink.valid & port.sink.first & port.sink.err)),
                NextState("IDLE")
            )
        )
