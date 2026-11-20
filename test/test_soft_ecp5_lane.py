#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Dirk Eibach
# SPDX-License-Identifier: BSD-2-Clause

import unittest

from migen import *
from migen.sim import passive

from litex.gen import *

from litepcie.phy.soft.serdes.ecp5 import ECP5PCIeSerDes

from test.model.soft.common import words_to_symbols
from litepcie.phy.soft.serdes.ecp5_model import SerDesECP5Model
from test.test_soft_serdes import stimulus as serdes_stimulus

from litepcie.phy.soft.common import TS1
from test.model.soft.common import symbols_to_words

LEAD_IN_TS = 24 # TS1 sent before the checked stream: the receiver's symbol aligner locks on their commas.

def stimulus(seed=0):
    words, bounds = serdes_stimulus(seed)
    lead = symbols_to_words(TS1.to_symbols())
    lead_words  = lead*LEAD_IN_TS
    lead_bounds = [(i == 0, i == len(lead) - 1) for i in range(len(lead))]*LEAD_IN_TS
    return lead_words + words, lead_bounds + bounds, words

CLOCKS = {"sys": 12, "pcie_link": 16, "pcie_pipe": 16, "pcie_rx0": 16, "pcie_tx_full": 8, "pcie_rx_full": 8}

class Bench(Module):
    """ECP5PCIeSerDes on the DCU model (serial loopback)."""
    def __init__(self, bit_offset=0, present=1, **kwargs):
        self.present = Signal(reset=present)
        model_kwargs = dict(bit_offset=bit_offset, present=self.present)
        model        = lambda *args, **kwargs: SerDesECP5Model(*args, model_kwargs=model_kwargs, **kwargs)
        self.pads = pads = Record([("tx_p", 1), ("tx_n", 1), ("rx_p", 1), ("rx_n", 1), ("perst", 1)])
        self.comb += pads.perst.eq(1) # PERST# deasserted.
        self.clock_domains.cd_sys       = ClockDomain("sys")
        self.clock_domains.cd_pcie_link = ClockDomain("pcie_link")
        self.submodules.serdes = ECP5PCIeSerDes(None, pads, serdes_cls=model, refclk=Signal(), with_clocking=False, **kwargs)
        self.lane = self.serdes.lanes[0]

def wait_ready(bench, timeout=20000):
    for _ in range(timeout):
        if (yield bench.lane.ready) and (yield bench.serdes.rx_ready):
            return True
        yield
    return False

