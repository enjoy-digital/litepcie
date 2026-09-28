#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

from migen import *

from litex.gen import *
from litex.soc.interconnect.packet import Header, HeaderField, Packetizer

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
            fmt_dict[ "cfg_rd0"] : header_sel.eq(_3DWS_SEL),
            fmt_dict[ "cfg_wr0"] : header_sel.eq(_3DWS_SEL),
            fmt_dict[    "cpld"] : header_sel.eq(_3DWS_SEL),
            fmt_dict[     "cpl"] : header_sel.eq(_3DWS_SEL),
            fmt_dict[ "ptm_req"] : header_sel.eq(_4DWS_SEL),
            fmt_dict[ "ptm_res"] : header_sel.eq(_4DWS_SEL),
        })

        # Keep the selected inserter until its final output beat is accepted. The
        # input can already carry the next packet's format while a tail is buffered.
        header_sel_d = Signal()
        ongoing      = Signal()
        self.sync += [
            If(source.valid & source.first & ~ongoing,
                header_sel_d.eq(header_sel),
                ongoing.eq(1),
            ),
            If(source.valid & source.ready & source.last, ongoing.eq(0)),
        ]

        # Header Inserters Mux.
        # Keep forward and return paths separate to avoid procedural feedback
        # between the mux and the inserters in event-driven RTL simulation.
        selected = Signal()
        self.comb += selected.eq(Mux(ongoing, header_sel_d, header_sel))
        for i, inserter in enumerate([header_inserter_3dws, header_inserter_4dws]):
            self.comb += [
                sink.connect(inserter.sink, omit={"valid", "ready"}),
                inserter.sink.valid.eq(sink.valid & (selected == i)),
                inserter.source.ready.eq(source.ready & (selected == i)),
            ]
        self.comb += sink.ready.eq(Mux(selected, header_inserter_4dws.sink.ready, header_inserter_3dws.sink.ready))
        for name in ["valid", "first", "last", "dat", "be"]:
            self.comb += getattr(source, name).eq(Mux(selected,
                getattr(header_inserter_4dws.source, name),
                getattr(header_inserter_3dws.source, name)))


# Generic TLP Header Inserter ---------------------------------------------------------------------


