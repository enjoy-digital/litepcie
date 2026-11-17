#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import os
import tempfile
import unittest
from unittest import mock
from xml.etree import ElementTree as ET

from migen import Signal
from migen.sim import run_simulation

from litepcie.phy import c5pciephy
from litepcie.phy.c5pciephy import C5PCIEPHY, _C5Config, _build_qsys

# Helpers ------------------------------------------------------------------------------------------

class DummyPlatform:
    def __init__(self, device="5CGTFD9E5F35C7"):
        self.device  = device
        self.sources = []
        self.ips     = []

    def add_source(self, filename, language=None):
        self.sources.append((filename, language))

    def add_ip(self, filename):
        self.ips.append(filename)


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
            # Device Control: Max Payload = 256 bytes, Max Read Request = 512 bytes.
            dcommand = (1 << 5) | (2 << 12)
            yield dut.tl_cfg_add.eq(0x0)
            yield dut.tl_cfg_ctl.eq(dcommand << 16)
            yield dut.tl_cfg_ctl_wr.eq(1)
            for _ in range(3):
                yield
            self.assertEqual((yield dut.max_payload_size), 256)
            self.assertEqual((yield dut.max_request_size), 512)

            # Holding the toggle steady must not recapture changing bus contents.
            yield dut.tl_cfg_ctl.eq(0)
            for _ in range(3):
                yield
            self.assertEqual((yield dut.max_payload_size), 256)
            self.assertEqual((yield dut.max_request_size), 512)

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

    def test_config_sizes_clamped_to_512(self):
        dut = _C5Config()

        def generator():
            # Device Control: Max Payload = 1024 bytes, Max Read Request = 4096 bytes.
            yield dut.tl_cfg_add.eq(0x0)
            yield dut.tl_cfg_ctl.eq(((3 << 5) | (5 << 12)) << 16)
            yield dut.tl_cfg_ctl_wr.eq(1)
            for _ in range(3):
                yield
            self.assertEqual((yield dut.max_payload_size), 512)
            self.assertEqual((yield dut.max_request_size), 512)

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

    def test_qsys_system(self):
        for nlanes, data_width, bar0_size in [(1, 64, 0x100000), (4, 128, 0x20000)]:
            with self.subTest(nlanes=nlanes, data_width=data_width):
                system = ET.fromstring(_build_qsys("5CGTFD9E5F35C7", nlanes, data_width, bar0_size))

                def parameters(path):
                    return {p.get("name"): p.get("value") for p in system.find(path)}

                self.assertEqual(system.get("name"), "pcie_phy")
                self.assertEqual(parameters(".")["device"], "5CGTFD9E5F35C7")

                hip = parameters("module[@name='hip']")
                self.assertEqual(hip["ast_width_hwtcl"],        f"Avalon-ST {data_width}-bit")
                self.assertEqual(hip["lane_mask_hwtcl"],        f"x{nlanes}")
                self.assertEqual(hip["bar0_size_mask_0_hwtcl"], str(bar0_size.bit_length() - 1))

                # One reconfiguration interface per lane and one for the TX PLL.
                for name in ["driver", "xcvr"]:
                    module = parameters(f"module[@name='{name}']")
                    self.assertEqual(module["number_of_reconfig_interfaces"], str(nlanes + 1))

                # The wrapper only connects ports of the interfaces the system exports.
                interfaces = [interface.get("name") for interface in system.findall("interface")]
                phy        = C5PCIEPHY(DummyPlatform(), DummyPads(nlanes), data_width=data_width)
                for port in phy.pcie_phy_params:
                    exported = any(port[2:].startswith(f"{name}_") for name in interfaces)
                    self.assertTrue(exported, port)

    def test_generate_hard_ip(self):
        platform = DummyPlatform()
        phy      = C5PCIEPHY(platform, DummyPads(), data_width=128)

        with tempfile.TemporaryDirectory() as tmp:
            quartus    = os.path.realpath(os.path.join(tmp, "quartus"))
            output_dir = os.path.realpath(os.path.join(tmp, "pcie"))
            qsys       = os.path.join(output_dir, "pcie_phy.qsys")
            qip        = os.path.join(output_dir, "pcie_phy", "synthesis", "pcie_phy.qip")
            commands   = []

            # Stand-in for qsys-generate: check its input and create the QIP it would generate.
            def run(command, cwd, check):
                commands.append((command, cwd, check))
                self.assertTrue(os.path.isfile(qsys))
                os.makedirs(os.path.dirname(qip))
                with open(qip, "w") as f:
                    f.write("")

            with mock.patch.dict(os.environ, {"QUARTUS_ROOTDIR": quartus}), \
                 mock.patch.object(c5pciephy.subprocess, "run", side_effect=run):
                phy.generate_hard_ip(output_dir)

            qsys_generate = os.path.join(quartus, "sopc_builder", "bin", "qsys-generate")
            self.assertEqual(commands, [
                ([qsys_generate, "pcie_phy.qsys", "--synthesis=VERILOG"], output_dir, True),
            ])
            with open(qsys, encoding="utf-8") as f:
                self.assertEqual(f.read(), _build_qsys(platform.device, 4, 128, phy.bar0_size))

        self.assertEqual(platform.ips, [qip])
        self.assertEqual(platform.sources, [])
        self.assertTrue(phy.external_hard_ip)

    def test_external_hard_ip_missing_qip(self):
        platform = DummyPlatform()
        phy      = C5PCIEPHY(platform, DummyPads())

        with self.assertRaises(FileNotFoundError):
            phy.use_external_hard_ip("/nonexistent/c5-ip/pcie_phy.qip")
        self.assertEqual(platform.ips, [])
        self.assertFalse(phy.external_hard_ip)


if __name__ == "__main__":
    unittest.main()
