#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

from migen import *

from litex.gen import *

from litepcie.tlp.common import *

# LitePCIeTLPHeaderInserter ------------------------------------------------------------------------


class LitePCIeTLPHeaderInserter3DWs4DWs(LiteXModule):
    def __init__(self, data_width, header_inserter_3dws_cls, header_inserter_4dws_cls, fmt):
        self.sink   = sink   = stream.Endpoint(tlp_raw_layout(data_width))
        self.source = source = stream.Endpoint(phy_layout(data_width))

        # # #

        # Header Inserters Modules.
        header_inserter_3dws = header_inserter_3dws_cls()
        header_inserter_4dws = header_inserter_4dws_cls()
        self.submodules += header_inserter_3dws, header_inserter_4dws

        # Header Inserters Sel.
        _3DWS_SEL = 0b0
        _4DWS_SEL = 0b1
        header_sel = Signal()
        self.comb += Case(fmt, {
            fmt_dict["mem_rd32"] : header_sel.eq(_3DWS_SEL),
            fmt_dict["mem_rd64"] : header_sel.eq(_4DWS_SEL),
            fmt_dict["mem_wr32"] : header_sel.eq(_3DWS_SEL),
            fmt_dict["mem_wr64"] : header_sel.eq(_4DWS_SEL),
            fmt_dict[    "cpld"] : header_sel.eq(_3DWS_SEL),
            fmt_dict[     "cpl"] : header_sel.eq(_3DWS_SEL),
            fmt_dict[ "ptm_req"] : header_sel.eq(_4DWS_SEL),
            fmt_dict[ "ptm_res"] : header_sel.eq(_4DWS_SEL),
        })

        # Header Inserters Mux.
        self.comb += Case(header_sel, {
            _3DWS_SEL : [
                sink.connect(header_inserter_3dws.sink),
                header_inserter_3dws.source.connect(source),
            ],
            _4DWS_SEL : [
                sink.connect(header_inserter_4dws.sink),
                header_inserter_4dws.source.connect(source),
            ],
        })


# Generic TLP Header Inserter (3DWs/4DWs) ----------------------------------------------------------


