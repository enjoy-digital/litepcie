#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import os
import random
import tempfile
import unittest
from unittest import mock
from xml.etree import ElementTree as ET

from migen import Module, Signal
from migen.fhdl.specials import Instance
from migen.fhdl.structure import Constant
from migen.sim import passive, run_simulation

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


def hard_ip_ports(phy, generated):
    """Elaborate the PHY and return the inputs and the outputs of its hard IP Instance."""
    if generated:
        with tempfile.TemporaryDirectory() as tmp:
            # Stand-in for qsys-generate: create the QIP it would generate.
            def run(command, cwd, check):
                os.makedirs(os.path.join(cwd, "pcie_phy", "synthesis"))
                with open(os.path.join(cwd, "pcie_phy", "synthesis", "pcie_phy.qip"), "w") as f:
                    f.write("")

            with mock.patch.dict(os.environ, {"QUARTUS_ROOTDIR": os.path.join(tmp, "quartus")}), \
                 mock.patch.object(c5pciephy.subprocess, "run", side_effect=run):
                phy.generate_hard_ip(os.path.join(tmp, "pcie"))
    else:
        phy.use_external_hard_ip("/tmp/c5-ip")
    phy.finalize()

    instance, = [s for s in phy._fragment.specials if getattr(s, "of", None) == "pcie_phy"]
    inputs  = {item.name: item.expr for item in instance.items if isinstance(item, Instance.Input)}
    outputs = {item.name: item.expr for item in instance.items if isinstance(item, Instance.Output)}
    return inputs, outputs

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

    def test_hard_ip_inputs_64_bit(self):
        # Inputs tied to 0 by the PHY (ports of the tx_st, config_tl and power_mngt interfaces).
        tied = [
            "tx_st_error",
            "config_tl_hpg_ctrler",
            "config_tl_cpl_err",
            "config_tl_cpl_pending",
            "power_mngt_pm_auxpwr",
            "power_mngt_pm_data",
            "power_mngt_pm_event",
        ]

        def check(inputs, outputs, app_reset):
            for name in tied:
                self.assertIn(name, inputs)
                self.assertIsInstance(inputs[name], Constant, name)
                self.assertEqual(inputs[name].value, 0, name)

            # The application reset follows the reset status of the hard IP.
            self.assertEqual("app_reset_reset_n" in inputs, app_reset)
            if app_reset:
                reset_n = inputs["app_reset_reset_n"]
                self.assertEqual(reset_n.op, "~")
                self.assertIs(reset_n.operands[0], outputs["hip_rst_reset_status"])

        # Reference: 128-bit with the generated system.
        ref_inputs, ref_outputs = hard_ip_ports(
            C5PCIEPHY(DummyPlatform(), DummyPads(4), data_width=128), generated=True)
        check(ref_inputs, ref_outputs, app_reset=True)

        for nlanes in [1, 4]:
            with self.subTest(nlanes=nlanes):
                # Generated system: every input driven at 128-bit is driven at 64-bit (the
                # interface has no empty at 64-bit).
                phy             = C5PCIEPHY(DummyPlatform(), DummyPads(nlanes), data_width=64)
                inputs, outputs = hard_ip_ports(phy, generated=True)
                expected        = {
                    name for name in ref_inputs
                    if not name.startswith("hip_serial_rx_in") and name != "tx_st_empty"
                }
                expected.update(f"hip_serial_rx_in{n}" for n in range(nlanes))
                self.assertEqual(set(inputs), expected)
                check(inputs, outputs, app_reset=True)

                # External system: same inputs, without the application reset it does not export.
                phy             = C5PCIEPHY(DummyPlatform(), DummyPads(nlanes), data_width=64)
                inputs, outputs = hard_ip_ports(phy, generated=False)
                self.assertEqual(set(inputs), expected - {"app_reset_reset_n"})
                check(inputs, outputs, app_reset=False)

    def test_external_hard_ip_missing_qip(self):
        platform = DummyPlatform()
        phy      = C5PCIEPHY(platform, DummyPads())

        with self.assertRaises(FileNotFoundError):
            phy.use_external_hard_ip("/nonexistent/c5-ip/pcie_phy.qip")
        self.assertEqual(platform.ips, [])
        self.assertFalse(phy.external_hard_ip)


# Hard IP RX Avalon-ST Interface -------------------------------------------------------------------

