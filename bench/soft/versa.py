#!/usr/bin/env python3

#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Dirk Eibach
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY bring-up on the Lattice ECP5 Versa board (LFE5UM-45F, Gen1 x1), over UARTBone.

Full endpoint (SoftPCIEPHY on the ECP5 PCIeSerDes, 128 KB BAR0, one DMA channel with its loopback, MSI). The
debug CSRs and LTSSM tracer are always there, the LTSSM is disabled at reset and by PERST# (--ltssm-autostart for
enumeration at boot). Control and status with bench/soft/status.py.

Board and host:
- Jumper J4 on pins 3 and 5 (the PRSNT net grounded) so that the clock manager passes the slot's 100 MHz
  reference clock. A card that does not link during the host's POST may be hidden by the BIOS: put the bitstream
  in the SPI flash (--flash-freq 62.0: the FPGA reads it at 62 MHz) with --ltssm-autostart, and cold boot the host.
- The FPGA must not be reconfigured while the host runs with the card enumerated.
- pcie_link is 75 MHz (the Data Link Layer does not close timing at 125 MHz on this device) and sys 62.5 MHz from the local
  oscillator (the DMA logic of the endpoint does not close timing reliably at 75 MHz). The soft PHY crosses between them.

python3 bench/soft/versa.py [--analog wizard|default] [--with-analyzer] [--driver] --build
"""

import os
import argparse

from migen import *
from migen.genlib.cdc import MultiReg

from litex.gen import *

from litex_boards.platforms import lattice_versa_ecp5

from litex.soc.cores.clock import ECP5PLL
from litex.soc.integration.soc_core import SoCMini
from litex.soc.integration.builder import Builder

from litepcie.phy.soft                   import SoftPCIEPHY
from litepcie.phy.soft.serdes.ecp5       import ECP5PCIeSerDes
from litepcie.software                   import generate_litepcie_software

# CRG ----------------------------------------------------------------------------------------------

class CRG(LiteXModule):
    """sys from the local oscillator (independent from the host's reference clock: debug works without the slot)."""
    def __init__(self, platform, sys_clk_freq):
        self.cd_sys = ClockDomain()

        # # #

        self.pll = pll = ECP5PLL()
        pll.register_clkin(platform.request("clk100"), 100e6)
        pll.create_clkout(self.cd_sys, sys_clk_freq)

# Soft PHY SoC -------------------------------------------------------------------------------------

class SoftPHYSoC(SoCMini):
    def __init__(self, platform, sys_clk_freq=int(62.5e6), link_freq=75e6, ltssm_autostart=False, analog="wizard",
        with_analyzer=False, vendor_id=0x1204, device_id=0xec11):
        SoCMini.__init__(self, platform, sys_clk_freq, ident="LitePCIe soft PHY bring-up on Versa ECP5", ident_version=True)

        # CRG --------------------------------------------------------------------------------------
        self.crg = CRG(platform, sys_clk_freq)

        # UARTBone ---------------------------------------------------------------------------------
        self.add_uartbone()

        # Reference clock generator (ispCLOCK) enable and reset: without them the SERDES refclk pins
        # stay without a clock.
        self.comb += [
            platform.request("refclk_en").eq(1),
            platform.request("refclk_rst_n").eq(1),
        ]

        # PHY --------------------------------------------------------------------------------------
        pads = platform.request("pcie_x1")
        self.serdes   = serdes = ECP5PCIeSerDes(platform, pads, link_freq=link_freq, analog=analog)
        self.pcie_phy = pcie_phy = SoftPCIEPHY(platform, pads, serdes=serdes,
            data_width = 64,
            bar0_size  = 0x20000,
            link_freq  = link_freq,
            vendor_id  = vendor_id,
            device_id  = device_id,
        )
        pcie_phy.add_timing_constraints(self.crg.cd_sys.clk)
        pcie_phy.add_debug(enable_reset=int(ltssm_autostart))
        pcie_phy.add_ltssm_tracer()
        self.add_pcie(phy=pcie_phy, ndmas=1, address_width=64, with_dma_loopback=True)

        # Leds (active low) ------------------------------------------------------------------------
        # 0 TX ready, 1 RX locked, 2 PERST# asserted, 3 receiver detected, 4 RX idle, 5 link up, 6 L0,
        # 7 heartbeat (the bitstream runs, no slot needed).
        leds = platform.request_all("user_led")
        phy  = pcie_phy.phy_layer
        lane = serdes.lanes[0]
        detected = Signal()
        self.sync.pcie_pipe += If(lane.detect_done, detected.eq(lane.rx_detected))
        heartbeat = Signal(26)
        self.sync += heartbeat.eq(heartbeat + 1)
        self.comb += [
            leds[0].eq(~serdes.ready),
            leds[1].eq(~serdes.rx_ready),
            leds[2].eq(~serdes.perst),
            leds[3].eq(~detected),
            leds[4].eq(~lane.rx_elecidle),
            leds[5].eq(~phy.ltssm.link_up),
            leds[6].eq(~phy.ltssm.l0),
            leds[7].eq(~heartbeat[25]),
        ]

        # Analyzer ---------------------------------------------------------------------------------
        # LiteScope on the lane: Symbols, Electrical Idle, errors, TS detection and the LTSSM state.
        if with_analyzer:
            from litescope import LiteScopeAnalyzer
            ltssm_state = Signal(6)
            self.specials += MultiReg(phy.ltssm.state, ltssm_state, "pcie_pipe")
            self.analyzer = LiteScopeAnalyzer([
                    lane.source.valid, lane.source.data, lane.source.ctrl,
                    lane.sink.valid,   lane.sink.data,   lane.sink.ctrl,
                    lane.rx_elecidle,  lane.tx_elecidle, lane.rx_errors, lane.ready,
                    lane.tx_detect_rx, lane.detect_done, lane.rx_detected,
                    phy.ts_chk.detected, phy.ts_chk.error, phy.eios_det.detected,
                    ltssm_state,
                ],
                depth        = 1024,
                clock_domain = "pcie_pipe",
                csr_csv      = "analyzer.csv",
            )

# Build --------------------------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Soft PCIe PHY bring-up on the Lattice ECP5 Versa board.")
    parser.add_argument("--build",           action="store_true", help="Build bitstream.")
    parser.add_argument("--sys-clk-freq",    default=62.5e6, type=float, help="System clock (Hz).")
    parser.add_argument("--link-freq",       default=75e6, type=float, help="pcie_link clock (Hz).")
    parser.add_argument("--analog",          default="wizard", choices=["wizard", "default"], help="DCU analog set.")
    parser.add_argument("--vendor-id",       default=0x1204, type=lambda x: int(x, 0), help="PCI vendor ID (Lattice).")
    parser.add_argument("--device-id",       default=0xec11, type=lambda x: int(x, 0), help="PCI device ID (ECP5 Gen1 x1).")
    parser.add_argument("--with-analyzer",   action="store_true", help="LiteScope analyzer on the lane.")
    parser.add_argument("--ltssm-autostart", action="store_true", help="LTSSM enabled at reset, not disabled by PERST#.")
    parser.add_argument("--flash-freq",      default=None, type=float, help="SPI flash read frequency (MHz), 62.0 for flash.")
    parser.add_argument("--seed",            default=1, type=int, help="nextpnr seed.")
    parser.add_argument("--driver",          action="store_true", help="Generate the PCIe driver.")
    parser.add_argument("--output-dir",      default="build/soft_versa", help="Build directory.")
    args = parser.parse_args()

    platform = lattice_versa_ecp5.Platform(device="LFE5UM", toolchain="trellis")
    soc      = SoftPHYSoC(platform,
        sys_clk_freq    = int(args.sys_clk_freq),
        link_freq       = args.link_freq,
        analog          = args.analog,
        with_analyzer   = args.with_analyzer,
        ltssm_autostart = args.ltssm_autostart,
        vendor_id       = args.vendor_id,
        device_id       = args.device_id,
    )
    builder = Builder(soc, output_dir=args.output_dir, csr_csv=os.path.join(args.output_dir, "csr.csv"))
    builder.build(run=args.build, seed=args.seed, **({} if args.flash_freq is None else {"freq": args.flash_freq}))

    if args.driver:
        generate_litepcie_software(soc, os.path.join(builder.output_dir, "driver"))

if __name__ == "__main__":
    main()
