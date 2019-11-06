# This file is Copyright (c) 2015-2019 Florent Kermarrec <florent@enjoy-digital.fr>
# License: BSD

from migen import *

from litex.soc.interconnect.csr import *

from litex.soc.integration.soc_core import SoCMini

from litepcie.phy.s7pciephy import S7PCIEPHY
from litepcie.core import LitePCIeEndpoint, LitePCIeMSI
from litepcie.frontend.dma import LitePCIeDMA
from litepcie.frontend.wishbone import LitePCIeWishboneBridge


class _CRG(Module, AutoCSR):
    def __init__(self, platform):
        self.clock_domains.cd_sys = ClockDomain("sys")
        self.comb += self.cd_sys.clk.eq(ClockSignal("pcie"))


class PCIeDMASoC(SoCMini):
    default_platform = "kc705"
    mem_map = {"csr": 0x00000000}
    def __init__(self, platform):
        sys_clk_freq = int(125e6)
        SoCMini.__init__(self, platform, sys_clk_freq, csr_data_width=32,
            ident="LitePCIe example design", ident_version=True)

        # CRG --------------------------------------------------------------------------------------
        self.submodules.crg = _CRG(platform)

        # PCIe PHY ---------------------------------------------------------------------------------
        self.submodules.pcie_phy = S7PCIEPHY(platform, platform.request("pcie_x1"))
        self.add_csr("pcie_phy")

        # PCIe Endpoint ----------------------------------------------------------------------------
        self.submodules.pcie_endpoint = LitePCIeEndpoint(self.pcie_phy)

        # PCIe Wishbone bridge ---------------------------------------------------------------------
        self.submodules.pcie_bridge = LitePCIeWishboneBridge(self.pcie_endpoint, lambda a: 1)
        self.add_wb_master(self.pcie_bridge.wishbone)

        # PCIe DMA ---------------------------------------------------------------------------------
        self.submodules.pcie_dma = LitePCIeDMA(self.pcie_phy, self.pcie_endpoint, with_loopback=True)
        self.add_csr("pcie_dma")

        # PCIe MSI ---------------------------------------------------------------------------------
        self.submodules.pcie_msi = LitePCIeMSI()
        self.add_csr("pcie_msi")
        self.comb += self.pcie_msi.source.connect(self.pcie_phy.msi)
        self.interrupts = {
            "PCIE_DMA_WRITER":    self.pcie_dma.writer.irq,
            "PCIE_DMA_READER":    self.pcie_dma.reader.irq
        }
        for i, (k, v) in enumerate(sorted(self.interrupts.items())):
            self.comb += self.pcie_msi.irqs[i].eq(v)
            self.add_constant(k + "_INTERRUPT", i)

default_subtarget = PCIeDMASoC