class _NoInstance:
    # The hard IP and the reference clock buffer are vendor Instances; the test plays the hard IP.
    @staticmethod
    def lower(dr):
        return Module()


class TestC5PCIEPHYRXReadyLatency(unittest.TestCase):
    """rx_st is an Avalon-ST source with readyLatency 3 (pcie_av_port.tcl: `rx_st readyLatency 3`):
    the hard IP may assert rx_st_valid in cycle k whenever rx_st_ready was asserted in cycle k-3, so
    up to 3 beats arrive after rx_st_ready deasserts. None of them may be lost."""

    def run_rx(self, data_width, npackets=64, ready_latency=3, ready_rate=0.7, cycles=3000):
        prng = random.Random(data_width)
        phy  = C5PCIEPHY(DummyPlatform(), DummyPads(), data_width=data_width, cd="pcie")
        phy.use_external_hard_ip("/tmp/c5-ip")
        p    = phy.pcie_phy_params

        # Memory Writes with a 3-DW header at a qword aligned address, as the hard IP presents
        # them: payload from the third qword, 3 to 10 qwords.
        qwords  = data_width//64
        tlps    = []
        packets = []
        for n in range(npackets):
            length  = prng.randrange(1, 17)
            header  = [(1 << 30) | length, 0x000000ff, n << 3]
            payload = [prng.getrandbits(32) for _ in range(length)]
            dwords  = header + [0] + payload + [0]*(length % 2)
            tlps.append(header + payload)
            packets.append([dwords[i] | (dwords[i + 1] << 32) for i in range(0, len(dwords), 2)])

        beats = []
        for packet in packets:
            for i in range(0, len(packet), qwords):
                chunk = packet[i:i + qwords]
                data  = sum(qword << (64*j) for j, qword in enumerate(chunk))
                beats.append((data, i == 0, i + qwords >= len(packet), qwords - len(chunk)))
        received = []

        @passive
        def hard_ip():
            # Worst-case source: a beat on every ready cycle while data is pending.
            ready = {}
            k     = 0
            while True:
                if beats and ready.get(k - ready_latency, 0):
                    data, sop, eop, empty = beats.pop(0)
                    yield p["o_rx_st_valid"].eq(1)
                    yield p["o_rx_st_data"].eq(data)
                    yield p["o_rx_st_startofpacket"].eq(sop)
                    yield p["o_rx_st_endofpacket"].eq(eop)
                    if data_width == 128:
                        yield p["o_rx_st_empty"].eq(empty)
                else:
                    yield p["o_rx_st_valid"].eq(0)
                yield
                ready[k] = (yield p["i_rx_st_ready"])
                k += 1

        def litepcie():
            # Random back-pressure, then ready until the end to drain the PHY.
            for cycle in range(cycles):
                yield phy.source.ready.eq(cycle >= cycles - 64 or prng.random() < ready_rate)
                yield
                if (yield phy.source.valid) and (yield phy.source.ready):
                    received.append((
                        (yield phy.source.dat),
                        (yield phy.source.be),
                        (yield phy.source.first),
                        (yield phy.source.last),
                    ))

        run_simulation(phy, {"pcie": [hard_ip(), litepcie()]}, clocks={"pcie": 10},
            special_overrides={Instance: _NoInstance})
        self.assertEqual(len(beats), 0)
        return tlps, received

    def test_rx_backpressure_with_ready_latency_3(self):
        for data_width in [64, 128]:
            with self.subTest(data_width=data_width):
                tlps, received = self.run_rx(data_width)

                # Packets received, as dwords.
                packets = [[]]
                for dat, be, first, last in received:
                    self.assertEqual(first, len(packets[-1]) == 0)
                    for i in range(data_width//32):
                        if (be >> (4*i)) & 0xf:
                            packets[-1].append((dat >> (32*i)) & 0xffffffff)
                    if last:
                        packets.append([])
                self.assertEqual(packets.pop(), [])

                # No beat lost: every TLP is received, in order and complete. The 64-bit PHY
                # keeps the qword alignment (padding dword after the header), the 128-bit PHY
                # removes it; byte enables are qword-granular (one unused trailing dword).
                self.assertEqual(len(packets), len(tlps))
                for tlp, packet in zip(tlps, packets):
                    if data_width == 64:
                        del packet[3]
                    self.assertEqual(packet[:len(tlp)], tlp)
                    self.assertIn(len(packet) - len(tlp), [0, 1])

if __name__ == "__main__":
    unittest.main()
