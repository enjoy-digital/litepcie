#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2019 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

from migen import *
from migen.genlib.misc import chooser

from litepcie.tlp.common import *

# LitePCIeTLPHeaderInserter64b ---------------------------------------------------------------------

class LitePCIeTLPHeaderInserter64b(Module):
    def __init__(self, endianness):
        self.sink   = sink   = stream.Endpoint(tlp_raw_layout(64))
        self.source = source = stream.Endpoint(phy_layout(64))

        # # #

        dat  = Signal(64, reset_less=True)
        last = Signal(reset_less=True)
        self.sync += \
            If(sink.valid & sink.ready,
                dat.eq(sink.dat),
                last.eq(sink.last)
            )

        self.submodules.fsm = fsm = FSM(reset_state="HEADER1")
        fsm.act("HEADER1",
            sink.ready.eq(1),
            If(sink.first,
                sink.ready.eq(0),
                source.valid.eq(sink.valid),
                source.first.eq(sink.first),
                source.last.eq(0),
                # 32 lsbs
                source.dat[32*0:32*1].eq(sink.header[32*0:32*1]),
                source.be[4*0:4*1].eq(0xf),
                # 32 msbs
                source.dat[32*1:32*2].eq(sink.header[32*1:32*2]),
                source.be[4*1:4*2].eq(0xf),
                If(source.valid & source.ready,
                    NextState("HEADER2"),
                )
            )
        )
        fsm.act("HEADER2",
            source.valid.eq(1),
            source.last.eq(sink.last),
            # 32 lsbs
            source.dat[32*0:32*1].eq(sink.header[32*2:32*3]),
            source.be[4*0:4*1].eq(0xf),
            # 32 msbs
            source.dat[32*1:32*2].eq(convert_bytes(sink.dat[32*0:32*1], endianness)),
            source.be[4*1:4*2].eq(convert_bits(sink.be[:4], endianness)),
            If(source.valid & source.ready,
                sink.ready.eq(1),
                If(source.last,
                    NextState("HEADER1")
                ).Else(
                    NextState("DATA")
                )
            )
        )
        fsm.act("DATA",
            source.valid.eq(sink.valid | last),
            source.last.eq(last),
            # 32 msbs
            source.dat[32*0:32*1].eq(convert_bytes(dat[32*1:32*2], endianness)),
			source.be[4*0:4*1].eq(0xf),
            # 32 lsbs
            source.dat[32*1:32*2].eq(convert_bytes(sink.dat[32*0:32*1], endianness)),
            If(last,
                source.be[4*1:4*2].eq(0x0)
            ).Else(
                source.be[4*1:4*2].eq(0xf)
            ),
            If(source.valid & source.ready,
                sink.ready.eq(~last),
                If(source.last,
                    NextState("HEADER1")
                )
            )
        )

# LitePCIeTLPHeaderInserter128b --------------------------------------------------------------------

