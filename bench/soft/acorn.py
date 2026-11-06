#!/usr/bin/env python3

#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY bring-up on the SQRL Acorn CLE-215(+) / LiteX Acorn Baseboard (Artix-7 GTP, PCIe x1).

The soft Physical Layer (A7PCIeSerDes + PCIePhysicalLayer, upstream role) trains against the host's
root port; the Data Link Layer is not there yet so the host sees the link in L0 with DLActive clear.
Control/status over UARTBone (serial on the Acorn P2 header / Baseboard) or JTAGBone:
- pcie_phy debug CSRs: keep the LTSSM disabled until the host has booted (configuration read
  timeouts during POST can hang some hosts), then enable it and `echo 1 > /sys/bus/pci/rescan`.
- LTSSM tracer (bench/test_ltssm_tracer.py with the UltraScale table), counters, optional LiteScope
  analyzer on the lane (--with-analyzer, analyzer.csv).

python3 bench/soft/acorn.py --build [--load] [--with-jtagbone] [--with-analyzer]
"""

import os
import argparse

from migen import *
from migen.genlib.cdc import MultiReg

from litex.gen import *

from litex_boards.platforms import sqrl_acorn

from litex.soc.cores.clock import *
from litex.soc.integration.soc_core import SoCMini
from litex.soc.integration.builder import Builder

from litex.build.generic_platform import *

from litepcie.phy.soft.serdes.gtp_7series import A7PCIeSerDes
from litepcie.phy.soft.pipe               import PCIePhysicalLayer
from litepcie.phy.soft.debug              import SoftPHYDebug
from litepcie.phy.soft                    import SoftPCIEPHY
from litepcie.software                    import generate_litepcie_software

# IOs ----------------------------------------------------------------------------------------------

# PCIe x1 on one lane of the Acorn's x4 connector (pcie_x4 pin order). The LiteX Acorn Baseboard
# Mini wires its x1 slot to lane index 3 (D9/C9 RX, D7/C7 TX), the default here; with the Acorn in
# a host slot, the lane connected to the host's Lane 0 may differ (--lane).
PCIE_X4_RX_P = ["B10", "B8", "D11", "D9"]
PCIE_X4_RX_N = ["A10", "A8", "C11", "C9"]
PCIE_X4_TX_P = ["B6",  "B4", "D5",  "D7"]
PCIE_X4_TX_N = ["A6",  "A4", "C5",  "C7"]

def pcie_x1_io(lane):
    return [
        ("pcie_soft_x1", 0,
            Subsignal("rst_n", Pins("J1"), IOStandard("LVCMOS33"), Misc("PULLUP=TRUE")),
            Subsignal("clk_p", Pins("F6")),
            Subsignal("clk_n", Pins("E6")),
            Subsignal("rx_p",  Pins(PCIE_X4_RX_P[lane])),
            Subsignal("rx_n",  Pins(PCIE_X4_RX_N[lane])),
            Subsignal("tx_p",  Pins(PCIE_X4_TX_P[lane])),
            Subsignal("tx_n",  Pins(PCIE_X4_TX_N[lane])),
        ),
    ]

# CRG ----------------------------------------------------------------------------------------------

class CRG(LiteXModule):
    def __init__(self, platform, sys_clk_freq):
        self.cd_sys = ClockDomain()

        # # #

        self.pll = pll = S7PLL(speedgrade=-2)
        pll.register_clkin(platform.request("clk200"), 200e6)
        pll.create_clkout(self.cd_sys, sys_clk_freq)

# Soft PHY SoC -------------------------------------------------------------------------------------

class SoftPHYSoC(SoCMini):
    def __init__(self, platform, sys_clk_freq=int(125e6), lane=3, with_jtagbone=False, with_analyzer=False,
        with_endpoint=False, ltssm_autostart=False, hard_ip=False):
        SoCMini.__init__(self, platform, sys_clk_freq, ident="LitePCIe soft PHY bring-up on Acorn", ident_version=True)

        # CRG --------------------------------------------------------------------------------------
        self.crg = CRG(platform, sys_clk_freq)

        # Bone -------------------------------------------------------------------------------------
        if with_jtagbone:
            self.add_jtagbone()
        else:
            self.add_uartbone()

        # Soft PHY ---------------------------------------------------------------------------------
        # M.2 CLKREQ#: reference clock requested, as the Acorn target.
        self.comb += platform.request("pcie_clkreq_n").eq(0)
        platform.add_extension(pcie_x1_io(lane))
        pads = platform.request("pcie_soft_x1")
        if hard_ip:
            # Same design on the hard IP (resource/timing comparison).
            from litepcie.phy.s7pciephy import S7PCIEPHY
            self.pcie_phy = S7PCIEPHY(platform, pads, data_width=64, bar0_size=0x20000)
            self.add_pcie(phy=self.pcie_phy, ndmas=1, address_width=64, with_dma_loopback=True)
            return
        if with_endpoint:
            # Full LitePCIe endpoint: driver, MMAP, DMA and MSI as with the hard-IP PHYs.
            self.pcie_phy = pcie_phy = SoftPCIEPHY(platform, pads,
                data_width   = 64,
                bar0_size    = 0x20000,
                sys_clk_freq = sys_clk_freq,
                speedgrade   = -2,
            )
            pcie_phy.add_timing_constraints(self.crg.cd_sys.clk)
            pcie_phy.add_debug(enable_reset=int(ltssm_autostart))
            self.add_pcie(phy=pcie_phy, ndmas=1, address_width=64, with_dma_loopback=True)
            serdes, phy = pcie_phy.serdes, pcie_phy.phy_layer
        else:
            # Physical Layer alone: L0 against the host, received Symbols dropped.
            self.serdes = serdes = A7PCIeSerDes(platform, pads, sys_clk_freq, speedgrade=-2)
            self.phy    = phy    = PCIePhysicalLayer(serdes, 125e6, upstream=True)
            serdes.add_timing_constraints(self.crg.cd_sys.clk)
            self.pcie_phy = SoftPHYDebug(phy, serdes, enable_reset=int(ltssm_autostart))
            self.comb += phy.source.ready.eq(1)

        # Leds -------------------------------------------------------------------------------------
        leds = platform.request_all("user_led")
        self.comb += [
            leds[0].eq(~serdes.ready),
            leds[1].eq(~phy.ltssm.link_up),
            leds[2].eq(~phy.ltssm.l0),
        ]
        if len(leds) > 3:
            self.comb += leds[3].eq(~phy.ltssm.rx_elecidle)

        # Analyzer ---------------------------------------------------------------------------------
        if with_analyzer:
            from litescope import LiteScopeAnalyzer
            lane = serdes.lanes[0]
            ltssm_state = Signal(6)
            self.specials += MultiReg(phy.ltssm.state, ltssm_state, "pcie_pipe")
            analyzer_signals = [
                lane.source.valid, lane.source.data, lane.source.ctrl,
                lane.sink.valid,   lane.sink.data,   lane.sink.ctrl,
                lane.rx_elecidle, lane.tx_elecidle, lane.rx_errors, lane.ready,
                phy.ts_chk.detected, phy.ts_chk.error, phy.eios_det.detected,
                ltssm_state,
            ]
            self.analyzer = LiteScopeAnalyzer(analyzer_signals,
                depth        = 2048,
                clock_domain = "pcie_pipe",
                csr_csv      = "analyzer.csv",
            )

# Build --------------------------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Soft PCIe PHY bring-up on the SQRL Acorn.")
    parser.add_argument("--build",         action="store_true", help="Build bitstream.")
    parser.add_argument("--load",          action="store_true", help="Load bitstream (volatile).")
    parser.add_argument("--variant",       default="cle-215+",  help="Board variant (cle-101, cle-215, cle-215+).")
    parser.add_argument("--lane",          default=3, type=int, help="PCIe lane of the x4 connector used as x1 (pcie_x4 pin order).")
    parser.add_argument("--with-jtagbone", action="store_true", help="JTAGBone instead of UARTBone.")
    parser.add_argument("--with-analyzer", action="store_true", help="LiteScope analyzer on the lane.")
    parser.add_argument("--with-endpoint", action="store_true", help="Full LitePCIe endpoint (SoftPCIEPHY, MMAP, DMA, MSI).")
    parser.add_argument("--ltssm-autostart", action="store_true", help="LTSSM enabled at reset (else through the debug CSR).")
    parser.add_argument("--hard-ip",       action="store_true", help="Same endpoint on the hard IP (S7PCIEPHY), for comparison.")
    parser.add_argument("--driver",        action="store_true", help="Generate the PCIe driver.")
    parser.add_argument("--output-dir",    default="build/soft_acorn", help="Build directory.")
    args = parser.parse_args()

    platform = sqrl_acorn.Platform(variant=args.variant)
    soc      = SoftPHYSoC(platform,
        lane          = args.lane,
        with_jtagbone = args.with_jtagbone,
        with_analyzer = args.with_analyzer,
        with_endpoint = args.with_endpoint,
        hard_ip       = args.hard_ip,
        ltssm_autostart = args.ltssm_autostart,
    )
    builder = Builder(soc, output_dir=args.output_dir, csr_csv="csr.csv")
    builder.build(run=args.build)

    if args.driver:
        generate_litepcie_software(soc, os.path.join(builder.output_dir, "driver"))

    if args.load:
        prog = soc.platform.create_programmer()
        prog.load_bitstream(builder.get_bitstream_filename(mode="sram"))

if __name__ == "__main__":
    main()
