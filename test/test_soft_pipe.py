#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import unittest

from migen import *

from litepcie.phy.soft.ltssm        import LTSSM_STATES
from litepcie.phy.soft.pipe         import PCIePhysicalLayer
from litepcie.phy.soft.serdes.model import PCIeSerDesModel

STATE_NAMES = {v: k for k, v in LTSSM_STATES.items()}

class LinkDUT(Module):
    """Upstream PHY (a) <-> downstream PHY (b) through two serdes models. Lane clocks "a"/"b",
    LTSSM/link clocks "a_link"/"b_link"."""
    def __init__(self, timer_scale=500, ts1_min=32):
        self.submodules.serdes_a = serdes_a = PCIeSerDesModel(tx_cd="a", rx_cd="b", rx_symbol_shift=1)
        self.submodules.serdes_b = serdes_b = PCIeSerDesModel(tx_cd="b", rx_cd="a", rx_symbol_shift=3)
        serdes_a.connect(serdes_b)
        self.submodules.phy_a = ClockDomainsRenamer({"pcie_pipe": "a", "pcie_link": "a_link"})(
            PCIePhysicalLayer(serdes_a, 125e6, upstream=True, timer_scale=timer_scale, ts1_min=ts1_min))
        self.submodules.phy_b = ClockDomainsRenamer({"pcie_pipe": "b", "pcie_link": "b_link"})(
            PCIePhysicalLayer(serdes_b, 125e6, upstream=False, timer_scale=timer_scale, ts1_min=ts1_min))
        self.comb += self.phy_b.link_number.eq(0x05)

CLOCKS = {"a": 16, "b": 16, "a_link": 8, "b_link": 8}

class TestSoftPIPE(unittest.TestCase):
    def test_elaboration(self):
        # Two Physical Layers on two serdes models elaborate (the link training itself is simulated
        # with Verilator: bench/soft/sim.py, far too slow for the Migen simulator).
        dut = LinkDUT()
        fragment = dut.get_fragment()
        self.assertTrue(len(fragment.comb) > 0)
