#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2022 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

from migen import *

from litex.gen import *

from litepcie.tlp.common import *

# Generic Header Extracter -------------------------------------------------------------------------

class _LitePCIeTLPHeaderExtracter(LiteXModule):
    """
    Generic (width-parameterized) header extracter.

    Preserves the legacy behavior:
    - 64b: header spans 2 beats, then COPY shifts by 1 DW across beats.
    - >=128b: header in first beat, then COPY shifts by 3 DWs across beats.
    - Flush is implemented with 'last' sticky flag (legacy style).
    - 2-phase flow: HEADER then COPY (with an initial IDLE).
    """
    def __init__(self, data_width):
        assert data_width in [64, 128, 256, 512]
        assert data_width % 32 == 0

        self.sink   = sink   = stream.Endpoint(phy_layout(data_width))
        self.source = source = stream.Endpoint(tlp_raw_layout(data_width))

        # # #

        dws_per_beat = data_width // 32

        # Legacy shift:
        # - 64b  : shift by 1 DW.
        # - >=128: shift by 3 DWs.
        shift_dws = 1 if data_width == 64 else 3
        assert 0 < shift_dws < dws_per_beat

        # Hold last accepted beat for COPY shifting.
        dat_r = Signal(data_width,    reset_less=True)
        be_r  = Signal(data_width//8, reset_less=True)
        self.sync += If(sink.valid & sink.ready,
            dat_r.eq(sink.dat),
            be_r.eq(sink.be),
        )

        first = Signal()
        last  = Signal()  # "flush pending"

        # Only used for 64b header capture (2 beats).
        hdr_cnt = Signal(max=2)

        # Helpers ----------------------------------------------------------------------------------

        def _dw(sig, i):
            return sig[32*i:32*(i+1)]

        def _be(sig, i):
            return sig[4*i:4*(i+1)]

        def _emit_shifted(prev_dat, prev_be, curr_dat, curr_be):
            """
            Output beat = prev[shift_dws:] + curr[:shift_dws]
            (DW/BE-wise).
            """
            stmts = []
            left_lanes = dws_per_beat - shift_dws

            # Left lanes from previous beat.
            for lane in range(left_lanes):
                stmts += [
                    _dw(source.dat, lane).eq(_dw(prev_dat, shift_dws + lane)),
                    _be(source.be,  lane).eq(_be(prev_be,  shift_dws + lane)),
                ]

            # Right lanes from current beat.
            for lane in range(left_lanes, dws_per_beat):
                in_lane = lane - left_lanes
                stmts += [
                    _dw(source.dat, lane).eq(_dw(curr_dat, in_lane)),
                    _be(source.be,  lane).eq(_be(curr_be,  in_lane)),
                ]

            return stmts

        # FSM --------------------------------------------------------------------------------------

        self.fsm = fsm = FSM(reset_state="IDLE")

        fsm.act("IDLE",
            NextValue(first, 1),
            NextValue(last,  0),
            If(data_width == 64,
                NextValue(hdr_cnt, 0),
            ),
            If(sink.valid,
                NextState("HEADER")
            )
        )

        if data_width == 64:
            # 64-bit: capture 4DW header over 2 beats (2DW/beat).
            fsm.act("HEADER",
                sink.ready.eq(1),
                If(sink.valid,
                    If(hdr_cnt == 0,
                        # Beat0 provides DW0..DW1.
                        NextValue(source.header[32*0:32*1], sink.dat[32*0:32*1]),
                        NextValue(source.header[32*1:32*2], sink.dat[32*1:32*2]),
                        NextValue(hdr_cnt, 1),
                        If(sink.last,
                            NextValue(last, 1)
                        ),
                    ).Else(
                        # Beat1 provides DW2..DW3.
                        NextValue(source.header[32*2:32*3], sink.dat[32*0:32*1]),
                        NextValue(source.header[32*3:32*4], sink.dat[32*1:32*2]),
                        If(sink.last,
                            NextValue(last, 1)
                        ),
                        NextState("COPY")
                    )
                )
            )
        else:
            # >=128-bit: capture header in first beat.
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

            *_emit_shifted(dat_r, be_r, sink.dat, sink.be),

            If(source.valid & source.ready,
                NextValue(first, 0),
                sink.ready.eq(~last),  # already acked when last=1
                If(source.last,
                    NextState("IDLE")
                )
            )
        )

# LitePCIeTLPHeaderExtracter64b --------------------------------------------------------------------

class LitePCIeTLPHeaderExtracter64b(LiteXModule):
    def __init__(self):
        self.submodules.impl = _LitePCIeTLPHeaderExtracter(data_width=64)
        self.sink   = self.impl.sink
        self.source = self.impl.source

# LitePCIeTLPHeaderExtracter128b -------------------------------------------------------------------

class LitePCIeTLPHeaderExtracter128b(LiteXModule):
    def __init__(self):
        self.submodules.impl = _LitePCIeTLPHeaderExtracter(data_width=128)
        self.sink   = self.impl.sink
        self.source = self.impl.source

# LitePCIeTLPHeaderExtracter256b -------------------------------------------------------------------

class LitePCIeTLPHeaderExtracter256b(LiteXModule):
    def __init__(self):
        self.submodules.impl = _LitePCIeTLPHeaderExtracter(data_width=256)
        self.sink   = self.impl.sink
        self.source = self.impl.source

# LitePCIeTLPHeaderExtracter512b -------------------------------------------------------------------

class LitePCIeTLPHeaderExtracter512b(LiteXModule):
    def __init__(self):
        self.submodules.impl = _LitePCIeTLPHeaderExtracter(data_width=512)
        self.sink   = self.impl.sink
        self.source = self.impl.source

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

        # Dispatch Sources.
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

        # Dispatcher.
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
