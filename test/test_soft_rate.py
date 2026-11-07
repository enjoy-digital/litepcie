#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import unittest

from migen import *

from litepcie.phy.soft.serdes.s7 import S7RateSequencer

class TestSoftRateSequencer(unittest.TestCase):
    def run_change(self, gt_done=True, rx_ready=True, budget=200000):
        dut = S7RateSequencer(clk_freq=1e6, clock_wait=4)
        log = {}
        def generator():
            yield dut.rx_ready.eq(1)
            yield
            self.assertEqual((yield dut.done), 1)
            yield dut.rate.eq(1)
            yield
            # Not done as soon as the rate differs.
            self.assertEqual((yield dut.done), 0)
            for cycle in range(budget):
                clk_rate, gt_rate, rx_reset = (yield dut.clk_rate), (yield dut.gt_rate), (yield dut.rx_reset)
                if clk_rate and "clk" not in log: log["clk"] = cycle
                if gt_rate and "gt" not in log: log["gt"] = cycle
                if rx_reset and "rx" not in log: log["rx"] = cycle
                if gt_rate and gt_done:
                    yield dut.gt_done.eq(1)
                yield dut.rx_ready.eq(rx_ready and not rx_reset and "rx" in log)
                if (yield dut.done):
                    log["done"] = cycle
                    break
                yield
            log["timeouts"] = (yield dut.timeouts)
        run_simulation(dut, generator())
        return log

    def test_sequence(self):
        # Lane clock, then transceivers, then RX re-initialization, then done.
        log = self.run_change()
        self.assertLess(log["clk"], log["gt"])
        self.assertLess(log["gt"], log["rx"])
        self.assertLess(log["rx"], log["done"])
        self.assertEqual(log["timeouts"], 0)

    def test_timeouts(self):
        # Rate done or RX ready missing: bounded, counted, the rate change completes.
        log = self.run_change(gt_done=False)
        self.assertIn("done", log)
        self.assertEqual(log["timeouts"], 1)
        log = self.run_change(rx_ready=False)
        self.assertIn("done", log)
        self.assertEqual(log["timeouts"], 1)
