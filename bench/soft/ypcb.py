#!/usr/bin/env python3

#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY bring-up on the YPCB-00338-1P1 (Kintex-7 GTX, PCIe x1 on Lane 0), over JTAGBone.

By default, the soft Physical Layer alone: the host's root port sees the link in L0 with DLActive clear.
--with-endpoint: full endpoint (SoftPCIEPHY, MMAP, DMA, MSI). --hard-ip: the same on the hard IP. The debug
CSRs and LTSSM tracer are always there, LTSSM disabled at reset and by PERST# (--ltssm-autostart for
enumeration at boot). Control and status with bench/soft/status.py.

python3 bench/soft/ypcb.py [--with-endpoint] [--driver] --build
"""

import os
import argparse

from migen import *

from litex.gen import *
from litex.build.generic_platform import *

from litex_boards.platforms import ypcb_00338_1p1

from litex.soc.cores.clock import *
from litex.soc.interconnect.csr import *
from litex.soc.integration.soc_core import SoCMini
from litex.soc.integration.builder import Builder

from litepcie.phy.soft.serdes.gtx_7series import K7PCIeSerDes
from litepcie.phy.soft.pipe               import PCIePhysicalLayer
from litepcie.phy.soft.debug              import SoftPHYDebug
from litepcie.phy.soft                    import SoftPCIEPHY
from litepcie.software                    import generate_litepcie_software

# CRG ----------------------------------------------------------------------------------------------

class CRG(LiteXModule):
    def __init__(self, platform, sys_clk_freq):
        self.cd_sys = ClockDomain()

        # # #

        self.pll = pll = S7MMCM(speedgrade=-2)
        pll.register_clkin(platform.request("clk200"), 200e6)
        pll.create_clkout(self.cd_sys, sys_clk_freq)

# Transceiver status -------------------------------------------------------------------------------

class GTStatus(LiteXModule, AutoCSR):
    def __init__(self, serdes):
        gt = serdes.gts[0]
        self._status = CSRStatus(fields=[
            CSRField("tx_ready",    size=1, offset=0),
            CSRField("rx_ready",    size=1, offset=1),
            CSRField("mmcm_locked", size=1, offset=2),
            CSRField("cpll_locked", size=1, offset=3),
        ])
        self.comb += [
            self._status.fields.tx_ready.eq(gt.tx_ready),
            self._status.fields.rx_ready.eq(gt.rx_ready),
            self._status.fields.mmcm_locked.eq(serdes.clocking.locked),
            self._status.fields.cpll_locked.eq(serdes.cpll0.lock),
        ]

# Soft PHY SoC -------------------------------------------------------------------------------------

class SoftPHYSoC(SoCMini):
    def __init__(self, platform, sys_clk_freq=int(125e6), with_analyzer=False, with_endpoint=False,
        ltssm_autostart=False, hard_ip=False, speed="gen1", nlanes=1):
        SoCMini.__init__(self, platform, sys_clk_freq, ident="LitePCIe soft PHY bring-up on YPCB", ident_version=True)

        # CRG --------------------------------------------------------------------------------------
        self.crg = CRG(platform, sys_clk_freq)

        # JTAGBone ---------------------------------------------------------------------------------
        self.add_jtagbone()

        # PHY --------------------------------------------------------------------------------------
        if nlanes == 2:
            # First lanes of the x4 connector.
            platform.add_extension([("pcie_x2", 0,
                Subsignal("clk_p", Pins("J8")),
                Subsignal("clk_n", Pins("J7")),
                Subsignal("rst_n", Pins("Y26"), IOStandard("LVCMOS18"), Misc("PULLUP=TRUE")),
                Subsignal("tx_p",  Pins("F2 H2")),
                Subsignal("tx_n",  Pins("F1 H1")),
                Subsignal("rx_p",  Pins("H6 J4")),
                Subsignal("rx_n",  Pins("H5 J3")),
            )])
        pads = platform.request(f"pcie_x{nlanes}")
        if hard_ip:
            # Same design on the hard IP (control and comparison): Gen2.
            from litepcie.phy.s7pciephy import S7PCIEPHY
            self.pcie_phy = S7PCIEPHY(platform, pads, data_width={1: 64, 4: 128, 8: 128}[nlanes], bar0_size=0x20000)
            self.pcie_phy.update_config({"PCIe_Blk_Locn": "X0Y0"})
            self.add_pcie(phy=self.pcie_phy, ndmas=1, address_width=64, with_dma_loopback=True)
            self.pcie_phy.add_gt_loc_constraints(locs=[f"GTXE2_CHANNEL_X0Y{23 - i}" for i in range(nlanes)], gt_type="gtx")
            return
        if with_endpoint:
            # Full LitePCIe endpoint: driver, MMAP, DMA and MSI as with the hard-IP PHYs.
            self.pcie_phy = pcie_phy = SoftPCIEPHY(platform, pads,
                data_width   = 64 if nlanes == 1 else 32*nlanes,
                bar0_size    = 0x20000,
                speed        = speed,
                sys_clk_freq = sys_clk_freq,
                speedgrade   = -2,
            )
            pcie_phy.add_timing_constraints(self.crg.cd_sys.clk)
            pcie_phy.add_debug(enable_reset=int(ltssm_autostart))
            pcie_phy.add_ltssm_tracer()
            self.add_pcie(phy=pcie_phy, ndmas=1, address_width=64, with_dma_loopback=True)
            serdes, phy = pcie_phy.serdes, pcie_phy.phy_layer
        else:
            # Physical Layer alone: L0 against the host, received Symbols dropped.
            gen2_capable = speed == "gen2"
            self.serdes = serdes = K7PCIeSerDes(platform, pads, sys_clk_freq, speedgrade=-2, rate_change=gen2_capable)
            self.phy    = phy    = PCIePhysicalLayer(serdes, 125e6, upstream=True, gen2_capable=gen2_capable)
            serdes.add_timing_constraints(self.crg.cd_sys.clk)
            self.pcie_phy = SoftPHYDebug(phy, serdes, enable_reset=int(ltssm_autostart))
            self.comb += phy.source.ready.eq(1)
        self.gt_status = GTStatus(serdes)

        # Leds -------------------------------------------------------------------------------------
        leds = platform.request_all("user_led")
        self.comb += [
            leds[0].eq(~serdes.ready),
            leds[1].eq(~phy.ltssm.link_up),
            leds[2].eq(~phy.ltssm.l0),
        ]

        # Analyzer ---------------------------------------------------------------------------------
        if with_analyzer:
            from migen.genlib.cdc import MultiReg
            from litescope import LiteScopeAnalyzer
            lane = serdes.lanes[0]
            ltssm_state = Signal(6)
            self.specials += MultiReg(phy.ltssm.state, ltssm_state, "pcie_pipe")
            self.analyzer = LiteScopeAnalyzer([
                    lane.source.valid, lane.source.data, lane.source.ctrl,
                    lane.sink.valid,   lane.sink.data,   lane.sink.ctrl,
                    lane.rx_elecidle, lane.tx_elecidle, lane.rx_errors, lane.ready,
                    phy.ts_chk.detected, phy.ts_chk.error, phy.eios_det.detected,
                    ltssm_state,
                ],
                depth        = 2048,
                clock_domain = "pcie_pipe",
                csr_csv      = "analyzer.csv",
            )

# Build --------------------------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Soft PCIe PHY bring-up on the YPCB-00338-1P1.")
    parser.add_argument("--build",           action="store_true", help="Build bitstream.")
    parser.add_argument("--with-analyzer",   action="store_true", help="LiteScope analyzer on the lane.")
    parser.add_argument("--with-endpoint",   action="store_true", help="Full LitePCIe endpoint (SoftPCIEPHY, MMAP, DMA, MSI).")
    parser.add_argument("--ltssm-autostart", action="store_true", help="LTSSM enabled at reset, not disabled by PERST#.")
    parser.add_argument("--hard-ip",         action="store_true", help="Same endpoint on the hard IP (S7PCIEPHY).")
    parser.add_argument("--speed",           default="gen1", choices=["gen1", "gen2"], help="Soft PHY maximum speed.")
    parser.add_argument("--nlanes",          default=1, type=int, choices=[1, 2, 4, 8], help="Lanes (x2: soft PHY only).")
    parser.add_argument("--driver",          action="store_true", help="Generate the PCIe driver.")
    parser.add_argument("--output-dir",      default="build/soft_ypcb", help="Build directory.")
    args = parser.parse_args()

    platform = ypcb_00338_1p1.Platform()
    soc      = SoftPHYSoC(platform,
        with_analyzer   = args.with_analyzer,
        with_endpoint   = args.with_endpoint,
        hard_ip         = args.hard_ip,
        speed           = args.speed,
        nlanes          = args.nlanes,
        ltssm_autostart = args.ltssm_autostart,
    )
    builder = Builder(soc, output_dir=args.output_dir, csr_csv=os.path.join(args.output_dir, "csr.csv"))
    builder.build(run=args.build)

    if args.driver:
        generate_litepcie_software(soc, os.path.join(builder.output_dir, "driver"))

if __name__ == "__main__":
    main()
