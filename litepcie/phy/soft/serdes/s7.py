#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY lane transceivers on Xilinx 7-Series, through LiteICLink: what GTP and GTX share.

nlanes transceivers on a PLL from the 100 MHz PCIe reference clock (VCO 2.5 GHz: 2.5 GT/s with the
output divider 2, 5.0 GT/s with TXRATE/RXRATE selecting divider 1), 40-bit raw interface with 8b/10b
in the fabric (4 Symbols per lane clock cycle), TX/RX buffers enabled, the lane clock ("pcie_pipe")
from S7PCIeClocking shared by the TX of all lanes, one recovered clock per lane for the RX ("pcie_rxN")
up to the elastic buffer.

PCIe specific transceiver attributes (buffer/CDR behavior on Electrical Idle, driver levels) follow the
Xilinx 7-Series PCIe wrapper settings; receiver detection is stubbed (receiver always present) until
the PCS PCIe mode is validated on hardware.
"""

from migen import *
from migen.genlib.cdc import MultiReg

from litex.gen import *

from litepcie.phy.soft.datapath        import RXErrorSubstitution
from litepcie.phy.soft.serdes.base     import PCIeSerDes
from litepcie.phy.soft.serdes.clocking import S7PCIeClocking

# 7-Series PCIe SerDes -----------------------------------------------------------------------------

class S7PCIeSerDes(PCIeSerDes):
    """Subclasses provide add_pll(refclk, refclk_freq), add_gt(i, pll, tx_pads, rx_pads, sys_clk_freq)
    gt_params(rxcdr_cfg) and gt_update_params(gt, params) for what is specific to the transceiver."""
    def __init__(self, platform, pads, sys_clk_freq, refclk_freq=100e6, rxcdr_cfg=None, pcs_pcie_en=False,
        skp_interval=None, speedgrade=-1):
        nlanes = len(pads.tx_p)
        PCIeSerDes.__init__(self, nlanes)
        self.platform = platform
        self.pads     = pads
        self.perst    = Signal() # o ("sys"): PERST# asserted.

        # # #

        # PERST# -----------------------------------------------------------------------------------
        self.specials += MultiReg(~pads.rst_n, self.perst)

        # Clocking ---------------------------------------------------------------------------------
        self.clocking = clocking = S7PCIeClocking(pads.clk_p, pads.clk_n, refclk_freq, reset=self.perst,
            speedgrade=speedgrade)
        self.comb += clocking.rate.eq(self.rate)

        # PLL (2.5 GT/s configuration, 5.0 GT/s through the rate ports) -----------------------------
        pll = self.add_pll(clocking.refclk, refclk_freq)

        # Lanes ------------------------------------------------------------------------------------
        self.gts = []
        readys   = []
        for i, lane in enumerate(self.lanes):
            tx_pads = Record([("p", 1), ("n", 1)])
            rx_pads = Record([("p", 1), ("n", 1)])
            self.comb += [
                pads.tx_p[i].eq(tx_pads.p),
                pads.tx_n[i].eq(tx_pads.n),
                rx_pads.p.eq(pads.rx_p[i]),
                rx_pads.n.eq(pads.rx_n[i]),
            ]
            tx_cd = f"pcie_tx{i}" # Lane clock (external tx_clk), transceiver's own reset.
            rx_cd = f"pcie_rx{i}" # Recovered clock.
            gt = self.add_gt(i, pll, tx_pads, rx_pads, sys_clk_freq)
            gt.add_stream_endpoints()
            rx_elecidle = Signal()
            params = dict(
                # Comma alignment on any byte: Ordered Sets at any Symbol position (word phase kept).
                p_ALIGN_COMMA_WORD = 1,
                # PIPE drive mode: TX_DEEMPH0/1 are the -6/-3.5 dB de-emphasis selected by TXDEEMPH.
                p_TX_DRIVE_MODE    = "PIPE",
                p_TX_DEEMPH0       = 0b10100,
                p_TX_DEEMPH1       = 0b01011,
                p_TX_MARGIN_FULL_0 = 0b1001111,
                p_TX_MARGIN_FULL_1 = 0b1001110,
                p_TX_MARGIN_FULL_2 = 0b1001101,
                p_TX_MARGIN_FULL_3 = 0b1001100,
                p_TX_MARGIN_FULL_4 = 0b1000011,
                p_TX_MARGIN_LOW_0  = 0b1000101,
                p_TX_MARGIN_LOW_1  = 0b1000110,
                p_TX_MARGIN_LOW_2  = 0b1000011,
                p_TX_MARGIN_LOW_3  = 0b1000010,
                p_TX_MARGIN_LOW_4  = 0b1000000,
                i_TXDEEMPH         = lane.tx_deemph,
                i_TXDIFFCTRL       = 0b1100, # 850 mV.
                # Electrical Idle: TX, and RX detection with a fabric clock.
                i_RXELECIDLEMODE   = 0b00,
                o_RXELECIDLE       = rx_elecidle,
                i_TXELECIDLE       = lane.tx_elecidle,
                # PCIe attributes (Xilinx 7-Series PCIe wrapper).
                p_RX_CLK25_DIV            = 4, # 100 MHz reference clock.
                p_TX_CLK25_DIV            = 4,
                p_PCS_PCIE_EN             = "TRUE" if pcs_pcie_en else "FALSE",
                p_RXCDR_LOCK_CFG          = 0b010101,
                p_RXCDR_HOLD_DURING_EIDLE = 0b1,
                p_RX_CM_SEL               = 0b11, # Programmable common mode.
                p_RXBUF_ADDR_MODE         = "FULL",
                p_RXBUF_EIDLE_HI_CNT      = 0b0100,
                p_RXBUF_EIDLE_LO_CNT      = 0b0000,
                p_RXBUF_RESET_ON_EIDLE    = "TRUE",
                p_TX_EIDLE_ASSERT_DELAY   = 0b100,
                p_TX_EIDLE_DEASSERT_DELAY = 0b010,
                p_TX_RXDETECT_REF         = 0b011,
                i_TXPOLARITY              = lane.tx_polarity,
                i_RXPOLARITY              = lane.rx_polarity,
            )
            params.update(self.gt_params(rxcdr_cfg))
            self.gt_update_params(gt, params)
            gt = ClockDomainsRenamer({"tx": tx_cd, "rx": rx_cd})(gt)
            self.submodules += gt
            self.gts.append(gt)

            # Controls.
            rx_reset = Signal()
            self.specials += MultiReg(lane.rx_reset, rx_reset, "sys")
            self.comb += [
                gt.tx_enable.eq(~self.perst),
                gt.rx_enable.eq(~self.perst & ~rx_reset),
                gt.loopback.eq(self.loopback),
            ]
            readys.append(gt.tx_ready & gt.rx_ready)
            self.specials += MultiReg(gt.tx_ready & gt.rx_ready, lane.ready, "pcie_pipe")

            # Datapaths.
            err = ClockDomainsRenamer(rx_cd)(RXErrorSubstitution(gt.decoders, clock_domain=rx_cd))
            self.submodules += err
            self.comb += gt.source.connect(err.sink)
            self.add_lane_datapaths(lane, gt.sink, err.source, rx_cd=rx_cd, skp_interval=skp_interval)
            self.add_rx_errors(lane, err.error, rx_cd)
            self.add_rx_elecidle_filter(lane, rx_elecidle)
            self.add_receiver_detection_stub(lane)

        self.specials += MultiReg(Reduce("AND", readys), self.ready, "pcie_link")
        self.comb += self.rate_done.eq(1) # Rate changes: later milestone (2.5 GT/s only).

    def add_timing_constraints(self, sys_clk):
        platform = self.platform
        platform.add_period_constraint(self.clocking.cd_pcie_pipe.clk, 1e9/125e6)
        platform.add_period_constraint(self.clocking.cd_pcie_link.clk, 1e9/125e6)
        platform.add_period_constraint(self.clocking.cd_pcie_oob.clk,  1e9/50e6)
        clks = [self.clocking.cd_pcie_pipe.clk, self.clocking.cd_pcie_link.clk]
        for gt in self.gts:
            platform.add_period_constraint(gt.cd_rx.clk, 1e9/125e6)
            clks.append(gt.cd_rx.clk)
        platform.add_false_path_constraints(sys_clk, *clks)
