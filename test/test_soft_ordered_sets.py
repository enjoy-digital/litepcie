#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import random
import unittest

from migen import *

from litepcie.phy.soft.common       import EIE, EIOS, FTS_OS, TS1, LOGICAL_IDLE, RATE_2_5GT, RATE_5_0GT
from litepcie.phy.soft.common       import training_sequence
from litepcie.phy.soft.ordered_sets import TSGenerator, TSChecker, OrderedSetDetector

from test.model.soft.common import symbols_to_words, ordered_set_words

def random_ts(rng):
    return dict(
        ts    = rng.choice([1, 2]),
        link  = rng.choice([None, rng.randrange(256)]),
        lane  = rng.choice([None, rng.randrange(32)]),
        n_fts = rng.randrange(256),
        rate  = rng.choice([RATE_2_5GT, RATE_2_5GT | RATE_5_0GT]),
        ctrl  = rng.randrange(32),
    )

def ts_fields(**ts):
    return dict(
        ts2      = int(ts["ts"] == 2),
        link     = 0 if ts["link"] is None else ts["link"],
        link_pad = int(ts["link"] is None),
        lane     = 0 if ts["lane"] is None else ts["lane"],
        lane_pad = int(ts["lane"] is None),
        n_fts    = ts["n_fts"],
        rate     = ts["rate"],
        ctrl     = ts["ctrl"],
    )

def run_checker(words):
    dut     = TSChecker()
    results = []
    def generator():
        for data, ctrl in words + [(0, 0)]*4:
            yield dut.sink.data.eq(data)
            yield dut.sink.ctrl.eq(ctrl)
            yield dut.sink.valid.eq(1)
            yield
            if (yield dut.detected):
                results.append(("ts", {
                    "ts2"      : (yield dut.ts.ts2),
                    "link"     : (yield dut.ts.link),
                    "link_pad" : (yield dut.ts.link_pad),
                    "lane"     : (yield dut.ts.lane),
                    "lane_pad" : (yield dut.ts.lane_pad),
                    "n_fts"    : (yield dut.ts.n_fts),
                    "rate"     : (yield dut.ts.rate),
                    "ctrl"     : (yield dut.ts.ctrl),
                }, (yield dut.inverted)))
            if (yield dut.error):
                results.append(("error",))
    run_simulation(dut, generator())
    return results

