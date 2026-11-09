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
from migen.genlib.cdc import MultiReg

from litex.gen import *

from litex.soc.interconnect import stream

from litepcie.phy.soft.serdes.s7       import S7PCIeSerDes, S7DRPSequencer
from litepcie.phy.soft.serdes.clocking import S7PCIeClocking

# Constants ----------------------------------------------------------------------------------------

# 8.0 GT/s attributes over DRP (address, mask: bits kept, 2.5/5.0 GT/s value, 8.0 GT/s value): CDR (the _GEN3 values
# of the Xilinx UltraScale+ PCIe GTY wrapper, applied by the transceiver itself in its PCIe mode) and the drive mode
# (PIPEGEN3: transmitter cursors from TXPRECURSOR/TXPOSTCURSOR). Addresses from the GTYE4 DRP map.
GTY_GEN3_DRP_ENTRIES = [
    (0x00e, 0x0000, 0x0002, 0x0003), # RXCDR_CFG0.
    (0x010, 0x0000, 0x0249, 0x0154), # RXCDR_CFG2.
    (0x0b4, 0x0000, 0xb46b, 0x146b), # RXCDR_CFG5.
    (0x07e, 0xe0ff, 0x0100, 0x0200), # TX_DRIVE_MODE[12:8]: PIPE, PIPEGEN3.
]

# USP PCIe SerDes ----------------------------------------------------------------------------------

