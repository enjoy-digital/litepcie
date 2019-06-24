# This file is Copyright (c) 2015-2019 Florent Kermarrec <florent@enjoy-digital.fr>
# License: BSD

from migen import *

from litex.soc.interconnect import wishbone

from litepcie.common import *


class LitePCIeWishboneBridge(Module):
    def __init__(self, endpoint, address_decoder, shadow_base=0x00000000, qword_aligned=False):
        self.wishbone = wishbone.Interface()

        # # #

        port = endpoint.crossbar.get_slave_port(address_decoder)
        self.submodules.fsm = fsm = FSM()

        update_dat = Signal()

        fsm.act("IDLE",
            If(port.sink.valid & port.sink.first,
                If(port.sink.we,
                    NextState("WRITE"),
                ).Else(
                    NextState("READ")
                )
            ).Else(
                port.sink.ready.eq(port.sink.valid)
            )
        )
        self.sync += [
            self.wishbone.sel.eq(0xf),
            self.wishbone.adr.eq(port.sink.adr[2:] | (shadow_base >> 2)),
            If(qword_aligned,
                If(port.sink.adr[2],
                    self.wishbone.dat_w.eq(port.sink.dat[:32])
                ).Else(
                    self.wishbone.dat_w.eq(port.sink.dat[32:])
                )
            ).Else(
                self.wishbone.dat_w.eq(port.sink.dat[:32]),
            )
        ]
        fsm.act("WRITE",
            self.wishbone.stb.eq(1),
            self.wishbone.we.eq(1),
            self.wishbone.cyc.eq(1),
            If(self.wishbone.ack,
                NextState("TERMINATE")
            )
        )
        fsm.act("READ",
            self.wishbone.stb.eq(1),
            self.wishbone.we.eq(0),
            self.wishbone.cyc.eq(1),
            If(self.wishbone.ack,
                update_dat.eq(1),
                NextState("COMPLETION")
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
                port.source.dat.eq(self.wishbone.dat_r),
            )
        ]
        fsm.act("COMPLETION",
            port.source.valid.eq(1),
            If(port.source.ready,
                NextState("TERMINATE")
            )
        )
        fsm.act("TERMINATE",
            port.sink.ready.eq(1),
            NextState("IDLE")
        )

