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

class TestSoftRateSequencerGen3(unittest.TestCase):
    def run_rates(self, rates, budget=100000):
        # Rate changes in order, with the transceivers' rate done only when TXRATE/RXRATE change: the PLL
        # selection, PMA resets and DRP writes around a change to/from 8.0 GT/s.
        dut = S7RateSequencer(clk_freq=1e6, clock_wait=4, gen3=True)
        events = []
        def generator():
            yield dut.rx_ready.eq(1)
            yield dut.pll_lock.eq(1)
            gt_rate_r = 0
            gt_rate_hold = [0]
            for rate in rates:
                yield dut.rate.eq(rate)
                yield
                drp_busy = 0
                for cycle in range(budget):
                    gt_rate = (yield dut.gt_rate)
                    # The transceivers' rate changes with the PMA out of reset only (Xilinx sequence).
                    if (yield dut.pma_reset) and gt_rate != gt_rate_hold[0]:
                        events.append(("rate under PMA reset", rate))
                    gt_rate_hold[0] = gt_rate
                    yield dut.gt_done.eq((gt_rate != 0) != (gt_rate_r != 0))
                    if (yield dut.drp_start):
                        events.append(("drp", rate, (yield dut.pll_sel), (yield dut.pma_reset)))
                        drp_busy = 5
                    yield dut.drp_done.eq(drp_busy == 0)
                    drp_busy = max(drp_busy - 1, 0)
                    if (yield dut.done):
                        events.append(("done", rate, (yield dut.pll_sel), (yield dut.pma_reset)))
                        gt_rate_r = gt_rate
                        break
                    yield
            events.append(("timeouts", (yield dut.timeouts)))
        run_simulation(dut, generator())
        return events

    def test_gen3(self):
        events = self.run_rates([2, 0, 1, 2, 1])
        self.assertEqual(events, [
            ("drp", 2, 1, 1), ("done", 2, 1, 0), # 2.5 -> 8.0 GT/s: Quad PLL, DRP under PMA reset, TXRATE.
            ("drp", 0, 0, 1), ("done", 0, 0, 0), # 8.0 -> 2.5 GT/s.
            ("done", 1, 0, 0),                   # 2.5 -> 5.0 GT/s: TXRATE only.
            ("drp", 2, 1, 1), ("done", 2, 1, 0), # 5.0 -> 8.0 GT/s: same TXRATE, no rate done to wait for.
            ("drp", 1, 0, 1), ("done", 1, 0, 0),
            ("timeouts", 0),
        ])

class TestSoftDRPSequencer(unittest.TestCase):
    def test_drp(self):
        # Read-modify-writes: the bits of the mask kept, the others from the value of sel.
        from litepcie.phy.soft.serdes.s7 import S7DRPSequencer
        from liteiclink.serdes.common import DRPInterface
        drp = DRPInterface()
        entries = [(0x10, 0x0000, 0x1111, 0x2222), (0x20, 0xff00, 0x0033, 0x0044)]
        dut = S7DRPSequencer(drp, entries)
        mem = {0x10: 0xabcd, 0x20: 0xabcd}
        def generator():
            yield dut.sel.eq(1)
            yield dut.start.eq(1)
            yield
            yield dut.start.eq(0)
            for _ in range(100):
                yield
                if (yield dut.done):
                    break
        def drp_model():
            # Access on en, rdy two cycles later.
            pending = []
            for _ in range(110):
                yield drp.rdy.eq(0)
                if pending and pending[0][0] == 0:
                    _, adr, we, di = pending.pop(0)
                    if we:
                        mem[adr] = di
                    else:
                        yield drp.do.eq(mem[adr])
                    yield drp.rdy.eq(1)
                pending = [(n - 1, a, w, d) for n, a, w, d in pending]
                if (yield drp.en):
                    pending.append((1, (yield drp.addr), (yield drp.we), (yield drp.di)))
                yield
        run_simulation(dut, [generator(), drp_model()])
        self.assertEqual(mem, {0x10: 0x2222, 0x20: 0xab44})