class _LitePCIeTLPHeaderInserterNDWs(LiteXModule):
    """Map PCIe's packed header/data interface to the shared byte-enabled packetizer."""
    def __init__(self, data_width, header_dws):
        assert data_width in [32, 64, 128, 256, 512]
        assert header_dws in [3, 4]
        self.sink   = sink   = stream.Endpoint(tlp_raw_layout(data_width))
        self.source = source = stream.Endpoint(phy_layout(data_width))

        # # #

        header = Header({"header" : HeaderField(0, 0, 32*header_dws)},
            length=4*header_dws, swap_field_bytes=False)
        payload_layout = [("data", data_width), ("be", data_width//8)]
        self.packetizer = packetizer = Packetizer(
            stream.EndpointDescription(payload_layout, header.get_layout()),
            stream.EndpointDescription(payload_layout), header, with_first=True)
        self.comb += [
            sink.connect(packetizer.sink, keep={"valid", "ready", "first", "last", "be"}),
            packetizer.sink.data.eq(sink.dat),
            packetizer.sink.header.eq(sink.header[:32*header_dws]),
            packetizer.source.connect(source, keep={"valid", "ready", "first", "last", "be"}),
            source.dat.eq(packetizer.source.data),
        ]


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


# LitePCIeTLPHeaderInserter32b ---------------------------------------------------------------------


class LitePCIeTLPHeaderInserter32b3DWs(_LitePCIeTLPHeaderInserterNDWs):
    def __init__(self):
        _LitePCIeTLPHeaderInserterNDWs.__init__(self, data_width=32, header_dws=3)


class LitePCIeTLPHeaderInserter32b4DWs(_LitePCIeTLPHeaderInserterNDWs):
    def __init__(self):
        _LitePCIeTLPHeaderInserterNDWs.__init__(self, data_width=32, header_dws=4)


class LitePCIeTLPHeaderInserter32b(LitePCIeTLPHeaderInserter3DWs4DWs):
    def __init__(self, fmt):
        LitePCIeTLPHeaderInserter3DWs4DWs.__init__(self,
            data_width               = 32,
            header_inserter_3dws_cls = LitePCIeTLPHeaderInserter32b3DWs,
            header_inserter_4dws_cls = LitePCIeTLPHeaderInserter32b4DWs,
            fmt                      = fmt,
        )


# LitePCIeTLPHeaderInserter64b ---------------------------------------------------------------------


class LitePCIeTLPHeaderInserter64b3DWs(_LitePCIeTLPHeaderInserterNDWs):
    def __init__(self):
        _LitePCIeTLPHeaderInserterNDWs.__init__(self, data_width=64, header_dws=3)


class LitePCIeTLPHeaderInserter64b4DWs(_LitePCIeTLPHeaderInserterNDWs):
    def __init__(self):
        _LitePCIeTLPHeaderInserterNDWs.__init__(self, data_width=64, header_dws=4)


class LitePCIeTLPHeaderInserter64b(LitePCIeTLPHeaderInserter3DWs4DWs):
    def __init__(self, fmt):
        LitePCIeTLPHeaderInserter3DWs4DWs.__init__(self,
            data_width               = 64,
            header_inserter_3dws_cls = LitePCIeTLPHeaderInserter64b3DWs,
            header_inserter_4dws_cls = LitePCIeTLPHeaderInserter64b4DWs,
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
            assert c in ["REQUEST", "COMPLETION", "CONFIGURATION", "PTM"]
        # Sink Endpoints.
        with_configuration = ("CONFIGURATION" in capabilities)
        if "REQUEST" in capabilities:
            self.req_sink = req_sink = stream.Endpoint(request_layout(data_width, address_width, with_configuration=with_configuration))
        if "COMPLETION" in capabilities:
            self.cmp_sink = cmp_sink = stream.Endpoint(completion_layout(data_width))
        if "PTM" in capabilities:
            self.ptm_sink = ptm_sink = stream.Endpoint(ptm_layout(data_width))

        # Source Endpoints.
        self.source   = stream.Endpoint(phy_layout(data_width))

        # # #

        req_is_cfg = Signal()
        if with_configuration:
            self.comb += req_is_cfg.eq(req_sink.is_cfg)

        # Format and Encode TLP Requests -----------------------------------------------------------

        if "REQUEST" in capabilities:
            self.tlp_req = tlp_req = stream.Endpoint(tlp_request_layout(data_width))

            request_be = Signal(data_width//8)
            self.comb += request_be.eq(2**(data_width//8)-1)
            dwords_per_beat = data_width//32
            if dwords_per_beat > 1:
                remainder_bits = (dwords_per_beat - 1).bit_length()
                remainder_cases = {
                    n : request_be.eq(2**(4*n)-1)
                    for n in range(1, dwords_per_beat)
                }
                self.comb += If(req_sink.last,
                    Case(req_sink.len[:remainder_bits], remainder_cases)
                )

            self.comb += [
                If(~req_is_cfg,
                    tlp_req.valid.eq(req_sink.valid),
                    req_sink.ready.eq(tlp_req.ready)
                ),
                tlp_req.first.eq(req_sink.first),
                tlp_req.last.eq(req_sink.last),

                tlp_req.type.eq(0b00000),
                If(req_sink.we,
                    tlp_req.fmt.eq(fmt_dict["mem_wr32"]),
                ).Else(
                    tlp_req.fmt.eq(fmt_dict["mem_rd32"]),
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
                            tlp_req.fmt.eq(fmt_dict["mem_wr64"]),
                        ).Else(
                            tlp_req.fmt.eq(fmt_dict["mem_rd64"]),
                        ),
                    )
                ]
            elif force_64b:
                # Address width is 32 bits but we force issuing 4DWs TLP
                self.comb += [
                    tlp_req.address[:32].eq(Constant(0, 32)),
                    tlp_req.address[32:].eq(req_sink.adr[:32]),
                    If(req_sink.we,
                        tlp_req.fmt.eq(fmt_dict["mem_wr64"]),
                    ).Else(
                        tlp_req.fmt.eq(fmt_dict["mem_rd64"]),
                    ),
                ]

            self.comb += [
                tlp_req.tc.eq(0),
                tlp_req.td.eq(0),
                tlp_req.ep.eq(0),
                tlp_req.attr.eq(req_sink.attr),
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
                    tlp_req.be.eq(request_be)
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

            # Register raw requests before arbitration to break the long
            # request-header timing cone into the shared packetizer buffer.
            tlp_raw_req_d   = stream.Endpoint(tlp_raw_layout(data_width))
            tlp_raw_req_buf = stream.Buffer(tlp_raw_layout(data_width))
            self.submodules += tlp_raw_req_buf
            self.comb += [
                tlp_raw_req.connect(tlp_raw_req_buf.sink),
                tlp_raw_req_buf.source.connect(tlp_raw_req_d),
            ]

        # Format and Encode TLP Completions --------------------------------------------------------

        if "COMPLETION" in capabilities:
            self.tlp_cmp = tlp_cmp = stream.Endpoint(tlp_completion_layout(data_width))

            completion_be = Signal(data_width//8)
            self.comb += completion_be.eq(2**(data_width//8)-1)
            dwords_per_beat = data_width//32
            if dwords_per_beat > 1:
                remainder_bits = (dwords_per_beat - 1).bit_length()
                remainder_cases = {
                    n : completion_be.eq(2**(4*n)-1)
                    for n in range(1, dwords_per_beat)
                }
                self.comb += If(cmp_sink.last,
                    Case(cmp_sink.len[:remainder_bits], remainder_cases)
                )

            self.comb += [
                tlp_cmp.valid.eq(cmp_sink.valid),
                cmp_sink.ready.eq(tlp_cmp.ready),
                tlp_cmp.first.eq(cmp_sink.first),
                tlp_cmp.last.eq(cmp_sink.last),

                tlp_cmp.tc.eq(cmp_sink.tc),
                tlp_cmp.td.eq(0),
                tlp_cmp.ep.eq(0),
                tlp_cmp.attr.eq(cmp_sink.attr),

                tlp_cmp.completer_id.eq(cmp_sink.cmp_id),
                If(cmp_sink.err,
                    tlp_cmp.type.eq(type_dict["cpl"]),
                    tlp_cmp.fmt.eq( fmt_dict["cpl"]),
                    tlp_cmp.status.eq(cpl_dict["ur"]),
                    tlp_cmp.length.eq(0),
                    tlp_cmp.byte_count.eq(0),
                    tlp_cmp.lower_address.eq(0),
                    tlp_cmp.be.eq(0),
                ).Else(
                    tlp_cmp.type.eq(type_dict["cpld"]),
                    tlp_cmp.fmt.eq( fmt_dict["cpld"]),
                    tlp_cmp.status.eq(cpl_dict["sc"]),
                    tlp_cmp.length.eq(cmp_sink.len),
                    tlp_cmp.byte_count.eq(cmp_sink.byte_count),
                    tlp_cmp.lower_address.eq(cmp_sink.adr),
                    tlp_cmp.be.eq(completion_be),
                ),
                tlp_cmp.bcm.eq(0),

                tlp_cmp.requester_id.eq(cmp_sink.req_id),
                tlp_cmp.tag.eq(cmp_sink.tag),

                tlp_cmp.dat.eq(cmp_sink.dat),
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

        # Format and Encode TLP PTM ----------------------------------------------------------------

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


        # Format and Encode TLP Configuration ------------------------------------------------------

        if "CONFIGURATION" in capabilities:
            self.tlp_cfg = tlp_cfg = stream.Endpoint(tlp_configuration_layout(data_width))
            self.comb += [
                If(req_is_cfg,
                    tlp_cfg.valid.eq(req_sink.valid),
                    req_sink.ready.eq(tlp_cfg.ready)
                ),

                # first/last.
                tlp_cfg.first.eq(req_sink.first),
                tlp_cfg.last.eq(req_sink.last),

                # Common fields.
                tlp_cfg.tc.eq(0),
                tlp_cfg.td.eq(0),
                tlp_cfg.ep.eq(0),
                tlp_cfg.attr.eq(0),
                tlp_cfg.length.eq(1),   # CFG accesses are 1 DW.

                # Routing/identity.
                tlp_cfg.requester_id.eq(req_sink.req_id),
                tlp_cfg.tag.eq(req_sink.tag),

                # Byte enables.
                tlp_cfg.first_be.eq(0xf),
                tlp_cfg.last_be.eq(0x0),

                # Target BDF + register.
                tlp_cfg.bus_number.eq(req_sink.bus_number),
                tlp_cfg.device_no.eq(req_sink.device_no),
                tlp_cfg.func.eq(req_sink.func),
                tlp_cfg.ext_reg.eq(req_sink.ext_reg),
                tlp_cfg.register_no.eq(req_sink.register_no),

                # Data + BE policy.
                tlp_cfg.dat.eq(req_sink.dat),
                If(req_sink.we,
                    tlp_cfg.be.eq(0xf)
                ).Else(
                    tlp_cfg.be.eq(0x00)
                ),

                # CFG0.
                If(req_sink.we,
                    tlp_cfg.type.eq(type_dict["cfg_wr0"]),
                    tlp_cfg.fmt.eq(fmt_dict["cfg_wr0"]),
                ).Else(
                    tlp_cfg.type.eq(type_dict["cfg_rd0"]),
                    tlp_cfg.fmt.eq(fmt_dict["cfg_rd0"]),
                ),
            ]

            tlp_raw_conf        = stream.Endpoint(tlp_raw_layout(data_width))
            tlp_raw_conf_header = Signal(len(tlp_raw_conf.header))
            self.comb += [
                tlp_cfg.connect(tlp_raw_conf, omit={*tlp_configuration_header_fields.keys()}),
                tlp_raw_conf.fmt.eq(tlp_cfg.fmt),
                tlp_configuration_header.encode(tlp_cfg, tlp_raw_conf_header),
            ]
            self.comb += dword_endianness_swap(
                src        = tlp_raw_conf_header,
                dst        = tlp_raw_conf.header,
                data_width = data_width,
                endianness = endianness,
                mode       = "dat",
                ndwords    = 4
            )

        # Arbitrate --------------------------------------------------------------------------------

        tlp_raws = []
        if "REQUEST" in capabilities:
            tlp_raws.append(tlp_raw_req_d)
        if "COMPLETION" in capabilities:
            tlp_raws.append(tlp_raw_cmp)
        if "CONFIGURATION" in capabilities:
            tlp_raws.append(tlp_raw_conf)
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
            32 : LitePCIeTLPHeaderInserter32b,
            64 : LitePCIeTLPHeaderInserter64b,
           128 : LitePCIeTLPHeaderInserter128b,
           256 : LitePCIeTLPHeaderInserter256b,
           512 : LitePCIeTLPHeaderInserter512b,
        }
        header_inserter = header_inserter_cls[data_width](fmt=tlp_raw_d.fmt)
        self.submodules += header_inserter
        self.comb += tlp_raw_d.connect(header_inserter.sink)
        self.comb += header_inserter.source.connect(self.source, omit={"dat", "be"})
        for name in ["dat", "be"]:
            self.comb += dword_endianness_swap(
                src        = getattr(header_inserter.source, name),
                dst        = getattr(self.source, name),
                data_width = data_width,
                endianness = endianness,
                mode       = name,
            )
