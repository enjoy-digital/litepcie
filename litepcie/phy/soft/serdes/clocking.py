#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY clocking on Xilinx 7-Series.

The 100 MHz PCIe reference clock from the slot feeds the transceivers PLL (IBUFDS_GTE2) and, through
the buffer's divided output, an MMCM generating the fixed clocks ("pcie_link" 125 MHz, "pcie_oob"
50 MHz for the Electrical Idle detection) and the two lane clocks (62.5 MHz for 2.5 GT/s, 125 MHz for
5.0 GT/s) switched by a glitch-free BUFGCTRL into "pcie_pipe" with the rate. The lane clock domain is
held in reset across a rate switch. Using the reference clock (common clock architecture) keeps the
lane clock frequency-locked to the transceivers (TX buffers enabled) and tracks the host's spread
spectrum.
"""

from migen import *
from migen.genlib.resetsync import AsyncResetSynchronizer

from litex.gen import *

from litex.soc.cores.clock import S7MMCM

# S7 PCIe Clocking ---------------------------------------------------------------------------------

class S7PCIeClocking(LiteXModule):
    def __init__(self, refclk_p, refclk_n, refclk_freq=100e6, reset=0, speedgrade=-1):
        self.refclk       = Signal()      # o: transceivers reference clock (GTREFCLK).
        self.rate         = Signal()      # i ("pcie_link"): 0: 2.5 GT/s, 1: 5.0 GT/s.
        self.locked       = Signal()      # o
        self.cd_pcie_link = ClockDomain() # 125 MHz.
        self.cd_pcie_oob  = ClockDomain() # 50 MHz.
        self.cd_pcie_pipe = ClockDomain() # 62.5/125 MHz (rate).

        # # #

        assert refclk_freq == 100e6

        # Reference clock buffer: O to the transceivers, ODIV2 (50 MHz) to the fabric.
        refclk_div2      = Signal()
        refclk_div2_bufg = Signal()
        self.specials += [
            Instance("IBUFDS_GTE2",
                i_CEB   = 0,
                i_I     = refclk_p,
                i_IB    = refclk_n,
                o_O     = self.refclk,
                o_ODIV2 = refclk_div2,
            ),
            Instance("BUFG", i_I=refclk_div2, o_O=refclk_div2_bufg),
        ]

        # MMCM.
        self.cd_pcie_pipe_gen1 = ClockDomain() # 62.5 MHz (unbuffered MMCM output).
        self.cd_pcie_pipe_gen2 = ClockDomain() # 125 MHz (unbuffered MMCM output).
        self.mmcm = mmcm = S7MMCM(speedgrade=speedgrade)
        self.comb += mmcm.reset.eq(reset)
        mmcm.register_clkin(refclk_div2_bufg, refclk_freq/2)
        mmcm.create_clkout(self.cd_pcie_link,      125e6, with_reset=False)
        mmcm.create_clkout(self.cd_pcie_oob,        50e6)
        mmcm.create_clkout(self.cd_pcie_pipe_gen1, 62.5e6, buf=None, with_reset=False)
        mmcm.create_clkout(self.cd_pcie_pipe_gen2,  125e6, buf=None, with_reset=False)
        self.comb += self.locked.eq(mmcm.locked)

        # Lane clock selection: held in reset while switching.
        sel       = Signal()
        count     = Signal(5)
        switching = Signal()
        self.sync.pcie_link += [
            If(sel != self.rate,
                sel.eq(self.rate),
                count.eq(31),
            ).Elif(count != 0,
                count.eq(count - 1)
            )
        ]
        self.comb += switching.eq((sel != self.rate) | (count != 0))
        self.specials += [
            Instance("BUFGCTRL",
                i_I0      = self.cd_pcie_pipe_gen1.clk,
                i_I1      = self.cd_pcie_pipe_gen2.clk,
                i_S0      = ~sel,
                i_S1      =  sel,
                i_CE0     = 1,
                i_CE1     = 1,
                i_IGNORE0 = 0,
                i_IGNORE1 = 0,
                o_O       = self.cd_pcie_pipe.clk,
            ),
        ]

        # Resets: synchronizer then a register driving the domain's large fanout, so that the
        # synchronizer's flip-flops stay together (metastability resolution, 2 ns maximum delay).
        def add_reset(cd, name, rst):
            cd_rst = ClockDomain(name)
            setattr(self, "cd_" + name, cd_rst)
            rst_r  = Signal(reset=1)
            self.comb += [
                cd_rst.clk.eq(cd.clk),
                cd.rst.eq(rst_r),
            ]
            self.specials += AsyncResetSynchronizer(cd_rst, rst)
            sync = getattr(self.sync, name)
            sync += rst_r.eq(0)
        add_reset(self.cd_pcie_link, "pcie_link_rst", ~mmcm.locked)
        add_reset(self.cd_pcie_pipe, "pcie_pipe_rst", ~mmcm.locked | switching)
