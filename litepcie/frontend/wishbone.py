#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2020 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

from migen import *

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

class LitePCIeWishboneMaster(Module):
    def __init__(self, endpoint,
        address_decoder = lambda a: 1,
        base_address    = 0x00000000,
        qword_aligned   = False):
        self.wishbone = wishbone.Interface()

        # # #

        port = endpoint.crossbar.get_slave_port(address_decoder)

        self.submodules.fsm = fsm = FSM(reset_state="IDLE")
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
            self.wishbone.sel.eq(0xf),
            self.wishbone.adr.eq(port.sink.adr[2:] + (base_address >> 2)),
            map_wishbone_dat(
                address       = port.sink.adr,
                data          = port.sink.dat,
                wishbone_dat  = self.wishbone.dat_w,
                qword_aligned = qword_aligned,
            ),
        ]
        fsm.act("DO-WRITE",
            self.wishbone.stb.eq(1),
            self.wishbone.we.eq(1),
            self.wishbone.cyc.eq(1),
            If(self.wishbone.ack,
                port.sink.ready.eq(1),
                NextState("IDLE")
            )
        )
        update_dat = Signal()
        fsm.act("DO-READ",
            self.wishbone.stb.eq(1),
            self.wishbone.we.eq(0),
            self.wishbone.cyc.eq(1),
            If(self.wishbone.ack,
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
                port.source.dat.eq(self.wishbone.dat_r)
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

class LitePCIeWishboneSlave(Module):
    def __init__(self, endpoint, qword_aligned=False):
        self.wishbone = wishbone.Interface()

        # # #

        port = endpoint.crossbar.get_master_port()

        self.submodules.fsm = fsm = FSM(reset_state="IDLE")
        fsm.act("IDLE",
            If(self.wishbone.stb & self.wishbone.cyc,
                If(self.wishbone.we,
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
            port.source.adr[2:].eq(self.wishbone.adr),
            port.source.req_id.eq(endpoint.phy.id),
            port.source.tag.eq(0),
            port.source.len.eq(1),
            port.source.dat.eq(self.wishbone.dat_w),
        ]
        fsm.act("ISSUE-WRITE",
            port.source.valid.eq(1),
            port.source.we.eq(1),
            If(port.source.ready,
                self.wishbone.ack.eq(1),
                NextState("IDLE")
            )
        )
        fsm.act("ISSUE-READ",
            port.source.valid.eq(1),
            port.source.we.eq(0),
            If(port.source.ready,
                NextState("RECEIVE-READ-COMPLETION")
            )
        )
        fsm.act("RECEIVE-READ-COMPLETION",
            port.sink.ready.eq(1),
            If(port.sink.valid & port.sink.first,
                map_wishbone_dat(
                    address       = port.sink.adr,
                    data          = port.sink.dat,
                    wishbone_dat  = self.wishbone.dat_r,
                    qword_aligned = qword_aligned,
                ),
                self.wishbone.ack.eq(1),
                NextState("IDLE")
            )
        )
