#!/usr/bin/env python3

#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY bring-up on the Alibaba Cloud KU3P board (Kintex UltraScale+ GTY), over JTAGBone.

By default, the soft Physical Layer alone: the host's root port sees the link in L0 with DLActive clear.
--with-endpoint: full endpoint (SoftPCIEPHY, MMAP, DMA, MSI). The debug CSRs and LTSSM tracer are always
there, LTSSM disabled at reset and by PERST# (--ltssm-autostart for enumeration at boot). Control and status
with bench/soft/status.py.

python3 bench/soft/ku3p.py [--with-endpoint] [--driver] --build
"""

import os
import argparse

from migen import *

from litex.gen import *

from litex_boards.platforms import alibaba_xcku3p

from litex.soc.cores.clock import *
from litex.soc.interconnect.csr import *
from litex.soc.integration.soc_core import SoCMini
from litex.soc.integration.builder import Builder

from litepcie.phy.soft.serdes.gty_ultrascale import USPPCIeSerDes
from litepcie.phy.soft.pipe                  import PCIePhysicalLayer
from litepcie.phy.soft.debug                 import SoftPHYDebug
from litepcie.phy.soft                       import SoftPCIEPHY
from litepcie.software                       import generate_litepcie_software

# CRG ----------------------------------------------------------------------------------------------

class CRG(LiteXModule):
    def __init__(self, platform, sys_clk_freq):
        self.cd_sys = ClockDomain()

        # # #

        self.pll = pll = USPMMCM(speedgrade=-2)
        pll.register_clkin(platform.request("clk100"), 100e6)
        pll.create_clkout(self.cd_sys, sys_clk_freq)

# Transceiver status -------------------------------------------------------------------------------

class GTStatus(LiteXModule, AutoCSR):
    def __init__(self, serdes):
        gt = serdes.gts[0]
        self._status = CSRStatus(fields=[
            CSRField("tx_ready",    size=1, offset=0),
            CSRField("rx_ready",    size=1, offset=1),
            CSRField("mmcm_locked", size=1, offset=2),
            CSRField("qpll_locked", size=1, offset=3),
        ])
        self.comb += [
            self._status.fields.tx_ready.eq(gt.tx_ready),
            self._status.fields.rx_ready.eq(gt.rx_ready),
            self._status.fields.mmcm_locked.eq(serdes.clocking.locked),
            self._status.fields.qpll_locked.eq(serdes.qpll0.lock),
        ]

# Soft PHY SoC -------------------------------------------------------------------------------------

class SoftPHYSoC(SoCMini):
    def __init__(self, platform, sys_clk_freq=int(125e6), with_endpoint=False, ltssm_autostart=False,
        speed="gen1", nlanes=1):
        SoCMini.__init__(self, platform, sys_clk_freq, ident="LitePCIe soft PHY bring-up on KU3P", ident_version=True)

        # CRG --------------------------------------------------------------------------------------
        self.crg = CRG(platform, sys_clk_freq)

        # JTAGBone ---------------------------------------------------------------------------------
        self.add_jtagbone()

        # PHY --------------------------------------------------------------------------------------
        pads = platform.request(f"pcie_x{nlanes}")
        if with_endpoint:
            # Full LitePCIe endpoint: driver, MMAP, DMA and MSI as with the hard-IP PHYs.
            self.pcie_phy = pcie_phy = SoftPCIEPHY(platform, pads,
                data_width   = 64 if nlanes == 1 else 32*nlanes*(2 if speed == "gen3" else 1),
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
            assert nlanes == 1 and speed != "gen3"
            gen2_capable = speed == "gen2"
            self.serdes = serdes = USPPCIeSerDes(platform, pads, sys_clk_freq, speedgrade=-2, rate_change=gen2_capable)
            self.phy    = phy    = PCIePhysicalLayer(serdes, 125e6, upstream=True, gen2_capable=gen2_capable)
            serdes.add_timing_constraints(self.crg.cd_sys.clk)
            self.pcie_phy = SoftPHYDebug(phy, serdes, enable_reset=int(ltssm_autostart))
            self.comb += phy.source.ready.eq(1)
        self.gt_status = GTStatus(serdes)

        # Clocks check: lane clock, Lane 0 recovered clock, 8.0 GT/s datapath (200 MHz at 8.0 GT/s).
        from litex.soc.cores.freqmeter import FreqMeter
        self.freq_pipe = FreqMeter(period=sys_clk_freq, clk=ClockSignal("pcie_pipe"))
        self.freq_rx0  = FreqMeter(period=sys_clk_freq, clk=ClockSignal("pcie_rx0"))
        if speed == "gen3":
            self.freq_g3 = FreqMeter(period=sys_clk_freq, clk=ClockSignal("pcie_g3"))

        # Leds -------------------------------------------------------------------------------------
        leds = platform.request_all("user_led")
        self.comb += [
            leds[0].eq(~serdes.ready),
            leds[1].eq(~phy.ltssm.link_up),
            leds[2].eq(~phy.ltssm.l0),
        ]

# Build --------------------------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Soft PCIe PHY bring-up on the Alibaba Cloud KU3P board.")
    parser.add_argument("--build",           action="store_true", help="Build bitstream.")
    parser.add_argument("--with-endpoint",   action="store_true", help="Full LitePCIe endpoint (SoftPCIEPHY, MMAP, DMA, MSI).")
    parser.add_argument("--ltssm-autostart", action="store_true", help="LTSSM enabled at reset, not disabled by PERST#.")
    parser.add_argument("--speed",           default="gen1", choices=["gen1", "gen2", "gen3"], help="Soft PHY maximum speed (gen3: --with-endpoint).")
    parser.add_argument("--nlanes",          default=1, type=int, choices=[1, 4, 8], help="Lanes.")
    parser.add_argument("--driver",          action="store_true", help="Generate the PCIe driver.")
    parser.add_argument("--output-dir",      default="build/soft_ku3p", help="Build directory.")
    args = parser.parse_args()

    platform = alibaba_xcku3p.Platform()
    soc      = SoftPHYSoC(platform,
        with_endpoint   = args.with_endpoint,
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
