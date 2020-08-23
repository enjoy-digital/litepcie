#!/usr/bin/env python3

#
# This file is part of LitePCIe.
#
# Copyright (c) 2019-2020 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""
LitePCIE standalone core generator

LitePCIe aims to be directly used as a python package when the SoC is created using LiteX. However,
for some use cases it could be interesting to generate a standalone verilog file of the core:
- integration of the core in a SoC using a more traditional flow.
- need to version/package the core.
- avoid Migen/LiteX dependencies.
- etc...

The standalone core is generated from a YAML configuration file that allows the user to generate
easily a custom configuration of the core.

Current version of the generator is limited to:
- Xilinx 7-Series.
- Xilinx Ultrascale.
- Altera Cyclone V.
"""

import yaml
import argparse
import subprocess

from migen import *
from migen.genlib.resetsync import AsyncResetSynchronizer
from migen.genlib.misc import WaitTimer

from litex.soc.cores.clock import *
from litex.soc.interconnect.csr import *
from litex.soc.interconnect import wishbone
from litex.soc.interconnect.axi import *
from litex.soc.integration.soc_core import *
from litex.soc.integration.builder import *

from litepcie.core import LitePCIeEndpoint, LitePCIeMSI, LitePCIeMSIMultiVector, LitePCIeMSIX
from litepcie.frontend.dma import LitePCIeDMA
from litepcie.frontend.wishbone import LitePCIeWishboneMaster, LitePCIeWishboneSlave
from litepcie.software import generate_litepcie_software_headers

from litex.build.generic_platform import *

# IOs/Interfaces -----------------------------------------------------------------------------------

def get_clkin_ios():
    return [
        # clk / rst
        ("clk", 0, Pins(1)),
        ("rst", 0, Pins(1))
    ]

def get_clkout_ios():
    return [
        # clk / rst
        ("clk125", 0, Pins(1)),
        ("rst125", 0, Pins(1))
    ]

def get_pcie_ios(phy_lanes=4):
    return [
        ("pcie", 0,
            Subsignal("rst_n", Pins(1)),
            Subsignal("clk_p", Pins(1)),
            Subsignal("clk_n", Pins(1)),
            Subsignal("rx_p",  Pins(phy_lanes)),
            Subsignal("rx_n",  Pins(phy_lanes)),
            Subsignal("tx_p",  Pins(phy_lanes)),
            Subsignal("tx_n",  Pins(phy_lanes)),
        ),
    ]

def get_axi_dma_ios(_id, dw):
    return [
        ("dma{}_writer_axi".format(_id), 0,
            Subsignal("tvalid", Pins(1)),
            Subsignal("tready", Pins(1)),
            Subsignal("tlast",  Pins(1)),
            Subsignal("tdata",  Pins(dw)),
            Subsignal("tuser",  Pins(1)), # first
        ),
        ("dma{}_reader_axi".format(_id), 0,
            Subsignal("tvalid", Pins(1)),
            Subsignal("tready", Pins(1)),
            Subsignal("tlast",  Pins(1)),
            Subsignal("tdata",  Pins(dw)),
            Subsignal("tuser",  Pins(1)), # first
        ),
    ]

def get_msi_irqs_ios(width=16):
    return [("msi_irqs", 0, Pins(width))]

# CRG ----------------------------------------------------------------------------------------------

class LitePCIeCRG(Module):
    def __init__(self, platform, sys_clk_freq, clk_external):
        self.clock_domains.cd_sys = ClockDomain()

        # # #

        if clk_external:
            platform.add_extension(get_clkin_ios())
            self.comb += self.cd_sys.clk.eq(platform.request("clk"))
            self.specials += AsyncResetSynchronizer(self.cd_sys, platform.request("rst"))
        else:
            platform.add_extension(get_clkout_ios())
            self.comb += self.cd_sys.clk.eq(ClockSignal("pcie"))
            self.comb += self.cd_sys.rst.eq(ResetSignal("pcie"))
            self.comb += platform.request("clk125").eq(ClockSignal("pcie"))
            self.comb += platform.request("rst125").eq(ResetSignal("pcie"))

# Core ---------------------------------------------------------------------------------------------

class LitePCIeCore(SoCMini):
    SoCMini.mem_map["csr"] = 0x00000000
    SoCMini.csr_map = {
        "ctrl":           0,
        "crg" :           1,
        "pcie_phy":       2,
        "pcie_msi":       3,
        "pcie_msi_table": 4,
    }
    def __init__(self, platform, core_config):
        platform.add_extension(get_pcie_ios(core_config["phy_lanes"]))
        for i in range(core_config["dma_channels"]):
            platform.add_extension(get_axi_dma_ios(i, core_config["phy_data_width"]))
        platform.add_extension(get_msi_irqs_ios(width=core_config["msi_irqs"]))
        sys_clk_freq = float(core_config.get("clk_freq", 125e6))

        # SoCMini ----------------------------------------------------------------------------------
        SoCMini.__init__(self, platform, clk_freq=sys_clk_freq,
            csr_data_width = 32,
            csr_ordering   = core_config.get("csr_ordering", "big"),
            ident          = "LitePCIe standalone core",
            ident_version  = True
        )

        # CRG --------------------------------------------------------------------------------------
        clk_external = core_config.get("clk_external", False)
        self.submodules.crg = LitePCIeCRG(platform, sys_clk_freq, clk_external)

        # PCIe PHY ---------------------------------------------------------------------------------
        self.submodules.pcie_phy = core_config["phy"](platform, platform.request("pcie"),
            pcie_data_width = core_config.get("phy_pcie_data_width", 64),
            data_width      = core_config["phy_data_width"],
            bar0_size       = core_config["phy_bar0_size"])

        # PCIe Endpoint ----------------------------------------------------------------------------
        self.submodules.pcie_endpoint = LitePCIeEndpoint(self.pcie_phy, endianness=core_config["endianness"])

        # PCIe Wishbone Master ---------------------------------------------------------------------
        pcie_wishbone_master = LitePCIeWishboneMaster(self.pcie_endpoint, qword_aligned=core_config["qword_aligned"])
        self.submodules += pcie_wishbone_master
        self.add_wb_master(pcie_wishbone_master.wishbone)

        # PCIe MMAP Master -------------------------------------------------------------------------
        if core_config.get("mmap", False):
            mmap_base        = core_config["mmap_base"]
            mmap_size        = core_config["mmap_size"]
            mmap_translation = core_config.get("mmap_translation", 0x00000000)
            wb = wishbone.Interface(data_width=32)
            self.mem_map["mmap"] = mmap_base
            self.add_wb_slave(mmap_base, wb, mmap_size)
            self.add_memory_region("mmap", mmap_base, mmap_size, type="io")
            axi = AXILiteInterface(data_width=32, address_width=32)
            wb2axi = Wishbone2AXILite(wb, axi, base_address=-mmap_translation)
            self.submodules += wb2axi
            platform.add_extension(axi.get_ios("mmap_axi_lite"))
            axi_pads = platform.request("mmap_axi_lite")
            self.comb += axi.connect_to_pads(axi_pads, mode="master")

        # PCIe MMAP Slave --------------------------------------------------------------------------
        if core_config.get("mmap_slave", False):
            platform.add_extension(axi.get_ios("mmap_slave_axi_lite"))
            axi_pads = platform.request("mmap_slave_axi_lite")
            axi = AXILiteInterface(data_width=32, address_width=32)
            self.comb += axi.connect_to_pads(axi_pads, mode="slave")
            axi2wb = AXILite2Wishbone(axi, wb)
            self.submodules += axi2wb
            pcie_wishbone_slave = LitePCIeWishboneSlave(self.pcie_endpoint, qword_aligned=core_config["qword_aligned"])
            self.submodules += pcie_wishbone_slave
            self.comb += wb.connect(pcie_wishbone_slave.wishbone)

        # PCIe DMA ---------------------------------------------------------------------------------
        pcie_dmas = []
        self.add_constant("DMA_CHANNELS", core_config["dma_channels"])
        for i in range(core_config["dma_channels"]):
            pcie_dma = LitePCIeDMA(self.pcie_phy, self.pcie_endpoint,
                with_buffering    = core_config["dma_buffering"] != 0,
                buffering_depth   = core_config["dma_buffering"],
                with_loopback     = core_config["dma_loopback"],
                with_synchronizer = core_config["dma_synchronizer"],
                with_monitor      = core_config["dma_monitor"])
            pcie_dma = stream.BufferizeEndpoints({"sink"   : stream.DIR_SINK})(pcie_dma)
            pcie_dma = stream.BufferizeEndpoints({"source" : stream.DIR_SOURCE})(pcie_dma)
            setattr(self.submodules, "pcie_dma" + str(i), pcie_dma)
            self.add_csr("pcie_dma{}".format(i))
            dma_writer_ios = platform.request("dma{}_writer_axi".format(i))
            dma_reader_ios = platform.request("dma{}_reader_axi".format(i))
            self.add_interrupt("pcie_dma{}_writer".format(i))
            self.add_interrupt("pcie_dma{}_reader".format(i))
            self.comb += [
                # Writer IOs
                pcie_dma.sink.valid.eq(dma_writer_ios.tvalid),
                dma_writer_ios.tready.eq(pcie_dma.sink.ready),
                pcie_dma.sink.last.eq(dma_writer_ios.tlast),
                pcie_dma.sink.data.eq(dma_writer_ios.tdata),
                pcie_dma.sink.first.eq(dma_writer_ios.tuser),

                # Reader IOs
                dma_reader_ios.tvalid.eq(pcie_dma.source.valid),
                pcie_dma.source.ready.eq(dma_reader_ios.tready),
                dma_reader_ios.tlast.eq(pcie_dma.source.last),
                dma_reader_ios.tdata.eq(pcie_dma.source.data),
                dma_reader_ios.tuser.eq(pcie_dma.source.first),
            ]

        # PCIe MSI ---------------------------------------------------------------------------------
        if core_config.get("msi_x", False):
            assert core_config["msi_irqs"] <= 32
            self.submodules.pcie_msi = LitePCIeMSIX(self.pcie_endpoint, width=64)
            self.comb += self.pcie_msi.irqs[32:32+core_config["msi_irqs"]].eq(platform.request("msi_irqs"))
        else:
            assert core_config["msi_irqs"] <= 16
            if core_config.get("msi_multivector", False):
                self.submodules.pcie_msi = LitePCIeMSIMultiVector(width=32)
            else:
                self.submodules.pcie_msi = LitePCIeMSI(width=32)
            self.comb += self.pcie_msi.source.connect(self.pcie_phy.msi)
            self.comb += self.pcie_msi.irqs[16:16+core_config["msi_irqs"]].eq(platform.request("msi_irqs"))
        self.interrupts = {}
        for i in range(core_config["dma_channels"]):
            self.interrupts["pcie_dma" + str(i) + "_writer"] = getattr(self, "pcie_dma" + str(i)).writer.irq
            self.interrupts["pcie_dma" + str(i) + "_reader"] = getattr(self, "pcie_dma" + str(i)).reader.irq
        for i, (k, v) in enumerate(sorted(self.interrupts.items())):
            self.comb += self.pcie_msi.irqs[i].eq(v)
            self.add_constant(k.upper() + "_INTERRUPT", i)
        assert len(self.interrupts.keys()) <= 16

    def generate_documentation(self, build_name, **kwargs):
        from litex.soc.doc import generate_docs
        generate_docs(self, "documentation".format(build_name),
            project_name = "LitePCIe standalone core",
            author       = "Enjoy-Digital")
        os.system("sphinx-build -M html documentation/ documentation/_build".format(build_name, build_name))

# Build --------------------------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="LitePCIe standalone core generator")
    parser.add_argument("config", help="YAML config file")
    parser.add_argument("--doc",  action="store_true", help="Build documentation")
    args = parser.parse_args()
    core_config = yaml.load(open(args.config).read(), Loader=yaml.Loader)

    # Convert YAML elements to Python/LiteX --------------------------------------------------------
    for k, v in core_config.items():
        replaces = {"False": False, "True": True, "None": None}
        for r in replaces.keys():
            if v == r:
                core_config[k] = replaces[r]

    # Generate core --------------------------------------------------------------------------------
    if core_config["phy"]  == "C5PCIEPHY":
        from litex.build.altera import AlteraPlatform
        from litepcie.phy.c5pciephy import C5PCIEPHY
        platform = AlteraPlatform("", io=[])
        core_config["phy"]           = C5PCIEPHY
        core_config["qword_aligned"] = True
        core_config["endianness"]    = "little"
    elif core_config["phy"] == "S7PCIEPHY":
        from litex.build.xilinx import XilinxPlatform
        from litepcie.phy.s7pciephy import S7PCIEPHY
        platform = XilinxPlatform(core_config["phy_device"], io=[], toolchain="vivado")
        core_config["phy"]           = S7PCIEPHY
        core_config["qword_aligned"] = False
        core_config["endianness"]    = "big"
    elif core_config["phy"] == "USPCIEPHY":
        from litex.build.xilinx import XilinxPlatform
        from litepcie.phy.uspciephy import USPCIEPHY
        platform = XilinxPlatform(core_config["phy_device"], io=[], toolchain="vivado")
        core_config["phy"]           = USPCIEPHY
        core_config["qword_aligned"] = False
        core_config["endianness"]    = "little"
    elif core_config["phy"] == "USPPCIEPHY":
        from litex.build.xilinx import XilinxPlatform
        from litepcie.phy.uspciephy import USPPCIEPHY
        platform = XilinxPlatform(core_config["phy_device"], io=[], toolchain="vivado")
        core_config["phy"]           = USPPCIEPHY
        core_config["qword_aligned"] = False
        core_config["endianness"]    = "little"
    else:
        raise ValueError("Unsupported PCIe PHY: {}".format(core_config["phy"]))
    soc      = LitePCIeCore(platform, core_config)
    builder  = Builder(soc, output_dir="build", compile_gateware=False)
    builder.build(build_name="litepcie_core", regular_comb=True)
    generate_litepcie_software_headers(soc, "./")

    if args.doc:
        soc.generate_documentation("litepcie_core")

if __name__ == "__main__":
    main()
