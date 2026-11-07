#!/usr/bin/env python3

#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""8.0 GT/s lane test on the YPCB-00338-1P1 (Kintex-7 GTX), no host involved: QPLL at 8 GHz, 128b/130b Blocks
through a transceiver loopback, Block alignment, scrambler. CSRs over JTAGBone:

python3 bench/soft/ypcb_gen3.py --build
"""

import argparse

from migen import *
from migen.genlib.cdc import BusSynchronizer, MultiReg

from litex.gen import *

from litex_boards.platforms import ypcb_00338_1p1

from litex.soc.cores.clock import *
from litex.soc.interconnect.csr import *
from litex.soc.integration.soc_core import SoCMini
from litex.soc.integration.builder import Builder

from liteiclink.serdes.gtx_7series import GTXQuadPLL, GTX

from litepcie.phy.soft.gen3 import LFSR_SEEDS, Gen3TXTester, Gen3RXChecker

class CRG(LiteXModule):
    def __init__(self, platform, sys_clk_freq):
        self.rst    = Signal()
        self.cd_sys = ClockDomain()
        self.pll = pll = S7PLL(speedgrade=-2)
        self.comb += pll.reset.eq(self.rst)
        pll.register_clkin(platform.request("clk200"), 200e6)
        pll.create_clkout(self.cd_sys, sys_clk_freq)
        platform.add_false_path_constraints(self.cd_sys.clk, pll.clkin)

class Gen3Lane(LiteXModule, AutoCSR):
    def __init__(self, gt, seed, tx_cd, rx_cd):
        self._status = CSRStatus(fields=[
            CSRField("tx_ready", size=1),
            CSRField("rx_ready", size=1),
            CSRField("aligned",  size=1),
        ])
        self._blocks = CSRStatus(32, description="Blocks checked.")
        self._errors = CSRStatus(32, description="Wrong Blocks.")
        self._eieos  = CSRStatus(32, description="EIEOS received.")

        # # #

        self.tx = tx = ClockDomainsRenamer(tx_cd)(Gen3TXTester(seed))
        self.rx = rx = ClockDomainsRenamer(rx_cd)(Gen3RXChecker(seed))
        self.comb += [
            gt.tx_produce_pattern.eq(1),
            gt.tx_pattern.eq(tx.data),
            rx.data.eq(gt.rx_prbs.i),
            self._status.fields.tx_ready.eq(gt.tx_ready),
            self._status.fields.rx_ready.eq(gt.rx_ready),
        ]
        self.specials += MultiReg(rx.aligned, self._status.fields.aligned, "sys")
        for value, csr in [(rx.blocks, self._blocks), (rx.errors, self._errors), (rx.eieos, self._eieos)]:
            bus = BusSynchronizer(32, rx_cd, "sys")
            self.submodules += bus
            self.comb += [bus.i.eq(value), csr.status.eq(bus.o)]

class Gen3SoC(SoCMini):
    def __init__(self, platform, sys_clk_freq=int(125e6), nlanes=4):
        SoCMini.__init__(self, platform, sys_clk_freq, ident="LitePCIe soft PHY 8.0 GT/s lane test", ident_version=True)
        self.crg = CRG(platform, sys_clk_freq)
        self.add_jtagbone()
        self._loopback = CSRStorage(3, reset=0b010, description="Transceiver loopback (0b010: near-end PMA).")

        pads   = platform.request("pcie_x4")
        refclk = Signal()
        self.specials += Instance("IBUFDS_GTE2", i_CEB=0, i_I=pads.clk_p, i_IB=pads.clk_n, o_O=refclk)
        self.qpll = qpll = GTXQuadPLL(refclk, 100e6, 8e9)
        print(qpll)

        clks = []
        for i in range(nlanes):
            tx_pads = Record([("p", 1), ("n", 1)])
            rx_pads = Record([("p", 1), ("n", 1)])
            self.comb += [
                pads.tx_p[i].eq(tx_pads.p),
                pads.tx_n[i].eq(tx_pads.n),
                rx_pads.p.eq(pads.rx_p[i]),
                rx_pads.n.eq(pads.rx_n[i]),
            ]
            gt = GTX(qpll, tx_pads, rx_pads, sys_clk_freq,
                data_width       = 40,
                tx_buffer_enable = True,
                rx_buffer_enable = True,
                clock_aligner    = False,
                pll_master       = i == 0,
            )
            gt.add_stream_endpoints()
            self.comb += [gt.loopback.eq(self._loopback.storage), gt.rx_align.eq(0)]
            tx_cd, rx_cd = f"gt{i}_tx", f"gt{i}_rx"
            gt = ClockDomainsRenamer({"tx": tx_cd, "rx": rx_cd})(gt)
            setattr(self, f"gt{i}", gt)
            setattr(self, f"lane{i}", Gen3Lane(gt, LFSR_SEEDS[i], tx_cd, rx_cd))
            platform.add_period_constraint(gt.cd_tx.clk, 1e9/200e6)
            platform.add_period_constraint(gt.cd_rx.clk, 1e9/200e6)
            clks += [gt.cd_tx.clk, gt.cd_rx.clk]
        platform.add_false_path_constraints(self.crg.cd_sys.clk, *clks)

def main():
    parser = argparse.ArgumentParser(description="8.0 GT/s lane test on the YPCB-00338-1P1.")
    parser.add_argument("--build",      action="store_true", help="Build bitstream.")
    parser.add_argument("--output-dir", default="build/soft_ypcb_gen3", help="Build directory.")
    args = parser.parse_args()
    platform = ypcb_00338_1p1.Platform()
    soc      = Gen3SoC(platform)
    builder  = Builder(soc, output_dir=args.output_dir, csr_csv=args.output_dir + "/csr.csv")
    builder.build(run=args.build)

if __name__ == "__main__":
    main()
