from litex.gen import *

from litepcie.core.tlp.common import *


class HeaderExtracter(Module):
    def __init__(self, data_width):
        self.sink = sink = Sink(phy_layout(data_width))
        self.source = source = Source(tlp_raw_layout(data_width))

        # # #

        if data_width != 64:
            raise ValueError("Current module only supports data_width of 64.")

        sop = Signal()
        sop_clr = Signal()
        sop_set = Signal()
        self.sync += If(sop_clr, sop.eq(0)).Elif(sop_set, sop.eq(1))

        eop = Signal()
        eop_clr = Signal()
        eop_set = Signal()
        self.sync += If(eop_clr, eop.eq(0)).Elif(eop_set, eop.eq(1))

        self.submodules.counter = counter = Counter(2)

        sink_dat_last = Signal(data_width)
        sink_be_last = Signal(data_width//8)

        self.submodules.fsm = fsm = FSM(reset_state="IDLE")
        fsm.act("IDLE",
            sop_set.eq(1),
            eop_clr.eq(1),
            counter.reset.eq(1),
            If(sink.stb,
                NextState("EXTRACT")
            )
        )
        fsm.act("EXTRACT",
            sink.ack.eq(1),
            If(sink.stb,
                counter.ce.eq(1),
                If(counter.value == tlp_common_header_length*8//data_width - 1,
                    If(sink.eop,
                        eop_set.eq(1)
                    ),
                    NextState("COPY")
                )
            )
        )
        self.sync += [
            If(counter.ce,
                self.source.header.eq(Cat(self.source.header[data_width:], sink.dat))
            ),
            If(sink.stb & sink.ack,
                sink_dat_last.eq(sink.dat),
                sink_be_last.eq(sink.be)
            )
        ]
        self.comb += [
            # XXX add genericity
            source.dat.eq(Cat(reverse_bytes(sink_dat_last[32:]),
                              reverse_bytes(sink.dat[:32]))),
            source.be.eq(Cat(reverse_bits(sink_be_last[4:][::-1]),
                             reverse_bits(sink.be[:4]))),
        ]
        fsm.act("COPY",
            source.stb.eq(sink.stb | eop),
            source.sop.eq(sop),
            source.eop.eq(sink.eop | eop),
            If(source.stb & source.ack,
                sop_clr.eq(1),
                sink.ack.eq(1 & ~eop), # already acked when eop is 1
                If(source.eop,
                    NextState("IDLE")
                )
            )
        )


class Depacketizer(Module):
    def __init__(self, data_width, address_mask=0):
        self.sink = Sink(phy_layout(data_width))

        self.req_source = Source(request_layout(data_width))
        self.cmp_source = Source(completion_layout(data_width))

        # # #

        # extract raw header
        header_extracter = HeaderExtracter(data_width)
        self.submodules += header_extracter
        self.comb += Record.connect(self.sink, header_extracter.sink)
        header = header_extracter.source.header


        # dispatch data according to fmt/type
        dispatch_source = Source(tlp_common_layout(data_width))
        dispatch_sinks = [Sink(tlp_common_layout(data_width)) for i in range(2)]

        self.comb += [
            dispatch_source.stb.eq(header_extracter.source.stb),
            header_extracter.source.ack.eq(dispatch_source.ack),
            dispatch_source.sop.eq(header_extracter.source.sop),
            dispatch_source.eop.eq(header_extracter.source.eop),
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
        tlp_req = Source(tlp_request_layout(data_width))
        self.comb += Record.connect(dispatch_sinks[0], tlp_req)
        self.comb += tlp_request_header.decode(header, tlp_req)

        req_source = self.req_source
        self.comb += [
            req_source.stb.eq(tlp_req.stb),
            req_source.we.eq(tlp_req.stb & (Cat(tlp_req.type, tlp_req.fmt) ==
                                            fmt_type_dict["mem_wr32"])),
            tlp_req.ack.eq(req_source.ack),
            req_source.sop.eq(tlp_req.sop),
            req_source.eop.eq(tlp_req.eop),
            req_source.adr.eq(Cat(Signal(2), tlp_req.address & (~address_mask))),
            req_source.len.eq(tlp_req.length),
            req_source.req_id.eq(tlp_req.requester_id),
            req_source.tag.eq(tlp_req.tag),
            req_source.dat.eq(tlp_req.dat),
        ]

        # decode TLP completion and format local completion
        tlp_cmp = Source(tlp_completion_layout(data_width))
        self.comb += Record.connect(dispatch_sinks[1], tlp_cmp)
        self.comb += tlp_completion_header.decode(header, tlp_cmp)

        cmp_source = self.cmp_source
        self.comb += [
            cmp_source.stb.eq(tlp_cmp.stb),
            tlp_cmp.ack.eq(cmp_source.ack),
            cmp_source.sop.eq(tlp_cmp.sop),
            cmp_source.eop.eq(tlp_cmp.eop),
            cmp_source.len.eq(tlp_cmp.length),
            cmp_source.last.eq(tlp_cmp.length == (tlp_cmp.byte_count[2:])),
            cmp_source.adr.eq(tlp_cmp.lower_address),
            cmp_source.req_id.eq(tlp_cmp.requester_id),
            cmp_source.cmp_id.eq(tlp_cmp.completer_id),
            cmp_source.err.eq(tlp_cmp.status != 0),
            cmp_source.tag.eq(tlp_cmp.tag),
            cmp_source.dat.eq(tlp_cmp.dat)
        ]
