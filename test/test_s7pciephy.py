#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import unittest
from types import SimpleNamespace

from migen import Signal

from litepcie.phy.s7pciephy import S7PCIEPHY


class DummyPlatform:
    device = "xc7a35t"

    def __init__(self):
        self.toolchain = SimpleNamespace(pre_placement_commands=[])

    def add_period_constraint(self, *args, **kwargs):
        pass

    def add_platform_command(self, command):
        pass


class TestS7PCIEPHY(unittest.TestCase):
    def test_tx_ecrc_follows_aer_control(self):
        pads = SimpleNamespace(
            rst_n = Signal(),
            clk_p = Signal(),
            clk_n = Signal(),
            tx_p  = Signal(2),
            tx_n  = Signal(2),
            rx_p  = Signal(2),
            rx_n  = Signal(2),
        )
        phy = S7PCIEPHY(DummyPlatform(), pads, data_width=64, pcie_data_width=64)

        self.assertIs(phy.pcie_phy_params["o_cfg_aer_ecrc_gen_en"], phy.cfg_aer_ecrc_gen_en)
        self.assertIs(phy.pcie_phy_params["i_s_axis_tx_tuser"],     phy.s_axis_tx_tuser)
        self.assertEqual(len(phy.s_axis_tx_tuser), 4)


if __name__ == "__main__":
    unittest.main()
