from migen import *
from migen.genlib.io import CRG
from migen.genlib.resetsync import AsyncResetSynchronizer
from migen.genlib.misc import timeline

from litex.soc.interconnect.csr import *
from litex.soc.interconnect import wishbone

from litex.soc.integration.soc_core import SoCCore
from litex.soc.cores.uart import UARTWishboneBridge

from litepcie.phy.c5pciephy import C5PCIEPHY
#from litepcie.phy.s7pciephy import S7PCIEPHY
from litepcie.core import LitePCIeEndpoint, LitePCIeMSI
from litepcie.frontend.dma import LitePCIeDMA
from litepcie.frontend.wishbone import LitePCIeWishboneBridge


class _CRG(Module, AutoCSR):
    def __init__(self, platform):
        self.clock_domains.cd_sys = ClockDomain("sys")

        # soft reset generaton
        self._soft_rst = CSR()
        soft_rst = Signal()
        # trigger soft reset 1us after CSR access to terminate
        # Wishbone access when reseting from PCIe
        self.sync += [
            timeline(self._soft_rst.re & self._soft_rst.r, [(125, [soft_rst.eq(1)])]),
        ]

        # sys_clk / sys_rst (from PCIe)
        self.comb += self.cd_sys.clk.eq(ClockSignal("pcie"))
        self.specials += AsyncResetSynchronizer(self.cd_sys, ResetSignal("pcie") | soft_rst)


class PCIeDMASoC(SoCCore):
    default_platform = "kc705"
    csr_map = {
        "crg":      16,
        "pcie_phy": 17,
        "dma":      18,
        "msi":      19
    }
    csr_map.update(SoCCore.csr_map)

    mem_map = SoCCore.mem_map
    mem_map["csr"] = 0x00000000

    def __init__(self, platform, with_uart_bridge=False):
        clk_freq = 125*1000000
        SoCCore.__init__(self, platform, clk_freq,
            cpu_type=None,
            shadow_base=0x00000000,
            csr_data_width=32,
            with_uart=False,
            ident="LitePCIe example design",
            with_timer=False
        )
        self.submodules.crg = _CRG(platform)

        # PCIe endpoint
        # self.submodules.pcie_phy = S7PCIEPHY(platform, platform.request("pcie_x1"))
        self.submodules.pcie_phy = C5PCIEPHY(platform, platform.request("pcie_x4"))
        self.submodules.pcie_endpoint = LitePCIeEndpoint(self.pcie_phy, with_reordering=True)

        # PCIe Wishbone bridge
        self.add_cpu_or_bridge(LitePCIeWishboneBridge(self.pcie_endpoint, lambda a: 1))
        self.add_wb_master(self.cpu_or_bridge.wishbone)

        # PCIe DMA
        self.submodules.dma = LitePCIeDMA(self.pcie_phy, self.pcie_endpoint, with_loopback=True)
        self.dma.source.connect(self.dma.sink)

        if with_uart_bridge:
            self.submodules.uart_bridge = UARTWishboneBridge(platform.request("serial"), clk_freq, baudrate=115200)
            self.add_wb_master(self.uart_bridge.wishbone)

        # MSI
        self.submodules.msi = LitePCIeMSI()
        self.comb += self.msi.source.connect(self.pcie_phy.msi)
        self.interrupts = {
            "DMA_WRITER":    self.dma.writer.irq,
            "DMA_READER":    self.dma.reader.irq
        }
        for i, (k, v) in enumerate(sorted(self.interrupts.items())):
            self.comb += self.msi.irqs[i].eq(v)
            self.add_constant(k + "_INTERRUPT", i)

default_subtarget = PCIeDMASoC
