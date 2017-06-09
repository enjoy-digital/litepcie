from litex.gen import *

from litepcie.core.tlp.common import *


class LitePCIeTLPHeaderExtracter(Module):
    def __init__(self, data_width):
        self.sink = sink = stream.Endpoint(phy_layout(data_width))
        self.source = source = stream.Endpoint(tlp_raw_layout(data_width))

        # # #

        if data_width != 64:
            raise ValueError("Current module only supports data_width of 64.")

        first = Signal()
        first_clr = Signal()
        first_set = Signal()
        self.sync += If(first_clr, first.eq(0)).Elif(first_set, first.eq(1))

        last = Signal()
        last_clr = Signal()
        last_set = Signal()
        self.sync += If(last_clr, last.eq(0)).Elif(last_set, last.eq(1))

        counter = Signal(2)
        counter_reset = Signal()
        counter_ce = Signal()
        self.sync += \
            If(counter_reset,
                counter.eq(0)
            ).Elif(counter_ce,
                counter.eq(counter + 1)
            )

        sink_dat_last = Signal(data_width)
        sink_be_last = Signal(data_width//8)

        self.submodules.fsm = fsm = FSM(reset_state="IDLE")
        fsm.act("IDLE",
            first_set.eq(1),
            last_clr.eq(1),
            counter_reset.eq(1),
            If(sink.valid,
                NextState("EXTRACT")
            )
        )
        fsm.act("EXTRACT",
            sink.ready.eq(1),
            If(sink.valid,
                counter_ce.eq(1),
                If(counter == tlp_common_header_length*8//data_width - 1,
                    If(sink.last,
                        last_set.eq(1)
                    ),
                    NextState("COPY")
                )
            )
        )
        self.sync += [
            If(counter_ce,
                self.source.header.eq(Cat(self.source.header[data_width:], sink.dat))
            ),
            If(sink.valid & sink.ready,
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
            source.valid.eq(sink.valid | last),
            source.first.eq(first),
            source.last.eq(sink.last | last),
            If(source.valid & source.ready,
                first_clr.eq(1),
                sink.ready.eq(1 & ~last), # already acked when last is 1
                If(source.last,
                    NextState("IDLE")
                )
            )
        )


class LitePCIeTLPDepacketizer(Module):
    def __init__(self, data_width, address_mask=0):
        self.sink = stream.Endpoint(phy_layout(data_width))

        self.req_source = stream.Endpoint(request_layout(data_width))
        self.cmp_source = stream.Endpoint(completion_layout(data_width))

        # # #

        # extract raw header
        header_extracter = LitePCIeTLPHeaderExtracter(data_width)
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
        tlp_req = stream.Endpoint(tlp_request_layout(data_width))
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
        tlp_cmp = stream.Endpoint(tlp_completion_layout(data_width))
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
