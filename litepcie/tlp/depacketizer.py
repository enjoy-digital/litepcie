# This file is Copyright (c) 2015-2019 Florent Kermarrec <florent@enjoy-digital.fr>
# License: BSD

from migen import *

from litepcie.tlp.common import *


class LitePCIeTLPHeaderExtracter64b(Module):
    def __init__(self, endianness):
        self.sink = sink = stream.Endpoint(phy_layout(64))
        self.source = source = stream.Endpoint(tlp_raw_layout(64))

        # # #

        first = Signal()
        last = Signal()
        count = Signal()

        dat = Signal(64, reset_less=True)
        be = Signal(64//8, reset_less=True)
        self.sync += \
            If(sink.valid & sink.ready,
                dat.eq(sink.dat),
                be.eq(sink.be)
            )

        self.submodules.fsm = fsm = FSM(reset_state="IDLE")
        fsm.act("IDLE",
            NextValue(first, 1),
            NextValue(last, 0),
            NextValue(count, 0),
            If(sink.valid, NextState("HEADER"))
        )
        fsm.act("HEADER",
            sink.ready.eq(1),
            If(sink.valid,
                NextValue(count, count + 1),
                NextValue(self.source.header[32*0:32*1], self.source.header[32*2:32*3]),
                NextValue(self.source.header[32*1:32*2], self.source.header[32*3:32*4]),
                NextValue(self.source.header[32*2:32*3], sink.dat[32*0:32*1]),
                NextValue(self.source.header[32*3:32*4], sink.dat[32*1:32*2]),
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
            source.dat[32*0:32*1].eq(convert_bytes(dat[32*1:32*2], endianness)),
            source.dat[32*1:32*2].eq(convert_bytes(sink.dat[32*0:32*1], endianness)),
            source.be[4*0:4*1].eq(convert_bits(be[4*1:4*2], endianness)),
            source.be[4*1:4*2].eq(convert_bits(sink.be[4*0:4*1], endianness))
        ]


class LitePCIeTLPHeaderExtracter128b(Module):
    def __init__(self, endianness):
        self.sink = sink = stream.Endpoint(phy_layout(128))
        self.source = source = stream.Endpoint(tlp_raw_layout(128))

        # # #

        first = Signal()
        last = Signal()

        dat = Signal(128, reset_less=True)
        be = Signal(128//8, reset_less=True)
        self.sync += \
            If(sink.valid & sink.ready,
                dat.eq(sink.dat),
                be.eq(sink.be)
            )

        self.submodules.fsm = fsm = FSM(reset_state="IDLE")
        fsm.act("IDLE",
            NextValue(first, 1),
            NextValue(last, 0),
            If(sink.valid,
                NextState("HEADER")
            )
        )
        fsm.act("HEADER",
            sink.ready.eq(1),
            If(sink.valid,
                NextValue(self.source.header[32*0:32*1], sink.dat[32*0:32*1]),
                NextValue(self.source.header[32*1:32*2], sink.dat[32*1:32*2]),
                NextValue(self.source.header[32*2:32*3], sink.dat[32*2:32*3]),
                NextValue(self.source.header[32*3:32*4], sink.dat[32*3:32*4]),
                If(sink.last, NextValue(last, 1)),
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
            source.dat[32*0:32*1].eq(convert_bytes(dat[32*3:32*4], endianness)),
            source.dat[32*1:32*2].eq(convert_bytes(sink.dat[32*0:32*1], endianness)),
            source.dat[32*2:32*3].eq(convert_bytes(sink.dat[32*1:32*2], endianness)),
            source.dat[32*3:32*4].eq(convert_bytes(sink.dat[32*2:32*3], endianness)),
            source.be[4*0:4*1].eq(convert_bits(be[4*3:4*4], endianness)),
            source.be[4*1:4*2].eq(convert_bits(sink.be[4*0:4*1], endianness)),
            source.be[4*2:4*3].eq(convert_bits(sink.be[4*1:4*2], endianness)),
            source.be[4*1:4*2].eq(convert_bits(sink.be[4*2:4*3], endianness))
        ]


class LitePCIeTLPDepacketizer(Module):
    def __init__(self, data_width, endianness, address_mask=0):
        self.sink = stream.Endpoint(phy_layout(data_width))

        self.req_source = stream.Endpoint(request_layout(data_width))
        self.cmp_source = stream.Endpoint(completion_layout(data_width))

        # # #

        # extract raw header
        header_extracter_cls = {
             64 : LitePCIeTLPHeaderExtracter64b,
            128 : LitePCIeTLPHeaderExtracter128b,
        }
        header_extracter = header_extracter_cls[data_width](endianness)
        self.submodules += header_extracter
        self.comb += self.sink.connect(header_extracter.sink)
        header = header_extracter.source.header


        # dispatch data according to fmt/type
        dispatch_source = stream.Endpoint(tlp_common_layout(data_width))
        dispatch_sinks = [stream.Endpoint(tlp_common_layout(data_width)) for i in range(2)]

        self.comb += [
            dispatch_source.valid.eq(header_extracter.source.valid),
            header_extracter.source.ready.eq(dispatch_source.ready),
            dispatch_source.first.eq(header_extracter.source.first),
            dispatch_source.last.eq(header_extracter.source.last),
            dispatch_source.dat.eq(header_extracter.source.dat),
            dispatch_source.be.eq(header_extracter.source.be),
            tlp_common_header.decode(header, dispatch_source)
        ]

        self.submodules.dispatcher = Dispatcher(dispatch_source, dispatch_sinks)

        fmt_type = Cat(dispatch_source.type, dispatch_source.fmt)
        self.comb += \
            If((fmt_type == fmt_type_dict["mem_rd32"]) |
               (fmt_type == fmt_type_dict["mem_wr32"]),
                self.dispatcher.sel.eq(0),
            ).Elif((fmt_type == fmt_type_dict["cpld"]) |
                   (fmt_type == fmt_type_dict["cpl"]),
                self.dispatcher.sel.eq(1),
            )

        # decode TLP request and format local request
        self.tlp_req = tlp_req = stream.Endpoint(tlp_request_layout(data_width))
        self.comb += dispatch_sinks[0].connect(tlp_req)
        self.comb += tlp_request_header.decode(header, tlp_req)

        req_source = self.req_source
        self.comb += [
            req_source.valid.eq(tlp_req.valid),
            req_source.we.eq(tlp_req.valid & (Cat(tlp_req.type, tlp_req.fmt) ==
                                            fmt_type_dict["mem_wr32"])),
            tlp_req.ready.eq(req_source.ready),
            req_source.first.eq(tlp_req.first),
            req_source.last.eq(tlp_req.last),
            req_source.adr.eq(Cat(Signal(2), tlp_req.address & (~address_mask))),
            req_source.len.eq(tlp_req.length),
            req_source.req_id.eq(tlp_req.requester_id),
            req_source.tag.eq(tlp_req.tag),
            req_source.dat.eq(tlp_req.dat),
        ]

        # decode TLP completion and format local completion
        self.tlp_cmp = tlp_cmp = stream.Endpoint(tlp_completion_layout(data_width))
        self.comb += dispatch_sinks[1].connect(tlp_cmp)
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
