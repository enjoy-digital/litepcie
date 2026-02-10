#
# This file is part of LitePCIe.
#
# Copyright (c) 2020-2026 Enjoy-Digital <enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

from migen import *

from litex.gen import *


class MAxisRCAdapter(LiteXModule):
    def __init__(self, data_width):
        assert data_width in [128, 256, 512]
        keep_width = data_width // 8

        # Raw RC AXIS from Xilinx hard IP/support wrapper.
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

        # # #

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
