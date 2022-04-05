#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2020 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

from migen import *
from migen.genlib.cdc import MultiReg

from litepcie.common import *

# TX Datapath --------------------------------------------------------------------------------------

class PHYTXDatapath(Module):
    def __init__(self, core_data_width, pcie_data_width, clock_domain):
        self.sink   = sink   = stream.Endpoint(phy_layout(core_data_width))
        self.source = source = stream.Endpoint(phy_layout(pcie_data_width))

        # # #

        if (clock_domain == "pcie") and (core_data_width == pcie_data_width):
            self.comb += sink.connect(source)
        else:
            pipe_valid = stream.PipeValid(phy_layout(core_data_width))
            pipe_valid = ClockDomainsRenamer(clock_domain)(pipe_valid)
            cdc        = stream.ClockDomainCrossing(
                layout          = phy_layout(core_data_width),
                cd_from         = clock_domain,
                cd_to           = "pcie",
                with_common_rst = True,
            )
            converter  = stream.StrideConverter(phy_layout(core_data_width), phy_layout(pcie_data_width))
            converter  = ClockDomainsRenamer("pcie")(converter)
            pipe_ready = stream.PipeReady(phy_layout(pcie_data_width))
            pipe_ready = ClockDomainsRenamer("pcie")(pipe_ready)
            self.submodules += pipe_valid, cdc, converter, pipe_ready
            self.comb += [
                sink.connect(pipe_valid.sink),
                pipe_valid.source.connect(cdc.sink),
                cdc.source.connect(converter.sink),
                converter.source.connect(pipe_ready.sink),
                pipe_ready.source.connect(source),
            ]

# PHYRX128BAligner ---------------------------------------------------------------------------------

class PHYRX128BAligner(Module):
    def __init__(self):
        self.sink   = sink   = stream.Endpoint(phy_layout(128))
        self.source = source = stream.Endpoint(phy_layout(128))
        self.first_dword = Signal(2)

        # # #

        dat_last = Signal(64, reset_less=True)
        be_last  = Signal(8,  reset_less=True)
        self.sync += [
            If(sink.valid & sink.ready,
                dat_last.eq(sink.dat[64:]),
                be_last.eq( sink.be[8:]),
            )
        ]

        self.submodules.fsm = fsm = FSM(reset_state="ALIGNED")
        fsm.act("ALIGNED",
            sink.connect(source, omit={"first"}),
            # If "first" on DWORD2 and "last" on the same cycle, switch to UNALIGNED.
            If(sink.valid & sink.last & sink.first & (self.first_dword == 2),
                source.be[8:].eq(0),
                If(source.ready,
                    NextState("UNALIGNED")
                )
            )
        )
        fsm.act("UNALIGNED",
            sink.connect(source, omit={"first", "dat", "be"}),
            source.dat.eq(Cat(dat_last, sink.dat)),
            source.be.eq( Cat(be_last,  sink.be)),
            # If "last" and not "first" on the same cycle, switch to ALIGNED.
            If(sink.valid & sink.last & ~sink.first,
                source.be[8:].eq(0),
                If(source.ready,
                    NextState("ALIGNED")
                )
            )
        )

# RX Datapath --------------------------------------------------------------------------------------

class PHYRXDatapath(Module):
    def __init__(self, core_data_width, pcie_data_width, clock_domain, with_aligner=False):
        self.sink   = sink   = stream.Endpoint(phy_layout(pcie_data_width))
        self.source = source = stream.Endpoint(phy_layout(core_data_width))

        # # #

        if (pcie_data_width == 128) and with_aligner:
            aligner = PHYRX128BAligner()
            aligner = ClockDomainsRenamer("pcie")(aligner)
            self.submodules.aligner = aligner
            self.comb += sink.connect(aligner.sink)
            sink = aligner.source

        if (clock_domain == "pcie") and (core_data_width == pcie_data_width):
            self.comb += sink.connect(source)
        else:
            pipe_ready = stream.PipeReady(phy_layout(core_data_width))
            pipe_ready = ClockDomainsRenamer("pcie")(pipe_ready)
            converter  = stream.StrideConverter(phy_layout(pcie_data_width), phy_layout(core_data_width))
            converter  = ClockDomainsRenamer("pcie")(converter)
            cdc        = stream.ClockDomainCrossing(
                layout          = phy_layout(core_data_width),
                cd_from         = "pcie",
                cd_to           = clock_domain,
                with_common_rst = True
            )
            pipe_valid = stream.PipeValid(phy_layout(core_data_width))
            pipe_valid = ClockDomainsRenamer(clock_domain)(pipe_valid)
            self.submodules += pipe_ready, converter, cdc, pipe_valid
            self.comb += [
                sink.connect(pipe_ready.sink),
                pipe_ready.source.connect(converter.sink),
                converter.source.connect(cdc.sink),
                cdc.source.connect(pipe_valid.sink),
                pipe_valid.source.connect(source),
            ]

# LTSSMTracer --------------------------------------------------------------------------------------

class LTSSMTracer(Module, AutoCSR):
    def __init__(self, ltssm):
        self._history = CSRStatus(description="History of LTSSM states",
            fields = [
                CSRField("new",   offset= 0, size=6, description="New LTSSM state"),
                CSRField("old",   offset= 6, size=6, description="Old LTSSM state"),
                CSRField("ovfl",  offset=30, size=1, description="Overflow"),
                CSRField("valid", offset=31, size=1, description="Is data valid"),
        ])

        # The ltssm state signal input is sampled in the sys domain just using a MultiReg. This means
        # on change we could have an invalid state during 1 cycle.
        #
        # We also don't use an AsyncFIFO because the pcie clock domain is held in reset most of the
        # LTSSM initial negotiation defeating the point of this module.

        fifo = stream.SyncFIFO([("new", 6), ("old", 6), ("ovfl", 1)], 128)
        self.submodules += fifo

        ltssm_cur = Signal(6)
        ltssm_d1  = Signal(6)
        ltssm_d2  = Signal(6)

        overflow  = Signal()
        change    = Signal()

        self.sync += [
            ltssm_d1.eq(ltssm_cur),
            If(fifo.sink.ready, ltssm_d2.eq(ltssm_d1)),
            change.eq((ltssm_cur != ltssm_d1) & ~change),
            overflow.eq((overflow | change) & ~fifo.sink.ready),
        ]

        self.comb += [
            ltssm_cur.eq(ltssm),
            fifo.sink.new.eq(ltssm_cur),
            fifo.sink.old.eq(ltssm_d2),
            fifo.sink.ovfl.eq(overflow),
            fifo.sink.valid.eq(overflow | change),
            self._history.fields.new.eq(fifo.source.new),
            self._history.fields.old.eq(fifo.source.old),
            self._history.fields.ovfl.eq(fifo.source.ovfl),
            self._history.fields.valid.eq(fifo.source.valid),
            fifo.source.ready.eq(self._history.we),
        ]