class TestECP5PCIeLane(unittest.TestCase):
    def test_ready(self):
        bench = Bench()
        results = {}
        def gen():
            results["ready"] = yield from wait_ready(bench)
        run_simulation(bench, {"pcie_pipe": [gen()]}, clocks=CLOCKS)
        self.assertTrue(results["ready"])

    def transfer(self, bench, words, bounds, tx_polarity=0, rx_polarity=0):
        lane = bench.lane
        outs = []
        done = []
        def tx():
            ok = yield from wait_ready(bench)
            assert ok
            yield lane.source.ready.eq(1)
            yield lane.tx_polarity.eq(tx_polarity)
            yield lane.rx_polarity.eq(rx_polarity)
            for _ in range(600): # SCI reconfiguration (polarity) in "sys".
                yield
            for (data, ctrl), (first, last) in zip(words, bounds):
                yield lane.sink.data.eq(data)
                yield lane.sink.ctrl.eq(ctrl)
                yield lane.sink.first.eq(first)
                yield lane.sink.last.eq(last)
                yield lane.sink.valid.eq(1)
                while True:
                    yield
                    if (yield lane.sink.ready):
                        break
            yield lane.sink.valid.eq(0)
            for _ in range(128):
                yield
            done.append(True)
        def rx():
            while not done:
                if (yield lane.source.valid):
                    outs.append(((yield lane.source.data), (yield lane.source.ctrl)))
                yield
        run_simulation(bench, {"pcie_pipe": [tx(), rx()]}, clocks=CLOCKS)
        return outs

    def check(self, outs, words):
        expected = words_to_symbols(words)
        received = words_to_symbols(outs)
        found    = any(received[i:i + len(expected)] == expected for i in range(len(received) - len(expected) + 1))
        self.assertTrue(found, "stream not received")

    def test_loopback_bit_offsets(self):
        # The raw 10BSER bus has no comma alignment: TS Ordered Sets and packets received at any bit offset.
        words, bounds, checked = stimulus()
        for offset in [0, 1, 4, 9]:
            with self.subTest(bit_offset=offset):
                self.check(self.transfer(Bench(bit_offset=offset), words, bounds), checked)

    def test_polarity(self):
        words, bounds, checked = stimulus(2)
        # Both inverted: corrected (TX inversion undone by the RX inversion).
        self.check(self.transfer(Bench(), words, bounds, tx_polarity=1, rx_polarity=1), checked)
        # Only the TX inverted: nothing decodable.
        outs     = self.transfer(Bench(), words, bounds, tx_polarity=1, rx_polarity=0)
        received = words_to_symbols(outs)
        expected = words_to_symbols(checked)[:8]
        self.assertNotIn(expected, [received[i:i + 8] for i in range(len(received))])

    def test_electrical_idle(self):
        bench = Bench()
        lane  = bench.lane
        r     = {}
        def gen():
            ok = yield from wait_ready(bench)
            assert ok
            yield lane.sink.valid.eq(1)
            for _ in range(64):
                yield
            r["active"] = yield lane.rx_elecidle
            yield lane.tx_elecidle.eq(1)
            for _ in range(200):
                yield
            r["idle"]       = yield lane.rx_elecidle
            r["idle_ready"] = yield lane.ready # TX ready is not lost with the RX signal.
            r["idle_rx_ready"] = yield bench.serdes.rx_ready
            yield lane.tx_elecidle.eq(0)
            for _ in range(8000):
                yield
                if (yield bench.serdes.rx_ready):
                    break
            r["back_rx_ready"] = yield bench.serdes.rx_ready
            r["back_idle"]     = yield lane.rx_elecidle
        run_simulation(bench, {"pcie_pipe": [gen()]}, clocks=CLOCKS)
        self.assertEqual(r["active"], 0)
        self.assertEqual(r["idle"], 1)
        self.assertEqual(r["idle_ready"], 1)
        self.assertEqual(r["idle_rx_ready"], 0)
        self.assertEqual(r["back_rx_ready"], 1)
        self.assertEqual(r["back_idle"], 0)

    def eios_symbols_on_the_line(self, tx_idle_delay):
        """Symbols on the line (10-bit values) from the EIOS (COM + 3 IDL) to the first idle chunk, with the idle
        asserted right after the EIOS word was sent (as the LTSSM does)."""
        bench = Bench(tx_idle_delay=tx_idle_delay)
        lane  = bench.lane
        chunks = []
        def pipe():
            ok = yield from wait_ready(bench)
            assert ok
            yield lane.skp_enable.eq(0)
            yield lane.scrambling_enable.eq(0)
            for _ in range(40):
                yield
            yield lane.sink.data.eq(0x7c7c7cbc) # COM, 3 x IDL (K28.3).
            yield lane.sink.ctrl.eq(0xf)
            yield lane.sink.first.eq(1)
            yield lane.sink.last.eq(1)
            yield lane.sink.valid.eq(1)
            yield
            yield lane.sink.valid.eq(0)
            yield lane.tx_elecidle.eq(1) # In the cycle after the EIOS word, as the LTSSM.
            for _ in range(30):
                yield
        @passive
        def line():
            # Line chunks (two symbols per DCU clock), from the start of the EIOS to the idle.
            model = bench.serdes.gt.dcu_model
            while True:
                chunks.append((yield model.line))
                yield
        run_simulation(bench, {"pcie_pipe": [pipe()], "pcie_tx_full": [line()]}, clocks=CLOCKS)
        syms = []
        for chunk in chunks:
            syms += [chunk & 0x3ff, chunk >> 10]
        start = next((i for i, sym in enumerate(syms) if sym in (0x17c, 0x283)), None) # K28.5.
        if start is None:
            return []
        out = []
        for sym in syms[start:]:
            if sym == 0:
                break
            out.append(sym)
        return out

    def test_tx_idle_delay(self):
        # The EIOS must be on the line completely before the transmitter goes idle: without the delay the idle
        # (a direct DCU input) overtakes the data in the TX pipeline and cuts it.
        self.assertEqual(len(self.eios_symbols_on_the_line(0)), 0)
        self.assertEqual(len(self.eios_symbols_on_the_line(1)), 0)
        self.assertEqual(len(self.eios_symbols_on_the_line(2)), 4) # COM + 3 IDL, then idle (the default).

    def detect(self, present):
        bench = Bench(present=present)
        lane  = bench.lane
        r     = {}
        def gen():
            ok = yield from wait_ready(bench)
            assert ok
            yield lane.tx_elecidle.eq(1)
            for _ in range(32):
                yield
            yield lane.tx_detect_rx.eq(1)
            yield
            yield lane.tx_detect_rx.eq(0)
            for i in range(400):
                yield
                if (yield lane.detect_done):
                    r["done"]     = i
                    r["detected"] = (yield lane.rx_detected)
                    break
            r["detections"] = yield bench.serdes.gt.dcu_model.detections
        run_simulation(bench, {"pcie_pipe": [gen()]}, clocks=CLOCKS)
        return r

    def test_receiver_detection(self):
        r = self.detect(present=1)
        self.assertIn("done", r)
        self.assertEqual(r["detected"], 1)
        self.assertEqual(r["detections"], 1)
        r = self.detect(present=0)
        self.assertIn("done", r)
        self.assertEqual(r["detected"], 0)

if __name__ == "__main__":
    unittest.main()