class _LitePCIeTLPHeaderInserterNDWs(LiteXModule):
    """
    Insert a 3DW or 4DW header in front of a payload stream.

    Behavior matches the legacy per-width implementations:
    - 2 states: HEADER then DATA.
    - For 64-bit, header needs 2 beats; the first sink beat is held stable while HEADER beats are emitted.
    - For >=128-bit, header fits in 1 beat.
    - When header consumes part of the first sink beat ("spill"), the remaining DWs are shifted in DATA and a final
      flush beat is emitted when the packet ends.
    """
    def __init__(self, data_width, header_dws):
        assert data_width % 32 == 0
        assert header_dws in [3, 4]

        self.sink   = sink   = stream.Endpoint(tlp_raw_layout(data_width))
        self.source = source = stream.Endpoint(phy_layout(data_width))

        # # #

        # Geometry --------------------------------------------------------------------------------

        dws_per_beat = data_width // 32

        # How many beats are needed to output header_dws DWs.
        header_beats = (header_dws + dws_per_beat - 1) // dws_per_beat

        # How many payload DWs are placed in the last header beat.
        # (0 means header ends exactly on a beat boundary.)
        spill_dws = header_beats*dws_per_beat - header_dws  # 0..dws_per_beat-1

        # State needed by shift/flush path ---------------------------------------------------------

        dat_r  = Signal(data_width,    reset_less=True)
        be_r   = Signal(data_width//8, reset_less=True)
        last_r = Signal(               reset_less=True)

        # Hold first payload beat (needed for 64b 2-beat header, for the spill in beat1).
        first_dat_r  = Signal(data_width,    reset_less=True)
        first_be_r   = Signal(data_width//8, reset_less=True)
        first_last_r = Signal(               reset_less=True)

        self.sync += [
            If(sink.valid & sink.ready,
                dat_r.eq(sink.dat),
                be_r.eq(sink.be),
                last_r.eq(sink.last),
                If(sink.first,
                    first_dat_r.eq(sink.dat),
                    first_be_r.eq(sink.be),
                    first_last_r.eq(sink.last),
                )
            )
        ]

        # Header beat counter.
        hb_cnt = Signal(max=max(header_beats, 2))

        # Helpers ----------------------------------------------------------------------------------

        def _dw(sig, i):
            return sig[32*i:32*(i+1)]

        def _be(sig, i):
            return sig[4*i:4*(i+1)]

        def _header_dw(i):
            return sink.header[32*i:32*(i+1)]

        def _payload0_dw(i):
            return _dw(first_dat_r, i)

        def _payload0_be(i):
            return _be(first_be_r, i)

        def _payload_dw(i):
            return _dw(sink.dat, i)

        def _payload_be(i):
            return _be(sink.be, i)

        def _header_last_condition(be_sig, last_sig):
            """
            Detect "header-only" termination in last header beat.
            Matches legacy logic:
              - spill_dws == 0: be == 0 means no payload.
              - spill_dws != 0: be[spill_dws:] == 0 means nothing beyond spilled payload DWs.
            """
            if spill_dws == 0:
                be_empty = (be_sig == 0)
            else:
                be_empty = (be_sig[4*spill_dws:] == 0)
            return last_sig & be_empty

        def _emit_shifted_data():
            """
            DATA state when spill_dws != 0.

            Left lanes: remaining DWs from previous sink beat (stored in dat_r/be_r) starting at spill_dws.
            Right lanes: new DWs from current sink beat, OR BE=0 on flush beat (last_r asserted).
            """
            stmts = []

            left_lanes = dws_per_beat - spill_dws

            # Left lanes from previous beat.
            for lane in range(left_lanes):
                stmts += [
                    _dw(source.dat, lane).eq(_dw(dat_r, spill_dws + lane)),
                    _be(source.be,  lane).eq(_be(be_r,  spill_dws + lane)),
                ]

            # Right lanes from current sink beat (or flush).
            for lane in range(left_lanes, dws_per_beat):
                in_lane = lane - left_lanes
                stmts += [
                    _dw(source.dat, lane).eq(_dw(sink.dat, in_lane)),
                    If(last_r,
                        _be(source.be, lane).eq(0x0)
                    ).Else(
                        _be(source.be, lane).eq(_be(sink.be, in_lane))
                    ),
                ]

            return stmts

        # FSM --------------------------------------------------------------------------------------

        self.fsm = fsm = FSM(reset_state="HEADER")

        # HEADER: emit header beats.
        fsm.act("HEADER",
            # Default.
            sink.ready.eq(0),

            If(header_beats == 1,
                # 1-beat header: consume the beat normally.
                sink.ready.eq(source.ready),
                source.valid.eq(sink.valid),
                source.first.eq(sink.first),

                *[
                    If(lane < header_dws,
                        _dw(source.dat, lane).eq(_header_dw(lane)),
                        _be(source.be,  lane).eq(0xF),
                    ).Else(
                        _dw(source.dat, lane).eq(_payload_dw(lane - header_dws)),
                        _be(source.be,  lane).eq(_payload_be(lane - header_dws)),
                    )
                    for lane in range(dws_per_beat)
                ],

                source.last.eq(_header_last_condition(sink.be, sink.last)),

                If(source.valid & source.ready,
                    NextValue(hb_cnt, 0),
                    If(~source.last,
                        NextState("DATA")
                    )
                )
            ).Else(
                # 2-beat header (64b): accept the first beat on hb_cnt==0, then stall for hb_cnt==1.
                If(hb_cnt == 0,
                    sink.ready.eq(source.ready),
                ).Else(
                    sink.ready.eq(0),
                ),

                source.valid.eq(sink.valid),
                source.first.eq((hb_cnt == 0) & sink.first),

                If(hb_cnt == 0,
                    # Header beat 0.
                    _dw(source.dat, 0).eq(_header_dw(0)), _be(source.be, 0).eq(0xF),
                    _dw(source.dat, 1).eq(_header_dw(1)), _be(source.be, 1).eq(0xF),
                ).Else(
                    # Header beat 1 (+ possible spill for 3DW).
                    _dw(source.dat, 0).eq(_header_dw(2)), _be(source.be, 0).eq(0xF),
                    If(header_dws == 3,
                        _dw(source.dat, 1).eq(_payload0_dw(0)),
                        _be(source.be,  1).eq(_payload0_be(0)),
                    ).Else(
                        _dw(source.dat, 1).eq(_header_dw(3)),
                        _be(source.be,  1).eq(0xF),
                    )
                ),

                source.last.eq((hb_cnt == 1) & _header_last_condition(first_be_r, first_last_r)),

                If(source.valid & source.ready,
                    If(hb_cnt == 0,
                        NextValue(hb_cnt, 1)
                    ).Else(
                        NextValue(hb_cnt, 0),
                        If(~source.last,
                            NextState("DATA")
                        )
                    )
                )
            )
        )

        # DATA: either passthrough (spill_dws==0) or shift/flush (spill_dws!=0).
        if spill_dws == 0:
            fsm.act("DATA",
                source.valid.eq(sink.valid),
                source.first.eq(0),
                source.last.eq(sink.last),
                source.dat.eq(sink.dat),
                source.be.eq(sink.be),

                sink.ready.eq(source.ready),

                If(source.valid & source.ready & source.last,
                    NextState("HEADER")
                )
            )
        else:
            fsm.act("DATA",
                source.valid.eq(sink.valid | last_r),
                source.first.eq(0),
                source.last.eq(last_r),

                *_emit_shifted_data(),

                If(source.valid & source.ready,
                    # When last_r=1 we are emitting the flush beat => do not accept a new sink beat.
                    sink.ready.eq(~last_r),
                    If(source.last,
                        NextState("HEADER")
                    )
                )
            )


class LitePCIeTLPHeaderInserter3DWs(_LitePCIeTLPHeaderInserterNDWs):
    def __init__(self, data_width):
        _LitePCIeTLPHeaderInserterNDWs.__init__(self,
            data_width = data_width,
            header_dws = 3,
        )


class LitePCIeTLPHeaderInserter4DWs(_LitePCIeTLPHeaderInserterNDWs):
    def __init__(self, data_width):
        _LitePCIeTLPHeaderInserterNDWs.__init__(self,
            data_width = data_width,
            header_dws = 4,
        )


# LitePCIeTLPHeaderInserter64b ---------------------------------------------------------------------


class LitePCIeTLPHeaderInserter64b(LitePCIeTLPHeaderInserter3DWs4DWs):
    def __init__(self, fmt):
        LitePCIeTLPHeaderInserter3DWs4DWs.__init__(self,
            data_width               = 64,
            header_inserter_3dws_cls = lambda: LitePCIeTLPHeaderInserter3DWs(64),
            header_inserter_4dws_cls = lambda: LitePCIeTLPHeaderInserter4DWs(64),
            fmt                      = fmt,
        )


# LitePCIeTLPHeaderInserter128b --------------------------------------------------------------------


class LitePCIeTLPHeaderInserter128b(LitePCIeTLPHeaderInserter3DWs4DWs):
    def __init__(self, fmt):
        LitePCIeTLPHeaderInserter3DWs4DWs.__init__(self,
            data_width               = 128,
            header_inserter_3dws_cls = lambda: LitePCIeTLPHeaderInserter3DWs(128),
            header_inserter_4dws_cls = lambda: LitePCIeTLPHeaderInserter4DWs(128),
            fmt                      = fmt,
        )


# LitePCIeTLPHeaderInserter256b --------------------------------------------------------------------


class LitePCIeTLPHeaderInserter256b(LitePCIeTLPHeaderInserter3DWs4DWs):
    def __init__(self, fmt):
        LitePCIeTLPHeaderInserter3DWs4DWs.__init__(self,
            data_width               = 256,
            header_inserter_3dws_cls = lambda: LitePCIeTLPHeaderInserter3DWs(256),
            header_inserter_4dws_cls = lambda: LitePCIeTLPHeaderInserter4DWs(256),
            fmt                      = fmt,
        )


# LitePCIeTLPHeaderInserter512b --------------------------------------------------------------------


class LitePCIeTLPHeaderInserter512b(LitePCIeTLPHeaderInserter3DWs4DWs):
    def __init__(self, fmt):
        LitePCIeTLPHeaderInserter3DWs4DWs.__init__(self,
            data_width               = 512,
            header_inserter_3dws_cls = lambda: LitePCIeTLPHeaderInserter3DWs(512),
            header_inserter_4dws_cls = lambda: LitePCIeTLPHeaderInserter4DWs(512),
            fmt                      = fmt,
        )


# LitePCIeTLPPacketizer ----------------------------------------------------------------------------

class LitePCIeTLPPacketizer(LiteXModule):
    def __init__(self, data_width, endianness, address_width=32, capabilities=["REQUEST", "COMPLETION"]):
        assert data_width%32 == 0
        assert address_width in [32, 64]
        if address_width == 64:
            assert data_width in [64, 128, 256, 512]
        for c in capabilities:
            assert c in ["REQUEST", "COMPLETION", "PTM"]
        # Sink Endpoints.
        if "REQUEST" in capabilities:
            self.req_sink = req_sink = stream.Endpoint(request_layout(data_width, address_width))
        if "COMPLETION" in capabilities:
            self.cmp_sink = cmp_sink = stream.Endpoint(completion_layout(data_width))
        if "PTM" in capabilities:
            self.ptm_sink = ptm_sink = stream.Endpoint(ptm_layout(data_width))
        # Source Endpoints.
        self.source   = stream.Endpoint(phy_layout(data_width))

        # # #

        # Format and Encode TLP Requests -----------------------------------------------------------

        if "REQUEST" in capabilities:
            self.tlp_req = tlp_req = stream.Endpoint(tlp_request_layout(data_width))
            self.comb += [
                tlp_req.valid.eq(req_sink.valid),
                req_sink.ready.eq(tlp_req.ready),
                tlp_req.first.eq(req_sink.first),
                tlp_req.last.eq(req_sink.last),

                tlp_req.type.eq(0b00000),
                If(req_sink.we,
                    tlp_req.fmt.eq( fmt_dict[ f"mem_wr32"]),
                ).Else(
                    tlp_req.fmt.eq( fmt_dict[ f"mem_rd32"]),
                ),
                tlp_req.address.eq(req_sink.adr),
            ]

            # On Ultrascale(+) / 256/512-bit, force to 64-bit (for 4DWs format).
            try:
                force_64b = (LiteXContext.platform.device[:4] in ["xcku", "xcvu", "xczu", 'xcau']) and (data_width in [256, 512])
            except:
                force_64b = False

            if address_width == 64:
                self.comb += [
                    # Use WR64/RD64 only when 64-bit Address's MSB != 0, else use WR32/RD32.
                    If((req_sink.adr[32:] != 0) | force_64b,
                        # Address's MSB on DW2, LSB on DW3 with 64-bit addressing: Requires swap due to
                        # Packetizer's behavior.
                        tlp_req.address[:32].eq(req_sink.adr[32:]),
                        tlp_req.address[32:].eq(req_sink.adr[:32]),
                        If(req_sink.we,
                            tlp_req.fmt.eq( fmt_dict[ f"mem_wr64"]),
                        ).Else(
                            tlp_req.fmt.eq( fmt_dict[ f"mem_rd64"]),
                        ),
                    )
                ]
            elif force_64b:
                # Address width is 32 bits but we force issuing 4DWs TLP
                self.comb += [
                    tlp_req.address[:32].eq(Constant(0, 32)),
                    tlp_req.address[32:].eq(req_sink.adr[:32]),
                    If(req_sink.we,
                        tlp_req.fmt.eq( fmt_dict[ f"mem_wr64"]),
                    ).Else(
                        tlp_req.fmt.eq( fmt_dict[ f"mem_rd64"]),
                    ),
                ]

            self.comb += [
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
                tlp_req.dat.eq(req_sink.dat),
                If(req_sink.we,
                    If(req_sink.len == 1,
                        tlp_req.be.eq(0xf)
                    ).Else(
                        tlp_req.be.eq(2**(data_width//8)-1)
                    )
                ).Else(
                    tlp_req.be.eq(0x00)
                )
            ]

            tlp_raw_req        = stream.Endpoint(tlp_raw_layout(data_width))
            tlp_raw_req_header = Signal(len(tlp_raw_req.header))
            self.comb += [
                tlp_req.connect(tlp_raw_req, omit={*tlp_request_header_fields.keys()}),
                tlp_raw_req.fmt.eq(tlp_req.fmt),
                tlp_request_header.encode(tlp_req, tlp_raw_req_header),
            ]
            self.comb += dword_endianness_swap(
                src        = tlp_raw_req_header,
                dst        = tlp_raw_req.header,
                data_width = data_width,
                endianness = endianness,
                mode       = "dat",
                ndwords    = 4
            )

        # Format and Encode TLP Completions --------------------------------------------------------

        if "COMPLETION" in capabilities:
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
                    tlp_cmp.type.eq(type_dict["cpl"]),
                    tlp_cmp.fmt.eq( fmt_dict["cpl"]),
                    tlp_cmp.status.eq(cpl_dict["ur"])
                ).Else(
                    tlp_cmp.type.eq(type_dict["cpld"]),
                    tlp_cmp.fmt.eq( fmt_dict["cpld"]),
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

            tlp_raw_cmp        = stream.Endpoint(tlp_raw_layout(data_width))
            tlp_raw_cmp_header = Signal(len(tlp_raw_cmp.header))
            self.comb += [
                tlp_cmp.connect(tlp_raw_cmp, omit={*tlp_completion_header_fields.keys()}),
                tlp_raw_cmp.fmt.eq(tlp_cmp.fmt),
                tlp_completion_header.encode(tlp_cmp, tlp_raw_cmp_header),
            ]
            self.comb += dword_endianness_swap(
                src        = tlp_raw_cmp_header,
                dst        = tlp_raw_cmp.header,
                data_width = data_width,
                endianness = endianness,
                mode       = "dat",
                ndwords    = 4
            )

        # Format and Encode TLP Completions --------------------------------------------------------

        if "PTM" in capabilities:
            self.tlp_ptm = tlp_ptm = stream.Endpoint(tlp_ptm_layout(data_width))
            self.comb += [
                tlp_ptm.valid.eq(ptm_sink.valid),
                ptm_sink.ready.eq(tlp_ptm.ready),
                tlp_ptm.first.eq(ptm_sink.first),
                tlp_ptm.last.eq(ptm_sink.last),

                tlp_ptm.tc.eq(0),
                tlp_ptm.ln.eq(0),
                tlp_ptm.th.eq(0),
                tlp_ptm.td.eq(0),
                tlp_ptm.ep.eq(0),
                tlp_ptm.attr.eq(0),
                tlp_ptm.length.eq(ptm_sink.length),

                tlp_ptm.requester_id.eq(ptm_sink.requester_id),
                tlp_ptm.message_code.eq(ptm_sink.message_code),
                tlp_ptm.master_time.eq(ptm_sink.master_time),

                If(ptm_sink.request,
                    tlp_ptm.type.eq(type_dict["ptm_req"]),
                    tlp_ptm.fmt.eq( fmt_dict["ptm_req"]),
                ),
                If(ptm_sink.response,
                    tlp_ptm.type.eq(type_dict["ptm_res"]),
                    tlp_ptm.fmt.eq( fmt_dict["ptm_res"]),
                    tlp_ptm.dat.eq(ptm_sink.dat),
                    tlp_ptm.be.eq(2**(data_width//8)-1), # CHECKME.
                ),
            ]

            tlp_raw_ptm        = stream.Endpoint(tlp_raw_layout(data_width))
            tlp_raw_ptm_header = Signal(len(tlp_raw_ptm.header))
            self.comb += [
                tlp_ptm.connect(tlp_raw_ptm, omit={*tlp_ptm_header_fields.keys()}),
                tlp_raw_ptm.fmt.eq(tlp_ptm.fmt),
                tlp_ptm_header.encode(tlp_ptm, tlp_raw_ptm_header),
            ]
            self.comb += dword_endianness_swap(
                src        = tlp_raw_ptm_header,
                dst        = tlp_raw_ptm.header,
                data_width = data_width,
                endianness = endianness,
                mode       = "dat",
                ndwords    = 4
            )

        # Arbitrate --------------------------------------------------------------------------------

        tlp_raws = []
        if "REQUEST" in capabilities:
            tlp_raws.append(tlp_raw_req)
        if "COMPLETION" in capabilities:
            tlp_raws.append(tlp_raw_cmp)
        if "PTM" in capabilities:
            tlp_raws.append(tlp_raw_ptm)
        tlp_raw = stream.Endpoint(tlp_raw_layout(data_width))
        self.arbitrer = Arbiter(
            masters = tlp_raws,
            slave   = tlp_raw
        )

        # Buffer -----------------------------------------------------------------------------------

        tlp_raw_d   = stream.Endpoint(tlp_raw_layout(data_width))
        tlp_raw_buf = stream.Buffer(tlp_raw_layout(data_width))
        self.submodules += tlp_raw_buf
        self.comb += [
            tlp_raw.connect(tlp_raw_buf.sink),
            tlp_raw_buf.source.connect(tlp_raw_d),
        ]

        # Insert header ----------------------------------------------------------------------------
        header_inserter_cls = {
            64 : LitePCIeTLPHeaderInserter64b,
           128 : LitePCIeTLPHeaderInserter128b,
           256 : LitePCIeTLPHeaderInserter256b,
           512 : LitePCIeTLPHeaderInserter512b,
        }
        header_inserter = header_inserter_cls[data_width](fmt=tlp_raw_d.fmt)
        self.submodules += header_inserter
        self.comb += tlp_raw_d.connect(header_inserter.sink)
        self.comb += header_inserter.source.connect(self.source, omit={"data", "be"})
        for name in ["dat", "be"]:
            self.comb += dword_endianness_swap(
                src        = getattr(header_inserter.source, name),
                dst        = getattr(self.source, name),
                data_width = data_width,
                endianness = endianness,
                mode       = name,
            )