class TestSoftOrderedSets(unittest.TestCase):
    def test_ts_generator(self):
        # Ordered Sets back-to-back while enabled, fields sampled per Ordered Set, first/last/done.
        rng    = random.Random(0)
        tss    = [random_ts(rng) for _ in range(6)]
        dut    = TSGenerator()
        outs   = []
        dones  = []
        def generator():
            yield dut.source.ready.eq(1)
            yield dut.enable.eq(1)
            index = 0
            fields = ts_fields(**tss[0])
            for name, value in fields.items():
                yield getattr(dut.ts, name).eq(value)
            while index < len(tss):
                yield
                if (yield dut.source.valid) and (yield dut.source.ready):
                    outs.append(((yield dut.source.data), (yield dut.source.ctrl), (yield dut.source.first), (yield dut.source.last)))
                if (yield dut.done):
                    dones.append(True)
                    index += 1
                    if index < len(tss):
                        fields = ts_fields(**tss[index])
                        for name, value in fields.items():
                            yield getattr(dut.ts, name).eq(value)
                    else:
                        yield dut.enable.eq(0)
            for _ in range(4):
                yield
                if (yield dut.source.valid) and (yield dut.source.ready):
                    outs.append(((yield dut.source.data), (yield dut.source.ctrl), (yield dut.source.first), (yield dut.source.last)))
        run_simulation(dut, generator())
        expected = []
        for ts in tss:
            expected += ordered_set_words(training_sequence(**ts))
        self.assertEqual([(d, c) for d, c, f, l in outs], expected)
        self.assertEqual([f for d, c, f, l in outs], [1, 0, 0, 0]*len(tss))
        self.assertEqual([l for d, c, f, l in outs], [0, 0, 0, 1]*len(tss))
        self.assertEqual(len(dones), len(tss))

    def test_ts_generator_eieos(self):
        # Rates above 2.5 GT/s: EIEOS first, then every 32 Training Sequences, not counted as one.
        dut   = TSGenerator()
        words = []
        dones = []
        def generator():
            yield dut.eieos.eq(1)
            yield dut.enable.eq(1)
            yield dut.source.ready.eq(1)
            yield
            for _ in range(4*70):
                if (yield dut.source.valid):
                    words.append(((yield dut.source.data), (yield dut.source.ctrl)))
                dones.append((yield dut.done))
                yield
        run_simulation(dut, generator())
        eie   = 0xfc # K28.7.
        eieos = [(0xfcfcfcbc, 0xf), (0xfcfcfcfc, 0xf), (0xfcfcfcfc, 0xf), (0x4afcfcfc, 0x7)]
        sets  = [words[i:i+4] for i in range(0, len(words) - 3, 4)]
        where = [i for i, os in enumerate(sets) if os == eieos]
        self.assertEqual(where[:3], [0, 33, 66])
        self.assertEqual(eie, EIE.value)
        # A Training Sequence per done, EIEOS excluded.
        self.assertEqual(sum(dones), len(sets) - len(where))

    def test_ts_generator_no_eieos(self):
        # 2.5 GT/s: Training Sequences only (first word's Symbol 1 isn't EIE).
        dut   = TSGenerator()
        words = []
        def generator():
            yield dut.enable.eq(1)
            yield dut.source.ready.eq(1)
            yield
            for _ in range(4*40):
                words.append((yield dut.source.ctrl))
                yield
        run_simulation(dut, generator())
        self.assertNotIn(0xf, words)
        self.assertNotIn(0x7, words)

    def test_ts_checker_any_alignment(self):
        # TS1/TS2 with random fields, PAD Link/Lane numbers, at every Symbol position, separated
        # by Logical Idle (any length) and other Ordered Sets.
        rng = random.Random(1)
        for shift in range(4):
            tss      = [random_ts(rng) for _ in range(8)]
            symbols  = [(LOGICAL_IDLE, 0)]*shift
            for ts in tss:
                symbols += training_sequence(**ts).to_symbols()
                symbols += [(LOGICAL_IDLE, 0)]*rng.randrange(0, 6)
                if rng.random() < 0.3:
                    symbols += EIOS.to_symbols()
            symbols += [(LOGICAL_IDLE, 0)]*((-len(symbols)) % 4)
            results  = run_checker(symbols_to_words(symbols))
            detected = [r for r in results if r[0] == "ts"]
            self.assertEqual([r for r in results if r[0] == "error"], [])
            self.assertEqual(len(detected), len(tss), f"shift {shift}")
            for (kind, fields, inverted), ts in zip(detected, tss):
                self.assertEqual(fields, ts_fields(**ts))
                self.assertEqual(inverted, 0)

    def test_ts_checker_inverted(self):
        # Inverted identifiers (D21.5/D26.5): detected with inverted set.
        for ts in [1, 2]:
            symbols = training_sequence(ts=ts, inverted=True).to_symbols()*2
            results = run_checker(symbols_to_words(symbols))
            detected = [r for r in results if r[0] == "ts"]
            self.assertEqual(len(detected), 2)
            for kind, fields, inverted in detected:
                self.assertEqual(inverted, 1)
                self.assertEqual(fields["ts2"], int(ts == 2))

    def test_ts_checker_errors(self):
        # A corrupted identifier: error and no detection; a COM in the middle restarts a sequence.
        good = training_sequence(ts=1, link=1, lane=2).to_symbols()
        bad  = list(good)
        bad[10] = (0x4b, 0)
        symbols = bad + good + good[:8] + good
        results = run_checker(symbols_to_words(symbols))
        self.assertEqual([r[0] for r in results], ["error", "ts", "error", "ts"])

    def test_ordered_set_detector(self):
        # EIOS/FTS detected at any Symbol position, once each, not on Training Sequences.
        for ordered_set in [EIOS, FTS_OS]:
            for shift in range(4):
                symbols  = [(LOGICAL_IDLE, 0)]*shift + ordered_set.to_symbols()
                symbols += [(LOGICAL_IDLE, 0)]*3 + ordered_set.to_symbols()
                symbols += TS1.to_symbols()
                symbols += [(LOGICAL_IDLE, 0)]*((-len(symbols)) % 4)
                dut   = OrderedSetDetector(ordered_set)
                count = []
                def generator():
                    for data, ctrl in symbols_to_words(symbols) + [(0, 0)]*2:
                        yield dut.sink.data.eq(data)
                        yield dut.sink.ctrl.eq(ctrl)
                        yield dut.sink.valid.eq(1)
                        yield
                        if (yield dut.detected):
                            count.append(True)
                run_simulation(dut, generator())
                self.assertEqual(len(count), 2, f"{ordered_set.name} shift {shift}")

    def test_generator_checker_loopback(self):
        class DUT(Module):
            def __init__(self):
                self.submodules.gen = TSGenerator()
                self.submodules.chk = TSChecker()
                self.comb += self.gen.source.connect(self.chk.sink)
        dut = DUT()
        count = []
        def generator():
            yield dut.gen.enable.eq(1)
            yield dut.gen.ts.ts2.eq(1)
            yield dut.gen.ts.link.eq(5)
            yield dut.gen.ts.lane_pad.eq(1)
            yield dut.gen.ts.n_fts.eq(0x80)
            yield dut.gen.ts.rate.eq(RATE_2_5GT)
            for _ in range(48):
                yield
                if (yield dut.chk.detected):
                    count.append(((yield dut.chk.ts.ts2), (yield dut.chk.ts.link), (yield dut.chk.ts.lane_pad), (yield dut.chk.ts.n_fts)))
        run_simulation(dut, generator())
        self.assertGreaterEqual(len(count), 8)
        self.assertTrue(all(c == (1, 5, 1, 0x80) for c in count))
