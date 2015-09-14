from migen.fhdl.std import *
from migen.actorlib.structuring import *
from migen.genlib.fsm import FSM, NextState

from litepcie.core.packet.common import *


class HeaderExtracter(Module):
    def __init__(self, dw):
        self.sink = sink = Sink(phy_layout(dw))
        self.source = source = Source(tlp_raw_layout(dw))

        # # #

        if dw != 64:
            raise ValueError("Current module only supports dw of 64.")

        sop = FlipFlop()
        eop = FlipFlop()
        self.submodules += sop, eop
        self.comb += [
            sop.d.eq(1),
            eop.d.eq(1)
        ]

        counter = Counter(2)
        self.submodules += counter

        sink_dat_last = Signal(dw)
        sink_be_last = Signal(dw//8)

        self.submodules.fsm = fsm = FSM(reset_state="IDLE")
        fsm.act("IDLE",
            sop.ce.eq(1),
            eop.reset.eq(1),
            counter.reset.eq(1),
            If(sink.stb,
                NextState("EXTRACT")
            )
        )
        fsm.act("EXTRACT",
            sink.ack.eq(1),
            If(sink.stb,
                counter.ce.eq(1),
                If(counter.value == 96//dw,
                    If(sink.eop,
                        eop.ce.eq(1)
                    ),
                    NextState("COPY")
                )
            )
        )
        self.sync += [
            If(counter.ce,
                self.source.header.eq(Cat(self.source.header[dw:], sink.dat))
            ),
            If(sink.stb & sink.ack,
                sink_dat_last.eq(sink.dat),
                sink_be_last.eq(sink.be)
            )
        ]
        self.comb += [
            source.dat.eq(Cat(reverse_bytes(sink_dat_last[32:]), reverse_bytes(sink.dat[:32]))), # XXX add genericity
            source.be.eq(Cat(freversed(sink_be_last[4:]), freversed(sink.be[:4]))),              # XXX ditto
        ]
        fsm.act("COPY",
            source.stb.eq(sink.stb | eop.q),
            source.sop.eq(sop.q),
            source.eop.eq(sink.eop | eop.q),
            If(source.stb & source.ack,
                sop.reset.eq(1),
                sink.ack.eq(1 & ~eop.q), # already acked when eop is 1
                If(source.eop,
                    NextState("IDLE")
                )
            )
        )


class Depacketizer(Module):
    def __init__(self, dw, address_mask=0):
        self.sink = Sink(phy_layout(dw))

        self.req_source = Source(request_layout(dw))
        self.cmp_source = Source(completion_layout(dw))

        ###

        # extract raw header
        header_extracter = HeaderExtracter(dw)
        self.submodules += header_extracter
        self.comb += Record.connect(self.sink, header_extracter.sink)
        header = header_extracter.source.header


        # dispatch data according to fmt/type
        dispatch_source = Source(tlp_common_layout(dw))
        dispatch_sinks = [Sink(tlp_common_layout(dw)) for i in range(2)]

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
            If((fmt_type == fmt_type_dict["mem_rd32"]) | (fmt_type == fmt_type_dict["mem_wr32"]),
                self.dispatcher.sel.eq(0),
            ).Elif((fmt_type == fmt_type_dict["cpld"]) | (fmt_type == fmt_type_dict["cpl"]),
                self.dispatcher.sel.eq(1),
            )

        # decode TLP request and format local request
        tlp_req = Source(tlp_request_layout(dw))
        self.comb += Record.connect(dispatch_sinks[0], tlp_req)
        self.comb += tlp_request_header.decode(header, tlp_req)

        req_source = self.req_source
        self.comb += [
            req_source.stb.eq(tlp_req.stb),
            req_source.we.eq(tlp_req.stb & (Cat(tlp_req.type, tlp_req.fmt) == fmt_type_dict["mem_wr32"])),
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
        tlp_cmp = Source(tlp_completion_layout(dw))
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
