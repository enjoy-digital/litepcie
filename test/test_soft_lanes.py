#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import unittest

from migen import *

from litepcie.phy.soft.common import COM
from litepcie.phy.soft.lanes  import RXLaneDeskew

def ts_words(lane, n):
    """n Training Sequences of 4 words on a lane: COM on Symbol 0 of the first word."""
    words = []
    for i in range(n):
        words += [(COM.value | ((i & 0xff) << 8) | (lane << 16), 0x1), (0x11111111, 0), (0x22222222, 0), (0x33333333, 0)]
    return words

class TestSoftLanes(unittest.TestCase):
    def run_deskew(self, skews, nlanes=2, cycles=200):
        """skews: words of delay per lane. Returns the locked/stable states and the source words."""
        dut = RXLaneDeskew(nlanes)
        streams = [[(0, 0)]*skews[i] + ts_words(i, cycles//4) for i in range(nlanes)]
        out = {"locked": 0, "stable": 0, "words": []}
        def generator():
            yield dut.align.eq(1)
            for t in range(cycles):
                for i in range(nlanes):
                    data, ctrl = streams[i][t]
                    yield dut.sinks[i].valid.eq(1)
                    yield dut.sinks[i].data.eq(data)
                    yield dut.sinks[i].ctrl.eq(ctrl)
                yield
                out["locked"] = (yield dut.locked)
                out["stable"] = (yield dut.stable)
                if (yield dut.source.valid):
                    out["words"].append(((yield dut.source.data), (yield dut.source.ctrl)))
        run_simulation(dut, generator())
        return out

    def test_skew(self):
        # Allowed skews (up to 2 words): locked, COMs side by side, same Training Sequence on both.
        for skews in [[0, 0], [0, 1], [2, 0]]:
            with self.subTest(skews=skews):
                out = self.run_deskew(skews)
                self.assertEqual(out["locked"], 1)
                self.assertEqual(out["stable"], 1)
                coms = [d for d, c in out["words"] if c & 0x3 == 0x3]
                self.assertGreater(len(coms), 10)
                for data in coms:
                    # Lanes side by side: Symbol 0 on 0/1, the index of the Training Sequence is Symbol 1.
                    self.assertEqual((data >> 16) & 0xff, (data >> 24) & 0xff)

    def run_backlog(self, backlog, **kwargs):
        """The lanes are in time, but one restarted first: it has old words in its FIFO when the others
        start. Returns the indexes of the Training Sequences side by side once stable."""
        dut   = RXLaneDeskew(2, **kwargs)
        pairs = []
        def generator():
            yield dut.align.eq(1)
            for t in range(160):
                data, ctrl = ts_words(0, 40)[t]
                for i in range(2):
                    yield dut.sinks[i].valid.eq(t >= (0 if i == 1 else backlog))
                    yield dut.sinks[i].data.eq(data)
                    yield dut.sinks[i].ctrl.eq(ctrl)
                yield
                if (yield dut.stable) and (yield dut.source.valid) and (yield dut.source.ctrl) & 0x3 == 0x3:
                    value = (yield dut.source.data)
                    pairs.append(((value >> 16) & 0xff, (value >> 24) & 0xff))
        run_simulation(dut, generator())
        return pairs

    def test_backlog(self):
        # COMs arriving together but from different Training Sequences: not taken for aligned lanes.
        for backlog in [4, 8, 12]:
            with self.subTest(backlog=backlog):
                pairs = self.run_backlog(backlog)
                self.assertGreater(len(pairs), 10)
                for a, b in pairs:
                    self.assertEqual(a, b)

    def test_backlog_guard_needed(self):
        # Same without the guard: shows what the previous test detects.
        pairs = self.run_backlog(8, max_skew=1000)
        self.assertGreater(len(pairs), 10)
        self.assertTrue(any(a != b for a, b in pairs))
