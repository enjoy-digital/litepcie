#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY lane transceivers on Xilinx 7-Series GTX (Kintex-7), through LiteICLink: one Channel PLL
per lane as the Xilinx wrapper at 2.5/5.0 GT/s (the GTX Quad PLL VCO does not go down to 2.5 GHz), LPM
receive equalizer, see S7PCIeSerDes. With gen3, a Quad PLL at 8 GHz per quad for 8.0 GT/s."""

from migen import *
from migen.genlib.cdc import MultiReg

from litex.gen import *

from litex.soc.interconnect import stream

from litepcie.phy.soft.serdes.s7 import S7PCIeSerDes, S7DRPSequencer

# Constants ----------------------------------------------------------------------------------------

# RXCDR_CFG for a common reference clock (Xilinx 7-Series PCIe GTX wrapper, GES silicon).
GTX_PCIE_RXCDR_CFG = 0x03000023FF10200020
GTX_PCIE_PMA_RSV   = 0x00018480

# RXCDR_CFG at 8.0 GT/s: the Xilinx PCIe wrapper's Gen3 GTX value (synchronous). The UG476 one for an output
# divider of 1 (0x03000023ff10400020) also works in near-end loopback, with no signal from a root port at
# 8.0 GT/s on the YPCB-00338-1P1. Can be changed from the gen3_rxcdr_cfg CSR (bring-up).
GTX_GEN3_RXCDR_CFG = 0x000b00000bff10100080

# 8.0 GT/s attributes over DRP (address, mask: bits kept, 2.5/5.0 GT/s value, 8.0 GT/s value), the 2.5/5.0 GT/s
# values from the static attributes; PMA_RSV, Electrical Idle and drive mode values of the Xilinx PCIe wrapper.
def gtx_gen3_drp_entries(rxcdr_cfg=GTX_PCIE_RXCDR_CFG, pma_rsv=GTX_PCIE_PMA_RSV, gen3_rxcdr_cfg=GTX_GEN3_RXCDR_CFG):
    word = lambda v, n: (v >> (16*n)) & 0xffff if isinstance(v, int) else v[16*n:16*(n + 1)]
    return [
        (0x099, 0x0000, word(pma_rsv, 0),   0x7080), # PMA_RSV[15:0].
        (0x09a, 0x0000, word(pma_rsv, 1),   0x001e), # PMA_RSV[31:16].
        (0x0a8, 0x0000, word(rxcdr_cfg, 0), word(gen3_rxcdr_cfg, 0)), # RXCDR_CFG[15:0].
        (0x0a9, 0x0000, word(rxcdr_cfg, 1), word(gen3_rxcdr_cfg, 1)), # RXCDR_CFG[31:16].
        (0x0aa, 0x0000, word(rxcdr_cfg, 2), word(gen3_rxcdr_cfg, 2)), # RXCDR_CFG[47:32].
        (0x0ab, 0x0000, word(rxcdr_cfg, 3), word(gen3_rxcdr_cfg, 3)), # RXCDR_CFG[63:48].
        (0x0ac, 0xff00, word(rxcdr_cfg, 4), word(gen3_rxcdr_cfg, 4)), # RXCDR_CFG[71:64].
        (0x0a7, 0xf7ff, 0x0800,             0x0000), # RXCDR_HOLD_DURING_EIDLE.
        (0x01e, 0xbfff, 0x4000,             0x0000), # RX_DFE_LPM_HOLD_DURING_EIDLE.
        (0x019, 0xffe0, 0x0001,             0x0002), # TX_DRIVE_MODE: PIPE, PIPEGEN3.
    ]

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
            tx_clk           = ClockSignal(self.gt_tx_cd),
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
            p_PMA_RSV                    = GTX_PCIE_PMA_RSV,
            p_RX_DFE_KL_CFG2             = 0x3290D86C,
            p_RX_DFE_LPM_HOLD_DURING_EIDLE = 0b1,
            p_TX_RXDETECT_CFG            = 100, # 100 MHz reference clock.
            i_RXLPMEN                    = 1,
            i_RXDFEXYDEN                 = 0,
        )

    def gt_update_params(self, gt, params):
        gt.gtx_params.update(params)

    # 8.0 GT/s -------------------------------------------------------------------------------------
    def add_gen3_lane(self, i, gt, lane, tx_cd, rx_cd, rxcdr_cfg):
        """Quad PLL of the lane, PLL selection/PMA resets/DRP from the rate sequencer, raw words, Transmitter
        Coefficients (the GTX cursors are in units of a Full Swing of 80). Returns the GTX parameters."""
        from liteiclink.serdes.gtx_7series import GTXQuadPLL
        rs = self.rate_sequencer
        if not hasattr(self, "qplls"):
            self.qplls = {}
            self.drp_dones = []
            self.qpll_locks = []
        quad = i//4
        if quad not in self.qplls:
            qpll = GTXQuadPLL(self.refclk, self.refclk_freq, 8e9)
            # Loop filter of the Xilinx PCIe wrapper at 8.0 GT/s (primitive default: 0xF).
            for special in qpll._fragment.specials:
                if isinstance(special, Instance):
                    special.items.append(Instance.Parameter("QPLL_LPF", 0b1101))
            setattr(self, f"qpll{quad}", qpll)
            self.qplls[quad] = qpll
            self.comb += qpll.reset.eq(self.perst)
            self.qpll_locks.append(qpll.lock)
            pll_lock = Signal()
            self.specials += MultiReg(Reduce("AND", self.qpll_locks), pll_lock, "pcie_link")
            self.comb += rs.pll_lock.eq(pll_lock)
        qpll = self.qplls[quad]

        # DRP writes of the rate's attributes, the 8.0 GT/s RXCDR_CFG from a CSR (bring-up), receive
        # equalizer at 8.0 GT/s: DFE, or LPM with gen3_lpm (debug).
        if not hasattr(self, "_gen3_rxcdr_cfg"):
            from litex.soc.interconnect.csr import CSRStorage
            self._gen3_rxcdr_cfg = CSRStorage(72, reset=GTX_GEN3_RXCDR_CFG,
                description="RXCDR_CFG written at 8.0 GT/s (rate change).")
            self.gen3_lpm   = Signal()
            self.gen3_eidle = Signal()
            self.gen3_xyden = Signal()
        drp = ClockDomainsRenamer("pcie_link")(S7DRPSequencer(gt.drp, gtx_gen3_drp_entries(
            GTX_PCIE_RXCDR_CFG if rxcdr_cfg is None else rxcdr_cfg, gen3_rxcdr_cfg=self._gen3_rxcdr_cfg.storage)))
        setattr(self, f"drp{i}", drp)
        self.drp_dones.append(drp.done)
        self.comb += [
            gt.drp.clk.eq(ClockSignal("pcie_link")),
            drp.start.eq(rs.drp_start),
            drp.sel.eq(rs.pll_sel),
            rs.drp_done.eq(Reduce("AND", self.drp_dones)),
        ]

        # DRP access from the CSRs (bring-up: attributes changed without a build), on the second input of the DRP
        # mux (drp_sel).
        from liteiclink.serdes.common import DRPInterface, DRPControl
        if not hasattr(self, "_drp_sel"):
            from litex.soc.interconnect.csr import CSRStorage
            self._drp_sel = CSRStorage(description="DRP of the transceivers from the CSRs (drp_control*) when set.")
        drp_csr = DRPInterface()
        gt.drp_mux.add_interface(drp_csr)
        setattr(self, f"drp_control{i}", DRPControl(drp_csr))

        # DRP program at 8.0 GT/s on the lane selected by drp_player_lane (bring-up: eye scans), on the third
        # input of the DRP mux while it runs; its outputs hold/reset the receive equalizer and CDR.
        if not hasattr(self, "drp_player"):
            from litex.soc.interconnect.csr import CSRStorage
            from litepcie.phy.soft.serdes.s7 import S7DRPPlayer
            self._drp_player_drp  = DRPInterface()
            self._drp_player_lane = CSRStorage(4, description="Lane of the DRP program.")
            self.drp_player = S7DRPPlayer(self._drp_player_drp)
            self.comb += self.drp_player.start.eq(rs.done & rs.pll_sel)
        player, pdrp, plane = self.drp_player, self._drp_player_drp, self._drp_player_lane.storage
        drp_player = DRPInterface()
        gt.drp_mux.add_interface(drp_player)
        self.comb += [
            drp_player.clk.eq(ClockSignal("pcie_link")),
            drp_player.addr.eq(pdrp.addr),
            drp_player.di.eq(pdrp.di),
            drp_player.we.eq(pdrp.we),
            drp_player.en.eq(pdrp.en & (plane == i)),
            If(plane == i, pdrp.rdy.eq(drp_player.rdy), pdrp.do.eq(drp_player.do)),
            gt.drp_mux.sel.eq(Mux(player.active & (plane == i), 2, self._drp_sel.storage)),
        ]
        pout = Signal(8)
        self.comb += If(rs.pll_sel, pout.eq(player.out))

        # Raw words: TX registered on the transmit clock, RX from the recovered clock through a FIFO.
        raw_tx    = Signal()
        raw_g3    = Signal()
        raw_tx_r  = Signal(40)
        self.specials += [
            MultiReg(rs.pll_sel, raw_tx, tx_cd),
            MultiReg(rs.pll_sel, raw_g3, "pcie_g3"),
        ]
        getattr(self.sync, tx_cd).__iadd__(raw_tx_r.eq(lane.raw_tx))
        rx_cdc = ClockDomainsRenamer({"write": rx_cd, "read": "pcie_g3"})(stream.AsyncFIFO([("data", 40)], 8, buffered=True))
        setattr(self, f"raw_rx_cdc{i}", rx_cdc)
        self.comb += [
            rx_cdc.sink.valid.eq(1),
            rx_cdc.sink.data.eq(gt.rx_prbs.i),
            rx_cdc.source.ready.eq(1),
            lane.raw_rx.eq(rx_cdc.source.data),
            lane.raw_rx_valid.eq(rx_cdc.source.valid & raw_g3),
        ]
        # No comma alignment at 8.0 GT/s: 8b/10b commas also match in 128b/130b data (in each EIEOS, at random
        # in scrambled data), the word boundary would move under the Block aligner.
        self.comb += gt.rx_align.eq(~rs.pll_sel)
        params   = gt.gtx_params
        tx_data  = params["i_TXDATA"]
        tx_mode  = params["i_TXCHARDISPMODE"]
        tx_val   = params["i_TXCHARDISPVAL"]
        return dict(
            i_QPLLCLK        = qpll.clk,
            i_QPLLREFCLK     = qpll.refclk,
            i_TXSYSCLKSEL    = Replicate(rs.pll_sel, 2),
            i_RXSYSCLKSEL    = Replicate(rs.pll_sel, 2),
            i_TXPMARESET     = rs.pma_reset,
            i_RXPMARESET     = rs.pma_reset,
            i_TXDATA         = Mux(raw_tx, Cat(*[raw_tx_r[10*k:10*k + 8] for k in range(4)]), tx_data),
            i_TXCHARDISPMODE = Mux(raw_tx, Cat(*[raw_tx_r[10*k + 9] for k in range(4)]), tx_mode),
            i_TXCHARDISPVAL  = Mux(raw_tx, Cat(*[raw_tx_r[10*k + 8] for k in range(4)]), tx_val),
            # Receive equalizer: LPM at 2.5/5.0 GT/s, DFE at 8.0 GT/s (as the Xilinx wrapper: RXDFEXYDEN 0,
            # gen3_xyden sets it as LiteICLink).
            # No Electrical Idle detection at 8.0 GT/s: the GTX reports Electrical Idle on a 8.0 GT/s signal
            # and squelches the received data (inferred instead, see lanes.py). gen3_eidle (debug) keeps it.
            i_RXELECIDLEMODE = Mux(rs.pll_sel & ~self.gen3_eidle, 0b11, 0b00),
            i_RXLPMEN        = ~rs.pll_sel | self.gen3_lpm,
            i_RXDFEXYDEN     = rs.pll_sel & ~self.gen3_lpm & self.gen3_xyden,
            # Receive equalizer and CDR controls from the DRP program at 8.0 GT/s (bring-up), the Xilinx wrapper
            # holds the AGC after its receiver equalization.
            i_RXDFELPMRESET  = pout[0],
            i_RXDFEAGCHOLD   = pout[1],
            i_RXCDRHOLD      = pout[2],
            i_RXOSHOLD       = pout[3],
            i_RXDFELFHOLD    = pout[4],
            i_TXPRECURSOR    = Cat(Constant(0, 1), lane.tx_eq_pre[0:4]),
            i_TXPOSTCURSOR   = Cat(Constant(0, 1), lane.tx_eq_post[0:4]),
        )
