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
    def __init__(self, device="xc7a35t"):
        self.device = device
        self.toolchain = SimpleNamespace(
            pre_placement_commands = [],
            pre_synthesis_commands = [],
        )

    def add_period_constraint(self, *args, **kwargs):
        pass

    def add_platform_command(self, command):
        pass


class DummyPads:
    def __init__(self, nlanes):
        self.rst_n = Signal()
        self.clk_p = Signal()
        self.clk_n = Signal()
        self.tx_p  = Signal(nlanes)
        self.tx_n  = Signal(nlanes)
        self.rx_p  = Signal(nlanes)
        self.rx_n  = Signal(nlanes)


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
        phy = S7PCIEPHY(DummyPlatform(), DummyPads(2), data_width=64, pcie_data_width=64)

        self.assertIs(phy.pcie_phy_params["o_cfg_aer_ecrc_gen_en"], phy.cfg_aer_ecrc_gen_en)
        self.assertIs(phy.pcie_phy_params["i_s_axis_tx_tuser"],     phy.s_axis_tx_tuser)
        self.assertEqual(len(phy.s_axis_tx_tuser), 4)

    def test_s7_clock_and_ip_config_match_link_width_and_datapath(self):
        for nlanes, pcie_data_width, user_clk_freq in [
            (1,  64, 125e6),
            (1, 128, 125e6),
            (2,  64, 125e6),
            (2, 128, 125e6),
            (4,  64, 250e6),
            (4, 128, 125e6),
            (8, 128, 250e6),
        ]:
            for data_width in [64, 128]:
                with self.subTest(
                    nlanes=nlanes,
                    pcie_data_width=pcie_data_width,
                    data_width=data_width,
                ):
                    platform = DummyPlatform(device="xc7k325t")
                    phy = S7PCIEPHY(
                        platform,
                        DummyPads(nlanes),
                        data_width      = data_width,
                        pcie_data_width = pcie_data_width,
                    )
                    mmcm_config = phy.mmcm.compute_config()
                    phy.add_sources(platform, phy_path="")
                    tcl = "\n".join(platform.toolchain.pre_synthesis_commands)

                    self.assertEqual(phy.userclk_freq, user_clk_freq)
                    self.assertEqual(phy.mmcm.clkouts[3].freq, user_clk_freq)
                    self.assertEqual(mmcm_config["clkout3_freq"], user_clk_freq)
                    self.assertIn(f"CONFIG.Maximum_Link_Width {{{{X{nlanes}}}}}", tcl)
                    self.assertIn(f"CONFIG.Interface_Width {{{{{pcie_data_width}_bit}}}}", tcl)
                    self.assertIn(
                        f"CONFIG.User_Clk_Freq {{{{{int(user_clk_freq/1e6)}}}}}",
                        tcl,
                    )
                    self.assertEqual(tcl.count("synth_ip $obj"), 1)

    def test_s7_rejects_x8_64b_datapath(self):
        with self.assertRaisesRegex(ValueError, "Gen2 x8.*64-bit"):
            S7PCIEPHY(DummyPlatform(), DummyPads(8), data_width=64, pcie_data_width=64)

    def test_usp_debug_interfaces_are_disabled_by_default(self):
        phy = USPPCIEPHY(
            DummyPlatform(device="xcau15p"),
            DummyPads(8),
            speed="gen4",
            data_width=512,
            pcie_data_width=512,
            ip_name="pcie4c_uscale_plus",
        )

        self.assertNotIn("en_ext_ch_gt_drp", phy.config)
        self.assertNotIn("en_pcie_drp", phy.config)
        self.assertNotIn("i_ext_ch_gt_drpaddr", phy.pcie_usp_phy_params)
        self.assertNotIn("i_drp_addr", phy.pcie_usp_phy_params)
        self.assertIs(phy.pcie_usp_phy_params["o_cfg_err_cor_out"], phy.cfg_err_cor)
        self.assertIs(
            phy.pcie_usp_phy_params["i_cfg_link_training_enable"],
            phy.link_training_enable,
        )

    def test_usp_optional_debug_interfaces_match_hard_ip_ports(self):
        platform = DummyPlatform(device="xcau15p")
        phy = USPPCIEPHY(
            platform,
            DummyPads(8),
            speed="gen4",
            data_width=512,
            pcie_data_width=512,
            ip_name="pcie4c_uscale_plus",
            with_ext_gt_drp=True,
            with_pcie_drp=True,
        )

        self.assertTrue(phy.config["en_ext_ch_gt_drp"])
        self.assertTrue(phy.config["en_pcie_drp"])
        self.assertEqual(len(phy.ext_gt_drp_addr), 80)
        self.assertEqual(len(phy.ext_gt_drp_di), 128)
        self.assertEqual(len(phy.ext_gt_drp_en), 8)
        self.assertEqual(len(phy.pcie_drp_addr), 10)
        self.assertEqual(len(phy.pcie_drp_di), 16)
        self.assertIs(
            phy.pcie_usp_phy_params["o_ext_ch_gt_drpclk"],
            phy.ext_gt_drp_clk,
        )
        self.assertIs(phy.pcie_usp_phy_params["o_drp_rdy"], phy.pcie_drp_rdy)
        phy.add_sources(platform)
        tcl = "\n".join(platform.toolchain.pre_synthesis_commands)
        self.assertIn("CONFIG.en_ext_ch_gt_drp {{True}}", tcl)
        self.assertIn("CONFIG.en_pcie_drp {{True}}", tcl)


if __name__ == "__main__":
    unittest.main()
