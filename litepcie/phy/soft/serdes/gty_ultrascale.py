#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY lane transceivers on Xilinx UltraScale+ GTY, through LiteICLink: Quad PLL0 at 10 GHz shared
by the lanes of a quad (2.5 GT/s with output divider 4, 5.0 GT/s with TXRATE/RXRATE selecting divider 2), 40-bit
raw interface with 8b/10b in the fabric, see S7PCIeSerDes. PCIe attributes from the Xilinx UltraScale+ PCIe GTY
wrapper (same PLL frequency), with the PCS PCIe mode off: the datapaths, rate and Electrical Idle are handled
by the soft PHY as on 7-Series."""

from migen import *

from litex.gen import *

from litepcie.phy.soft.serdes.s7       import S7PCIeSerDes
from litepcie.phy.soft.serdes.clocking import S7PCIeClocking

# USP PCIe SerDes ----------------------------------------------------------------------------------

class USPPCIeSerDes(S7PCIeSerDes):
    def add_clocking(self, pads, refclk_freq, speedgrade, gen3):
        assert not gen3, "8.0 GT/s: not yet on UltraScale+."
        return S7PCIeClocking(pads.clk_p, pads.clk_n, refclk_freq, reset=self.perst, speedgrade=speedgrade,
            usp=True)

    def add_pll(self, refclk, refclk_freq):
        from liteiclink.serdes.gty_ultrascale import GTYQuadPLL
        # One Quad PLL0 per quad (lanes 4*q to 4*q + 3).
        self.qplls = [GTYQuadPLL(refclk, refclk_freq, 2.5e9, qpll="qpll0") for _ in range((self.nlanes + 3)//4)]
        for q, qpll in enumerate(self.qplls):
            setattr(self, f"qpll{q}", qpll)
        return self.qplls

    def add_gt(self, i, pll, tx_pads, rx_pads, sys_clk_freq):
        from liteiclink.serdes.gty_ultrascale import GTY
        return GTY(pll[i//4], tx_pads, rx_pads, sys_clk_freq,
            tx_clk           = ClockSignal(self.gt_tx_cd),
            data_width       = 40,
            tx_buffer_enable = True,
            rx_buffer_enable = True,
            clock_aligner    = False,
            pll_master       = (i%4 == 0),
        )

    def pcie_gt_params(self, lane, rx_elecidle, pcs_pcie_en):
        return dict(
            # Comma alignment on any byte: Ordered Sets at any Symbol position (word phase kept).
            p_ALIGN_COMMA_WORD = 1,
            # PIPE drive mode: TX_DEEMPH0/1 are the -6/-3.5 dB de-emphasis selected by TXDEEMPH, swing from
            # TX_MARGIN_FULL_0.
            p_TX_DRIVE_MODE    = "PIPE",
            p_TX_DEEMPH0       = 0b010100,
            p_TX_DEEMPH1       = 0b001101,
            p_TX_MARGIN_FULL_0 = 0b1011000,
            p_TX_MARGIN_FULL_1 = 0b1010111,
            p_TX_MARGIN_FULL_2 = 0b1010101,
            p_TX_MARGIN_FULL_3 = 0b1010011,
            p_TX_MARGIN_FULL_4 = 0b1010001,
            p_TX_MARGIN_LOW_0  = 0b1001100,
            p_TX_MARGIN_LOW_1  = 0b1001011,
            p_TX_MARGIN_LOW_2  = 0b1001000,
            p_TX_MARGIN_LOW_3  = 0b1000010,
            p_TX_MARGIN_LOW_4  = 0b1000000,
            i_TXDEEMPH         = Cat(lane.tx_deemph, Constant(0, 1)),
            i_TXMARGIN         = 0b000,
            i_TXSWING          = 0,
            i_TXDIFFCTRL       = 0b11111,
            # Electrical Idle: TX, and RX detection (OOB on the PMA clock).
            i_RXELECIDLEMODE   = 0b00,
            o_RXELECIDLE       = rx_elecidle,
            i_TXELECIDLE       = lane.tx_elecidle,
            p_OOB_PWRUP        = 0b1,
            p_OOBDIVCTL        = 0b01,
            p_RXOOB_CLK_CFG    = "PMA",
            p_RXOOB_CFG        = 0b000000110,
            p_RXELECIDLE_CFG   = "SIGCFG_1",
            p_RX_SIG_VALID_DLY = 4,
            # PCIe attributes (Xilinx UltraScale+ PCIe GTY wrapper).
            p_RX_CLK25_DIV               = 4, # 100 MHz reference clock.
            p_TX_CLK25_DIV               = 4,
            p_PCS_PCIE_EN                = "TRUE" if pcs_pcie_en else "FALSE",
            p_RXCDR_CFG0                 = 0x0002,
            p_RXCDR_CFG1                 = 0x0000,
            p_RXCDR_CFG2                 = 0x0249,
            p_RXCDR_CFG3                 = 0x0012,
            p_RXCDR_CFG4                 = 0x5cf6,
            p_RXCDR_CFG5                 = 0xb46b,
            p_RXCDR_LOCK_CFG0            = 0x2201,
            p_RXCDR_LOCK_CFG1            = 0x9fff,
            p_RXCDR_LOCK_CFG2            = 0x0000,
            p_RXCDR_HOLD_DURING_EIDLE    = 0b0,
            p_RX_DFE_LPM_HOLD_DURING_EIDLE = 0b0,
            p_RX_CM_SEL                  = 0b11, # Programmable common mode.
            p_RX_CM_TRIM                 = 10,
            p_RXBUF_ADDR_MODE            = "FULL",
            p_RXBUF_EIDLE_HI_CNT         = 0b0100,
            p_RXBUF_EIDLE_LO_CNT         = 0b0000,
            p_RXBUF_RESET_ON_EIDLE       = "TRUE",
            p_RXBUF_RESET_ON_RATE_CHANGE = "TRUE",
            p_TX_EIDLE_ASSERT_DELAY      = 0b100,
            p_TX_EIDLE_DEASSERT_DELAY    = 0b011,
            p_TX_RXDETECT_CFG            = 0b110010,
            p_TX_RXDETECT_REF            = 5,
            # Line rate dependent PMA settings (2.5/5.0 GT/s from the 10 GHz PLL).
            p_CH_HSPMUX                  = 0x4040,
            p_PREIQ_FREQ_BST             = 1,
            p_RTX_BUF_CML_CTRL           = 0b101,
            p_RXPI_CFG0                  = 0x3002,
            p_RXPI_CFG1                  = 0x0054,
            p_TXPI_CFG0                  = 0x3100,
            p_TXPI_CFG1                  = 0x0000,
            p_TX_PI_BIASSET              = 1,
            p_RX_PMA_RSV0                = 0x000f,
            i_RXCDRHOLD                  = 0,
            i_TXPOLARITY                 = lane.tx_polarity,
            i_RXPOLARITY                 = lane.rx_polarity,
        )

    def gt_params(self, rxcdr_cfg):
        return {}

    def gt_update_params(self, gt, params):
        gt.gty_params.update(params)