class LitePCIeTLPHeaderInserter128b(Module):
    def __init__(self, endianness):
        self.sink   = sink   = stream.Endpoint(tlp_raw_layout(128))
        self.source = source = stream.Endpoint(phy_layout(128))

        # # #

        dat  = Signal(128, reset_less=True)
        last = Signal(reset_less=True)
        self.sync += \
            If(sink.valid & sink.ready,
                dat.eq(sink.dat),
                last.eq(sink.last)
            )

        self.submodules.fsm = fsm = FSM(reset_state="HEADER")
        fsm.act("HEADER",
            sink.ready.eq(1),
            If(sink.valid & sink.first,
                sink.ready.eq(0),
                source.valid.eq(1),
                source.first.eq(1),
                source.last.eq(sink.last),
                # 32 l lsbs
                source.dat[32*0:32*1].eq(sink.header[32*0:32*1]),
                source.be[4*0:4*1].eq(0xf),
                # 32 l msbs
                source.dat[32*1:32*2].eq(sink.header[32*1:32*2]),
                source.be[4*1:4*2].eq(0xf),
                # 32 h lsbs
                source.dat[32*2:32*3].eq(sink.header[32*2:32*3]),
                source.be[4*2:4*3].eq(0xf),
                # 32 h msbs
                source.dat[32*3:32*4].eq(convert_bytes(sink.dat[32*0:32*1], endianness)),
                source.be[4*3:4*4].eq(convert_bits(sink.be[:4], endianness)),
                If(source.valid & source.ready,
                    sink.ready.eq(1),
                    If(~source.last,
                        NextState("DATA"),
                    )
                )
            )
        )
        fsm.act("DATA",
            source.valid.eq(sink.valid | last),
            source.last.eq(last),
            # 32 l lsbs
            source.dat[32*0:32*1].eq(convert_bytes(dat[32*1:32*2], endianness)),
            source.be[4*0:4*1].eq(0xf),
            # 32 l msbs
            source.dat[32*1:32*2].eq(convert_bytes(dat[32*2:32*3], endianness)),
            source.be[4*1:4*2].eq(0xf),
            # 32 h lsbs
            source.dat[32*2:32*3].eq(convert_bytes(dat[32*3:2*32*4], endianness)),
            source.be[4*2:4*3].eq(0xf),
            # 32 h msbs
            source.dat[32*3:32*4].eq(convert_bytes(sink.dat[32*0:32*1], endianness)),
            If(last,
                source.be[4*3:4*4].eq(0x0)
            ).Else(
                source.be[4*3:4*4].eq(0xf)
            ),
            If(source.valid & source.ready,
                sink.ready.eq(~last),
                If(source.last,
                    NextState("HEADER")
                )
            )
        )

# LitePCIeTLPHeaderInserter256b --------------------------------------------------------------------

