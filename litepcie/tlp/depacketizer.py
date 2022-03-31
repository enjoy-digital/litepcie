#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2022 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

from migen import *

from litepcie.tlp.common import *

# LitePCIeTLPHeaderExtracter64b --------------------------------------------------------------------

class LitePCIeTLPHeaderExtracter64b(Module):
    def __init__(self):
        self.sink   = sink   = stream.Endpoint(phy_layout(64))
        self.source = source = stream.Endpoint(tlp_raw_layout(64))

        # # #

        first = Signal()
        last  = Signal()
        count = Signal()
        dat   = Signal(64,    reset_less=True)
        be    = Signal(64//8, reset_less=True)
        self.sync += \
            If(sink.valid & sink.ready,
                dat.eq(sink.dat),
                be.eq(sink.be)
            )

        self.submodules.fsm = fsm = FSM(reset_state="IDLE")
        fsm.act("IDLE",
            NextValue(first, 1),
            NextValue(last,  0),
            NextValue(count, 0),
            If(sink.valid, NextState("HEADER"))
        )
        fsm.act("HEADER",
            sink.ready.eq(1),
            If(sink.valid,
                NextValue(count, count + 1),
                NextValue(source.header[32*0:32*1], source.header[32*2:32*3]),
                NextValue(source.header[32*1:32*2], source.header[32*3:32*4]),
                NextValue(source.header[32*2:32*3],      sink.dat[32*0:32*1]),
                NextValue(source.header[32*3:32*4],      sink.dat[32*1:32*2]),
                If(count,
                    If(sink.last, NextValue(last, 1)),
                    NextState("COPY")
                )
            )
        )
        fsm.act("COPY",
            source.valid.eq(sink.valid | last),
            source.first.eq(first),
            source.last.eq(sink.last | last),
            If(source.valid & source.ready,
                NextValue(first, 0),
                sink.ready.eq(1 & ~last), # already acked when last is 1
                If(source.last, NextState("IDLE"))
            )
        )
        self.comb += [
            source.dat[32*0:32*1].eq(     dat[32*1:32*2]),
            source.dat[32*1:32*2].eq(sink.dat[32*0:32*1]),
            source.be[  4*0: 4*1].eq(     be[4*1:4*2]),
            source.be[  4*1: 4*2].eq(sink.be[4*0:4*1])
        ]

# LitePCIeTLPHeaderExtracter128b -------------------------------------------------------------------

class LitePCIeTLPHeaderExtracter128b(Module):
    def __init__(self):
        self.sink   = sink   = stream.Endpoint(phy_layout(128))
        self.source = source = stream.Endpoint(tlp_raw_layout(128))

        # # #

        first = Signal()
        last  = Signal()
        dat   = Signal(128,    reset_less=True)
        be    = Signal(128//8, reset_less=True)
        self.sync += \
            If(sink.valid & sink.ready,
                dat.eq(sink.dat),
                be.eq(sink.be)
            )

        self.submodules.fsm = fsm = FSM(reset_state="IDLE")
        fsm.act("IDLE",
            NextValue(first, 1),
            NextValue(last,  0),
            If(sink.valid,
                NextState("HEADER")
            )
        )
        fsm.act("HEADER",
            sink.ready.eq(1),
            If(sink.valid,
                NextValue(source.header[32*0:32*1], sink.dat[32*0:32*1]),
                NextValue(source.header[32*1:32*2], sink.dat[32*1:32*2]),
                NextValue(source.header[32*2:32*3], sink.dat[32*2:32*3]),
                NextValue(source.header[32*3:32*4], sink.dat[32*3:32*4]),
                If(sink.last,
                    NextValue(last, 1)
                ),
                NextState("COPY")
            )
        )
        fsm.act("COPY",
            source.valid.eq(sink.valid | last),
            source.first.eq(first),
            source.last.eq(sink.last | last),
            If(source.valid & source.ready,
                NextValue(first, 0),
                sink.ready.eq(1 & ~last), # already acked when last is 1
                If(source.last,
                    NextState("IDLE")
                )
            )
        )
        self.comb += [
            source.dat[32*0:32*1].eq(     dat[32*3:32*4]),
            source.dat[32*1:32*2].eq(sink.dat[32*0:32*1]),
            source.dat[32*2:32*3].eq(sink.dat[32*1:32*2]),
            source.dat[32*3:32*4].eq(sink.dat[32*2:32*3]),
            source.be[  4*0: 4*1].eq(        be[4*3:4*4]),
            source.be[  4*1: 4*2].eq(   sink.be[4*0:4*1]),
            source.be[  4*2: 4*3].eq(   sink.be[4*1:4*2]),
            source.be[  4*1: 4*2].eq(   sink.be[4*2:4*3]),
        ]

# LitePCIeTLPHeaderExtracter256b -------------------------------------------------------------------

class LitePCIeTLPHeaderExtracter256b(Module):
    def __init__(self):
        self.sink   = sink   = stream.Endpoint(phy_layout(256))
        self.source = source = stream.Endpoint(tlp_raw_layout(256))

        # # #

        first = Signal()
        last  = Signal()
        dat   = Signal(256,    reset_less=True)
        be    = Signal(256//8, reset_less=True)
        self.sync += \
            If(sink.valid & sink.ready,
                dat.eq(sink.dat),
                be.eq(sink.be)
            )

        self.submodules.fsm = fsm = FSM(reset_state="IDLE")
        fsm.act("IDLE",
            NextValue(first, 1),
            NextValue(last,  0),
            If(sink.valid,
                NextState("HEADER")
            )
        )
        fsm.act("HEADER",
            sink.ready.eq(1),
            If(sink.valid,
                NextValue(source.header[32*0:32*1], sink.dat[32*0:32*1]),
                NextValue(source.header[32*1:32*2], sink.dat[32*1:32*2]),
                NextValue(source.header[32*2:32*3], sink.dat[32*2:32*3]),
                NextValue(source.header[32*3:32*4], sink.dat[32*3:32*4]),
                If(sink.last,
                    NextValue(last, 1)
                ),
                NextState("COPY")
            )
        )
        fsm.act("COPY",
            source.valid.eq(sink.valid | last),
            source.first.eq(first),
            source.last.eq(sink.last | last),
            If(source.valid & source.ready,
                NextValue(first, 0),
                sink.ready.eq(1 & ~last), # already acked when last is 1
                If(source.last,
                    NextState("IDLE")
                )
            )
        )
        self.comb += [
            source.dat[32*0:32*1].eq(     dat[32*3:32*4]),
            source.dat[32*1:32*2].eq(     dat[32*4:32*5]),
            source.dat[32*2:32*3].eq(     dat[32*5:32*6]),
            source.dat[32*3:32*4].eq(     dat[32*6:32*7]),
            source.dat[32*4:32*5].eq(     dat[32*7:32*8]),
            source.dat[32*5:32*6].eq(sink.dat[32*0:32*1]),
            source.dat[32*6:32*7].eq(sink.dat[32*1:32*2]),
            source.dat[32*7:32*8].eq(sink.dat[32*2:32*3]),

            source.be[4*0:4*1].eq(     be[4*3:4*4]),
            source.be[4*1:4*2].eq(     be[4*4:4*5]),
            source.be[4*2:4*3].eq(     be[4*5:4*6]),
            source.be[4*3:4*4].eq(     be[4*6:4*7]),
            source.be[4*4:4*5].eq(     be[4*7:4*8]),
            source.be[4*5:4*6].eq(sink.be[4*0:4*1]),
            source.be[4*6:4*7].eq(sink.be[4*1:4*2]),
            source.be[4*7:4*8].eq(sink.be[4*2:4*3])
        ]

# LitePCIeTLPHeaderExtracter512b -------------------------------------------------------------------

class LitePCIeTLPHeaderExtracter512b(Module):
    def __init__(self):
        self.sink   = sink   = stream.Endpoint(phy_layout(512))
        self.source = source = stream.Endpoint(tlp_raw_layout(512))

        # # #

        first = Signal()
        last  = Signal()
        dat   = Signal(512,    reset_less=True)
        be    = Signal(512//8, reset_less=True)
        self.sync += \
            If(sink.valid & sink.ready,
                dat.eq(sink.dat),
                be.eq(sink.be)
            )

        self.submodules.fsm = fsm = FSM(reset_state="IDLE")
        fsm.act("IDLE",
            NextValue(first, 1),
            NextValue(last,  0),
            If(sink.valid,
                NextState("HEADER")
            )
        )
        fsm.act("HEADER",
            sink.ready.eq(1),
            If(sink.valid,
                NextValue(source.header[32*0:32*1], sink.dat[32*0:32*1]),
                NextValue(source.header[32*1:32*2], sink.dat[32*1:32*2]),
                NextValue(source.header[32*2:32*3], sink.dat[32*2:32*3]),
                NextValue(source.header[32*3:32*4], sink.dat[32*3:32*4]),
                If(sink.last,
                    NextValue(last, 1)
                ),
                NextState("COPY")
            )
        )
        fsm.act("COPY",
            source.valid.eq(sink.valid | last),
            source.first.eq(first),
            source.last.eq(sink.last | last),
            If(source.valid & source.ready,
                NextValue(first, 0),
                sink.ready.eq(1 & ~last), # already acked when last is 1
                If(source.last,
                    NextState("IDLE")
                )
            )
        )
        self.comb += [
            source.dat[ 32*0: 32*1].eq(     dat[ 32*3: 32*4]),
            source.dat[ 32*1: 32*2].eq(     dat[ 32*4: 32*5]),
            source.dat[ 32*2: 32*3].eq(     dat[ 32*5: 32*6]),
            source.dat[ 32*3: 32*4].eq(     dat[ 32*6: 32*7]),
            source.dat[ 32*4: 32*5].eq(     dat[ 32*7: 32*8]),
            source.dat[ 32*5: 32*6].eq(     dat[ 32*8: 32*9]),
            source.dat[ 32*6: 32*7].eq(     dat[ 32*9:32*10]),
            source.dat[ 32*7: 32*8].eq(     dat[32*10:32*11]),
            source.dat[ 32*8: 32*9].eq(     dat[32*11:32*12]),
            source.dat[ 32*9:32*10].eq(     dat[32*12:32*13]),
            source.dat[32*10:32*11].eq(     dat[32*13:32*14]),
            source.dat[32*11:32*12].eq(     dat[32*14:32*15]),
            source.dat[32*12:32*13].eq(     dat[32*15:32*16]),
            source.dat[32*13:32*14].eq(sink.dat[ 32*0: 32*1]),
            source.dat[32*14:32*15].eq(sink.dat[ 32*1: 32*2]),
            source.dat[32*15:32*16].eq(sink.dat[ 32*2: 32*3]),


            source.be[ 4*0: 4*1].eq(     be[ 4*3: 4*4]),
            source.be[ 4*1: 4*2].eq(     be[ 4*4: 4*5]),
            source.be[ 4*2: 4*3].eq(     be[ 4*5: 4*6]),
            source.be[ 4*3: 4*4].eq(     be[ 4*6: 4*7]),
            source.be[ 4*4: 4*5].eq(     be[ 4*7: 4*8]),
            source.be[ 4*5: 4*6].eq(     be[ 4*8: 4*9]),
            source.be[ 4*6: 4*7].eq(     be[ 4*9:4*10]),
            source.be[ 4*7: 4*8].eq(     be[4*10:4*11]),
            source.be[ 4*8: 4*9].eq(     be[4*11:4*12]),
            source.be[ 4*9:4*10].eq(     be[4*12:4*13]),
            source.be[4*10:4*11].eq(     be[4*13:4*14]),
            source.be[4*11:4*12].eq(     be[4*14:4*15]),
            source.be[4*12:4*13].eq(     be[4*15:4*16]),
            source.be[4*13:4*14].eq(sink.be[ 4*0: 4*1]),
            source.be[4*14:4*15].eq(sink.be[ 4*1: 4*2]),
            source.be[4*15:4*16].eq(sink.be[ 4*2: 4*3]),
        ]

# LitePCIeTLPDepacketizer --------------------------------------------------------------------------

class LitePCIeTLPDepacketizer(Module):
    def __init__(self, data_width, endianness, address_mask=0):
        self.sink       = stream.Endpoint(phy_layout(data_width))
        self.req_source = stream.Endpoint(request_layout(data_width))
        self.cmp_source = stream.Endpoint(completion_layout(data_width))

        # # #

        # Extract raw header -----------------------------------------------------------------------
        header_extracter_cls = {
             64 : LitePCIeTLPHeaderExtracter64b,
            128 : LitePCIeTLPHeaderExtracter128b,
            256 : LitePCIeTLPHeaderExtracter256b,
            512 : LitePCIeTLPHeaderExtracter512b,
        }
        header_extracter = header_extracter_cls[data_width]()
        self.submodules += header_extracter
        self.comb += self.sink.connect(header_extracter.sink)
        header = header_extracter.source.header

        # Dispatch data according to fmt/type ------------------------------------------------------
        dispatch_source = stream.Endpoint(tlp_common_layout(data_width))
        dispatch_sinks  = [stream.Endpoint(tlp_common_layout(data_width)) for i in range(3)]
        self.comb += dispatch_sinks[0b00].ready.eq(1) # Always ready when unknown.

        self.comb += [
            dispatch_source.valid.eq(header_extracter.source.valid),
            header_extracter.source.ready.eq(dispatch_source.ready),
            dispatch_source.first.eq(header_extracter.source.first),
            dispatch_source.last.eq(header_extracter.source.last),
            tlp_common_header.decode(header, dispatch_source)
        ]
        self.comb += dword_endianness_swap(
            src        = header_extracter.source.dat,
            dst        = dispatch_source.dat,
            data_width = data_width,
            endianness = endianness,
            mode       = "dat",
        )
        self.comb += dword_endianness_swap(
            src        = header_extracter.source.be,
            dst        = dispatch_source.be,
            data_width = data_width,
            endianness = endianness,
            mode       = "be",
        )
        self.submodules.dispatcher = Dispatcher(dispatch_source, dispatch_sinks)

        fmt_type = Cat(dispatch_source.type, dispatch_source.fmt)
        self.comb += [
            self.dispatcher.sel.eq(0b00),
            If((fmt_type == fmt_type_dict["mem_rd32"]) |
               (fmt_type == fmt_type_dict["mem_wr32"]),
                self.dispatcher.sel.eq(0b01),
            ),
            If((fmt_type == fmt_type_dict["cpld"]) |
               (fmt_type == fmt_type_dict["cpl"]),
               self.dispatcher.sel.eq(0b10),
            ),
        ]

        # Decode TLP request and format local request ----------------------------------------------
        self.tlp_req = tlp_req = stream.Endpoint(tlp_request_layout(data_width))
        self.comb += dispatch_sinks[0b01].connect(tlp_req)
        self.comb += tlp_request_header.decode(header, tlp_req)

        req_type   = Cat(tlp_req.type, tlp_req.fmt)
        req_source = self.req_source
        self.comb += [
            req_source.valid.eq(tlp_req.valid),
            req_source.we.eq(tlp_req.valid & (req_type == fmt_type_dict["mem_wr32"])),
            tlp_req.ready.eq(req_source.ready),
            req_source.first.eq(tlp_req.first),
            req_source.last.eq(tlp_req.last),
            req_source.adr.eq(tlp_req.address & (~address_mask)),
            req_source.len.eq(tlp_req.length),
            req_source.req_id.eq(tlp_req.requester_id),
            req_source.tag.eq(tlp_req.tag),
            req_source.dat.eq(tlp_req.dat)
        ]

        # Decode TLP completion and format local completion ----------------------------------------
        self.tlp_cmp = tlp_cmp = stream.Endpoint(tlp_completion_layout(data_width))
        self.comb += dispatch_sinks[0b10].connect(tlp_cmp)
        self.comb += tlp_completion_header.decode(header, tlp_cmp)

        cmp_source = self.cmp_source
        self.comb += [
            cmp_source.valid.eq(tlp_cmp.valid),
            tlp_cmp.ready.eq(cmp_source.ready),
            cmp_source.first.eq(tlp_cmp.first),
            cmp_source.last.eq(tlp_cmp.last),
            cmp_source.len.eq(tlp_cmp.length),
            cmp_source.end.eq(tlp_cmp.length == (tlp_cmp.byte_count[2:])),
            cmp_source.adr.eq(tlp_cmp.lower_address),
            cmp_source.req_id.eq(tlp_cmp.requester_id),
            cmp_source.cmp_id.eq(tlp_cmp.completer_id),
            cmp_source.err.eq(tlp_cmp.status != 0),
            cmp_source.tag.eq(tlp_cmp.tag),
            cmp_source.dat.eq(tlp_cmp.dat)
        ]
