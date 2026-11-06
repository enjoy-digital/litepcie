#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import random
import unittest

from migen import *

from litepcie.phy.soft.dll.buffer import PacketBuffer

class TestSoftDLLBuffer(unittest.TestCase):
    def run_buffer(self, packets, aborts, ready_rate=1.0, depth=64):
        """packets: list of (param, [words]); aborts: indexes of the packets aborted on their last
        word. Returns the packets read."""
        dut  = PacketBuffer([("meta", 4)], depth=depth, packets=8)
        rng  = random.Random(0)
        outs = []
        done = []
        def writer():
            for i, (param, words) in enumerate(packets):
                for j, word in enumerate(words):
                    last = (j == len(words) - 1)
                    yield dut.sink.data.eq(word)
                    yield dut.sink.meta.eq(param)
                    yield dut.sink.first.eq(j == 0)
                    yield dut.sink.last.eq(last)
                    yield dut.sink.valid.eq(1)
                    yield dut.abort.eq(last and (i in aborts))
                    yield
                    while not (yield dut.sink.ready):
                        yield
                    yield dut.abort.eq(0)
                yield dut.sink.valid.eq(0)
                for _ in range(rng.randrange(0, 3)):
                    yield
            for _ in range(1200):
                yield
            done.append(True)
        def reader():
            current = None
            while not done:
                yield dut.source.ready.eq(int(rng.random() < ready_rate))
                yield
                if (yield dut.source.valid) and (yield dut.source.ready):
                    if (yield dut.source.first):
                        current = ((yield dut.source.meta), [])
                    current[1].append((yield dut.source.data))
                    if (yield dut.source.last):
                        outs.append(current)
                        current = None
        run_simulation(dut, [writer(), reader()])
        return outs

    def test_packets(self):
        rng = random.Random(1)
        packets = [(i, [rng.getrandbits(32) for _ in range(rng.randrange(1, 9))]) for i in range(12)]
        outs = self.run_buffer(packets, aborts=set())
        self.assertEqual(outs, packets)

    def test_packets_backpressure(self):
        rng = random.Random(2)
        packets = [(i, [rng.getrandbits(32) for _ in range(rng.randrange(1, 9))]) for i in range(12)]
        outs = self.run_buffer(packets, aborts=set(), ready_rate=0.4)
        self.assertEqual(outs, packets)

    def test_abort(self):
        rng = random.Random(3)
        packets = [(i, [rng.getrandbits(32) for _ in range(rng.randrange(1, 9))]) for i in range(12)]
        aborts  = {1, 5, 6}
        outs = self.run_buffer(packets, aborts=aborts)
        self.assertEqual(outs, [p for i, p in enumerate(packets) if i not in aborts])

    def test_full(self):
        # Packets larger than the free space wait; everything is delivered.
        rng = random.Random(4)
        packets = [(i, [rng.getrandbits(32) for _ in range(20)]) for i in range(8)]
        outs = self.run_buffer(packets, aborts=set(), ready_rate=0.3, depth=64)
        self.assertEqual(outs, packets)
