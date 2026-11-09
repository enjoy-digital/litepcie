#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import unittest

from migen import *

from litex.gen import *
from litex.build.generic_platform import *
from litex.build.xilinx import Xilinx7SeriesPlatform, XilinxUSPPlatform

from litepcie.phy.soft import SoftPCIEPHY

_io = [("pcie_x1", 0,
    Subsignal("clk_p", Pins("1")), Subsignal("clk_n", Pins("2")), Subsignal("rst_n", Pins("3")),
    Subsignal("tx_p",  Pins("4")), Subsignal("tx_n",  Pins("5")),
    Subsignal("rx_p",  Pins("6")), Subsignal("rx_n",  Pins("7")),
)]

class TestSoftPHYTransceivers(unittest.TestCase):
    def elaborate(self, device, speed="gen1"):
        platform_cls = XilinxUSPPlatform if device.startswith("xcku") else Xilinx7SeriesPlatform
        platform = platform_cls(device, _io, toolchain="vivado")
        class DUT(LiteXModule):
            def __init__(self):
                self.cd_sys = ClockDomain()
                self.phy = SoftPCIEPHY(platform, platform.request("pcie_x1"), data_width=64, speed=speed)
                self.phy.add_debug()
        return str(platform.get_verilog(DUT()))

    def test_artix7_gtp(self):
        verilog = self.elaborate("xc7a200t-fbg484-3")
        self.assertIn("GTPE2_CHANNEL", verilog)
        self.assertNotIn("GTXE2_CHANNEL", verilog)

    def test_kintex7_gtx(self):
        verilog = self.elaborate("xc7k480t-ffg1156-2")
        self.assertIn("GTXE2_CHANNEL", verilog)
        self.assertNotIn("GTPE2_CHANNEL", verilog)
        self.assertNotIn("SIGVALIDCLK", verilog) # GTP port, the GTX takes its OOB clock on CLKRSVD[0].
        self.assertRegex(verilog, r"\.CLKRSVD\s*\(\{3'd0, \w+\}\)")
        for attribute in [r"\.PCS_RSVD_ATTR\s*\(\d+'d392\)", r"\.RXLPMEN\s*\(1'd1\)", r"\.TX_DRIVE_MODE\s*\(\"PIPE\"\)",
            r"\.CPLL_FBDIV\s*\(3'd5\)", r"\.CPLL_FBDIV_45\s*\(3'd5\)", r"\.TXOUT_DIV\s*\(2'd2\)", r"\.RXOUT_DIV\s*\(2'd2\)"]:
            self.assertRegex(verilog, attribute)

    def test_rate_change_ports(self):
        # Gen2: the transceivers' rate comes from the sequencer, Gen1 keeps the output dividers.
        gen2 = self.elaborate("xc7k480t-ffg1156-2", speed="gen2")
        self.assertRegex(gen2, r"\.TXRATE\s*\(\{2'd0, ")
        self.assertRegex(gen2, r"\.RXRATE\s*\(\{2'd0, ")
        gen1 = self.elaborate("xc7k480t-ffg1156-2")
        self.assertRegex(gen1, r"\.TXRATE\s*\(1'd0\)")
        self.assertNotIn("ratesequencer", gen1.lower())

    def test_kintex_usp_gty(self):
        verilog = self.elaborate("xcku3p-ffvb676-2-e")
        self.assertIn("GTYE4_CHANNEL", verilog)
        self.assertIn("GTYE4_COMMON", verilog)
        self.assertIn("IBUFDS_GTE4", verilog)
        self.assertIn("MMCME4_ADV", verilog)
        for attribute in [r"\.TX_DRIVE_MODE\s*\(\"PIPE\"\)", r"\.PCS_PCIE_EN\s*\(\"FALSE\"\)",
            r"\.RX_CLK25_DIV\s*\(\d+'d4\)", r"\.TXOUT_DIV\s*\(\d+'d4\)", r"\.RXOUT_DIV\s*\(\d+'d4\)",
            r"\.QPLL0_FBDIV\s*\(\d+'d100\)", r"\.RXELECIDLEMODE\s*\(1'd0\)"]:
            self.assertRegex(verilog, attribute)

    def test_unsupported_device(self):
        with self.assertRaises(NotImplementedError):
            self.elaborate("xcku040-ffva1156-2")
