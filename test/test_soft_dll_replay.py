#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import unittest

from migen import *
from migen.sim import passive

from litex.gen import *

from litepcie.phy.soft.dll.retry        import ReplayBuffer

class TestReplayCapacity(unittest.TestCase):
    def check(self, sizes, depth=16):
        """Unacknowledged TLPs of given DW counts, offered without pause: never more DWs accepted than
        the memory holds, and they all come back unchanged on a replay."""
        dut = LiteXModule()
        dut.replay = replay = ReplayBuffer(depth=depth, descriptors=16, replay_timer=100000)
        dut.comb += [replay.enable.eq(1), replay.fc_ok.eq(1), replay.source.ready.eq(1)]
        accepted = []
        received = []
        @passive
        def monitor():
            while True:
                if (yield replay.source.valid):
                    received.append((yield replay.source.data))
                yield
        def generator():
            word = 0
            for size in sizes:
                for i in range(size):
                    yield replay.sink.valid.eq(1)
                    yield replay.sink.first.eq(i == 0)
                    yield replay.sink.last.eq(i == size - 1)
                    yield replay.sink.data.eq(0x10000000 + word)
                    for _ in range(50):
                        yield
                        if (yield replay.sink.ready):
                            accepted.append(0x10000000 + word)
                            word += 1
                            break
                    else:
                        yield replay.sink.valid.eq(0)
                        return
        def finish():
            yield from generator()
            yield replay.sink.valid.eq(0)
            for _ in range(100):
                yield
            del received[:]
            yield replay.nak.eq(1)
            yield replay.ack.eq(1)
            yield replay.ack_seq.eq(0xfff)
            yield
            yield replay.nak.eq(0)
            yield replay.ack.eq(0)
            for _ in range(100):
                yield
            stored = accepted[:len(received)]
            self.assertLessEqual(len(accepted), depth + 1) # + the input stage.
            self.assertEqual(received, stored)
        run_simulation(dut, [finish(), monitor()])

    def test_even_tlps(self):
        self.check([4]*8)

    def test_odd_tlps(self):
        # An odd number of DWs stored first.
        self.check([3] + [4]*8)

    def test_single_dw_tlps(self):
        self.check([1, 3] + [2]*8)