class LitePCIeTLPHeaderInserter256b(Module):
    def __init__(self, endianness):
        self.sink   = sink   = stream.Endpoint(tlp_raw_layout(256))
        self.source = source = stream.Endpoint(phy_layout(256))

        # # #

        dat  = Signal(256, reset_less=True)
        be  = Signal(256//8, reset_less=True)
        last = Signal(reset_less=True)
        self.sync += \
            If(sink.valid & sink.ready,
                dat.eq(sink.dat),
                be.eq(sink.be),
                last.eq(sink.last)
            )

        self.submodules.fsm = fsm = FSM(reset_state="HEADER")
        fsm.act("HEADER",
            sink.ready.eq(1),
            If(sink.valid & sink.first,
                sink.ready.eq(0),
                source.valid.eq(1),
                source.first.eq(1),
                source.last.eq(sink.last),

                source.dat[32*0:32*1].eq(sink.header[32*0:32*1]),
                source.dat[32*1:32*2].eq(sink.header[32*1:32*2]),
                source.dat[32*2:32*3].eq(sink.header[32*2:32*3]),
                source.dat[32*3:32*4].eq(convert_bytes(sink.dat[32*0:32*1], endianness)),
                source.dat[32*4:32*5].eq(convert_bytes(sink.dat[32*1:32*2], endianness)),
                source.dat[32*5:32*6].eq(convert_bytes(sink.dat[32*2:32*3], endianness)),
                source.dat[32*6:32*7].eq(convert_bytes(sink.dat[32*3:32*4], endianness)),
                source.dat[32*7:32*8].eq(convert_bytes(sink.dat[32*4:32*5], endianness)),

                source.be[4*0:4*1].eq(0xf),
                source.be[4*1:4*2].eq(0xf),
                source.be[4*2:4*3].eq(0xf),
                source.be[4*3:4*4].eq(convert_bits(sink.be[4*0:4*1], endianness)),
                source.be[4*4:4*5].eq(convert_bits(sink.be[4*1:4*2], endianness)),
                source.be[4*5:4*6].eq(convert_bits(sink.be[4*2:4*3], endianness)),
                source.be[4*6:4*7].eq(convert_bits(sink.be[4*3:4*4], endianness)),
                source.be[4*7:4*8].eq(convert_bits(sink.be[4*4:4*5], endianness)),

                If(source.valid & source.ready,
                    sink.ready.eq(1),
                    If(~source.last,
                        NextState("DATA"),
                    )
                )
            )
        )
        fsm.act("DATA",
            source.valid.eq(sink.valid | last),
            source.last.eq(last),

            source.dat[32*0:32*1].eq(convert_bytes(dat[32*5:32*6], endianness)),
            source.dat[32*1:32*2].eq(convert_bytes(dat[32*6:32*7], endianness)),
            source.dat[32*2:32*3].eq(convert_bytes(dat[32*7:32*8], endianness)),
            source.dat[32*3:32*4].eq(convert_bytes(sink.dat[32*0:32*1], endianness)),
            source.dat[32*4:32*5].eq(convert_bytes(sink.dat[32*1:32*2], endianness)),
            source.dat[32*5:32*6].eq(convert_bytes(sink.dat[32*2:32*3], endianness)),
            source.dat[32*6:32*7].eq(convert_bytes(sink.dat[32*3:32*4], endianness)),
            source.dat[32*7:32*8].eq(convert_bytes(sink.dat[32*4:32*5], endianness)),

            source.be[4*0:4*1].eq(convert_bits(be[4*5:4*6], endianness)),
            source.be[4*1:4*2].eq(convert_bits(be[4*6:4*7], endianness)),
            source.be[4*2:4*3].eq(convert_bits(be[4*7:4*8], endianness)),
            If(last,
                source.be[4*3:4*8].eq(0x0)
            ).Else(
                source.be[4*3:4*4].eq(convert_bits(sink.be[4*0:4*1], endianness)),
                source.be[4*4:4*5].eq(convert_bits(sink.be[4*1:4*2], endianness)),
                source.be[4*5:4*6].eq(convert_bits(sink.be[4*2:4*3], endianness)),
                source.be[4*6:4*7].eq(convert_bits(sink.be[4*3:4*4], endianness)),
                source.be[4*7:4*8].eq(convert_bits(sink.be[4*4:4*5], endianness)),
            ),
            If(source.valid & source.ready,
                sink.ready.eq(~last),
                If(source.last,
                    NextState("HEADER")
                )
            )
        )

# LitePCIeTLPHeaderInserter512b --------------------------------------------------------------------

class LitePCIeTLPHeaderInserter512b(Module):
    def __init__(self, endianness):
        self.sink   = sink   = stream.Endpoint(tlp_raw_layout(512))
        self.source = source = stream.Endpoint(phy_layout(512))

        # # #

        dat  = Signal(512, reset_less=True)
        be  = Signal(512//8, reset_less=True)
        last = Signal(reset_less=True)
        self.sync += \
            If(sink.valid & sink.ready,
                dat.eq(sink.dat),
                be.eq(sink.be),
                last.eq(sink.last)
            )

        self.submodules.fsm = fsm = FSM(reset_state="HEADER")
        fsm.act("HEADER",
            sink.ready.eq(1),
            If(sink.valid & sink.first,
                sink.ready.eq(0),
                source.valid.eq(1),
                source.first.eq(1),
                source.last.eq(sink.last),

                source.dat[32*0:32*1].eq(sink.header[32*0:32*1]),
                source.dat[32*1:32*2].eq(sink.header[32*1:32*2]),
                source.dat[32*2:32*3].eq(sink.header[32*2:32*3]),
                source.dat[32*3:32*4].eq(convert_bytes(sink.dat[32*0:32*1], endianness)),
                source.dat[32*4:32*5].eq(convert_bytes(sink.dat[32*1:32*2], endianness)),
                source.dat[32*5:32*6].eq(convert_bytes(sink.dat[32*2:32*3], endianness)),
                source.dat[32*6:32*7].eq(convert_bytes(sink.dat[32*3:32*4], endianness)),
                source.dat[32*7:32*8].eq(convert_bytes(sink.dat[32*4:32*5], endianness)),
                source.dat[32*8:32*9].eq(convert_bytes(sink.dat[32*5:32*6], endianness)),
                source.dat[32*9:32*10].eq(convert_bytes(sink.dat[32*6:32*7], endianness)),
                source.dat[32*10:32*11].eq(convert_bytes(sink.dat[32*7:32*8], endianness)),
                source.dat[32*11:32*12].eq(convert_bytes(sink.dat[32*8:32*9], endianness)),
                source.dat[32*12:32*13].eq(convert_bytes(sink.dat[32*9:32*10], endianness)),
                source.dat[32*13:32*14].eq(convert_bytes(sink.dat[32*10:32*11], endianness)),
                source.dat[32*14:32*15].eq(convert_bytes(sink.dat[32*11:32*12], endianness)),
                source.dat[32*15:32*16].eq(convert_bytes(sink.dat[32*12:32*13], endianness)),

                source.be[4*0:4*1].eq(0xf),
                source.be[4*1:4*2].eq(0xf),
                source.be[4*2:4*3].eq(0xf),
                source.be[4*3:4*4].eq(convert_bits(sink.be[4*0:4*1], endianness)),
                source.be[4*4:4*5].eq(convert_bits(sink.be[4*1:4*2], endianness)),
                source.be[4*5:4*6].eq(convert_bits(sink.be[4*2:4*3], endianness)),
                source.be[4*6:4*7].eq(convert_bits(sink.be[4*3:4*4], endianness)),
                source.be[4*7:4*8].eq(convert_bits(sink.be[4*4:4*5], endianness)),
                source.be[4*8:4*9].eq(convert_bits(sink.be[4*5:4*6], endianness)),
                source.be[4*9:4*10].eq(convert_bits(sink.be[4*6:4*7], endianness)),
                source.be[4*10:4*11].eq(convert_bits(sink.be[4*7:4*8], endianness)),
                source.be[4*11:4*12].eq(convert_bits(sink.be[4*8:4*9], endianness)),
                source.be[4*12:4*13].eq(convert_bits(sink.be[4*9:4*10], endianness)),
                source.be[4*13:4*14].eq(convert_bits(sink.be[4*10:4*11], endianness)),
                source.be[4*14:4*15].eq(convert_bits(sink.be[4*11:4*12], endianness)),
                source.be[4*15:4*16].eq(convert_bits(sink.be[4*12:4*13], endianness)),

                If(source.valid & source.ready,
                    sink.ready.eq(1),
                    If(~source.last,
                        NextState("DATA"),
                    )
                )
            )
        )
        fsm.act("DATA",
            source.valid.eq(sink.valid | last),
            source.last.eq(last),

            source.dat[32*0:32*1].eq(convert_bytes(dat[32*13:32*14], endianness)),
            source.dat[32*1:32*2].eq(convert_bytes(dat[32*14:32*15], endianness)),
            source.dat[32*2:32*3].eq(convert_bytes(dat[32*15:32*16], endianness)),
            source.dat[32*3:32*4].eq(convert_bytes(sink.dat[32*0:32*1], endianness)),
            source.dat[32*4:32*5].eq(convert_bytes(sink.dat[32*1:32*2], endianness)),
            source.dat[32*5:32*6].eq(convert_bytes(sink.dat[32*2:32*3], endianness)),
            source.dat[32*6:32*7].eq(convert_bytes(sink.dat[32*3:32*4], endianness)),
            source.dat[32*7:32*8].eq(convert_bytes(sink.dat[32*4:32*5], endianness)),
            source.dat[32*8:32*9].eq(convert_bytes(sink.dat[32*5:32*6], endianness)),
            source.dat[32*9:32*10].eq(convert_bytes(sink.dat[32*6:32*7], endianness)),
            source.dat[32*10:32*11].eq(convert_bytes(sink.dat[32*7:32*8], endianness)),
            source.dat[32*11:32*12].eq(convert_bytes(sink.dat[32*8:32*9], endianness)),
            source.dat[32*12:32*13].eq(convert_bytes(sink.dat[32*9:32*10], endianness)),
            source.dat[32*13:32*14].eq(convert_bytes(sink.dat[32*10:32*11], endianness)),
            source.dat[32*14:32*15].eq(convert_bytes(sink.dat[32*11:32*12], endianness)),
            source.dat[32*15:32*16].eq(convert_bytes(sink.dat[32*12:32*13], endianness)),

            source.be[4*0:4*1].eq(convert_bits(be[4*13:4*14], endianness)),
            source.be[4*1:4*2].eq(convert_bits(be[4*14:4*15], endianness)),
            source.be[4*2:4*3].eq(convert_bits(be[4*15:4*16], endianness)),
            If(last,
                source.be[4*3:4*16].eq(0x0)
            ).Else(
                source.be[4*3:4*4].eq(convert_bits(sink.be[4*0:4*1], endianness)),
                source.be[4*4:4*5].eq(convert_bits(sink.be[4*1:4*2], endianness)),
                source.be[4*5:4*6].eq(convert_bits(sink.be[4*2:4*3], endianness)),
                source.be[4*6:4*7].eq(convert_bits(sink.be[4*3:4*4], endianness)),
                source.be[4*7:4*8].eq(convert_bits(sink.be[4*4:4*5], endianness)),
                source.be[4*8:4*9].eq(convert_bits(sink.be[4*5:4*6], endianness)),
                source.be[4*9:4*10].eq(convert_bits(sink.be[4*6:4*7], endianness)),
                source.be[4*10:4*11].eq(convert_bits(sink.be[4*7:4*8], endianness)),
                source.be[4*11:4*12].eq(convert_bits(sink.be[4*8:4*9], endianness)),
                source.be[4*12:4*13].eq(convert_bits(sink.be[4*9:4*10], endianness)),
                source.be[4*13:4*14].eq(convert_bits(sink.be[4*10:4*11], endianness)),
                source.be[4*14:4*15].eq(convert_bits(sink.be[4*11:4*12], endianness)),
                source.be[4*15:4*16].eq(convert_bits(sink.be[4*12:4*13], endianness)),
            ),
            If(source.valid & source.ready,
                sink.ready.eq(~last),
                If(source.last,
                    NextState("HEADER")
                )
            )
        )

# LitePCIeTLPPacketizer ----------------------------------------------------------------------------

class LitePCIeTLPPacketizer(Module):
    def __init__(self, data_width, endianness):
        self.req_sink = req_sink = stream.Endpoint(request_layout(data_width))
        self.cmp_sink = cmp_sink = stream.Endpoint(completion_layout(data_width))
        self.source   = stream.Endpoint(phy_layout(data_width))

        # # #

        # Format TLP request and encode it ---------------------------------------------------------
        self.tlp_req = tlp_req = stream.Endpoint(tlp_request_layout(data_width))
        self.comb += [
            tlp_req.valid.eq(req_sink.valid),
            req_sink.ready.eq(tlp_req.ready),
            tlp_req.first.eq(req_sink.first),
            tlp_req.last.eq(req_sink.last),

            If(req_sink.we,
                Cat(tlp_req.type, tlp_req.fmt).eq(fmt_type_dict["mem_wr32"])
            ).Else(
                Cat(tlp_req.type, tlp_req.fmt).eq(fmt_type_dict["mem_rd32"])
            ),

            tlp_req.tc.eq(0),
            tlp_req.td.eq(0),
            tlp_req.ep.eq(0),
            tlp_req.attr.eq(0),
            tlp_req.length.eq(req_sink.len),

            tlp_req.requester_id.eq(req_sink.req_id),
            tlp_req.tag.eq(req_sink.tag),
            If(req_sink.len > 1,
                tlp_req.last_be.eq(0xf)
            ).Else(
                tlp_req.last_be.eq(0x0)
            ),
            tlp_req.first_be.eq(0xf),
            tlp_req.address.eq(req_sink.adr),

            tlp_req.dat.eq(req_sink.dat),
            If(req_sink.we,
                tlp_req.be.eq(2**(data_width//8)-1)
            ).Else(
                tlp_req.be.eq(0x00)
            )
        ]

        tlp_raw_req = stream.Endpoint(tlp_raw_layout(data_width))
        self.comb += [
            tlp_raw_req.valid.eq(tlp_req.valid),
            tlp_req.ready.eq(tlp_raw_req.ready),
            tlp_raw_req.first.eq(tlp_req.first),
            tlp_raw_req.last.eq(tlp_req.last),
            tlp_request_header.encode(tlp_req, tlp_raw_req.header),
            tlp_raw_req.dat.eq(tlp_req.dat),
            tlp_raw_req.be.eq(tlp_req.be)
        ]

        # Format TLP completion and encode it ------------------------------------------------------
        self.tlp_cmp = tlp_cmp = stream.Endpoint(tlp_completion_layout(data_width))
        self.comb += [
            tlp_cmp.valid.eq(cmp_sink.valid),
            cmp_sink.ready.eq(tlp_cmp.ready),
            tlp_cmp.first.eq(cmp_sink.first),
            tlp_cmp.last.eq(cmp_sink.last),

            tlp_cmp.tc.eq(0),
            tlp_cmp.td.eq(0),
            tlp_cmp.ep.eq(0),
            tlp_cmp.attr.eq(0),
            tlp_cmp.length.eq(cmp_sink.len),

            tlp_cmp.completer_id.eq(cmp_sink.cmp_id),
            If(cmp_sink.err,
                Cat(tlp_cmp.type, tlp_cmp.fmt).eq(fmt_type_dict["cpl"]),
                tlp_cmp.status.eq(cpl_dict["ur"])
            ).Else(
                Cat(tlp_cmp.type, tlp_cmp.fmt).eq(fmt_type_dict["cpld"]),
                tlp_cmp.status.eq(cpl_dict["sc"])
            ),
            tlp_cmp.bcm.eq(0),
            tlp_cmp.byte_count.eq(cmp_sink.len*4),

            tlp_cmp.requester_id.eq(cmp_sink.req_id),
            tlp_cmp.tag.eq(cmp_sink.tag),
            tlp_cmp.lower_address.eq(cmp_sink.adr),

            tlp_cmp.dat.eq(cmp_sink.dat),
            If(cmp_sink.last & cmp_sink.first,
                tlp_cmp.be.eq(0xf)
            ).Else(
                tlp_cmp.be.eq(2**(data_width//8)-1)
            ),
        ]

        tlp_raw_cmp = stream.Endpoint(tlp_raw_layout(data_width))
        self.comb += [
            tlp_raw_cmp.valid.eq(tlp_cmp.valid),
            tlp_cmp.ready.eq(tlp_raw_cmp.ready),
            tlp_raw_cmp.first.eq(tlp_cmp.first),
            tlp_raw_cmp.last.eq(tlp_cmp.last),
            tlp_completion_header.encode(tlp_cmp, tlp_raw_cmp.header),
            tlp_raw_cmp.dat.eq(tlp_cmp.dat),
            tlp_raw_cmp.be.eq(tlp_cmp.be)
        ]

        # Arbitrate --------------------------------------------------------------------------------
        tlp_raw = stream.Endpoint(tlp_raw_layout(data_width))
        self.submodules.arbitrer = Arbiter([tlp_raw_req, tlp_raw_cmp], tlp_raw)

        # Insert header ----------------------------------------------------------------------------
        header_inserter_cls = {
            64 : LitePCIeTLPHeaderInserter64b,
           128 : LitePCIeTLPHeaderInserter128b,
           256 : LitePCIeTLPHeaderInserter256b,
           512 : LitePCIeTLPHeaderInserter512b,
        }
        header_inserter = header_inserter_cls[data_width](endianness)
        self.submodules += header_inserter
        self.comb += [
            tlp_raw.connect(header_inserter.sink),
            header_inserter.source.connect(self.source)
        ]