class USPPCIeSerDes(S7PCIeSerDes):
    # TXRATE/RXRATE: TXOUT_DIV/RXOUT_DIV (4) at 2.5 GT/s, divider 2 at 5.0 GT/s (Quad PLL0 at 10 GHz), divider 1
    # at 8.0 GT/s (Quad PLL1 at 8 GHz).
    gt_rates = {0: 0b000, 1: 0b010, 2: 0b001}

    def add_clocking(self, pads, refclk_freq, speedgrade, gen3):
        return S7PCIeClocking(pads.clk_p, pads.clk_n, refclk_freq, reset=self.perst, speedgrade=speedgrade,
            gen3=gen3, usp=True)

    def add_pll(self, refclk, refclk_freq):
        from liteiclink.serdes.gty_ultrascale import GTYQuadPLL
        self.refclk      = refclk
        self.refclk_freq = refclk_freq
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
            p_RXCDR_CFG2_GEN2            = 0x259,
            p_RXCDR_CFG3                 = 0x0012,
            p_RXCDR_CFG3_GEN2            = 0x12,
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

    # 8.0 GT/s -------------------------------------------------------------------------------------
    def add_gen3_lane(self, i, gt, lane, tx_cd, rx_cd, rxcdr_cfg):
        """Quad PLL1 at 8 GHz next to the Quad PLL0 of the lane's quad, PLL selection/PMA resets/DRP from the rate
        sequencer, raw words, Transmitter Coefficients (cursors in units of a Full Swing of 80, as the GTX).
        Returns the GTY parameters."""
        from liteiclink.serdes.gty_ultrascale import GTYQuadPLL
        from liteiclink.serdes.common import DRPInterface, DRPControl
        from litex.soc.interconnect.csr import CSRStorage
        rs   = self.rate_sequencer
        quad = i//4
        if not hasattr(self, "gen3_locks"):
            self.gen3_locks = []
            self.drp_dones  = []
            self.gen3_lpm   = Signal()
            self.gen3_eidle = Signal()
            self.gen3_xyden = Signal()
            self._drp_sel   = CSRStorage(description="DRP of the transceivers from the CSRs (drp_control*) when set.")
        qpll = self.qplls[quad]
        if not hasattr(qpll, "gen3_clk"):
            # Quad PLL1 at 8 GHz in the same GTYE4_COMMON (Xilinx UltraScale+ PCIe GTY wrapper values at 8.0 GT/s).
            config = GTYQuadPLL.compute_config(self.refclk_freq, 8e9, qpll="qpll1")
            qpll.gen3_clk    = Signal()
            qpll.gen3_refclk = Signal()
            qpll.gen3_lock   = Signal()
            qpll.gty_params.update(
                p_QPLL1_FBDIV      = config["n"],
                p_QPLL1_REFCLK_DIV = config["m"],
                p_QPLL1CLKOUT_RATE = "HALF",
                p_QPLL1_CFG0       = 0b0011001100011000,
                p_QPLL1_CFG2       = 0b0000111111000011,
                p_QPLL1_CFG4       = 0b0000000000000010,
                p_QPLL1_CP         = 0b0001111111,
                p_QPLL1_LPF        = 0b0111010100,
                p_QPLL1_LOCK_CFG   = 0b0000010111101000,
                p_QPLL1_SDM_CFG0   = 0b0000000010000000,
                i_GTREFCLK01       = self.refclk,
                i_QPLL1REFCLKSEL   = 0b001,
                i_QPLL1PD          = 0,
                i_QPLL1RESET       = self.perst,
                o_QPLL1LOCK        = qpll.gen3_lock,
                o_QPLL1OUTCLK      = qpll.gen3_clk,
                o_QPLL1OUTREFCLK   = qpll.gen3_refclk,
            )
            # The GTYE4_COMMON is instantiated by GTYQuadPLL's constructor: instantiated again with QPLL1.
            for special in list(qpll._fragment.specials):
                if isinstance(special, Instance) and special.of == "GTYE4_COMMON":
                    qpll._fragment.specials.remove(special)
            qpll.specials += Instance("GTYE4_COMMON", **qpll.gty_params)
            self.gen3_locks.append(qpll.gen3_lock)
            pll_lock = Signal()
            self.specials += MultiReg(Reduce("AND", self.gen3_locks), pll_lock, "pcie_link")
            self.comb += rs.pll_lock.eq(pll_lock)

        # DRP writes of the rate's attributes.
        drp = ClockDomainsRenamer("pcie_link")(S7DRPSequencer(gt.drp, GTY_GEN3_DRP_ENTRIES))
        setattr(self, f"drp{i}", drp)
        self.drp_dones.append(drp.done)
        self.comb += [
            gt.drp.clk.eq(ClockSignal("pcie_link")),
            drp.start.eq(rs.drp_start),
            drp.sel.eq(rs.pll_sel),
            rs.drp_done.eq(Reduce("AND", self.drp_dones)),
        ]

        # DRP access from the CSRs (bring-up: attributes and eye scans without a build), on the second input of the
        # DRP mux (drp_sel).
        drp_csr = DRPInterface()
        gt.drp_mux.add_interface(drp_csr)
        setattr(self, f"drp_control{i}", DRPControl(drp_csr))
        self.comb += gt.drp_mux.sel.eq(self._drp_sel.storage)

        # Raw words: TX registered on the transmit clock (LiteICLink's raw path), RX from the recovered clock
        # through a FIFO.
        raw_g3 = Signal()
        self.specials += MultiReg(rs.pll_sel, raw_g3, "pcie_g3")
        getattr(self.sync, tx_cd).__iadd__(gt.tx_raw.eq(lane.raw_tx))
        self.comb += gt.tx_raw_enable.eq(rs.pll_sel)
        rx_cdc = ClockDomainsRenamer({"write": rx_cd, "read": "pcie_g3"})(stream.AsyncFIFO([("data", 40)], 8, buffered=True))
        setattr(self, f"raw_rx_cdc{i}", rx_cdc)
        self.comb += [
            rx_cdc.sink.valid.eq(1),
            rx_cdc.sink.data.eq(gt.rx_prbs.i),
            rx_cdc.source.ready.eq(1),
            lane.raw_rx.eq(rx_cdc.source.data),
            lane.raw_rx_valid.eq(rx_cdc.source.valid & raw_g3),
        ]
        # No comma alignment at 8.0 GT/s (8b/10b commas also match in 128b/130b data).
        self.comb += gt.rx_align.eq(~rs.pll_sel)
        return dict(
            i_QPLL1CLK       = qpll.gen3_clk,
            i_QPLL1REFCLK    = qpll.gen3_refclk,
            # PLL: Quad PLL0 (10 GHz) at 2.5/5.0 GT/s, Quad PLL1 (8 GHz) at 8.0 GT/s.
            i_TXSYSCLKSEL    = Mux(rs.pll_sel, 0b11, 0b10),
            i_RXSYSCLKSEL    = Mux(rs.pll_sel, 0b11, 0b10),
            i_TXPLLCLKSEL    = Mux(rs.pll_sel, 0b10, 0b11),
            i_RXPLLCLKSEL    = Mux(rs.pll_sel, 0b10, 0b11),
            i_TXPMARESET     = rs.pma_reset,
            i_RXPMARESET     = rs.pma_reset,
            # Receive equalizer: LPM at 2.5/5.0 GT/s, DFE at 8.0 GT/s (as the Xilinx wrapper), LPM with gen3_lpm.
            # Electrical Idle inferred at 8.0 GT/s (see lanes.py), the transceiver's with gen3_eidle (debug).
            i_RXELECIDLEMODE = Mux(rs.pll_sel & ~self.gen3_eidle, 0b11, 0b00),
            i_RXLPMEN        = ~rs.pll_sel | self.gen3_lpm,
            i_RXDFEXYDEN     = 1,
            i_TXPRECURSOR    = Cat(Constant(0, 1), lane.tx_eq_pre[0:4]),
            i_TXPOSTCURSOR   = Cat(Constant(0, 1), lane.tx_eq_post[0:4]),
        )

    def gt_update_params(self, gt, params):
        gt.gty_params.update(params)
