#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2023 Florent Kermarrec <florent@enjoy-digital.fr>
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

# LitePCIeTLPHeaderInserter64b ---------------------------------------------------------------------

class LitePCIeTLPHeaderInserter64b3DWs(LiteXModule):
    def __init__(self):
        self.sink   = sink   = stream.Endpoint(tlp_raw_layout(64))
        self.source = source = stream.Endpoint(phy_layout(64))

        # # #

        count = Signal()
        dat   = Signal(64,    reset_less=True)
        be    = Signal(64//8, reset_less=True)
        last  = Signal(       reset_less=True)
        self.sync += [
            If(sink.valid & sink.ready,
                dat.eq(sink.dat),
                be.eq(sink.be),
                last.eq(sink.last)
            )
        ]

        self.fsm = fsm = FSM(reset_state="HEADER")
        fsm.act("HEADER",
            sink.ready.eq(1),
            If(sink.valid & sink.first,
                sink.ready.eq(0),
                source.valid.eq(1),
                source.first.eq((count == 0) & sink.first),
                source.last.eq( (count == 1) & sink.last & (sink.be[4*1:] == 0)),
                If(count == 0,
                    source.dat[32*0:32*1].eq(sink.header[32*0:]),
                    source.dat[32*1:32*2].eq(sink.header[32*1:]),
                    source.be[4*0:4*1].eq(0xf),
                    source.be[4*1:4*2].eq(0xf),
                ),
                If(count == 1,
                    source.dat[32*0:32*1].eq(sink.header[32*2:]),
                    source.dat[32*1:32*2].eq(sink.dat[32*0:]),
                    source.be[4*0:4*1].eq(0xf),
                    source.be[4*1:4*2].eq(sink.be[4*0:]),
                ),
                If(source.valid & source.ready,
                    NextValue(count, count + 1),
                    If(count == 1,
                        sink.ready.eq(1),
                        If(~source.last,
                            NextState("DATA")
                        )
                    )
                )
            )
        )
        fsm.act("DATA",
            source.valid.eq(sink.valid | last),
            source.last.eq(last),

            source.dat[32*0:32*1].eq(dat[32*1:]),
            source.dat[32*1:32*2].eq(sink.dat[32*0:]),

            source.be[4*0:4*1].eq(be[4*0:]),
            If(last,
                source.be[4*1:4*2].eq(0x0)
            ).Else(
                source.be[4*1:4*2].eq(sink.be[4*0:])
            ),

            If(source.valid & source.ready,
                sink.ready.eq(~last),
                If(source.last,
                    NextState("HEADER")
                )
            )
        )

class LitePCIeTLPHeaderInserter64b4DWs(LiteXModule):
    def __init__(self):
        self.sink   = sink   = stream.Endpoint(tlp_raw_layout(64))
        self.source = source = stream.Endpoint(phy_layout(64))

        # # #

        count = Signal()
        self.fsm = fsm = FSM(reset_state="HEADER")
        fsm.act("HEADER",
            sink.ready.eq(1),
            If(sink.valid & sink.first,
                sink.ready.eq(0),
                source.valid.eq(1),
                source.first.eq((count == 0) & sink.first),
                source.last.eq( (count == 1) & sink.last & (sink.be == 0)),
                If(count == 0,
                    source.dat[32*0:32*1].eq(sink.header[32*0:]),
                    source.dat[32*1:32*2].eq(sink.header[32*1:]),
                    source.be[4*0:4*1].eq(0xf),
                    source.be[4*1:4*2].eq(0xf),
                ),
                If(count == 1,
                    source.dat[32*0:32*1].eq(sink.header[32*2:]),
                    source.dat[32*1:32*2].eq(sink.header[32*3:]),
                    source.be[4*0:4*1].eq(0xf),
                    source.be[4*1:4*2].eq(0xf),
                ),
                If(source.valid & source.ready,
                    NextValue(count, count + 1),
                    If(count == 1,
                        sink.ready.eq(1),
                        If(~source.last,
                            sink.ready.eq(0),
                            NextState("DATA")
                        )
                    )
                )
            )
        )
        fsm.act("DATA",
            source.valid.eq(sink.valid),
            source.last.eq(sink.last),

            source.dat[32*0:32*1].eq(sink.dat[32*0:]),
            source.dat[32*1:32*2].eq(sink.dat[32*1:]),
            source.be[4*0:4*1].eq(sink.be[4*0:]),
            source.be[4*1:4*2].eq(sink.be[4*1:]),

            If(source.valid & source.ready,
                sink.ready.eq(1),
                If(source.last,
                    NextState("HEADER")
                )
            )
        )

class LitePCIeTLPHeaderInserter64b(LitePCIeTLPHeaderInserter3DWs4DWs):
    def __init__(self, fmt):
        LitePCIeTLPHeaderInserter3DWs4DWs.__init__(self,
            data_width               = 64,
            header_inserter_3dws_cls = LitePCIeTLPHeaderInserter64b3DWs,
            header_inserter_4dws_cls = LitePCIeTLPHeaderInserter64b4DWs,
            fmt                      = fmt,
        )

# LitePCIeTLPHeaderInserter128b --------------------------------------------------------------------

class LitePCIeTLPHeaderInserter128b3DWs(LiteXModule):
    def __init__(self):
        self.sink   = sink   = stream.Endpoint(tlp_raw_layout(128))
        self.source = source = stream.Endpoint(phy_layout(128))

        # # #

        dat  = Signal(128,    reset_less=True)
        be   = Signal(128//8, reset_less=True)
        last = Signal(        reset_less=True)
        self.sync += [
            If(sink.valid & sink.ready,
                dat.eq(sink.dat),
                be.eq(sink.be),
                last.eq(sink.last)
            )
        ]

        self.fsm = fsm = FSM(reset_state="HEADER")
        fsm.act("HEADER",
            sink.ready.eq(1),
            If(sink.valid & sink.first,
                sink.ready.eq(0),
                source.valid.eq(1),
                source.first.eq(1),
                source.last.eq(sink.last & (sink.be[4*1:] == 0)),

                source.dat[32*0:32*1].eq(sink.header[32*0:]),
                source.dat[32*1:32*2].eq(sink.header[32*1:]),
                source.dat[32*2:32*3].eq(sink.header[32*2:]),
                source.dat[32*3:32*4].eq(sink.dat[32*0:]),

                source.be[4*0:4*1].eq(0xf),
                source.be[4*1:4*2].eq(0xf),
                source.be[4*2:4*3].eq(0xf),
                source.be[4*3:4*4].eq(sink.be[0:]),

                If(source.valid & source.ready,
                    sink.ready.eq(1),
                    If(~source.last,
                        NextState("DATA"),
                    )
                )
            )
        )
        fsm.act("DATA",
            source.valid.eq(sink.valid | last),
            source.last.eq(last),

            source.dat[32*0:32*1].eq(dat[32*1:]),
            source.dat[32*1:32*2].eq(dat[32*2:]),
            source.dat[32*2:32*3].eq(dat[32*3:]),
            source.dat[32*3:32*4].eq(sink.dat[32*0:]),

            source.be[4*0:4*1].eq(be[1:]),
            source.be[4*1:4*2].eq(be[2:]),
            source.be[4*2:4*3].eq(be[3:]),
            If(last,
                source.be[4*3:4*4].eq(0x0)
            ).Else(
                source.be[4*3:4*4].eq(sink.be[0:])
            ),

            If(source.valid & source.ready,
                sink.ready.eq(~last),
                If(source.last,
                    NextState("HEADER")
                )
            )
        )

class LitePCIeTLPHeaderInserter128b4DWs(LiteXModule):
    def __init__(self):
        self.sink   = sink   = stream.Endpoint(tlp_raw_layout(128))
        self.source = source = stream.Endpoint(phy_layout(128))

        # # #

        self.fsm = fsm = FSM(reset_state="HEADER")
        fsm.act("HEADER",
            sink.ready.eq(1),
            If(sink.valid & sink.first,
                sink.ready.eq(0),
                source.valid.eq(1),
                source.first.eq(1),
                source.last.eq(sink.last & (sink.be == 0)),

                source.dat[32*0:32*1].eq(sink.header[32*0:]),
                source.dat[32*1:32*2].eq(sink.header[32*1:]),
                source.dat[32*2:32*3].eq(sink.header[32*2:]),
                source.dat[32*3:32*4].eq(sink.header[32*3:]),

                source.be[4*0:4*1].eq(0xf),
                source.be[4*1:4*2].eq(0xf),
                source.be[4*2:4*3].eq(0xf),
                source.be[4*3:4*4].eq(0xf),

                If(source.valid & source.ready,
                    sink.ready.eq(1),
                    If(~source.last,
                        sink.ready.eq(0),
                        NextState("DATA"),
                    )
                )
            )
        )
        fsm.act("DATA",
            source.valid.eq(sink.valid),
            source.last.eq(sink.last),

            source.dat[32*0:32*1].eq(sink.dat[32*0:]),
            source.dat[32*1:32*2].eq(sink.dat[32*1:]),
            source.dat[32*2:32*3].eq(sink.dat[32*2:]),
            source.dat[32*3:32*4].eq(sink.dat[32*3:]),

            source.be[4*0:4*1].eq(sink.be[4*0:]),
            source.be[4*1:4*2].eq(sink.be[4*1:]),
            source.be[4*2:4*3].eq(sink.be[4*2:]),
            source.be[4*3:4*4].eq(sink.be[4*3:]),

            If(source.valid & source.ready,
                sink.ready.eq(1),
                If(source.last,
                    NextState("HEADER")
                )
            )
        )

class LitePCIeTLPHeaderInserter128b(LitePCIeTLPHeaderInserter3DWs4DWs):
    def __init__(self, fmt):
        LitePCIeTLPHeaderInserter3DWs4DWs.__init__(self,
            data_width               = 128,
            header_inserter_3dws_cls = LitePCIeTLPHeaderInserter128b3DWs,
            header_inserter_4dws_cls = LitePCIeTLPHeaderInserter128b4DWs,
            fmt                      = fmt,
        )

# LitePCIeTLPHeaderInserter256b --------------------------------------------------------------------

class LitePCIeTLPHeaderInserter256b3DWs(LiteXModule):
    def __init__(self):
        self.sink   = sink   = stream.Endpoint(tlp_raw_layout(256))
        self.source = source = stream.Endpoint(phy_layout(256))

        # # #

        dat  = Signal(256,    reset_less=True)
        be   = Signal(256//8, reset_less=True)
        last = Signal(        reset_less=True)
        self.sync += [
            If(sink.valid & sink.ready,
                dat.eq(sink.dat),
                be.eq(sink.be),
                last.eq(sink.last)
            )
        ]

        self.fsm = fsm = FSM(reset_state="HEADER")
        fsm.act("HEADER",
            sink.ready.eq(1),
            If(sink.valid & sink.first,
                sink.ready.eq(0),
                source.valid.eq(1),
                source.first.eq(1),
                source.last.eq(sink.last & (sink.be[4*5:] == 0)),

                source.dat[32*0:32*1].eq(sink.header[32*0:]),
                source.dat[32*1:32*2].eq(sink.header[32*1:]),
                source.dat[32*2:32*3].eq(sink.header[32*2:]),
                source.dat[32*3:32*4].eq(sink.dat[32*0:]),
                source.dat[32*4:32*5].eq(sink.dat[32*1:]),
                source.dat[32*5:32*6].eq(sink.dat[32*2:]),
                source.dat[32*6:32*7].eq(sink.dat[32*3:]),
                source.dat[32*7:32*8].eq(sink.dat[32*4:]),

                source.be[4*0:4*1].eq(0xf),
                source.be[4*1:4*2].eq(0xf),
                source.be[4*2:4*3].eq(0xf),
                source.be[4*3:4*4].eq(sink.be[4*0:]),
                source.be[4*4:4*5].eq(sink.be[4*1:]),
                source.be[4*5:4*6].eq(sink.be[4*2:]),
                source.be[4*6:4*7].eq(sink.be[4*3:]),
                source.be[4*7:4*8].eq(sink.be[4*4:]),

                If(source.valid & source.ready,
                    sink.ready.eq(1),
                    If(~source.last,
                        NextState("DATA"),
                    )
                )
            )
        )
        fsm.act("DATA",
            source.valid.eq(sink.valid | last),
            source.last.eq(last),

            source.dat[32*0:32*1].eq(dat[32*5:]),
            source.dat[32*1:32*2].eq(dat[32*6:]),
            source.dat[32*2:32*3].eq(dat[32*7:]),
            source.dat[32*3:32*4].eq(sink.dat[32*0:]),
            source.dat[32*4:32*5].eq(sink.dat[32*1:]),
            source.dat[32*5:32*6].eq(sink.dat[32*2:]),
            source.dat[32*6:32*7].eq(sink.dat[32*3:]),
            source.dat[32*7:32*8].eq(sink.dat[32*4:]),

            source.be[4*0:4*1].eq(be[4*5:]),
            source.be[4*1:4*2].eq(be[4*6:]),
            source.be[4*2:4*3].eq(be[4*7:]),
            If(last,
                source.be[4*3:4*8].eq(0x0)
            ).Else(
                source.be[4*3:4*4].eq(sink.be[4*0:]),
                source.be[4*4:4*5].eq(sink.be[4*1:]),
                source.be[4*5:4*6].eq(sink.be[4*2:]),
                source.be[4*6:4*7].eq(sink.be[4*3:]),
                source.be[4*7:4*8].eq(sink.be[4*4:]),
            ),
            If(source.valid & source.ready,
                sink.ready.eq(~last),
                If(source.last,
                    NextState("HEADER")
                )
            )
        )

class LitePCIeTLPHeaderInserter256b4DWs(LiteXModule):
    def __init__(self):
        self.sink   = sink   = stream.Endpoint(tlp_raw_layout(256))
        self.source = source = stream.Endpoint(phy_layout(256))

        # # #

        dat  = Signal(256,    reset_less=True)
        be   = Signal(256//8, reset_less=True)
        last = Signal(        reset_less=True)
        self.sync += [
            If(sink.valid & sink.ready,
                dat.eq(sink.dat),
                be.eq(sink.be),
                last.eq(sink.last)
            )
        ]

        self.fsm = fsm = FSM(reset_state="HEADER")
        fsm.act("HEADER",
            sink.ready.eq(1),
            If(sink.valid & sink.first,
                sink.ready.eq(0),
                source.valid.eq(1),
                source.first.eq(1),
                source.last.eq(sink.last & (sink.be[4*4:] == 0)),

                source.dat[32*0:32*1].eq(sink.header[32*0:]),
                source.dat[32*1:32*2].eq(sink.header[32*1:]),
                source.dat[32*2:32*3].eq(sink.header[32*2:]),
                source.dat[32*3:32*4].eq(sink.header[32*3:]),
                source.dat[32*4:32*5].eq(sink.dat[32*0:]),
                source.dat[32*5:32*6].eq(sink.dat[32*1:]),
                source.dat[32*6:32*7].eq(sink.dat[32*2:]),
                source.dat[32*7:32*8].eq(sink.dat[32*3:]),

                source.be[4*0:4*1].eq(0xf),
                source.be[4*1:4*2].eq(0xf),
                source.be[4*2:4*3].eq(0xf),
                source.be[4*3:4*4].eq(0xf),
                source.be[4*4:4*5].eq(sink.be[4*0:]),
                source.be[4*5:4*6].eq(sink.be[4*1:]),
                source.be[4*6:4*7].eq(sink.be[4*2:]),
                source.be[4*7:4*8].eq(sink.be[4*3:]),

                If(source.valid & source.ready,
                    sink.ready.eq(1),
                    If(~source.last,
                        NextState("DATA"),
                    )
                )
            )
        )
        fsm.act("DATA",
            source.valid.eq(sink.valid | last),
            source.last.eq(last),

            source.dat[32*0:32*1].eq(dat[32*4:]),
            source.dat[32*1:32*2].eq(dat[32*5:]),
            source.dat[32*2:32*3].eq(dat[32*6:]),
            source.dat[32*3:32*4].eq(dat[32*7:]),
            source.dat[32*4:32*5].eq(sink.dat[32*0:]),
            source.dat[32*5:32*6].eq(sink.dat[32*1:]),
            source.dat[32*6:32*7].eq(sink.dat[32*2:]),
            source.dat[32*7:32*8].eq(sink.dat[32*3:]),

            source.be[4*0:4*1].eq(be[4*4:]),
            source.be[4*1:4*2].eq(be[4*5:]),
            source.be[4*2:4*3].eq(be[4*6:]),
            source.be[4*3:4*4].eq(be[4*7:]),
            If(last,
                source.be[4*4:4*8].eq(0x0)
            ).Else(
                source.be[4*4:4*5].eq(sink.be[4*0:]),
                source.be[4*5:4*6].eq(sink.be[4*1:]),
                source.be[4*6:4*7].eq(sink.be[4*2:]),
                source.be[4*7:4*8].eq(sink.be[4*3:]),
            ),
            If(source.valid & source.ready,
                sink.ready.eq(~last),
                If(source.last,
                    NextState("HEADER")
                )
            )
        )

class LitePCIeTLPHeaderInserter256b(LitePCIeTLPHeaderInserter3DWs4DWs):
    def __init__(self, fmt):
        LitePCIeTLPHeaderInserter3DWs4DWs.__init__(self,
            data_width               = 256,
            header_inserter_3dws_cls = LitePCIeTLPHeaderInserter256b3DWs,
            header_inserter_4dws_cls = LitePCIeTLPHeaderInserter256b4DWs,
            fmt                      = fmt,
        )

# LitePCIeTLPHeaderInserter512b --------------------------------------------------------------------

class LitePCIeTLPHeaderInserter512b3DWs(LiteXModule):
    def __init__(self):
        self.sink   = sink   = stream.Endpoint(tlp_raw_layout(512))
        self.source = source = stream.Endpoint(phy_layout(512))

        # # #

        dat  = Signal(512,    reset_less=True)
        be   = Signal(512//8, reset_less=True)
        last = Signal(        reset_less=True)
        self.sync += [
            If(sink.valid & sink.ready,
                dat.eq(sink.dat),
                be.eq(sink.be),
                last.eq(sink.last)
            )
        ]

        self.fsm = fsm = FSM(reset_state="HEADER")
        fsm.act("HEADER",
            sink.ready.eq(1),
            If(sink.valid & sink.first,
                sink.ready.eq(0),
                source.valid.eq(1),
                source.first.eq(1),
                source.last.eq(sink.last & (sink.be[4*13:] == 0)),

                source.dat[32* 0:32* 1].eq(sink.header[32*0:]),
                source.dat[32* 1:32* 2].eq(sink.header[32*1:]),
                source.dat[32* 2:32* 3].eq(sink.header[32*2:]),
                source.dat[32* 3:32* 4].eq(sink.dat[32* 0:]),
                source.dat[32* 4:32* 5].eq(sink.dat[32* 1:]),
                source.dat[32* 5:32* 6].eq(sink.dat[32* 2:]),
                source.dat[32* 6:32* 7].eq(sink.dat[32* 3:]),
                source.dat[32* 7:32* 8].eq(sink.dat[32* 4:]),
                source.dat[32* 8:32* 9].eq(sink.dat[32* 5:]),
                source.dat[32* 9:32*10].eq(sink.dat[32* 6:]),
                source.dat[32*10:32*11].eq(sink.dat[32* 7:]),
                source.dat[32*11:32*12].eq(sink.dat[32* 8:]),
                source.dat[32*12:32*13].eq(sink.dat[32* 9:]),
                source.dat[32*13:32*14].eq(sink.dat[32*10:]),
                source.dat[32*14:32*15].eq(sink.dat[32*11:]),
                source.dat[32*15:32*16].eq(sink.dat[32*12:]),

                source.be[4* 0:4* 1].eq(0xf),
                source.be[4* 1:4* 2].eq(0xf),
                source.be[4* 2:4* 3].eq(0xf),
                source.be[4* 3:4* 4].eq(sink.be[4* 0:]),
                source.be[4* 4:4* 5].eq(sink.be[4* 1:]),
                source.be[4* 5:4* 6].eq(sink.be[4* 2:]),
                source.be[4* 6:4* 7].eq(sink.be[4* 3:]),
                source.be[4* 7:4* 8].eq(sink.be[4* 4:]),
                source.be[4* 8:4* 9].eq(sink.be[4* 5:]),
                source.be[4* 9:4*10].eq(sink.be[4* 6:]),
                source.be[4*10:4*11].eq(sink.be[4* 7:]),
                source.be[4*11:4*12].eq(sink.be[4* 8:]),
                source.be[4*12:4*13].eq(sink.be[4* 9:]),
                source.be[4*13:4*14].eq(sink.be[4*10:]),
                source.be[4*14:4*15].eq(sink.be[4*11:]),
                source.be[4*15:4*16].eq(sink.be[4*12:]),

                If(source.valid & source.ready,
                    sink.ready.eq(1),
                    If(~source.last,
                        NextState("DATA"),
                    )
                )
            )
        )
        fsm.act("DATA",
            source.valid.eq(sink.valid | last),
            source.last.eq(last),

            source.dat[32* 0:32* 1].eq(     dat[32*13:]),
            source.dat[32* 1:32* 2].eq(     dat[32*14:]),
            source.dat[32* 2:32* 3].eq(     dat[32*15:]),
            source.dat[32* 3:32* 4].eq(sink.dat[32* 0:]),
            source.dat[32* 4:32* 5].eq(sink.dat[32* 1:]),
            source.dat[32* 5:32* 6].eq(sink.dat[32* 2:]),
            source.dat[32* 6:32* 7].eq(sink.dat[32* 3:]),
            source.dat[32* 7:32* 8].eq(sink.dat[32* 4:]),
            source.dat[32* 8:32* 9].eq(sink.dat[32* 5:]),
            source.dat[32* 9:32*10].eq(sink.dat[32* 6:]),
            source.dat[32*10:32*11].eq(sink.dat[32* 7:]),
            source.dat[32*11:32*12].eq(sink.dat[32* 8:]),
            source.dat[32*12:32*13].eq(sink.dat[32* 9:]),
            source.dat[32*13:32*14].eq(sink.dat[32*10:]),
            source.dat[32*14:32*15].eq(sink.dat[32*11:]),
            source.dat[32*15:32*16].eq(sink.dat[32*12:]),

            source.be[4*0:4*1].eq(be[4*13:]),
            source.be[4*1:4*2].eq(be[4*14:]),
            source.be[4*2:4*3].eq(be[4*15:]),
            If(last,
                source.be[4*3:4*16].eq(0x0)
            ).Else(
                source.be[4* 3:4* 4].eq(sink.be[4* 0:]),
                source.be[4* 4:4* 5].eq(sink.be[4* 1:]),
                source.be[4* 5:4* 6].eq(sink.be[4* 2:]),
                source.be[4* 6:4* 7].eq(sink.be[4* 3:]),
                source.be[4* 7:4* 8].eq(sink.be[4* 4:]),
                source.be[4* 8:4* 9].eq(sink.be[4* 5:]),
                source.be[4* 9:4*10].eq(sink.be[4* 6:]),
                source.be[4*10:4*11].eq(sink.be[4* 7:]),
                source.be[4*11:4*12].eq(sink.be[4* 8:]),
                source.be[4*12:4*13].eq(sink.be[4* 9:]),
                source.be[4*13:4*14].eq(sink.be[4*10:]),
                source.be[4*14:4*15].eq(sink.be[4*11:]),
                source.be[4*15:4*16].eq(sink.be[4*12:]),
            ),
            If(source.valid & source.ready,
                sink.ready.eq(~last),
                If(source.last,
                    NextState("HEADER")
                )
            )
        )

class LitePCIeTLPHeaderInserter512b4DWs(LiteXModule):
    def __init__(self):
        self.sink   = sink   = stream.Endpoint(tlp_raw_layout(512))
        self.source = source = stream.Endpoint(phy_layout(512))

        # # #

        dat  = Signal(512,    reset_less=True)
        be   = Signal(512//8, reset_less=True)
        last = Signal(        reset_less=True)
        self.sync += [
            If(sink.valid & sink.ready,
                dat.eq(sink.dat),
                be.eq(sink.be),
                last.eq(sink.last)
            )
        ]

        self.fsm = fsm = FSM(reset_state="HEADER")
        fsm.act("HEADER",
            sink.ready.eq(1),
            If(sink.valid & sink.first,
                sink.ready.eq(0),
                source.valid.eq(1),
                source.first.eq(1),
                source.last.eq(sink.last & (sink.be[4*12:] == 0)),

                source.dat[32* 0:32* 1].eq(sink.header[32*0:]),
                source.dat[32* 1:32* 2].eq(sink.header[32*1:]),
                source.dat[32* 2:32* 3].eq(sink.header[32*2:]),
                source.dat[32* 3:32* 4].eq(sink.header[32*3:]),
                source.dat[32* 4:32* 5].eq(sink.dat[32* 0:]),
                source.dat[32* 5:32* 6].eq(sink.dat[32* 1:]),
                source.dat[32* 6:32* 7].eq(sink.dat[32* 2:]),
                source.dat[32* 7:32* 8].eq(sink.dat[32* 3:]),
                source.dat[32* 8:32* 9].eq(sink.dat[32* 4:]),
                source.dat[32* 9:32*10].eq(sink.dat[32* 5:]),
                source.dat[32*10:32*11].eq(sink.dat[32* 6:]),
                source.dat[32*11:32*12].eq(sink.dat[32* 7:]),
                source.dat[32*12:32*13].eq(sink.dat[32* 8:]),
                source.dat[32*13:32*14].eq(sink.dat[32* 9:]),
                source.dat[32*14:32*15].eq(sink.dat[32*10:]),
                source.dat[32*15:32*16].eq(sink.dat[32*11:]),

                source.be[4* 0:4* 1].eq(0xf),
                source.be[4* 1:4* 2].eq(0xf),
                source.be[4* 2:4* 3].eq(0xf),
                source.be[4* 3:4* 4].eq(0xf),
                source.be[4* 4:4* 5].eq(sink.be[4* 0:]),
                source.be[4* 5:4* 6].eq(sink.be[4* 1:]),
                source.be[4* 6:4* 7].eq(sink.be[4* 2:]),
                source.be[4* 7:4* 8].eq(sink.be[4* 3:]),
                source.be[4* 8:4* 9].eq(sink.be[4* 4:]),
                source.be[4* 9:4*10].eq(sink.be[4* 5:]),
                source.be[4*10:4*11].eq(sink.be[4* 6:]),
                source.be[4*11:4*12].eq(sink.be[4* 7:]),
                source.be[4*12:4*13].eq(sink.be[4* 8:]),
                source.be[4*13:4*14].eq(sink.be[4* 9:]),
                source.be[4*14:4*15].eq(sink.be[4*10:]),
                source.be[4*15:4*16].eq(sink.be[4*11:]),

                If(source.valid & source.ready,
                    sink.ready.eq(1),
                    If(~source.last,
                        NextState("DATA"),
                    )
                )
            )
        )
        fsm.act("DATA",
            source.valid.eq(sink.valid | last),
            source.last.eq(last),

            source.dat[32* 0:32* 1].eq(     dat[32*12:]),
            source.dat[32* 1:32* 2].eq(     dat[32*13:]),
            source.dat[32* 2:32* 3].eq(     dat[32*14:]),
            source.dat[32* 3:32* 4].eq(     dat[32*15:]),
            source.dat[32* 4:32* 5].eq(sink.dat[32* 0:]),
            source.dat[32* 5:32* 6].eq(sink.dat[32* 1:]),
            source.dat[32* 6:32* 7].eq(sink.dat[32* 2:]),
            source.dat[32* 7:32* 8].eq(sink.dat[32* 3:]),
            source.dat[32* 8:32* 9].eq(sink.dat[32* 4:]),
            source.dat[32* 9:32*10].eq(sink.dat[32* 5:]),
            source.dat[32*10:32*11].eq(sink.dat[32* 6:]),
            source.dat[32*11:32*12].eq(sink.dat[32* 7:]),
            source.dat[32*12:32*13].eq(sink.dat[32* 8:]),
            source.dat[32*13:32*14].eq(sink.dat[32* 9:]),
            source.dat[32*14:32*15].eq(sink.dat[32*10:]),
            source.dat[32*15:32*16].eq(sink.dat[32*11:]),

            source.be[4*0:4*1].eq(be[4*12:]),
            source.be[4*1:4*2].eq(be[4*13:]),
            source.be[4*2:4*3].eq(be[4*14:]),
            source.be[4*3:4*4].eq(be[4*15:]),

            If(last,
                source.be[4*4:4*16].eq(0x0)
            ).Else(
                source.be[ 4*4: 4*5].eq(sink.be[4* 0:]),
                source.be[ 4*5: 4*6].eq(sink.be[4* 1:]),
                source.be[ 4*6: 4*7].eq(sink.be[4* 2:]),
                source.be[ 4*7: 4*8].eq(sink.be[4* 3:]),
                source.be[ 4*8: 4*9].eq(sink.be[4* 4:]),
                source.be[ 4*9:4*10].eq(sink.be[4* 5:]),
                source.be[4*10:4*11].eq(sink.be[4* 6:]),
                source.be[4*11:4*12].eq(sink.be[4* 7:]),
                source.be[4*12:4*13].eq(sink.be[4* 8:]),
                source.be[4*13:4*14].eq(sink.be[4* 9:]),
                source.be[4*14:4*15].eq(sink.be[4*10:]),
                source.be[4*15:4*16].eq(sink.be[4*11:]),
            ),
            If(source.valid & source.ready,
                sink.ready.eq(~last),
                If(source.last,
                    NextState("HEADER")
                )
            )
        )

class LitePCIeTLPHeaderInserter512b(LitePCIeTLPHeaderInserter3DWs4DWs):
    def __init__(self, fmt):
        LitePCIeTLPHeaderInserter3DWs4DWs.__init__(self,
            data_width               = 512,
            header_inserter_3dws_cls = LitePCIeTLPHeaderInserter512b3DWs,
            header_inserter_4dws_cls = LitePCIeTLPHeaderInserter512b4DWs,
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
