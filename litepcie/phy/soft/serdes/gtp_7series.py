#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY lane transceivers on Xilinx 7-Series GTP (Artix-7), through LiteICLink.

nlanes GTP channels on one GTP Quad PLL from the 100 MHz PCIe reference clock (VCO 2.5 GHz: 2.5 GT/s
with the output divider 2, 5.0 GT/s with TXRATE/RXRATE selecting divider 1), 40-bit raw interface
with 8b/10b in the fabric (4 Symbols per lane clock cycle), TX/RX buffers enabled, the lane clock
("pcie_pipe") from S7PCIeClocking shared by the TX of all lanes, one recovered clock per lane for the
RX ("pcie_rxN") up to the elastic buffer.

PCIe specific transceiver attributes (common clock CDR configuration, buffer/CDR/LPM behavior on
Electrical Idle, driver levels) follow the Xilinx 7-Series PCIe wrapper settings; receiver
detection is stubbed (receiver always present) until the PCS PCIe mode is validated on hardware.
"""

from migen import *
from migen.genlib.cdc import MultiReg

from litex.gen import *

from litepcie.phy.soft.datapath       import RXErrorSubstitution
from litepcie.phy.soft.serdes.base     import PCIeSerDes
from litepcie.phy.soft.serdes.clocking import S7PCIeClocking

# Constants ----------------------------------------------------------------------------------------

# RXCDR_CFG for a common reference clock (Xilinx 7-Series PCIe GTP wrapper, both rates); the
# asynchronous reference clock variant (+/-300 ppm) is 0x000107FE406021041010.
GTP_PCIE_RXCDR_CFG = 0x000107FE406001041010

# A7 PCIe SerDes -----------------------------------------------------------------------------------

class A7PCIeSerDes(PCIeSerDes):
    def __init__(self, platform, pads, sys_clk_freq, refclk_freq=100e6, rxcdr_cfg=GTP_PCIE_RXCDR_CFG,
        pcs_pcie_en=False, skp_interval=None):
        from liteiclink.serdes.gtp_7series import GTPQuadPLL, GTP

        nlanes = len(pads.tx_p)
        PCIeSerDes.__init__(self, nlanes)
        self.platform = platform
        self.pads     = pads
        self.perst    = Signal() # o ("sys"): PERST# asserted.

        # # #

        # PERST# -----------------------------------------------------------------------------------
        self.specials += MultiReg(~pads.rst_n, self.perst)

        # Clocking ---------------------------------------------------------------------------------
        self.clocking = clocking = S7PCIeClocking(pads.clk_p, pads.clk_n, refclk_freq, reset=self.perst)
        self.comb += clocking.rate.eq(self.rate)

        # Quad PLL (2.5 GT/s configuration, 5.0 GT/s through the rate ports) ----------------------
        self.qpll = qpll = GTPQuadPLL(clocking.refclk, refclk_freq, 2.5e9)

        # Lanes ------------------------------------------------------------------------------------
        self.gtps = []
        readys    = []
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
            gtp = GTP(qpll, tx_pads, rx_pads, sys_clk_freq,
                qpll_reset       = (i == 0),
                tx_clk           = ClockSignal("pcie_pipe"),
                data_width       = 40,
                tx_buffer_enable = True,
                rx_buffer_enable = True,
                clock_aligner    = False,
            )
            gtp.add_stream_endpoints()
            # Comma alignment on any byte: Ordered Sets at any Symbol position (word phase kept).
            gtp.gtp_params.update(p_ALIGN_COMMA_WORD=1)
            # PIPE drive mode: TX_DEEMPH0/1 are the -6/-3.5 dB de-emphasis selected by TXDEEMPH.
            gtp.gtp_params.update(
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
            )
            # Electrical Idle: TX, and RX detection with a fabric clock.
            rx_elecidle = Signal()
            gtp.gtp_params.update(
                p_PCS_RSVD_ATTR  = 0x000000000100, # OOB/Electrical Idle detection power-up.
                p_RXOOB_CLK_CFG  = "FABRIC",
                i_SIGVALIDCLK    = ClockSignal("pcie_oob"),
                i_RXELECIDLEMODE = 0b00,
                o_RXELECIDLE     = rx_elecidle,
                i_TXELECIDLE     = lane.tx_elecidle,
            )
            # PCIe attributes (Xilinx 7-Series PCIe GTP wrapper).
            gtp.gtp_params.update(
                p_PCS_PCIE_EN             = "TRUE" if pcs_pcie_en else "FALSE",
                p_RXCDR_CFG               = rxcdr_cfg,
                p_RXCDR_HOLD_DURING_EIDLE = 0b1,
                p_RXCDR_LOCK_CFG          = 0b010101,
                p_RXLPM_HOLD_DURING_EIDLE = 0b1,
                p_RXLPM_INCM_CFG          = 0b1,
                p_RXLPM_IPCM_CFG          = 0b0,
                p_RX_CM_SEL               = 0b11,   # Programmable common mode...
                p_RX_CM_TRIM              = 0b1010, # ...800 mV.
                p_RXBUF_ADDR_MODE         = "FULL",
                p_RXBUF_EIDLE_HI_CNT      = 0b0100,
                p_RXBUF_EIDLE_LO_CNT      = 0b0000,
                p_RXBUF_RESET_ON_EIDLE    = "TRUE",
                p_PD_TRANS_TIME_NONE_P2   = 0x09,
                p_TX_EIDLE_ASSERT_DELAY   = 0b100,
                p_TX_EIDLE_DEASSERT_DELAY = 0b010,
                p_TXOOB_CFG               = 0b1, # Filter stale TX data when exiting Electrical Idle.
                p_TX_RXDETECT_REF         = 0b011,
                i_TXPOLARITY              = lane.tx_polarity,
                i_RXPOLARITY              = lane.rx_polarity,
            )
            gtp = ClockDomainsRenamer({"tx": tx_cd, "rx": rx_cd})(gtp)
            self.submodules += gtp
            self.gtps.append(gtp)

            # Controls.
            rx_reset = Signal()
            self.specials += MultiReg(lane.rx_reset, rx_reset, "sys")
            self.comb += [
                gtp.tx_enable.eq(~self.perst),
                gtp.rx_enable.eq(~self.perst & ~rx_reset),
                gtp.loopback.eq(self.loopback),
            ]
            readys.append(gtp.tx_ready & gtp.rx_ready)
            self.specials += MultiReg(gtp.tx_ready & gtp.rx_ready, lane.ready, "pcie_pipe")

            # Datapaths.
            err = ClockDomainsRenamer(rx_cd)(RXErrorSubstitution(gtp.decoders, clock_domain=rx_cd))
            self.submodules += err
            self.comb += gtp.source.connect(err.sink)
            self.add_lane_datapaths(lane, gtp.sink, err.source, rx_cd=rx_cd, skp_interval=skp_interval)
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
        for gtp in self.gtps:
            platform.add_period_constraint(gtp.cd_rx.clk, 1e9/125e6)
            clks.append(gtp.cd_rx.clk)
        platform.add_false_path_constraints(sys_clk, *clks)
