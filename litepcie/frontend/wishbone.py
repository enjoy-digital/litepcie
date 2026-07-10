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
    # Exit early if data width is 32 bits to avoid a zero-width slice.
    if len(data) == 32:
        return [wishbone_dat.eq(data)]

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

        # Read Request State.
        request_adr       = Signal(32)
        request_len       = Signal(10)
        request_first_be  = Signal(4)
        request_last_be   = Signal(4)
        request_req_id    = Signal(16)
        request_tc        = Signal(3)
        request_tag       = Signal(8)
        dword_index       = Signal(10)
        byte_count        = Signal(12)
        read_dat          = Signal(32)

        first_byte_count = Signal(3)
        last_byte_count  = Signal(3)
        request_byte_count = Signal(12)
        self.comb += [
            first_byte_count.eq(sum(port.sink.first_be[n] for n in range(4))),
            last_byte_count.eq(sum(port.sink.last_be[n] for n in range(4))),
            If(port.sink.len == 1,
                request_byte_count.eq(first_byte_count),
            ).Else(
                request_byte_count.eq(first_byte_count + last_byte_count + 4*(port.sink.len - 2)),
            ),
        ]

        current_be = Signal(4)
        self.comb += If(request_len == 1,
            current_be.eq(request_first_be),
        ).Elif(dword_index == 0,
            current_be.eq(request_first_be),
        ).Elif(dword_index == (request_len - 1),
            current_be.eq(request_last_be),
        ).Else(
            current_be.eq(0xf),
        )

        current_byte_count = Signal(3)
        current_lower_offset = Signal(2)
        self.comb += [
            current_byte_count.eq(sum(current_be[n] for n in range(4))),
            If(current_be[0],
                current_lower_offset.eq(0),
            ).Elif(current_be[1],
                current_lower_offset.eq(1),
            ).Elif(current_be[2],
                current_lower_offset.eq(2),
            ).Else(
                current_lower_offset.eq(3),
            ),
        ]

        # Wishbone Master FSM.
        self.fsm = fsm = FSM(reset_state="IDLE")
        fsm.act("IDLE",
            If(port.sink.valid & port.sink.first,
                If(port.sink.we,
                    NextState("DO-WRITE")
                ).Else(
                    NextValue(request_adr,      port.sink.adr),
                    NextValue(request_len,      port.sink.len),
                    NextValue(request_first_be, port.sink.first_be),
                    NextValue(request_last_be,  port.sink.last_be),
                    NextValue(request_req_id,   port.sink.req_id),
                    NextValue(request_tc,       port.sink.tc),
                    NextValue(request_tag,      port.sink.tag),
                    NextValue(dword_index,      0),
                    NextValue(byte_count,       request_byte_count),
                    NextState("DO-READ")
                )
            ).Else(
                port.sink.ready.eq(1)
            )
        )
        self.comb += [
            self.bus.sel.eq(Mux(fsm.ongoing("DO-READ"), current_be, 0xf)),
            If(fsm.ongoing("DO-READ"),
                self.bus.adr.eq(request_adr[2:] + dword_index + (base_address >> 2)),
            ).Else(
                self.bus.adr.eq(port.sink.adr[2:] + (base_address >> 2)),
            ),
        ]
        self.sync += [
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
        fsm.act("DO-READ",
            self.bus.stb.eq(1),
            self.bus.we.eq(0),
            self.bus.cyc.eq(1),
            If(self.bus.ack,
                NextValue(read_dat, self.bus.dat_r),
                NextState("ISSUE-READ-COMPLETION")
            )
        )
        self.comb += [
            port.source.first.eq(1),
            port.source.last.eq(1),
            port.source.len.eq(1),
            port.source.byte_count.eq(byte_count),
            port.source.err.eq(0),
            port.source.tag.eq(request_tag),
            port.source.adr.eq(request_adr + 4*dword_index + current_lower_offset),
            port.source.cmp_id.eq(endpoint.phy.id),
            port.source.req_id.eq(request_req_id),
            port.source.tc.eq(request_tc),
            port.source.dat.eq(read_dat),
        ]
        fsm.act("ISSUE-READ-COMPLETION",
            port.source.valid.eq(1),
            If(port.source.ready,
                If(dword_index == (request_len - 1),
                    port.sink.ready.eq(1),
                    NextState("IDLE"),
                ).Else(
                    NextValue(dword_index, dword_index + 1),
                    NextValue(byte_count, byte_count - current_byte_count),
                    NextState("DO-READ"),
                )
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
