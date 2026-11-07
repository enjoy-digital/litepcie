#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY link simulation with Verilator (bench/soft/sim.py): two Physical Layers train to L0,
exchange packets, go through Recovery (Link Retrain) and exchange packets again."""

import os
import shutil
import subprocess
import sys
import unittest

import pytest

pytestmark = [pytest.mark.slow, pytest.mark.sim]

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

class TestSoftSim(unittest.TestCase):
    def run_sim(self, name, *args, script="sim.py"):
        if shutil.which("verilator") is None:
            self.skipTest("Verilator not available")
        output_dir = os.path.join(ROOT, "build", "test", "soft_sim_" + name)
        shutil.rmtree(output_dir, ignore_errors=True)
        cmd = [sys.executable, os.path.join(ROOT, "bench", "soft", script), "--output-dir", output_dir] + list(args)
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=1800)
        self.assertEqual(result.returncode, 0, result.stdout[-4000:] + result.stderr[-4000:])
        return result.stdout

    def check(self, output):
        self.assertIn("L0 reached, link   5 lane  0", output)
        self.assertIn("RECOVERY OK", output)
        self.assertIn("SIM OK", output)
        for line in output.splitlines():
            if "DATA" in line and "OK" in line:
                self.assertIn("    0/    0 errors", line)

    def test_link(self):
        # Scaled timers, specification TS1 count.
        self.check(self.run_sim("scaled", "--timer-scale", "100", "--packets", "32"))

    def test_link_spec_timers(self):
        # Specification timers (events, not timeouts, drive the training).
        self.check(self.run_sim("spec", "--timer-scale", "1", "--packets", "32"))

    def check_dll(self, output):
        self.check(output)
        self.assertIn("DL_Active (both)", output)

    def test_dll(self):
        # Data Link Layers on both sides: flow control initialization, TLPs both ways.
        self.check_dll(self.run_sim("dll", "--with-dll", "--packets", "64"))

    def test_dll_corruption(self):
        # Lane corruption: Naks and replays, TLPs still delivered exactly once, in order.
        output = self.run_sim("dll_corrupt", "--with-dll", "--packets", "64", "--corrupt-every", "5")
        self.check_dll(output)
        self.assertRegex(output, r"replays: up +[1-9]")
        self.assertRegex(output, r"receiver errors: up +\d+, down +[1-9]")

    def test_dll_lost_dllps(self):
        # DLLPs lost (Acks, UpdateFC): REPLAY_TIMER, duplicates discarded by the receiver.
        self.check_dll(self.run_sim("dll_drop", "--with-dll", "--packets", "64", "--drop-dllp-every", "3"))

    def check_speed(self, output, rate):
        self.check_dll(output)
        self.assertIn(f"SPEED OK: rate {rate}/{rate}", output)
        # No new training after the first L0.
        self.assertNotIn("Detect.Quiet", output[output.index("L0 reached"):])

    def test_gen2_speed_change(self):
        # Directed speed change to 5.0 GT/s, TLPs at full lane rate, Recovery at 5.0 GT/s.
        self.check_speed(self.run_sim("gen2", "--gen2", "--with-dll", "--packets", "64"), 1)

    def test_gen2_fallback(self):
        # The upstream can't receive at 5.0 GT/s: back to 2.5 GT/s without a new training.
        self.check_speed(self.run_sim("gen2_fail", "--gen2", "--fail-5g", "--with-dll", "--packets", "64"), 0)

    def check_wide(self, output, nlanes):
        self.assertIn("SIM OK", output)
        self.assertIn(f"lanes ok {2**nlanes - 1:x}/{2**nlanes - 1:x}", output)
        self.assertNotIn("TIMEOUT", output)
        self.assertRegex(output, r"mismatches +0/ +0")

    def test_wide_dll(self):
        # Two wide Data Link Layers, with lane corruption: every TLP delivered once and in order.
        for ndw in [2, 4, 8]:
            with self.subTest(ndw=ndw):
                output = self.run_sim(f"wide_dll_{ndw}", "--ndw", str(ndw), "--nlanes", str(ndw), "--tlps", "64",
                    "--corrupt-every", "8", script="sim_wide.py")
                self.assertIn("SIM OK", output)
                self.assertRegex(output, r"replays +[1-9]")

    def test_multi_lane(self):
        # Two multi-lane Physical and Data Link Layers: Symbol shifts and skew per lane, training,
        # speed change to 5.0 GT/s, TLPs through a Link Retrain.
        for nlanes in [2, 4, 8]:
            for gen2 in [False, True]:
                with self.subTest(nlanes=nlanes, gen2=gen2):
                    args = ["--phy", "--nlanes", str(nlanes), "--tlps", "64"] + (["--gen2"] if gen2 else [])
                    output = self.run_sim(f"multi_lane_{nlanes}_{gen2}", *args, script="sim_wide.py")
                    self.check_wide(output, nlanes)
                    if gen2:
                        self.assertIn("SPEED OK: rate 1/1", output)

    def test_width_negotiation(self):
        # Lanes out of service on the upstream side: a narrower link, traffic and Recovery at this width.
        for nlanes, dead, width, gen2 in [(2, "0x2", 1, False), (4, "0x8", 2, False), (4, "0x2", 1, True),
                                          (8, "0x80", 4, False), (8, "0x10", 4, True), (8, "0x4", 2, False), (8, "0x2", 1, False)]:
            with self.subTest(nlanes=nlanes, dead=dead):
                args = ["--phy", "--nlanes", str(nlanes), "--tlps", "32", "--dead-lanes", dead] + (["--gen2"] if gen2 else [])
                output = self.run_sim(f"width_{nlanes}_{dead}_{gen2}", *args, script="sim_wide.py")
                self.assertIn("SIM OK", output)
                self.assertRegex(output, rf"width x *{width}/x *{width}")
                self.assertRegex(output, r"mismatches +0/ +0")
                self.assertNotIn("Detect.Quiet", output[output.index("L0 reached"):])

    def test_endpoint_narrower(self):
        # The configuration space reports the negotiated width, a design of x4 at x2.
        output = self.run_sim("endpoint_x4_x2", "--nlanes", "4", "--data-width", "128", "--dead-lanes", "0x8", "--width", "2",
            script="sim_endpoint.py")
        self.assertIn("device read: cafe1234", output)
        self.assertIn("SIM OK", output)

    def test_multi_lane_restart(self):
        # Receivers restarting at different times after the rate change: back in L0 at 5.0 GT/s without a
        # new training. The model doesn't reset the receive domain as the transceivers do, which isn't
        # covered here: some stall patterns then leave a Training Sequence inside a lane (x4).
        for nlanes in [2, 8]:
            with self.subTest(nlanes=nlanes):
                output = self.run_sim(f"multi_lane_restart_{nlanes}", "--phy", "--nlanes", str(nlanes), "--tlps", "32",
                    "--gen2", "--rate-stall", "3", script="sim_wide.py")
                self.check_wide(output, nlanes)
                self.assertIn("SPEED OK: rate 1/1", output)
                self.assertNotIn("Detect.Quiet", output[output.index("L0 reached"):])

    def test_soc_narrower(self):
        # DMA of the SoC with Completions split as a host does, on a narrower link at the 5.0 GT/s rate.
        for nlanes, dead in [(4, "0x0"), (4, "0xe"), (4, "0xc"), (2, "0x2")]:
            with self.subTest(nlanes=nlanes, dead=dead):
                output = self.run_sim(f"soc_{nlanes}_{dead}", "--nlanes", str(nlanes), "--dead-lanes", dead, "--full-rate",
                    "--dma-size", "4096", "--dma-buffers", "2", script="sim_soc.py")
                self.assertIn("SIM OK", output)

    def test_endpoint_multi_lane(self):
        # Scripted root on a LitePCIe endpoint through multi-lane links.
        for nlanes in [2, 4, 8]:
            with self.subTest(nlanes=nlanes):
                output = self.run_sim(f"endpoint_x{nlanes}", "--nlanes", str(nlanes), "--data-width", str(32*nlanes), script="sim_endpoint.py")
                self.assertIn("device read: cafe1234", output)
                self.assertIn("SIM OK", output)

    def test_endpoint(self):
        # Scripted root <-> LitePCIe endpoint on SoftPCIEPHY: configuration space, BAR0 accesses, byte
        # order, Unsupported Requests, MSI, device reads and writes, wire TLPs compared.
        for data_width in [64, 128]:
            with self.subTest(data_width=data_width):
                output = self.run_sim(f"endpoint_{data_width}", "--data-width", str(data_width), script="sim_endpoint.py")
                self.assertIn("device read: cafe1234", output)
                self.assertIn("SIM OK", output)
                self.assertNotIn("expected", output)

    def test_soc(self):
        # Acorn-like SoC (add_pcie, 64-bit DMA) against a host model with the driver's register
        # sequence: CSRs over BAR0, DMA loopback through host memory, split completions, MSIs.
        for mps, size, buffers in [(128, 512, 2), (256, 1024, 4), (512, 8192, 2), (256, 8192, 4)]:
            with self.subTest(mps=mps, size=size):
                output = self.run_sim(f"soc_{mps}", "--mps", str(mps), "--dma-size", str(size),
                    "--dma-buffers", str(buffers), script="sim_soc.py")
                self.assertIn("SIM OK", output)
                self.assertNotIn("expected", output)
                self.assertNotIn("host memory:", output)
                self.assertRegex(output, r"replays +0/ +0, receiver errors +0/ +0")

    def test_dll_sequence_wrap(self):
        # More TLPs than the 12-bit Sequence Number and the 8-bit header credits cover.
        output = self.run_sim("dll_wrap", "--with-dll", "--packets", "4500", "--max-cycles", "3000000")
        self.check_dll(output)
