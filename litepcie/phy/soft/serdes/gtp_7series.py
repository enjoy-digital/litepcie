#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY lane transceivers on Xilinx 7-Series GTP (Artix-7), through LiteICLink: one GTP Quad PLL
shared by the lanes, see S7PCIeSerDes."""

from migen import *

from litex.gen import *

from litepcie.phy.soft.serdes.s7 import S7PCIeSerDes

# Constants ----------------------------------------------------------------------------------------

# RXCDR_CFG for a common reference clock (Xilinx 7-Series PCIe GTP wrapper, both rates); the
# asynchronous reference clock variant (+/-300 ppm) is 0x000107FE406021041010.
GTP_PCIE_RXCDR_CFG = 0x000107FE406001041010

# A7 PCIe SerDes -----------------------------------------------------------------------------------

class A7PCIeSerDes(S7PCIeSerDes):
    def add_pll(self, refclk, refclk_freq):
        from liteiclink.serdes.gtp_7series import GTPQuadPLL
        self.qpll = GTPQuadPLL(refclk, refclk_freq, 2.5e9)
        return self.qpll

    def add_gt(self, i, pll, tx_pads, rx_pads, sys_clk_freq):
        from liteiclink.serdes.gtp_7series import GTP
        return GTP(pll, tx_pads, rx_pads, sys_clk_freq,
            qpll_reset       = (i == 0),
            tx_clk           = ClockSignal("pcie_pipe"),
            data_width       = 40,
            tx_buffer_enable = True,
            rx_buffer_enable = True,
            clock_aligner    = False,
        )

    def gt_params(self, rxcdr_cfg):
        return dict(
            p_PCS_RSVD_ATTR           = 0x000000000100, # OOB/Electrical Idle detection power-up.
            p_RXOOB_CLK_CFG           = "FABRIC",
            i_SIGVALIDCLK             = ClockSignal("pcie_oob"),
            p_RXCDR_CFG               = GTP_PCIE_RXCDR_CFG if rxcdr_cfg is None else rxcdr_cfg,
            p_RXLPM_HOLD_DURING_EIDLE = 0b1,
            p_RXLPM_INCM_CFG          = 0b1,
            p_RXLPM_IPCM_CFG          = 0b0,
            p_RX_CM_TRIM              = 0b1010, # 800 mV.
            p_TXOOB_CFG               = 0b1, # Filter stale TX data when exiting Electrical Idle.
        )

    def gt_update_params(self, gt, params):
        gt.gtp_params.update(params)
