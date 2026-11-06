#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY lane transceivers on Xilinx 7-Series GTX (Kintex-7), through LiteICLink: one Channel PLL
per lane as the Xilinx wrapper at 2.5/5.0 GT/s (the GTX Quad PLL VCO does not go down to 2.5 GHz), LPM
receive equalizer, see S7PCIeSerDes."""

from migen import *

from litex.gen import *

from litepcie.phy.soft.serdes.s7 import S7PCIeSerDes

# Constants ----------------------------------------------------------------------------------------

# RXCDR_CFG for a common reference clock (Xilinx 7-Series PCIe GTX wrapper, GES silicon).
GTX_PCIE_RXCDR_CFG = 0x03000023FF10200020

# K7 PCIe SerDes -----------------------------------------------------------------------------------

class K7PCIeSerDes(S7PCIeSerDes):
    def add_pll(self, refclk, refclk_freq):
        self.refclk      = refclk
        self.refclk_freq = refclk_freq

    def add_gt(self, i, pll, tx_pads, rx_pads, sys_clk_freq):
        from liteiclink.serdes.gtx_7series import GTXChannelPLL, GTX
        cpll = GTXChannelPLL(self.refclk, self.refclk_freq, 2.5e9)
        setattr(self, f"cpll{i}", cpll)
        return GTX(cpll, tx_pads, rx_pads, sys_clk_freq,
            tx_clk           = ClockSignal("pcie_pipe"),
            data_width       = 40,
            tx_buffer_enable = True,
            rx_buffer_enable = True,
            clock_aligner    = False,
        )

    def gt_params(self, rxcdr_cfg):
        return dict(
            # OOB/Electrical Idle detection power-up, external OOB clock, filter stale TX data when
            # exiting Electrical Idle.
            p_PCS_RSVD_ATTR              = 0x000000000188,
            p_RX_SIG_VALID_DLY           = 4,
            i_CLKRSVD                    = Cat(ClockSignal("pcie_oob"), Constant(0, 3)),
            p_RXCDR_CFG                  = GTX_PCIE_RXCDR_CFG if rxcdr_cfg is None else rxcdr_cfg,
            p_CPLL_CFG                   = 0xA407CC,
            p_PMA_RSV                    = 0x00018480,
            p_RX_DFE_KL_CFG2             = 0x3290D86C,
            p_RX_DFE_LPM_HOLD_DURING_EIDLE = 0b1,
            p_TX_RXDETECT_CFG            = 100, # 100 MHz reference clock.
            i_RXLPMEN                    = 1,
            i_RXDFEXYDEN                 = 0,
        )

    def gt_update_params(self, gt, params):
        gt.gtx_params.update(params)
