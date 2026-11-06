#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import unittest

from migen import *

from litex.gen import *
from litex.build.generic_platform import *
from litex.build.xilinx import Xilinx7SeriesPlatform

from litepcie.phy.soft import SoftPCIEPHY

_io = [("pcie_x1", 0,
    Subsignal("clk_p", Pins("1")), Subsignal("clk_n", Pins("2")), Subsignal("rst_n", Pins("3")),
    Subsignal("tx_p",  Pins("4")), Subsignal("tx_n",  Pins("5")),
    Subsignal("rx_p",  Pins("6")), Subsignal("rx_n",  Pins("7")),
)]

class TestSoftPHYTransceivers(unittest.TestCase):
    def elaborate(self, device):
        platform = Xilinx7SeriesPlatform(device, _io, toolchain="vivado")
        class DUT(LiteXModule):
            def __init__(self):
                self.cd_sys = ClockDomain()
                self.phy = SoftPCIEPHY(platform, platform.request("pcie_x1"), data_width=64)
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

    def test_unsupported_device(self):
        with self.assertRaises(NotImplementedError):
            self.elaborate("xcku040-ffva1156-2")
