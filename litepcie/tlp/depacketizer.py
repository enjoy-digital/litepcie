#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2022 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

from migen import *

from litex.gen import *

from litepcie.tlp.common import *

# LitePCIeTLPHeaderExtracter64b --------------------------------------------------------------------

class LitePCIeTLPHeaderExtracter64b(LiteXModule):
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

        self.fsm = fsm = FSM(reset_state="IDLE")
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

class LitePCIeTLPHeaderExtracter128b(LiteXModule):
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

        self.fsm = fsm = FSM(reset_state="IDLE")
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

class LitePCIeTLPHeaderExtracter256b(LiteXModule):
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

        self.fsm = fsm = FSM(reset_state="IDLE")
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

class LitePCIeTLPHeaderExtracter512b(LiteXModule):
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

        self.fsm = fsm = FSM(reset_state="IDLE")
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

class LitePCIeTLPDepacketizer(LiteXModule):
    def __init__(self, data_width, endianness, address_mask=0, capabilities=["REQUEST", "COMPLETION"]):
        # Sink Endpoint.
        self.sink = stream.Endpoint(phy_layout(data_width))

        # Source Endpoints.
        for c in capabilities:
            assert c in ["REQUEST", "COMPLETION", "CONFIGURATION", "PTM"]
        if "REQUEST" in capabilities:
            self.req_source  = req_source  = stream.Endpoint(request_layout(data_width))
        if "COMPLETION" in capabilities:
            self.cmp_source  = cmp_source  = stream.Endpoint(completion_layout(data_width))
        if "CONFIGURATION" in capabilities:
            self.conf_source = conf_source = stream.Endpoint(configuration_layout(data_width))
        if "PTM" in capabilities:
            self.ptm_source = ptm_source = stream.Endpoint(ptm_layout(data_width))

        # # #

        # Extract RAW Header from Sink -------------------------------------------------------------

        header_extracter_cls = {
             64 : LitePCIeTLPHeaderExtracter64b,
            128 : LitePCIeTLPHeaderExtracter128b,
            256 : LitePCIeTLPHeaderExtracter256b,
            512 : LitePCIeTLPHeaderExtracter512b,
        }
        self.header_extracter = header_extracter = header_extracter_cls[data_width]()
        self.comb += self.sink.connect(header_extracter.sink)
        header = header_extracter.source.header

        # Create Dispatcher ------------------------------------------------------------------------

        # Dispatch Sources
        self.dispatch_sources = dispatch_sources = {"DISCARD" : stream.Endpoint(tlp_common_layout(data_width))}
        for source in capabilities:
            dispatch_sources[source] = stream.Endpoint(tlp_common_layout(data_width))

        def dispatch_source_sel(name):
            for n, k in enumerate(dispatch_sources.keys()):
                if k == name:
                    return n
            return None

        # Dispatch Sink.
        self.dispatch_sink = dispatch_sink = stream.Endpoint(tlp_common_layout(data_width))

        # Dispatcher
        self.dispatcher = Dispatcher(
            master = dispatch_sink,
            slaves = dispatch_sources.values()
        )

        # Ensure DISCARD source is always ready.
        self.comb += dispatch_sources["DISCARD"].ready.eq(1)

        # Connect Header Extracter to Dispatch Sink.
        self.comb += [
            header_extracter.source.connect(dispatch_sink, keep={"valid", "ready", "first", "last"}),
            tlp_common_header.decode(header, dispatch_sink)
        ]
        self.comb += dword_endianness_swap(
            src        = header_extracter.source.dat,
            dst        = dispatch_sink.dat,
            data_width = data_width,
            endianness = endianness,
            mode       = "dat",
        )
        self.comb += dword_endianness_swap(
            src        = header_extracter.source.be,
            dst        = dispatch_sink.be,
            data_width = data_width,
            endianness = endianness,
            mode       = "be",
        )

        # Create fmt_type for destination decoding.
        self.fmt_type = fmt_type = Cat(dispatch_sink.type, dispatch_sink.fmt)

        # Set default Dispatcher select to DISCARD Sink.
        self.comb += self.dispatcher.sel.eq(dispatch_source_sel("DISCARD"))

        # Decode/Dispatch TLP Requests -------------------------------------------------------------

        if "REQUEST" in capabilities:
            self.comb += [
                If((fmt_type == fmt_type_dict["mem_rd32"]) |
                   (fmt_type == fmt_type_dict["mem_wr32"]),
                    self.dispatcher.sel.eq(dispatch_source_sel("REQUEST")),
                )
            ]

            self.tlp_req = tlp_req = stream.Endpoint(tlp_request_layout(data_width))
            self.comb += dispatch_sources["REQUEST"].connect(tlp_req)
            self.comb += tlp_request_header.decode(header, tlp_req)

            req_type = Cat(tlp_req.type, tlp_req.fmt)
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

        # Decode/Dispatch TLP Completions ----------------------------------------------------------

        if "COMPLETION" in capabilities:
            self.comb += [
                If((fmt_type == fmt_type_dict["cpld"]) |
                   (fmt_type == fmt_type_dict["cpl"]),
                    self.dispatcher.sel.eq(dispatch_source_sel("COMPLETION")),
                )
            ]

            self.tlp_cmp = tlp_cmp = stream.Endpoint(tlp_completion_layout(data_width))
            self.comb += dispatch_sources["COMPLETION"].connect(tlp_cmp)
            self.comb += tlp_completion_header.decode(header, tlp_cmp)

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


        # Decode/Dispatch TLP Configurations -------------------------------------------------------

        if "CONFIGURATION" in capabilities:
            self.comb += [
                If((fmt_type == fmt_type_dict["cfg_rd0"]) |
                   (fmt_type == fmt_type_dict["cfg_wr0"]),
                    self.dispatcher.sel.eq(dispatch_source_sel("CONFIGURATION")),
                )
            ]

            self.tlp_conf = tlp_conf = stream.Endpoint(tlp_configuration_layout(data_width))
            self.comb += dispatch_sources["CONFIGURATION"].connect(tlp_conf)
            self.comb += tlp_configuration_header.decode(header, tlp_conf)

            self.comb += [
                conf_source.valid.eq(tlp_conf.valid),
                tlp_conf.ready.eq(conf_source.ready),
                conf_source.first.eq(tlp_conf.first),
                conf_source.last.eq(tlp_conf.last),
                If(fmt_type == fmt_type_dict["cfg_rd0"],
                    conf_source.we.eq(0)
                ),
                If(fmt_type == fmt_type_dict["cfg_wr0"],
                    conf_source.we.eq(1)
                ),
                conf_source.req_id.eq(tlp_conf.requester_id),
                conf_source.bus_number.eq(tlp_conf.bus_number),
                conf_source.device_no.eq(tlp_conf.device_no),
                conf_source.func.eq(tlp_conf.func),
                conf_source.ext_reg.eq(tlp_conf.ext_reg),
                conf_source.register_no.eq(tlp_conf.register_no),
                conf_source.tag.eq(tlp_conf.tag),
                conf_source.dat.eq(tlp_conf.dat)
            ]

        # Decode/Dispatch TLP PTM Requests/Responses -----------------------------------------------

        if "PTM" in capabilities:
            self.comb += [
                If((fmt_type == fmt_type_dict["ptm_req"]) |
                   (fmt_type == fmt_type_dict["ptm_res"]),
                    self.dispatcher.sel.eq(dispatch_source_sel("PTM")),
                )
            ]

            self.tlp_ptm = tlp_ptm = stream.Endpoint(tlp_ptm_layout(data_width))
            self.comb += dispatch_sources["PTM"].connect(tlp_ptm)
            self.comb += tlp_ptm_header.decode(header, tlp_ptm)

            self.comb += [
                ptm_source.valid.eq(tlp_ptm.valid),
                tlp_ptm.ready.eq(ptm_source.ready),
                ptm_source.first.eq(tlp_ptm.first),
                ptm_source.last.eq(tlp_ptm.last),
                ptm_source.requester_id.eq(tlp_ptm.requester_id),
                ptm_source.length.eq(tlp_ptm.length),
                ptm_source.message_code.eq(tlp_ptm.message_code),
                ptm_source.master_time.eq(tlp_ptm.master_time),
                ptm_source.dat.eq(tlp_ptm.dat)
            ]
