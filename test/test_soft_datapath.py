#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import random
import unittest

from migen import *

from litex.soc.cores.code_8b10b import Decoder

from litepcie.phy.soft.common   import COM, STP, END, ERR, SKP_OS, TS1, LOGICAL_IDLE
from litepcie.phy.soft.coding   import encode_8b10b
from litepcie.phy.soft.datapath import RXSKPRemover, TXSKPInserter, RXErrorSubstitution
from litepcie.phy.soft.datapath import TXLaneDatapath, RXLaneDatapath, SKP_OS_WORD

from test.model.soft.common import symbols_to_words, words_to_symbols

def random_packet(rng, ndws):
    """STP + payload + END (multiple of 4 Symbols)."""
    return [(STP.value, 1)] + [(rng.getrandbits(8), 0) for _ in range(4*ndws + 2)] + [(END.value, 1)]

def feed_and_collect(dut, words, extra=16, cd="sys", ready=True):
    """Drive words on dut.sink (continuous), collect the words accepted on dut.source."""
    outs = []
    done = []
    def generator():
        yield dut.source.ready.eq(ready)
        for data, ctrl in words + [(0, 0)]*extra:
            yield dut.sink.data.eq(data)
            yield dut.sink.ctrl.eq(ctrl)
            yield dut.sink.valid.eq(1)
            while True:
                yield
                if (yield dut.sink.ready):
                    break
        yield dut.sink.valid.eq(0)
        for _ in range(16):
            yield
        done.append(True)
    def monitor():
        while not done:
            if (yield dut.source.valid) and (yield dut.source.ready):
                outs.append(((yield dut.source.data), (yield dut.source.ctrl)))
            yield
    run_simulation(dut, [generator(), monitor()])
    return outs

