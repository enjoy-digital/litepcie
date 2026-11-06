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
    def run_sim(self, name, *args):
        if shutil.which("verilator") is None:
            self.skipTest("Verilator not available")
        output_dir = os.path.join(ROOT, "build", "test", "soft_sim_" + name)
        shutil.rmtree(output_dir, ignore_errors=True)
        cmd = [sys.executable, os.path.join(ROOT, "bench", "soft", "sim.py"), "--output-dir", output_dir] + list(args)
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
