from litex.gen import *
from litex.gen.genlib.misc import chooser

from litepcie.core.tlp.common import *


class LitePCIeTLPHeaderInserter(Module):
    def __init__(self, data_width):
        self.sink = sink = stream.Endpoint(tlp_raw_layout(data_width))
        self.source = source = stream.Endpoint(phy_layout(data_width))

        # # #

        if data_width != 64:
            raise ValueError("Current module only supports data_width of 64.")

        dat_last = Signal(data_width)
        eop_last = Signal()
        self.sync += \
            If(sink.stb & sink.ack,
                dat_last.eq(sink.dat),
                eop_last.eq(sink.eop)
            )

        self.submodules.fsm = fsm = FSM(reset_state="IDLE")
        fsm.act("IDLE",
            sink.ack.eq(1),
            If(sink.stb,
                sink.ack.eq(0),
                source.stb.eq(1),
                source.dat.eq(sink.header[:data_width]),
                source.be.eq(0xff),
                If(source.stb & source.ack,
                    NextState("INSERT"),
                )
            )
        )
        fsm.act("INSERT",
            source.stb.eq(1),
            source.eop.eq(sink.eop),
            # XXX add genericity
            source.dat.eq(Cat(sink.header[data_width:96],
                              reverse_bytes(sink.dat[:32]))),
            source.be.eq(Cat(Signal(4, reset=0xf),
                             reverse_bits(sink.be[:4]))),
            If(source.stb & source.ack,
                sink.ack.eq(1),
                If(source.eop,
                    NextState("IDLE")
                ).Else(
                    NextState("COPY")
                )
            )
        )
        fsm.act("COPY",
            source.stb.eq(sink.stb | eop_last),
            source.eop.eq(eop_last),
            # XXX add genericity
            source.dat.eq(Cat(reverse_bytes(dat_last[32:64]),
                              reverse_bytes(sink.dat[:32]))),
            If(eop_last,
                source.be.eq(0x0f)
            ).Else(
                source.be.eq(0xff)
            ),
            If(source.stb & source.ack,
                sink.ack.eq(~eop_last),
                If(source.eop,
                    NextState("IDLE")
                )
            )
        )


class LitePCIeTLPPacketizer(Module):
    def __init__(self, data_width):
        self.req_sink = req_sink = stream.Endpoint(request_layout(data_width))
        self.cmp_sink = cmp_sink = stream.Endpoint(completion_layout(data_width))

        self.source = stream.Endpoint(phy_layout(data_width))

        # # #

        # format TLP request and encode it
        tlp_req = stream.Endpoint(tlp_request_layout(data_width))
        self.comb += [
            tlp_req.stb.eq(req_sink.stb),
            req_sink.ack.eq(tlp_req.ack),
            tlp_req.eop.eq(req_sink.eop),

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
            tlp_req.address.eq(req_sink.adr[2:]),

            tlp_req.dat.eq(req_sink.dat),
            If(req_sink.we,
                tlp_req.be.eq(0xff)
            ).Else(
                tlp_req.be.eq(0x00)
            ),
        ]

        tlp_raw_req = stream.Endpoint(tlp_raw_layout(data_width))
        self.comb += [
            tlp_raw_req.stb.eq(tlp_req.stb),
            tlp_req.ack.eq(tlp_raw_req.ack),
            tlp_raw_req.eop.eq(tlp_req.eop),
            tlp_request_header.encode(tlp_req, tlp_raw_req.header),
            tlp_raw_req.dat.eq(tlp_req.dat),
            tlp_raw_req.be.eq(tlp_req.be),
        ]

        # format TLP completion and encode it
        tlp_cmp = stream.Endpoint(tlp_completion_layout(data_width))
        self.comb += [
            tlp_cmp.stb.eq(cmp_sink.stb),
            cmp_sink.ack.eq(tlp_cmp.ack),
            tlp_cmp.eop.eq(cmp_sink.eop),

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
            tlp_cmp.be.eq(0xff)
        ]

        tlp_raw_cmp = stream.Endpoint(tlp_raw_layout(data_width))
        self.comb += [
            tlp_raw_cmp.stb.eq(tlp_cmp.stb),
            tlp_cmp.ack.eq(tlp_raw_cmp.ack),
            tlp_raw_cmp.eop.eq(tlp_cmp.eop),
            tlp_completion_header.encode(tlp_cmp, tlp_raw_cmp.header),
            tlp_raw_cmp.dat.eq(tlp_cmp.dat),
            tlp_raw_cmp.be.eq(tlp_cmp.be),
        ]

        # arbitrate
        tlp_raw = stream.Endpoint(tlp_raw_layout(data_width))
        self.submodules.arbitrer = Arbiter([tlp_raw_req, tlp_raw_cmp], tlp_raw)

        # insert header
        header_inserter = LitePCIeTLPHeaderInserter(data_width)
        self.submodules += header_inserter
        self.comb += [
            tlp_raw.connect(header_inserter.sink),
            header_inserter.source.connect(self.source)
        ]
