#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import os
import unittest

from migen import Signal
from migen.sim import run_simulation

from litepcie.phy.c5pciephy import C5PCIEPHY, _C5Config

# Helpers ------------------------------------------------------------------------------------------

class DummyPlatform:
    def __init__(self):
        self.sources = []

    def add_source(self, filename, language=None):
        self.sources.append((filename, language))


class DummyPads:
    def __init__(self, nlanes=4):
        self.clk_p = Signal()
        self.clk_n = Signal()
        self.rst_n = Signal()
        self.rx_p  = Signal(nlanes)
        self.tx_p  = Signal(nlanes)

# Tests --------------------------------------------------------------------------------------------

class TestC5PCIEPHY(unittest.TestCase):
    def test_config_toggle_decode(self):
        dut = _C5Config()

        def generator():
            # Device Control: Max Payload = 512 bytes, Max Read Request = 1024 bytes.
            dcommand = (2 << 5) | (3 << 12)
            yield dut.tl_cfg_add.eq(0x0)
            yield dut.tl_cfg_ctl.eq(dcommand)
            yield dut.tl_cfg_ctl_wr.eq(1)
            for _ in range(3):
                yield
            self.assertEqual((yield dut.max_payload_size), 512)
            self.assertEqual((yield dut.max_request_size), 1024)

            # Holding the toggle steady must not recapture changing bus contents.
            yield dut.tl_cfg_ctl.eq(0)
            for _ in range(3):
                yield
            self.assertEqual((yield dut.max_payload_size), 512)
            self.assertEqual((yield dut.max_request_size), 1024)

            # The next toggle carries the bus/device register.
            bus_number    = 0x5a
            device_number = 0x12
            yield dut.tl_cfg_add.eq(0xf)
            yield dut.tl_cfg_ctl.eq((bus_number << 5) | device_number)
            yield dut.tl_cfg_ctl_wr.eq(0)
            for _ in range(3):
                yield
            self.assertEqual((yield dut.bus_number), bus_number)
            self.assertEqual((yield dut.device_number), device_number)
            self.assertEqual((yield dut.id), (bus_number << 8) | (device_number << 3))

        run_simulation(dut, generator())

    def test_external_hard_ip_path(self):
        platform = DummyPlatform()
        phy      = C5PCIEPHY(platform, DummyPads())
        phy.use_external_hard_ip("/tmp/c5-ip")

        qip = os.path.join(
            "/tmp/c5-ip", "altera", "cyclone_v", "pcie_phy", "synthesis", "pcie_phy.qip")
        self.assertEqual(platform.sources, [(qip, "QIP")])
        self.assertTrue(phy.external_hard_ip)

    def test_generated_wrapper_ports(self):
        phy    = C5PCIEPHY(DummyPlatform(), DummyPads(nlanes=2))
        params = phy.pcie_phy_params

        self.assertIn("o_config_tl_tl_cfg_ctl_wr", params)
        self.assertIn("o_hip_rst_reset_status", params)
        self.assertIn("i_hip_serial_rx_in0", params)
        self.assertIn("i_hip_serial_rx_in1", params)
        self.assertNotIn("i_hip_serial_rx_in2", params)


if __name__ == "__main__":
    unittest.main()
