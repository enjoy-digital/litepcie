#!/usr/bin/env python3

#
# This file is part of LitePCIe.
#
# Copyright (c) 2020 Florent Kermarrec <florent@enjoy-digital.fr>
# Copyright (c) 2020 Antmicro <www.antmicro.com>
# SPDX-License-Identifier: BSD-2-Clause

import os
import argparse

from migen import *

from litex_boards.platforms import profpga_xcvu19p

from litex.soc.cores.clock import USPPLL
from litex.soc.interconnect.csr import *
from litex.soc.integration.soc_core import *
from litex.soc.integration.builder import *

from litepcie.phy.usppciephy import USP19PPCIEPHY
from litepcie.core import LitePCIeEndpoint, LitePCIeMSI
from litepcie.frontend.dma import LitePCIeDMA
from litepcie.frontend.wishbone import LitePCIeWishboneBridge
from litepcie.software import generate_litepcie_software

# CRG ----------------------------------------------------------------------------------------------

class _CRG(Module):
    def __init__(self, platform, sys_clk_freq):
        self.clock_domains.cd_sys = ClockDomain()

        # # #

        # PLL
        self.submodules.pll = pll = USPPLL(speedgrade=-2)
        pll.register_clkin(platform.request("clk300"), 300e6)
        pll.create_clkout(self.cd_sys, sys_clk_freq)

# LitePCIeSoC --------------------------------------------------------------------------------------

class LitePCIeSoC(SoCMini):
    configs = {
        # Gen3  data_width, sys_clk_freq
        "gen3:x4" : (128, int(125e6)),
        "gen3:x8" : (256, int(125e6)),
        # Gen4  data_width, sys_clk_freq
        "gen4:x4" : (256, int(125e6)),
    }
    def __init__(self, platform, speed="gen3", nlanes=4):
        data_width, sys_clk_freq = self.configs[speed + ":x{}".format(nlanes)]

        # SoCMini ----------------------------------------------------------------------------------
        SoCMini.__init__(self, platform, sys_clk_freq,
            csr_data_width = 32,
            ident          = "LitePCIe example design on proFPGA XCVU19P ({}:x{})".format(speed, nlanes),
            ident_version  = True,
            with_uart      = True,
            uart_name      = "bridge")

        # CRG --------------------------------------------------------------------------------------
        self.submodules.crg = _CRG(platform, sys_clk_freq)
        self.add_csr("crg")

        # PCIe -------------------------------------------------------------------------------------
        # PHY
        self.submodules.pcie_phy = USP19PPCIEPHY(platform, platform.request("pcie_x" + str(nlanes)),
            speed      = speed,
            data_width = data_width,
            bar0_size  = 0x20000,
        )
        platform.add_false_path_constraints(self.crg.cd_sys.clk, self.pcie_phy.cd_pcie.clk)
        self.add_csr("pcie_phy")

        # Endpoint
        self.submodules.pcie_endpoint = LitePCIeEndpoint(self.pcie_phy,
            endianness           = "little",
            max_pending_requests = 8
        )

        # Wishbone bridge
        self.submodules.pcie_bridge = LitePCIeWishboneBridge(self.pcie_endpoint,
            base_address = self.mem_map["csr"])
        self.add_wb_master(self.pcie_bridge.wishbone)

        # DMA0
        self.submodules.pcie_dma0 = LitePCIeDMA(self.pcie_phy, self.pcie_endpoint,
            with_buffering = True, buffering_depth=1024,
            with_loopback  = True)
        self.add_csr("pcie_dma0")

        # DMA1
        self.submodules.pcie_dma1 = LitePCIeDMA(self.pcie_phy, self.pcie_endpoint,
            with_buffering = True, buffering_depth=1024,
            with_loopback  = True)
        self.add_csr("pcie_dma1")

        self.add_constant("DMA_CHANNELS", 2)

        # MSI
        self.submodules.pcie_msi = LitePCIeMSI()
        self.add_csr("pcie_msi")
        self.comb += self.pcie_msi.source.connect(self.pcie_phy.msi)
        self.interrupts = {
            "PCIE_DMA0_WRITER":    self.pcie_dma0.writer.irq,
            "PCIE_DMA0_READER":    self.pcie_dma0.reader.irq,
            "PCIE_DMA1_WRITER":    self.pcie_dma1.writer.irq,
            "PCIE_DMA1_READER":    self.pcie_dma1.reader.irq,
        }
        for i, (k, v) in enumerate(sorted(self.interrupts.items())):
            self.comb += self.pcie_msi.irqs[i].eq(v)
            self.add_constant(k + "_INTERRUPT", i)

# Build --------------------------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="LitePCIe SoC on proFPGA XCVU19P")
    parser.add_argument("--build",  action="store_true", help="Build bitstream")
    parser.add_argument("--driver", action="store_true", help="Generate LitePCIe driver")
    parser.add_argument("--load",   action="store_true", help="Load bitstream (to SRAM)")
    parser.add_argument("--speed",  default="gen3",      help="PCIe speed: gen3 (default) or gen4")
    parser.add_argument("--nlanes", default=4,           help="PCIe lanes: 4 (default) or 8")
    args = parser.parse_args()

    platform = profpga_xcvu19p.Platform()
    soc      = LitePCIeSoC(platform, speed=args.speed, nlanes=int(args.nlanes))
    builder  = Builder(soc, csr_csv="csr.csv")
    builder.build(run=args.build)

    if args.driver:
        generate_litepcie_software(soc, os.path.join(builder.output_dir, "driver"))

    if args.load:
        prog = soc.platform.create_programmer()
        prog.load_bitstream(os.path.join(builder.gateware_dir, soc.build_name + ".bit"))

if __name__ == "__main__":
    main()