class TestSoftDatapath(unittest.TestCase):
    def test_skp_remover(self):
        # SKP Ordered Sets at every Symbol position (COM also on Symbol 3: lookahead) removed, the
        # other Symbols repacked in order.
        rng      = random.Random(0)
        symbols  = []
        expected = []
        for shift in range(4):
            data = [(rng.getrandbits(8), 0) for _ in range(8 + shift)]
            symbols  += data + SKP_OS.to_symbols()
            expected += data
        # COM not followed by a SKP (EIOS-like) is kept.
        tail = [(COM.value, 1), (0x7c, 1), (0x7c, 1), (0x7c, 1)] + [(rng.getrandbits(8), 0) for _ in range(8)]
        symbols  += tail
        expected += tail
        words = symbols_to_words(symbols + [(0, 0)]*((-len(symbols)) % 4))
        outs  = feed_and_collect(RXSKPRemover(), words)
        self.assertEqual(words_to_symbols(outs)[:len(expected)], expected)

    def test_skp_inserter(self):
        # SKP Ordered Sets scheduled every interval words, inserted only between packets.
        rng     = random.Random(1)
        words   = []
        bounds  = []
        for _ in range(12):
            packet = symbols_to_words(random_packet(rng, rng.randrange(1, 8)))
            for i, word in enumerate(packet):
                words.append(word)
                bounds.append((i == 0, i == len(packet) - 1))
        dut  = TXSKPInserter(interval=8)
        outs = []
        done = []
        def generator():
            yield dut.source.ready.eq(1)
            for (data, ctrl), (first, last) in zip(words, bounds):
                yield dut.sink.data.eq(data)
                yield dut.sink.ctrl.eq(ctrl)
                yield dut.sink.first.eq(first)
                yield dut.sink.last.eq(last)
                yield dut.sink.valid.eq(1)
                while True:
                    yield
                    if (yield dut.sink.ready):
                        break
            yield dut.sink.valid.eq(0)
            for _ in range(8):
                yield
            done.append(True)
        def monitor():
            while not done:
                if (yield dut.source.valid) and (yield dut.source.ready):
                    outs.append(((yield dut.source.data), (yield dut.source.ctrl), (yield dut.source.first), (yield dut.source.last)))
                yield
        run_simulation(dut, [generator(), monitor()])
        payload = [(d, c) for d, c, f, l in outs if (d, c) != SKP_OS_WORD]
        skps    = [(f, l) for d, c, f, l in outs if (d, c) == SKP_OS_WORD]
        self.assertEqual(payload, words)
        self.assertGreaterEqual(len(skps), len(words)//8 - 2)
        self.assertTrue(all(f and l for f, l in skps))
        # Never inside a packet: the word before a SKP Ordered Set ends a packet (or is a SKP).
        for i, (d, c, f, l) in enumerate(outs):
            if (d, c) == SKP_OS_WORD and i > 0:
                self.assertTrue(outs[i - 1][3])

    def test_error_substitution(self):
        # Decode errors replaced by the ERR K Symbol.
        class DUT(Module):
            def __init__(self):
                self.submodules.decoder = decoder = Decoder(True)
                self.submodules.sub = sub = RXErrorSubstitution([decoder], with_disparity=False)
                self.sink   = sub.sink
                self.source = sub.source
                self.comb += [
                    sub.sink.valid.eq(1),
                    sub.sink.data.eq(decoder.d),
                    sub.sink.ctrl.eq(decoder.k),
                ]
        dut = DUT()
        code_ok, _ = encode_8b10b(0x4a, 0, 0)
        code_ok    = int(f"{code_ok:010b}"[::-1], 2)
        results = []
        def generator():
            for code in [code_ok, code_ok, 0, code_ok]:
                yield dut.decoder.input.eq(code)
                yield
                results.append(((yield dut.source.data), (yield dut.source.ctrl)))
            yield
            results.append(((yield dut.source.data), (yield dut.source.ctrl)))
        run_simulation(dut, generator())
        self.assertIn((0x4a, 0), results)
        self.assertIn((ERR.value, 1), results)

    def lane_roundtrip(self, rx_period, skp_enable=True, interval=8):
        # Partner TX (TXLaneDatapath in the recovered clock domain) -> local RX lane datapath
        # (descrambling, SKP removal, elastic CDC to sys).
        class DUT(Module):
            def __init__(self):
                self.submodules.tx = tx = ClockDomainsRenamer("rx")(TXLaneDatapath(skp_interval=interval))
                self.submodules.rx = rx = RXLaneDatapath(cd_from="rx", cd_to="sys")
                self.comb += [
                    tx.skp_enable.eq(skp_enable),
                    tx.source.connect(rx.sink),
                ]
        dut = DUT()
        rng = random.Random(2)
        symbols = []
        bounds  = []
        items   = [TS1.to_symbols()]*4
        for _ in range(24):
            items.append(random_packet(rng, rng.randrange(1, 6)))
            items.append([(LOGICAL_IDLE, 0)]*4*rng.randrange(0, 3))
        for item in items:
            words = symbols_to_words(item)
            for i, word in enumerate(words):
                symbols.append(word)
                bounds.append((i == 0, i == len(words) - 1))
        outs = []
        done = []
        def tx_generator():
            for (data, ctrl), (first, last) in zip(symbols, bounds):
                yield dut.tx.sink.data.eq(data)
                yield dut.tx.sink.ctrl.eq(ctrl)
                yield dut.tx.sink.first.eq(first)
                yield dut.tx.sink.last.eq(last)
                yield dut.tx.sink.valid.eq(1)
                while True:
                    yield
                    if (yield dut.tx.sink.ready):
                        break
            # Keep the stream continuous (Logical Idle) to flush the lookahead/CDC.
            yield dut.tx.sink.first.eq(0)
            yield dut.tx.sink.last.eq(0)
            yield dut.tx.sink.data.eq(0)
            yield dut.tx.sink.ctrl.eq(0)
            for _ in range(64):
                yield
            done.append(True)
        overflows = []
        def rx_monitor():
            yield dut.rx.source.ready.eq(1)
            while not done:
                if (yield dut.rx.source.valid):
                    outs.append(((yield dut.rx.source.data), (yield dut.rx.source.ctrl)))
                yield
            for _ in range(8):
                yield
            overflows.append((yield dut.rx.overflows))
        run_simulation(dut, {"rx": [tx_generator()], "sys": [rx_monitor()]}, clocks={"sys": 10, "rx": rx_period})
        return dut, symbols, outs, overflows[0]

    def test_lane_roundtrip(self):
        # Same clock: everything transmitted is received descrambled, without SKP Ordered Sets.
        dut, symbols, outs, overflows = self.lane_roundtrip(rx_period=10)
        expected = words_to_symbols(symbols)
        received = words_to_symbols(outs)
        self.assertEqual(received[:len(expected)], expected)
        self.assertEqual(overflows, 0)

    def test_lane_roundtrip_fast_partner(self):
        # Partner 10% faster (far beyond the 600 ppm of PCIe) with a SKP Ordered Set every 4 words:
        # compensated by the elastic buffer, nothing dropped.
        dut, symbols, outs, overflows = self.lane_roundtrip(rx_period=9, interval=4)
        expected = words_to_symbols(symbols)
        received = words_to_symbols(outs)
        self.assertEqual(received[:len(expected)], expected)
        self.assertEqual(overflows, 0)

    def test_lane_roundtrip_fast_partner_without_skp(self):
        # Without SKP Ordered Sets, the elastic buffer overflows and drops words.
        dut, symbols, outs, overflows = self.lane_roundtrip(rx_period=9, skp_enable=False)
        expected = words_to_symbols(symbols)
        received = words_to_symbols(outs)
        self.assertNotEqual(received[:len(expected)], expected)
        self.assertGreater(overflows, 0)
