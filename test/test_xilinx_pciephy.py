#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import unittest
from types import SimpleNamespace

from migen import Signal

from litepcie.phy.common     import get_bar_size_config
from litepcie.phy.s7pciephy import S7PCIEPHY
from litepcie.phy.uspciephy import USPCIEPHY
from litepcie.phy.usppciephy import USPPCIEPHY


class DummyPlatform:
    device = "xc7a35t"

    def __init__(self):
        self.toolchain = SimpleNamespace(
            pre_placement_commands = [],
            pre_synthesis_commands = [],
        )

    def add_period_constraint(self, *args, **kwargs):
        pass

    def add_platform_command(self, command):
        pass


class TestXilinxPCIEPHY(unittest.TestCase):
    def test_bar_size_config_is_exact(self):
        self.assertEqual(get_bar_size_config(        128), ("Bytes",      128))
        self.assertEqual(get_bar_size_config(     4*1024), ("Kilobytes",   4))
        self.assertEqual(get_bar_size_config(   256*1024), ("Kilobytes", 256))
        self.assertEqual(get_bar_size_config(1*1024*1024), ("Megabytes",   1))

        for invalid_size in [0, 64, 192, 3*1024, 4*1024*1024*1024]:
            with self.subTest(invalid_size=invalid_size):
                with self.assertRaises(ValueError):
                    get_bar_size_config(invalid_size)

    def test_ultrascale_bar_size_config_is_exact(self):
        for phy_cls, extra in [
            (USPCIEPHY,  {}),
            (USPPCIEPHY, {"ip_name": "pcie4_uscale_plus"}),
        ]:
            with self.subTest(phy=phy_cls.__name__):
                phy = SimpleNamespace(
                    speed            = "gen3",
                    nlanes           = 4,
                    mode             = "Endpoint",
                    pcie_data_width  = 256,
                    bar0_scale       = "Kilobytes",
                    bar0_size_config = 256,
                    config           = {},
                    **extra,
                )
                platform = DummyPlatform()
                phy_cls.add_sources(phy, platform)
                tcl = "\n".join(platform.toolchain.pre_synthesis_commands)

                self.assertIn("CONFIG.pf0_bar0_scale {{Kilobytes}}", tcl)
                self.assertIn("CONFIG.pf0_bar0_size {{256}}", tcl)

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
