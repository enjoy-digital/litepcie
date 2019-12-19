#!/usr/bin/env python3

# This file is Copyright (c) 2019 Florent Kermarrec <florent@enjoy-digital.fr>
# License: BSD

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

Current version of the generator is limited to Xilinx 7-Series FPGA / Altera Cyclone V.
"""

import yaml
import argparse

from migen import *

from litex.soc.interconnect.csr import *
from litex.soc.interconnect import wishbone
from litex.soc.interconnect.axi import *
from litex.soc.integration.soc_core import *
from litex.soc.integration.builder import *
from litex.soc.integration.export import get_csr_header, get_soc_header

from litepcie.core import LitePCIeEndpoint, LitePCIeMSI
from litepcie.frontend.dma import LitePCIeDMA
from litepcie.frontend.wishbone import LitePCIeWishboneBridge

from litex.build.generic_platform import *

# IOs/Interfaces -----------------------------------------------------------------------------------

def get_common_ios():
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

def get_axi_lite_mmap_ios(aw, dw):
    return [
        ("mmap_axi_lite", 0,
            # aw
            Subsignal("aw_valid", Pins(1)),
            Subsignal("aw_ready", Pins(1)),
            Subsignal("aw_addr",  Pins(aw)),

            # w
            Subsignal("w_valid", Pins(1)),
            Subsignal("w_ready", Pins(1)),
            Subsignal("w_strb",  Pins(dw//8)),
            Subsignal("w_data",  Pins(dw)),

            # b
            Subsignal("b_valid", Pins(1)),
            Subsignal("b_ready", Pins(1)),
            Subsignal("b_resp",  Pins(2)),

            # ar
            Subsignal("ar_valid", Pins(1)),
            Subsignal("ar_ready", Pins(1)),
            Subsignal("ar_addr",  Pins(aw)),

            # r
            Subsignal("r_valid", Pins(1)),
            Subsignal("r_ready", Pins(1)),
            Subsignal("r_resp",  Pins(2)),
        ),
    ]

def get_axi_dma_ios(_id, dw):
    return [
        ("dma{}_writer_axi".format(_id), 0,
            Subsignal("tvalid", Pins(1)),
            Subsignal("tready", Pins(1)),
            Subsignal("tlast",  Pins(1)),
            Subsignal("tdata",  Pins(dw)),
        ),
        ("dma{}_reader_axi".format(_id), 0,
            Subsignal("tvalid", Pins(1)),
            Subsignal("tready", Pins(1)),
            Subsignal("tlast",  Pins(1)),
            Subsignal("tdata",  Pins(dw)),
        ),
    ]

def get_msi_irqs_ios(width=16):
    return [("msi_irqs", 0, Pins(width))]

# CRG ----------------------------------------------------------------------------------------------

class LitePCIeCRG(Module):
    def __init__(self, platform, sys_clk_freq):
        assert sys_clk_freq == 125e6
        self.rst = CSR() # not used

        # # #

        clk125 = platform.request("clk125")
        platform.add_period_constraint(clk125, 1e9/125e6)

        self.clock_domains.cd_sys = ClockDomain()
        self.comb += self.cd_sys.clk.eq(clk125)

# Core ---------------------------------------------------------------------------------------------

class LitePCIeCore(SoCMini):
    SoCMini.mem_map["csr"] = 0x00000000
    def __init__(self, platform, core_config):
        platform.add_extension(get_common_ios())
        platform.add_extension(get_pcie_ios(core_config["phy_lanes"]))
        for i in range(core_config["dma_channels"]):
            platform.add_extension(get_axi_dma_ios(i, 64))
        assert core_config["msi_irqs"] <= 16
        platform.add_extension(get_msi_irqs_ios(width=core_config["msi_irqs"]))
        sys_clk_freq = int(125e6)

        # SoCMini ----------------------------------------------------------------------------------
        SoCMini.__init__(self, platform, clk_freq=sys_clk_freq, csr_data_width = 32,
            ident="LitePCIe generated core", ident_version=True)

        # CRG --------------------------------------------------------------------------------------
        self.submodules.crg = LitePCIeCRG(platform, sys_clk_freq)
        self.add_csr("crg")

        # PCIe PHY ---------------------------------------------------------------------------------
        self.submodules.pcie_phy = core_config["phy"](platform, platform.request("pcie"),
            data_width=core_config["phy_data_width"], bar0_size=0x20000)
        self.pcie_phy.use_external_hard_ip("./")
        self.add_csr("pcie_phy")

        # PCIe Endpoint ----------------------------------------------------------------------------
        self.submodules.pcie_endpoint = LitePCIeEndpoint(self.pcie_phy, endianness="little")

        # PCIe Wishbone bridge ---------------------------------------------------------------------
        pcie_wishbone = LitePCIeWishboneBridge(self.pcie_endpoint, lambda a: 1,
            qword_aligned = core_config["qword_aligned"])
        self.submodules += pcie_wishbone
        self.add_wb_master(pcie_wishbone.wishbone)

        # PCIe MMAP --------------------------------------------------------------------------------
        if core_config["mmap"]:
            platform.add_extension(get_axi_lite_mmap_ios(aw=32, dw=32))
            wb = wishbone.Interface(data_width=32)
            self.add_wb_slave(core_config["mmap_base"], wb, core_config["mmap_size"])
            self.add_memory_region("mmap", core_config["mmap_base"], core_config["mmap_size"], type="io")
            axi = AXILiteInterface(data_width=32, address_width=32)
            wb2axi = Wishbone2AXILite(wb, axi)
            self.submodules += wb2axi
            mmap_ios = platform.request("mmap_axi_lite")
            self.comb += [
                # aw
                mmap_ios.aw_valid.eq(axi.aw.valid),
                axi.aw.ready.eq(mmap_ios.aw_ready),
                mmap_ios.aw_addr.eq(axi.aw.addr),

                # w
                mmap_ios.w_valid.eq(axi.w.valid),
                axi.w.ready.eq(mmap_ios.w_ready),
                mmap_ios.w_strb.eq(axi.w.strb),
                mmap_ios.w_data.eq(axi.w.data),

                # b
                axi.b.valid.eq(mmap_ios.b_valid),
                mmap_ios.b_ready.eq(axi.b.ready),
                axi.b.resp.eq(mmap_ios.b_resp),

                # ar
                mmap_ios.ar_valid.eq(axi.ar.valid),
                axi.ar.ready.eq(mmap_ios.ar_ready),
                mmap_ios.ar_addr.eq(axi.ar.addr),

                # r
                axi.r.valid.eq(mmap_ios.r_valid),
                mmap_ios.r_ready.eq(axi.r.ready),
                axi.r.resp.eq(mmap_ios.r_resp),
            ]

        # PCIe DMA ---------------------------------------------------------------------------------
        pcie_dmas = []
        for i in range(core_config["dma_channels"]):
            pcie_dma = LitePCIeDMA(self.pcie_phy, self.pcie_endpoint,
                with_buffering    = core_config["dma_buffering"] != 0,
                buffering_depth   = core_config["dma_buffering"],
                with_loopback     = core_config["dma_loopback"],
                with_synchronizer = core_config["dma_synchronizer"],
                with_monitor      = core_config["dma_monitor"])
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

                # Reader IOs
                dma_reader_ios.tvalid.eq(pcie_dma.source.valid),
                pcie_dma.source.ready.eq(dma_reader_ios.tready),
                dma_reader_ios.tlast.eq(pcie_dma.source.last),
                dma_reader_ios.tdata.eq(pcie_dma.source.data),
            ]

        # PCIe MSI ---------------------------------------------------------------------------------
        self.submodules.pcie_msi = LitePCIeMSI(width=32)
        self.add_csr("pcie_msi")
        self.comb += self.pcie_msi.source.connect(self.pcie_phy.msi)
        self.interrupts = {}
        for i in range(core_config["dma_channels"]):
            self.interrupts["pcie_dma" + str(i) + "_writer"] = getattr(self, "pcie_dma" + str(i)).writer.irq
            self.interrupts["pcie_dma" + str(i) + "_reader"] = getattr(self, "pcie_dma" + str(i)).reader.irq
        for i, (k, v) in enumerate(sorted(self.interrupts.items())):
            self.comb += self.pcie_msi.irqs[i].eq(v)
            self.add_constant(k.upper() + "_INTERRUPT", i)
        assert len(self.interrupts.keys()) <= 16
        self.comb += self.pcie_msi.irqs[16:16+core_config["msi_irqs"]].eq(platform.request("msi_irqs"))

    def generate_software_headers(self):
        csr_header = get_csr_header(self.csr_regions, self.constants, with_access_functions=False)
        tools.write_to_file(os.path.join("csr.h"), csr_header)
        soc_header = get_soc_header(self.constants, with_access_functions=False)
        tools.write_to_file(os.path.join("soc.h"), soc_header)

# Build --------------------------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="LitePCIe standalone core generator")
    parser.add_argument("config", help="YAML config file")
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
    elif core_config["phy"] == "S7PCIEPHY":
        from litex.build.xilinx import XilinxPlatform
        from litepcie.phy.s7pciephy import S7PCIEPHY
        platform = XilinxPlatform("xc7a", io=[])
        core_config["phy"]           = S7PCIEPHY
        core_config["qword_aligned"] = False
    else:
        raise ValueError("Unsupported PCIe PHY: {}".format(core_config["phy"]))
    soc      = LitePCIeCore(platform, core_config)
    builder  = Builder(soc, output_dir="build", compile_gateware=False)
    vns      = builder.build(build_name="litepcie_core", regular_comb=True)
    soc.generate_software_headers()

if __name__ == "__main__":
    main()
