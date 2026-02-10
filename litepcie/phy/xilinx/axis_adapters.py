#
# This file is part of LitePCIe.
#
# Copyright (c) 2020-2026 Enjoy-Digital <enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

from migen import *

from litex.gen import *

# Xilinx AXIS adaptation is implemented in LiteX/Migen (Python) to avoid
# duplicated legacy Verilog per-family/per-width variants.


def _pack_keep_cc(tkeep, data_width):
    # CC keep packing follows the legacy wrapper behavior:
    # - 128/256b: one output bit per 4-bit nibble, set when nibble is non-zero.
    # - 512b: one output bit per nibble, copied from nibble bit0.
    if data_width == 128:
        return Cat(*[(tkeep[4*i:4*(i + 1)] != 0) for i in range(4)])
    if data_width == 256:
        return Cat(*[(tkeep[4*i:4*(i + 1)] != 0) for i in range(8)])
    return Cat(*[tkeep[4*i] for i in range(16)])


def _pack_keep_rq(tkeep, data_width):
    # RQ keep packing follows the legacy wrapper behavior:
    # - 128b: one output bit per 4-bit nibble, set when nibble is non-zero.
    # - 256/512b: one output bit per nibble, copied from nibble bit0.
    if data_width == 128:
        return Cat(*[(tkeep[4*i:4*(i + 1)] != 0) for i in range(4)])
    return Cat(*[tkeep[4*i] for i in range(data_width // 32)])


def _rq_upper_user(discontinue):
    return Cat(
        C(0, 3),
        discontinue,
        C(0, 1),
        C(0, 2),
        C(0, 8),
        C(0, 1),
        C(0, 4),
        C(0, 32),
    )


class MAxisRCAdapter(LiteXModule):
    """Adapt Xilinx RC AXIS (hard IP format) to LitePCIe RC stream format."""
    def __init__(self, data_width):
        assert data_width in [128, 256, 512]
        keep_width = data_width // 8

        # Raw RC AXIS from Xilinx hard IP.
        self.s_axis_tdata  = Signal(data_width)
        self.s_axis_tkeep  = Signal(keep_width // 4)
        self.s_axis_tlast  = Signal()
        self.s_axis_tready = Signal(4)
        self.s_axis_tuser  = Signal(85)
        self.s_axis_tvalid = Signal()

        # Adapted RC AXIS to LitePCIe PHY datapath.
        self.m_axis_tdata  = Signal(data_width)
        self.m_axis_tkeep  = Signal(keep_width)
        self.m_axis_tlast  = Signal()
        self.m_axis_tready = Signal()
        self.m_axis_tuser  = Signal(85)
        self.m_axis_tvalid = Signal()
        self.m_axis_sop    = Signal()

        # -----------------------------------------------------------------------------------------

        rc_cnt = Signal(2)
        self.sync += [
            If(self.s_axis_tvalid & self.s_axis_tready[0],
                If(self.s_axis_tlast,
                    rc_cnt.eq(0)
                ).Elif(~rc_cnt[1],
                    rc_cnt.eq(rc_cnt + 1)
                )
            )
        ]
        self.comb += self.m_axis_sop.eq(rc_cnt == 0)

        poisoning   = Signal()
        poisoning_l = Signal()
        self.comb += poisoning.eq(self.s_axis_tdata[46])
        self.sync += [
            If(self.s_axis_tvalid & self.m_axis_sop,
                poisoning_l.eq(poisoning)
            )
        ]

        dwlen       = Signal(10)
        attr        = Signal(2)
        tc          = Signal(3)
        bytecnt     = Signal(12)
        cmpstatus   = Signal(3)
        completerid = Signal(16)
        lowaddr     = Signal(7)
        tag         = Signal(8)
        requesterid = Signal(16)
        fmt         = Signal(3)
        typ         = Signal(5)

        self.comb += [
            dwlen.eq(self.s_axis_tdata[32:42]),
            attr.eq(self.s_axis_tdata[92:94]),
            tc.eq(self.s_axis_tdata[89:92]),
            bytecnt.eq(self.s_axis_tdata[16:28]),
            cmpstatus.eq(self.s_axis_tdata[43:46]),
            completerid.eq(self.s_axis_tdata[72:88]),
            lowaddr.eq(self.s_axis_tdata[0:7]),
            tag.eq(self.s_axis_tdata[64:72]),
            requesterid.eq(self.s_axis_tdata[48:64]),
            If(self.s_axis_tdata[29],
                If(bytecnt == 0,
                    fmt.eq(0b000),
                    typ.eq(0b01011)
                ).Else(
                    fmt.eq(0b010),
                    typ.eq(0b01011)
                )
            ).Else(
                If(bytecnt == 0,
                    fmt.eq(0b000),
                    typ.eq(0b01010)
                ).Else(
                    fmt.eq(0b010),
                    typ.eq(0b01010)
                )
            )
        ]

        header0 = Signal(64)
        header1 = Signal(64)
        self.comb += [
            header0.eq(Cat(
                dwlen,
                C(0, 2),
                attr,
                C(0, 1),  # ep
                C(0, 1),  # td
                C(0, 4),
                tc,
                C(0, 1),
                typ,
                fmt,
                bytecnt,
                C(0, 1),  # bmc
                cmpstatus,
                completerid
            )),
            header1.eq(Cat(
                lowaddr,
                C(0, 1),
                tag,
                requesterid,
                self.s_axis_tdata[96:128]
            ))
        ]

        poisoning_out = Signal()
        self.comb += poisoning_out.eq(Mux(self.m_axis_sop, poisoning, poisoning_l))

        self.comb += [
            self.m_axis_tvalid.eq(self.s_axis_tvalid),
            self.m_axis_tlast.eq(self.s_axis_tlast),
            self.s_axis_tready.eq(Replicate(self.m_axis_tready, 4)),
        ]

        if data_width == 128:
            self.comb += [
                If(self.m_axis_sop,
                    self.m_axis_tdata.eq(Cat(header0, header1))
                ).Else(
                    self.m_axis_tdata.eq(self.s_axis_tdata)
                ),
                If(self.m_axis_sop,
                    self.m_axis_tkeep.eq(Replicate(C(1, 1), keep_width))
                ).Else(
                    self.m_axis_tkeep.eq(self.s_axis_tuser[:keep_width])
                ),
                self.m_axis_tuser.eq(Cat(
                    self.s_axis_tuser[42],
                    poisoning_out,
                    C(0, 8),
                    C(0, 4),
                    self.m_axis_sop,
                    C(0, 2),
                    C(0, 5),
                    C(0, 63)
                ))
            ]
        else:
            self.comb += [
                If(self.m_axis_sop,
                    self.m_axis_tdata.eq(Cat(header0, header1, self.s_axis_tdata[128:data_width]))
                ).Else(
                    self.m_axis_tdata.eq(self.s_axis_tdata)
                ),
                If(self.m_axis_sop,
                    self.m_axis_tkeep.eq(Cat(C(0xFFF, 12), self.s_axis_tuser[12:keep_width]))
                ).Else(
                    self.m_axis_tkeep.eq(self.s_axis_tuser[:keep_width])
                ),
                self.m_axis_tuser.eq(Cat(
                    self.s_axis_tuser[42],
                    poisoning_out,
                    C(0, 8),
                    C(0, 5),
                    C(0, 2),
                    C(0, 5),
                    C(0, 63)
                ))
            ]


class MAxisCQAdapter(LiteXModule):
    """Adapt Xilinx CQ AXIS (hard IP format) to LitePCIe CQ stream format."""
    def __init__(self, data_width):
        assert data_width in [128, 256, 512]
        keep_width = data_width // 8

        # Raw CQ AXIS from Xilinx hard IP.
        self.s_axis_tdata  = Signal(data_width)
        self.s_axis_tkeep  = Signal(keep_width // 4)
        self.s_axis_tlast  = Signal()
        self.s_axis_tready = Signal(4)
        self.s_axis_tuser  = Signal(256)
        self.s_axis_tvalid = Signal()

        # Adapted CQ AXIS to LitePCIe PHY datapath.
        self.m_axis_tdata  = Signal(data_width)
        self.m_axis_tkeep  = Signal(keep_width)
        self.m_axis_tlast  = Signal()
        self.m_axis_tready = Signal()
        self.m_axis_tuser  = Signal(85)
        self.m_axis_tvalid = Signal()
        self.m_axis_sop    = Signal()

        # -----------------------------------------------------------------------------------------

        tdata_hdr = Signal(64)
        self.comb += tdata_hdr.eq(self.s_axis_tdata[64:128])

        dwlen       = Signal(10)
        attr        = Signal(2)
        tc          = Signal(3)
        tag         = Signal(8)
        requesterid = Signal(16)
        reqtype     = Signal(4)
        fmt         = Signal(3)
        typ         = Signal(5)
        read_req    = Signal()

        self.comb += [
            dwlen.eq(tdata_hdr[0:10]),
            attr.eq(tdata_hdr[60:62]),
            tc.eq(tdata_hdr[57:60]),
            tag.eq(tdata_hdr[32:40]),
            requesterid.eq(tdata_hdr[16:32]),
            reqtype.eq(tdata_hdr[11:15]),
            Case(reqtype, {
                0b0000: [fmt.eq(0b000), typ.eq(0b00000)],
                0b0111: [fmt.eq(0b000), typ.eq(0b00001)],
                0b0001: [fmt.eq(0b010), typ.eq(0b00000)],
                0b0010: [fmt.eq(0b000), typ.eq(0b00010)],
                0b0011: [fmt.eq(0b010), typ.eq(0b00010)],
                0b1000: [fmt.eq(0b000), typ.eq(0b00100)],
                0b1010: [fmt.eq(0b010), typ.eq(0b00100)],
                0b1001: [fmt.eq(0b000), typ.eq(0b00101)],
                0b1011: [fmt.eq(0b010), typ.eq(0b00101)],
                "default": [fmt.eq(0), typ.eq(0)],
            }),
            read_req.eq(fmt[:2] == 0),
        ]

        cnt       = Signal(2)
        tlast_lat = Signal()
        self.sync += [
            If(self.s_axis_tvalid & self.s_axis_tready[0],
                If(self.s_axis_tlast,
                    cnt.eq(0)
                ).Elif(~cnt[1],
                    cnt.eq(cnt + 1)
                )
            )
        ]

        sop    = Signal()
        second = Signal()
        self.comb += [
            sop.eq((cnt == 0) & ~tlast_lat),
            second.eq(cnt == 1),
            self.m_axis_sop.eq(sop),
        ]

        tuser_barhit = Signal(8)
        self.sync += [
            If(self.s_axis_tvalid & sop,
                tuser_barhit.eq(Cat(tdata_hdr[11:15], tdata_hdr[48:51], C(0, 1)))
            )
        ]

        header = Signal(64)
        self.sync += [
            If(self.s_axis_tvalid & sop,
                header.eq(Cat(
                    dwlen,
                    C(0, 2),
                    attr,
                    C(0, 1),  # ep
                    C(0, 1),  # td
                    C(0, 4),
                    tc,
                    C(0, 1),
                    typ,
                    fmt,
                    self.s_axis_tuser[0:8],  # be (128/256), overwritten in 512 branch.
                    tag,
                    requesterid
                ))
            )
        ]

        ready_a = Signal()
        self.comb += ready_a.eq(((cnt == 0) | self.m_axis_tready) & ~tlast_lat)
        self.comb += self.s_axis_tready.eq(Replicate(ready_a, 4))

        if data_width == 128:
            read_l        = Signal()
            tlast_dly_en  = Signal()
            tdata_a1      = Signal(128)
            tlast_be1     = Signal(16)
            ecrc          = Signal()
            hiaddr_mask   = Signal(32)

            self.comb += hiaddr_mask.eq(Mux(read_l, 0, self.s_axis_tdata[0:32]))

            self.sync += [
                If(self.s_axis_tvalid & sop,
                    read_l.eq(read_req)
                ),
                If(self.s_axis_tvalid & self.s_axis_tready[0],
                    tdata_a1.eq(self.s_axis_tdata),
                    tlast_be1.eq(self.s_axis_tuser[8:24])
                ),
                ecrc.eq(self.s_axis_tuser[41]),
                If(self.s_axis_tvalid & sop,
                    header.eq(Cat(
                        dwlen,
                        C(0, 2),
                        attr,
                        C(0, 1),
                        C(0, 1),
                        C(0, 4),
                        tc,
                        C(0, 1),
                        typ,
                        fmt,
                        self.s_axis_tuser[0:8],
                        tag,
                        requesterid
                    ))
                )
            ]

            self.sync += [
                If(tlast_lat & self.m_axis_tready,
                    tlast_dly_en.eq(0)
                ).Elif(self.s_axis_tvalid & sop,
                    If(read_req,
                        tlast_dly_en.eq(1)
                    ).Else(
                        tlast_dly_en.eq(dwlen[:2] != 1)
                    )
                )
            ]

            self.sync += [
                If(tlast_lat & self.m_axis_tready,
                    tlast_lat.eq(0)
                ).Elif(self.s_axis_tvalid & self.s_axis_tready[0] & self.s_axis_tlast,
                    If(sop | tlast_dly_en,
                        tlast_lat.eq(1)
                    )
                )
            ]

            self.comb += [
                self.m_axis_tlast.eq(Mux(tlast_dly_en, tlast_lat, self.s_axis_tlast)),
                self.m_axis_tvalid.eq((self.s_axis_tvalid & (cnt != 0)) | tlast_lat),
                If(read_l | second,
                    self.m_axis_tdata.eq(Cat(header, tdata_a1[0:32], hiaddr_mask))
                ).Else(
                    self.m_axis_tdata.eq(Cat(tdata_a1[32:128], self.s_axis_tdata[0:32]))
                ),
                If(read_l,
                    self.m_axis_tkeep.eq(C(0x0FFF, keep_width))
                ).Elif(tlast_lat,
                    self.m_axis_tkeep.eq(Cat(tlast_be1[4:16], C(0, 4)))
                ).Else(
                    self.m_axis_tkeep.eq(C((1 << keep_width) - 1, keep_width))
                ),
                self.m_axis_tuser.eq(Cat(
                    ecrc,
                    C(0, 1),
                    tuser_barhit,
                    C(0, 5),
                    C(0, 2),
                    C(0, 5),
                    C(0, 63)
                ))
            ]
        elif data_width == 256:
            rdwr_l       = Signal()
            tlast_dly_en = Signal()
            tdata_a1     = Signal(256)
            tlast_be1    = Signal(32)

            self.sync += [
                If(self.s_axis_tvalid & sop,
                    rdwr_l.eq(self.s_axis_tlast)
                ),
                If(self.s_axis_tvalid & self.s_axis_tready[0],
                    tdata_a1.eq(self.s_axis_tdata),
                    tlast_be1.eq(self.s_axis_tuser[8:40])
                ),
                If(self.s_axis_tvalid & sop,
                    header.eq(Cat(
                        dwlen,
                        C(0, 2),
                        attr,
                        C(0, 1),
                        C(0, 1),
                        C(0, 4),
                        tc,
                        C(0, 1),
                        typ,
                        fmt,
                        self.s_axis_tuser[0:8],
                        tag,
                        requesterid
                    ))
                )
            ]

            self.sync += [
                If(tlast_lat & self.m_axis_tready,
                    tlast_dly_en.eq(0)
                ).Elif(self.s_axis_tvalid & sop,
                    tlast_dly_en.eq(self.s_axis_tlast | (dwlen[:3] != 5))
                )
            ]

            self.sync += [
                If(tlast_lat & self.m_axis_tready,
                    tlast_lat.eq(0)
                ).Elif(self.s_axis_tvalid & self.s_axis_tready[0] & self.s_axis_tlast,
                    If(sop | tlast_dly_en,
                        tlast_lat.eq(1)
                    )
                )
            ]

            self.comb += [
                self.m_axis_tlast.eq(Mux(tlast_dly_en, tlast_lat, self.s_axis_tlast)),
                self.m_axis_tvalid.eq((self.s_axis_tvalid & (cnt != 0)) | tlast_lat),
                If(rdwr_l | second,
                    self.m_axis_tdata.eq(Cat(header, tdata_a1[0:32], tdata_a1[128:256], self.s_axis_tdata[0:32]))
                ).Else(
                    self.m_axis_tdata.eq(Cat(tdata_a1[32:256], self.s_axis_tdata[0:32]))
                ),
                If(rdwr_l,
                    self.m_axis_tkeep.eq(Cat(C(0xFFF, 12), tlast_be1[16:32], C(0, 4)))
                ).Elif(tlast_lat,
                    self.m_axis_tkeep.eq(Cat(tlast_be1[4:32], C(0, 4)))
                ).Else(
                    self.m_axis_tkeep.eq(C((1 << keep_width) - 1, keep_width))
                ),
                self.m_axis_tuser.eq(Cat(
                    self.s_axis_tuser[41],
                    C(0, 1),
                    tuser_barhit,
                    C(0, 5),
                    C(0, 2),
                    C(0, 5),
                    C(0, 63)
                ))
            ]
        else:
            rdwr_l       = Signal()
            tlast_dly_en = Signal()
            tdata_a1     = Signal(512)
            tlast_be1    = Signal(64)
            be_512       = Signal(8)

            self.comb += be_512.eq(Cat(self.s_axis_tuser[0:4], self.s_axis_tuser[8:12]))

            self.sync += [
                If(self.s_axis_tvalid & sop,
                    rdwr_l.eq(self.s_axis_tlast)
                ),
                If(self.s_axis_tvalid & self.s_axis_tready[0],
                    tdata_a1.eq(self.s_axis_tdata),
                    tlast_be1.eq(self.s_axis_tuser[16:80])
                ),
                If(self.s_axis_tvalid & sop,
                    header.eq(Cat(
                        dwlen,
                        C(0, 2),
                        attr,
                        C(0, 1),
                        C(0, 1),
                        C(0, 4),
                        tc,
                        C(0, 1),
                        typ,
                        fmt,
                        be_512,
                        tag,
                        requesterid
                    ))
                )
            ]

            self.sync += [
                If(tlast_lat & self.m_axis_tready,
                    tlast_dly_en.eq(0)
                ).Elif(self.s_axis_tvalid & sop,
                    tlast_dly_en.eq(self.s_axis_tlast | (dwlen[:4] != 13))
                )
            ]

            self.sync += [
                If(tlast_lat & self.m_axis_tready,
                    tlast_lat.eq(0)
                ).Elif(self.s_axis_tvalid & self.s_axis_tready[0] & self.s_axis_tlast,
                    If(sop | tlast_dly_en,
                        tlast_lat.eq(1)
                    )
                )
            ]

            self.comb += [
                self.m_axis_tlast.eq(Mux(tlast_dly_en, tlast_lat, self.s_axis_tlast)),
                self.m_axis_tvalid.eq((self.s_axis_tvalid & (cnt != 0)) | tlast_lat),
                If(rdwr_l | second,
                    self.m_axis_tdata.eq(Cat(header, tdata_a1[0:32], tdata_a1[128:512], self.s_axis_tdata[0:32]))
                ).Else(
                    self.m_axis_tdata.eq(Cat(tdata_a1[32:512], self.s_axis_tdata[0:32]))
                ),
                If(rdwr_l,
                    self.m_axis_tkeep.eq(Cat(C(0xFFF, 12), tlast_be1[16:64], C(0, 4)))
                ).Elif(tlast_lat,
                    self.m_axis_tkeep.eq(Cat(tlast_be1[4:64], C(0, 4)))
                ).Else(
                    self.m_axis_tkeep.eq(C((1 << keep_width) - 1, keep_width))
                ),
                self.m_axis_tuser.eq(Cat(
                    self.s_axis_tuser[96],
                    C(0, 1),
                    tuser_barhit,
                    C(0, 5),
                    C(0, 2),
                    C(0, 5),
                    C(0, 63)
                ))
            ]


class SAxisCCAdapter(LiteXModule):
    """Adapt LitePCIe CC stream format to Xilinx CC AXIS (hard IP format)."""
    def __init__(self, data_width):
        assert data_width in [128, 256, 512]
        keep_width = data_width // 8

        # LitePCIe CC AXIS (input).
        self.s_axis_tdata  = Signal(data_width)
        self.s_axis_tkeep  = Signal(keep_width)
        self.s_axis_tlast  = Signal()
        self.s_axis_tready = Signal()
        self.s_axis_tuser  = Signal(4)
        self.s_axis_tvalid = Signal()

        # Raw CC AXIS to Xilinx hard IP (output).
        self.m_axis_tdata  = Signal(data_width)
        self.m_axis_tkeep  = Signal(keep_width // 4)
        self.m_axis_tlast  = Signal()
        self.m_axis_tready = Signal()
        self.m_axis_tuser  = Signal(33)
        self.m_axis_tvalid = Signal()

        # -----------------------------------------------------------------------------------------

        cnt = Signal(2)
        self.sync += [
            If(self.s_axis_tvalid & self.m_axis_tready,
                If(self.s_axis_tlast,
                    cnt.eq(0)
                ).Elif(~cnt[1],
                    cnt.eq(cnt + 1)
                )
            )
        ]
        tfirst = Signal()
        self.comb += tfirst.eq(cnt == 0)

        tkeep_or = Signal(keep_width // 4)
        self.comb += tkeep_or.eq(_pack_keep_cc(self.s_axis_tkeep, data_width))

        lowaddr     = Signal(7)
        bytecnt     = Signal(13)
        lockedrdcmp = Signal()
        dwordcnt    = Signal(10)
        cmpstatus   = Signal(3)
        poison      = Signal()
        requesterid = Signal(16)
        tag         = Signal(8)
        completerid = Signal(16)
        tc          = Signal(3)
        attr        = Signal(3)
        td          = Signal()
        self.comb += [
            lowaddr.eq(self.s_axis_tdata[64:71]),
            bytecnt.eq(Cat(self.s_axis_tdata[32:44], C(0, 1))),
            lockedrdcmp.eq(self.s_axis_tdata[24:30] == 0b001011),
            dwordcnt.eq(self.s_axis_tdata[0:10]),
            cmpstatus.eq(self.s_axis_tdata[45:48]),
            poison.eq(self.s_axis_tdata[14]),
            requesterid.eq(self.s_axis_tdata[80:96]),
            tag.eq(self.s_axis_tdata[72:80]),
            completerid.eq(self.s_axis_tdata[48:64]),
            tc.eq(self.s_axis_tdata[20:23]),
            attr.eq(Cat(self.s_axis_tdata[12:14], C(0, 1))),
            td.eq(self.s_axis_tdata[15] | self.s_axis_tuser[0]),
        ]

        header0 = Signal(64)
        header1 = Signal(64)
        self.comb += [
            header0.eq(Cat(
                lowaddr,
                C(0, 1),
                C(0, 2),  # at
                C(0, 6),
                bytecnt,
                lockedrdcmp,
                C(0, 2),
                dwordcnt,
                cmpstatus,
                poison,
                C(0, 2),
                requesterid
            )),
            header1.eq(Cat(
                tag,
                completerid,
                C(0, 1),  # completerid_en
                tc,
                attr,
                td,
                self.s_axis_tdata[96:128]
            ))
        ]

        self.comb += [
            self.s_axis_tready.eq(self.m_axis_tready),
            self.m_axis_tvalid.eq(self.s_axis_tvalid),
            self.m_axis_tlast.eq(self.s_axis_tlast),
            self.m_axis_tkeep.eq(tkeep_or),
            self.m_axis_tuser.eq(Cat(self.s_axis_tuser[3])),
        ]
        if data_width == 128:
            self.comb += [
                If(tfirst,
                    self.m_axis_tdata.eq(Cat(header0, header1))
                ).Else(
                    self.m_axis_tdata.eq(self.s_axis_tdata)
                )
            ]
        else:
            self.comb += [
                If(tfirst,
                    self.m_axis_tdata.eq(Cat(header0, header1, self.s_axis_tdata[128:data_width]))
                ).Else(
                    self.m_axis_tdata.eq(self.s_axis_tdata)
                )
            ]


class SAxisRQAdapter(LiteXModule):
    """Adapt LitePCIe RQ stream format to Xilinx RQ AXIS (hard IP format)."""
    def __init__(self, data_width):
        assert data_width in [128, 256, 512]
        keep_width = data_width // 8
        tuser_width = 137 if data_width == 512 else 60

        # LitePCIe RQ AXIS (input).
        self.s_axis_tdata  = Signal(data_width)
        self.s_axis_tkeep  = Signal(keep_width)
        self.s_axis_tlast  = Signal()
        self.s_axis_tready = Signal()
        self.s_axis_tuser  = Signal(4)
        self.s_axis_tvalid = Signal()

        # Raw RQ AXIS to Xilinx hard IP (output).
        self.m_axis_tdata  = Signal(data_width)
        self.m_axis_tkeep  = Signal(keep_width // 4)
        self.m_axis_tlast  = Signal()
        self.m_axis_tready = Signal()
        self.m_axis_tuser  = Signal(tuser_width)
        self.m_axis_tvalid = Signal()

        # -----------------------------------------------------------------------------------------

        tkeep_or = Signal(keep_width // 4)
        self.comb += tkeep_or.eq(_pack_keep_rq(self.s_axis_tkeep, data_width))

        dwlen = Signal(11)
        reqtype = Signal(4)
        self.comb += [
            dwlen.eq(Cat(self.s_axis_tdata[0:10], C(0, 1))),
            If(Cat(self.s_axis_tdata[24:29], self.s_axis_tdata[30:32]) == 0b0000000,
                reqtype.eq(0b0000)
            ).Elif(Cat(self.s_axis_tdata[24:29], self.s_axis_tdata[30:32]) == 0b0000001,
                reqtype.eq(0b0111)
            ).Elif(Cat(self.s_axis_tdata[24:29], self.s_axis_tdata[30:32]) == 0b0100000,
                reqtype.eq(0b0001)
            ).Elif(self.s_axis_tdata[24:32] == 0b00000010,
                reqtype.eq(0b0010)
            ).Elif(self.s_axis_tdata[24:32] == 0b01000010,
                reqtype.eq(0b0011)
            ).Elif(self.s_axis_tdata[24:32] == 0b00000100,
                reqtype.eq(0b1000)
            ).Elif(self.s_axis_tdata[24:32] == 0b01000100,
                reqtype.eq(0b1010)
            ).Elif(self.s_axis_tdata[24:32] == 0b00000101,
                reqtype.eq(0b1001)
            ).Elif(self.s_axis_tdata[24:32] == 0b01000101,
                reqtype.eq(0b1011)
            ).Else(
                reqtype.eq(0b1111)
            )
        ]

        poisoning    = Signal()
        requesterid  = Signal(16)
        tag          = Signal(8)
        tc           = Signal(3)
        attr         = Signal(3)
        ecrc         = Signal()
        tdata_header = Signal(64)
        self.comb += [
            poisoning.eq(self.s_axis_tdata[14] | self.s_axis_tuser[1]),
            requesterid.eq(self.s_axis_tdata[48:64]),
            tag.eq(self.s_axis_tdata[40:48]),
            tc.eq(self.s_axis_tdata[20:23]),
            attr.eq(Cat(self.s_axis_tdata[12:14], C(0, 1))),
            ecrc.eq(self.s_axis_tdata[15] | self.s_axis_tuser[0]),
            tdata_header.eq(Cat(
                dwlen,
                reqtype,
                poisoning,
                requesterid,
                tag,
                C(0, 16),  # completerid
                C(0, 1),   # requester_en
                tc,
                attr,
                ecrc
            ))
        ]

        firstbe = Signal(4)
        lastbe  = Signal(4)
        self.comb += [
            firstbe.eq(self.s_axis_tdata[32:36]),
            lastbe.eq(self.s_axis_tdata[36:40]),
        ]

        if data_width == 128:
            cnt          = Signal(2)
            tlast_dly_en = Signal()
            tlast_lat    = Signal()
            firstbe_l    = Signal(4)
            lastbe_l     = Signal(4)
            tdata_l      = Signal(32)

            tfirst = Signal()
            read   = Signal()
            write  = Signal()
            self.comb += [
                tfirst.eq((cnt == 0) & ~tlast_lat),
                read.eq(self.s_axis_tdata[30:32] == 0),
                write.eq(~read),
            ]

            ready_ff = Signal()
            self.comb += [
                ready_ff.eq(self.m_axis_tready & ~tlast_lat),
                self.s_axis_tready.eq(ready_ff),
            ]

            self.sync += [
                If(self.s_axis_tvalid & ready_ff,
                    If(self.s_axis_tlast,
                        cnt.eq(0)
                    ).Elif(~cnt[1],
                        cnt.eq(cnt + 1)
                    )
                ),
                If(self.s_axis_tvalid & tfirst & ready_ff & write,
                    tlast_dly_en.eq(self.s_axis_tdata[0:2] == 1)
                ),
                If(tlast_lat & self.m_axis_tready,
                    tlast_lat.eq(0)
                ).Elif(self.s_axis_tvalid & self.s_axis_tlast & self.m_axis_tready,
                    If(tfirst,
                        tlast_lat.eq(write)
                    ).Else(
                        tlast_lat.eq(tlast_dly_en)
                    )
                ),
                If(self.s_axis_tvalid & tfirst,
                    firstbe_l.eq(firstbe),
                    lastbe_l.eq(lastbe)
                ),
                If(self.s_axis_tvalid & ready_ff,
                    tdata_l.eq(self.s_axis_tdata[96:128])
                )
            ]

            upper_user = Signal(52)
            self.comb += upper_user.eq(_rq_upper_user(self.s_axis_tuser[3]))
            self.comb += [
                self.m_axis_tlast.eq(Mux(tfirst, read, Mux(tlast_dly_en, tlast_lat, self.s_axis_tlast))),
                self.m_axis_tvalid.eq(self.s_axis_tvalid | tlast_lat),
                self.m_axis_tdata.eq(Mux(tfirst,
                    Cat(self.s_axis_tdata[64:96], C(0, 32), tdata_header),
                    Cat(tdata_l, self.s_axis_tdata[0:96]))),
                self.m_axis_tkeep.eq(Mux(tlast_lat, C(0b0001, 4), C(0b1111, 4))),
                self.m_axis_tuser.eq(Cat(
                    Mux(tfirst, Cat(firstbe, lastbe), Cat(firstbe_l, lastbe_l)),
                    upper_user
                )),
            ]
        elif data_width == 256:
            tfirst_ff = Signal(reset=1)
            firstbe_l = Signal(4)
            lastbe_l  = Signal(4)

            self.comb += self.s_axis_tready.eq(self.m_axis_tready)
            self.sync += [
                If(self.s_axis_tvalid & self.m_axis_tready,
                    tfirst_ff.eq(0),
                    If(self.s_axis_tlast,
                        tfirst_ff.eq(1)
                    )
                ),
                If(self.s_axis_tvalid & tfirst_ff,
                    firstbe_l.eq(firstbe),
                    lastbe_l.eq(lastbe)
                )
            ]

            upper_user = Signal(52)
            self.comb += upper_user.eq(_rq_upper_user(self.s_axis_tuser[3]))
            self.comb += [
                self.m_axis_tlast.eq(self.s_axis_tlast),
                self.m_axis_tvalid.eq(self.s_axis_tvalid),
                self.m_axis_tdata.eq(Mux(tfirst_ff,
                    Cat(self.s_axis_tdata[96:128], self.s_axis_tdata[64:96], tdata_header, self.s_axis_tdata[128:256]),
                    self.s_axis_tdata)),
                self.m_axis_tkeep.eq(tkeep_or),
                self.m_axis_tuser.eq(Cat(
                    Mux(tfirst_ff, Cat(firstbe, lastbe), Cat(firstbe_l, lastbe_l)),
                    upper_user
                )),
            ]
        else:
            cnt          = Signal(2)
            tlast_dly_en = Signal()
            tlast_lat    = Signal()
            firstbe_l    = Signal(4)
            lastbe_l     = Signal(4)
            tdata_l      = Signal(32)

            tfirst = Signal()
            read   = Signal()
            write  = Signal()
            self.comb += [
                tfirst.eq((cnt == 0) & ~tlast_lat),
                read.eq(self.s_axis_tdata[30:32] == 0),
                write.eq(~read),
            ]

            ready_ff = Signal()
            self.comb += [
                ready_ff.eq(self.m_axis_tready & ~tlast_lat),
                self.s_axis_tready.eq(ready_ff),
            ]

            self.sync += [
                If(self.s_axis_tvalid & ready_ff,
                    If(self.s_axis_tlast,
                        cnt.eq(0)
                    ).Elif(~cnt[1],
                        cnt.eq(cnt + 1)
                    )
                ),
                If(self.s_axis_tvalid & tfirst & write,
                    tlast_dly_en.eq(self.s_axis_tdata[0:4] == 13)
                ),
                If(tlast_lat & self.m_axis_tready,
                    tlast_lat.eq(0)
                ).Elif(self.s_axis_tvalid & self.s_axis_tlast & self.m_axis_tready,
                    If(tfirst,
                        If(write,
                            tlast_lat.eq(dwlen == 13)
                        ).Else(
                            tlast_lat.eq(0)
                        )
                    ).Else(
                        tlast_lat.eq(tlast_dly_en)
                    )
                ),
                If(self.s_axis_tvalid & tfirst,
                    firstbe_l.eq(firstbe),
                    lastbe_l.eq(lastbe)
                ),
                If(self.s_axis_tvalid & ready_ff,
                    tdata_l.eq(self.s_axis_tdata[480:512])
                )
            ]

            self.comb += [
                self.m_axis_tlast.eq(Mux(tfirst,
                    read | (dwlen < 13),
                    Mux(tlast_dly_en, tlast_lat, self.s_axis_tlast))),
                self.m_axis_tvalid.eq(self.s_axis_tvalid | tlast_lat),
                self.m_axis_tdata.eq(Mux(tfirst,
                    Cat(self.s_axis_tdata[64:96], C(0, 32), tdata_header, self.s_axis_tdata[96:480]),
                    Cat(tdata_l, self.s_axis_tdata[0:480]))),
                self.m_axis_tkeep.eq(Mux(tlast_lat,
                    C(0x0001, 16),
                    Cat(C(1, 1), tkeep_or[0:15]))),
                self.m_axis_tuser.eq(Cat(
                    firstbe,
                    C(0, 4),
                    lastbe,
                    C(0, 4),
                    C(0, 20),
                    self.s_axis_tuser[3],
                    C(0, 100)
                )),
            ]
