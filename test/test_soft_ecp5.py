#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Dirk Eibach
# SPDX-License-Identifier: BSD-2-Clause

import unittest

from migen import *
from migen.sim import passive

from litex.gen import *
from litex.build.generic_platform import *
from litex.build.lattice import LatticeECP5Platform

from litepcie.phy.soft import SoftPCIEPHY
from litepcie.phy.soft.serdes.ecp5 import ECP5PCIeDetect, ECP5PCIeSerDes

_io = [
    ("pcie_x1", 0,
        Subsignal("clk_p", Pins("Y11")), Subsignal("clk_n", Pins("Y12")),
        Subsignal("rx_p",  Pins("Y5")),  Subsignal("rx_n",  Pins("Y6")),
        Subsignal("tx_p",  Pins("W4")),  Subsignal("tx_n",  Pins("W5")),
        Subsignal("perst", Pins("A6"), IOStandard("LVCMOS33")),
    ),
]

class DCUDetectModel(Module):
    """Behavior of the DCU receiver detection (TN1261): done low a few cycles after the strobe, high again
    when finished, con valid then."""
    def __init__(self, det_en, ct, done, con, present, duration=20):
        self.log = []
        # Using generators rather than logic: driven from the testbench (see below).
        self.det_en, self.ct, self.done, self.con, self.present, self.duration = det_en, ct, done, con, present, duration

    @passive
    def generator(self):
        yield self.done.eq(1)
        while True:
            yield
            if (yield self.ct):
                self.log.append(("ct", (yield self.det_en)))
                for _ in range(3):
                    yield
                yield self.done.eq(0)
                for _ in range(self.duration):
                    yield
                yield self.con.eq((yield self.present))
                yield self.done.eq(1)

class TestECP5PCIeDetect(unittest.TestCase):
    def run_detect(self, present, with_dcu=True, timeout=250e-6):
        dut = ECP5PCIeDetect(clk_freq=125e6, timeout=timeout)
        present_s = Signal(reset=present)
        model = DCUDetectModel(dut.det_en, dut.ct, dut.dcu_done, dut.dcu_con, present_s)
        result = {"done": 0, "connected": None, "det_en_before_ct": None, "ct_cycles": 0, "det_en_after": None}

        def stim():
            yield
            yield dut.request.eq(1)
            yield
            yield dut.request.eq(0)
            det_en_cycles = 0
            for _ in range(5000):
                if (yield dut.det_en) and not (yield dut.ct):
                    det_en_cycles += 1
                if (yield dut.ct):
                    if result["det_en_before_ct"] is None:
                        result["det_en_before_ct"] = det_en_cycles
                    result["ct_cycles"] += 1
                if (yield dut.done):
                    result["done"] += 1
                    result["connected"] = (yield dut.connected)
                    yield
                    result["det_en_after"] = (yield dut.det_en)
                    break
                yield

        gens = [stim()] + ([model.generator()] if with_dcu else [])
        run_simulation(dut, gens, clocks={"sys": 8})
        return result

    def test_receiver_present(self):
        r = self.run_detect(present=1)
        self.assertEqual(r["done"], 1)
        self.assertEqual(r["connected"], 1)
        # TN1261: detection mode >= 120ns (15 cycles at 125MHz) before a 4 cycles strobe.
        self.assertGreaterEqual(r["det_en_before_ct"], 15)
        self.assertEqual(r["ct_cycles"], 4)
        # Detection mode released at the end (normal TX operation resumes).
        self.assertEqual(r["det_en_after"], 0)

    def test_no_receiver(self):
        r = self.run_detect(present=0)
        self.assertEqual(r["done"], 1)
        self.assertEqual(r["connected"], 0)

    def test_timeout_without_dcu(self):
        # No DCU answer (ex: PCIE_MODE missing): the detection ends reporting no receiver.
        r = self.run_detect(present=1, with_dcu=False, timeout=2e-6)
        self.assertEqual(r["done"], 1)
        self.assertEqual(r["connected"], 0)

class TestECP5PCIeSerDes(unittest.TestCase):
    def elaborate(self, **kwargs):
        platform = LatticeECP5Platform("LFE5UM-45F-8BG381I", _io, toolchain="trellis")
        class DUT(LiteXModule):
            def __init__(self):
                self.cd_sys = ClockDomain()
                pads = platform.request("pcie_x1")
                self.serdes = serdes = ECP5PCIeSerDes(platform, pads, **kwargs)
                self.phy = SoftPCIEPHY(platform, pads, serdes=serdes, data_width=64, link_freq=kwargs.get("link_freq", 125e6))
        return str(platform.get_verilog(DUT()))

    def test_dcu_pcie_mode(self):
        verilog = self.elaborate(link_freq=75e6)
        self.assertIn("DCUA", verilog)
        self.assertIn("EXTREFB", verilog)
        for attribute in [r"\.CH0_PCIE_MODE\s*\(\"0b1\"\)", r"\.D_TX_MAX_RATE\s*\(\"2.5\"\)", r"\.CH0_CDR_MAX_RATE\s*\(\"2.5\"\)",
            r"\.CH0_FFC_PCIE_DET_EN\s*\(", r"\.CH0_FFC_PCIE_CT\s*\(", r"\.CH0_FFS_PCIE_DONE\s*\(", r"\.CH0_FFS_PCIE_CON\s*\(",
            r"\.CH0_PROTOCOL\s*\(\"10BSER\"\)",
            r"\.CH0_RTERM_RX\s*\(\"0d22\"\)", r"\.CH0_TDRV_SLICE4_SEL\s*\(\"0b01\"\)", r"\.D_SETIRPOLY_CH\s*\(\"0b10\"\)"]:
            self.assertRegex(verilog, attribute)

    def test_dcu_analog_default(self):
        # The 10BSER sample code analog attributes (the 5G/SATA ones of LiteICLink) stay selectable.
        verilog = self.elaborate(link_freq=75e6, analog="default")
        for attribute in [r"\.CH0_RTERM_RX\s*\(\"0d19\"\)", r"\.CH0_TDRV_SLICE4_SEL\s*\(\"0b00\"\)",
            r"\.D_SETIRPOLY_CH\s*\(\"0b01\"\)", r"\.CH0_PCIE_MODE\s*\(\"0b1\"\)"]:
            self.assertRegex(verilog, attribute)

if __name__ == "__main__":
    unittest.main()
