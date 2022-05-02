#!/usr/bin/env python3

#
# This file is part of LitePCIe.
#
# Copyright (c) 2022 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import os
import yaml
import argparse

from migen import *

from litex_boards.platforms import sqrl_acorn

from litex.soc.cores.clock import S7PLL
from litex.soc.interconnect.csr import *
from litex.soc.integration.soc_core import *
from litex.soc.integration.builder import *

from litepcie.phy import s7pciephy

class Open(Signal): pass

# CRG ----------------------------------------------------------------------------------------------

class _CRG(Module):
    def __init__(self, platform, sys_clk_freq):
        self.clock_domains.cd_sys = ClockDomain()

        # # #

        # PLL
        self.submodules.pll = pll = S7PLL(speedgrade=-2)
        pll.register_clkin(platform.request("clk200"), 200e6)
        pll.create_clkout(self.cd_sys, sys_clk_freq)

# LitePCIeSoC --------------------------------------------------------------------------------------

class LitePCIeSoC(SoCMini):
    def __init__(self,  platform, sys_clk_freq=int(125e6)):
        # CRG --------------------------------------------------------------------------------------
        self.submodules.crg = _CRG(platform, sys_clk_freq)

        # SoCMini ----------------------------------------------------------------------------------
        SoCMini.__init__(self, platform, sys_clk_freq, ident="LitePCIe standalone example design on Acorn")

        # LitePCIe core generation -----------------------------------------------------------------
        core_config = yaml.load(open("../examples/acorn.yml").read(), Loader=yaml.Loader)
        os.system("litepcie_gen ../examples/acorn.yml")

        # LitePCIe instance ------------------------------------------------------------------------
        pcie_pads  = platform.request("pcie_x4")
        litepcie_core_params = dict(
            # Clk / Rst ----------------------------------------------------------------------------
            i_clk                    = ClockSignal("sys"),
            i_rst                    = ResetSignal("sys"),

            # PCIe pins ----------------------------------------------------------------------------
            i_pcie_rst_n             = pcie_pads.rst_n,
            i_pcie_clk_p             = pcie_pads.clk_p,
            i_pcie_clk_n             = pcie_pads.clk_n,
            i_pcie_rx_p              = pcie_pads.rx_p,
            i_pcie_rx_n              = pcie_pads.rx_n,
            o_pcie_tx_p              = pcie_pads.tx_p,
            o_pcie_tx_n              = pcie_pads.tx_n,

            # AXI MMAP -----------------------------------------------------------------------------
            o_mmap_axi_lite_awvalid  = Open(),
            i_mmap_axi_lite_awready  = 1,
            o_mmap_axi_lite_awaddr   = Open(),

            o_mmap_axi_lite_wvalid   = Open(),
            i_mmap_axi_lite_wready   = 0,
            o_mmap_axi_lite_wstrb    = Open(),
            o_mmap_axi_lite_wdata    = Open(),

            i_mmap_axi_lite_bvalid   = 0,
            o_mmap_axi_lite_bready   = Open(),
            i_mmap_axi_lite_bresp    = 0,

            o_mmap_axi_lite_arvalid  = Open(),
            i_mmap_axi_lite_arready  = 0,
            o_mmap_axi_lite_araddr   = Open(),

            i_mmap_axi_lite_rvalid   = 0,
            o_mmap_axi_lite_rready   = Open(),
            i_mmap_axi_lite_rdata    = 0,
            i_mmap_axi_lite_rresp    = 0,

            # AXI ST DMA0 --------------------------------------------------------------------------
            i_dma0_writer_axi_tvalid = 0,
            o_dma0_writer_axi_tready = Open(),
            i_dma0_writer_axi_tlast  = 0,
            i_dma0_writer_axi_tdata  = 0,

            o_dma0_reader_axi_tvalid = Open(),
            i_dma0_reader_axi_tready = 0,
            o_dma0_reader_axi_tlast  = Open(),
            o_dma0_reader_axi_tdata  = Open(),

            # AXI ST DMA1 --------------------------------------------------------------------------
            i_dma1_writer_axi_tvalid = 0,
            o_dma1_writer_axi_tready = Open(),
            i_dma1_writer_axi_tlast  = 0,
            i_dma1_writer_axi_tdata  = 0,

            o_dma1_reader_axi_tvalid = Open(),
            i_dma1_reader_axi_tready = 0,
            o_dma1_reader_axi_tlast  = Open(),
            o_dma1_reader_axi_tdata  = Open(),

            # AXI ST DMA2 --------------------------------------------------------------------------
            i_dma2_writer_axi_tvalid = 0,
            o_dma2_writer_axi_tready = Open(),
            i_dma2_writer_axi_tlast  = 0,
            i_dma2_writer_axi_tdata  = 0,

            o_dma2_reader_axi_tvalid = Open(),
            i_dma2_reader_axi_tready = 0,
            o_dma2_reader_axi_tlast  = Open(),
            o_dma2_reader_axi_tdata  = Open(),

            # AXI ST DMA3 --------------------------------------------------------------------------
            i_dma3_writer_axi_tvalid = 0,
            o_dma3_writer_axi_tready = Open(),
            i_dma3_writer_axi_tlast  = 0,
            i_dma3_writer_axi_tdata  = 0,

            o_dma3_reader_axi_tvalid = Open(),
            i_dma3_reader_axi_tready = 0,
            o_dma3_reader_axi_tlast  = Open(),
            o_dma3_reader_axi_tdata  = Open(),

            # Interrupts ---------------------------------------------------------------------------
            i_msi_irqs               = 0,
        )
        self.specials += Instance("litepcie_core", **litepcie_core_params)
        platform.add_period_constraint(pcie_pads.clk_p, 1e9/100e6)
        platform.toolchain.pre_placement_commands.append("set_false_path -from [get_clocks userclk2] -to [get_clocks litepciesoc_clkout]")
        platform.toolchain.pre_placement_commands.append("set_false_path -from [get_clocks litepciesoc_clkout] -to [get_clocks userclk2]")

        # LitePCIe sources -------------------------------------------------------------------------
        # LitePCIe core
        platform.add_source("build/gateware/litepcie_core.v")
        # Xilinx PHY
        phy_path = os.path.dirname(s7pciephy.__file__)
        platform.add_source(os.path.join(phy_path, "xilinx_s7_gen2", "pcie_pipe_clock.v"))
        platform.add_source(os.path.join(phy_path, "xilinx_s7_gen2", "pcie_s7_support.v"))
        config = {
                "Bar0_Scale"         : "Megabytes",
                "Bar0_Size"          : 128, # FIXME: Use core_config["phy_bar0_size"].
                "Buf_Opt_BMA"        : True,
                "Component_Name"     : "pcie",
                "Device_ID"          : 7024,
                "IntX_Generation"    : False,
                "Interface_Width"    : "128_bit",
                "Legacy_Interrupt"   : None,
                "Multiple_Message_Capable"  : '1_vector',
                "Link_Speed"         : "5.0_GT/s",
                "MSI_64b"            : False,
                "Max_Payload_Size"   : "512_bytes",
                "Maximum_Link_Width" : "X4",
                "PCIe_Blk_Locn"      : "X0Y0",
                "Ref_Clk_Freq"       : "100_MHz",
                "Trans_Buf_Pipeline" : None,
                "Trgt_Link_Speed"    : "4'h2",
                "User_Clk_Freq"      : 125,
            }
        ip_tcl = []
        ip_tcl.append("create_ip -vendor xilinx.com -name pcie_7x -module_name pcie_s7")
        ip_tcl.append("set obj [get_ips pcie_s7]")
        ip_tcl.append("set_property -dict [list \\")
        for config, value in config.items():
            ip_tcl.append("CONFIG.{} {} \\".format(config, '{{' + str(value) + '}}'))
        ip_tcl.append(f"] $obj")
        ip_tcl.append("synth_ip $obj")
        platform.toolchain.pre_synthesis_commands += ip_tcl

# Build --------------------------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="LitePCIe SoC on Acorn")
    parser.add_argument("--build",  action="store_true", help="Build bitstream")
    parser.add_argument("--load",   action="store_true", help="Load bitstream (to SRAM)")
    args = parser.parse_args()

    platform = sqrl_acorn.Platform()
    soc      = LitePCIeSoC(platform)
    builder  = Builder(soc)
    builder.build(run=args.build)

    if args.load:
        prog = soc.platform.create_programmer()
        prog.load_bitstream(os.path.join(builder.gateware_dir, soc.build_name + ".bit"))

if __name__ == "__main__":
    main()
