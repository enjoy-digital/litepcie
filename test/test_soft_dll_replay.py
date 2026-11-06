#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import unittest

from migen import *
from migen.sim import passive

from litex.gen import *

from litepcie.phy.soft.dll.flow_control import FlowControlTX, FC_P, FC_NP
from litepcie.phy.soft.dll.retry        import ReplayBuffer

MWR = 0x01000040 # 1 DW Memory Write:  Posted,     1 data credit.
MRD = 0x01000000 # 1 DW Memory Read:   Non-Posted, 0 data credit.

class DUT(LiteXModule):
    def __init__(self):
        self.replay = replay = ReplayBuffer(depth=256, descriptors=16, replay_timer=100000)
        self.fc     = fc     = FlowControlTX()
        self.comb += [
            replay.enable.eq(1),
            replay.source.ready.eq(1),
            fc.tlp_type.eq(replay.fc_type),
            fc.tlp_data.eq(replay.fc_data),
            replay.fc_ok.eq(fc.ok),
            fc.consume.eq(replay.fc_consume),
        ]

def send(dut, tlps):
    """Back-to-back TLPs: header DW0 and one more DW."""
    for dw0 in tlps:
        for i, data in enumerate([dw0, 0x11223344]):
            yield dut.replay.sink.valid.eq(1)
            yield dut.replay.sink.first.eq(i == 0)
            yield dut.replay.sink.last.eq(i == 1)
            yield dut.replay.sink.data.eq(data)
            yield
            while not (yield dut.replay.sink.ready):
                yield
    yield dut.replay.sink.valid.eq(0)

def set_limit(dut, fc_type, hdr, data, init=True):
    yield dut.fc.fc_type.eq(fc_type)
    yield dut.fc.fc_hdr.eq(hdr)
    yield dut.fc.fc_data.eq(data)
    yield (dut.fc.init if init else dut.fc.update).eq(1)
    yield
    yield (dut.fc.init if init else dut.fc.update).eq(0)

class TestCredits(unittest.TestCase):
    def run_dut(self, script):
        dut     = DUT()
        started = []
        @passive
        def monitor():
            while True:
                if (yield dut.replay.source.valid) and (yield dut.replay.source.first):
                    started.append(((yield dut.replay.source.seq), (yield dut.replay.source.data)))
                yield
        run_simulation(dut, [script(dut, started), monitor()])

    def test_exact_credits_not_overrun(self):
        # Credits for exactly 3 back-to-back TLPs: a stale ok would let the 4th one out.
        def script(dut, started):
            yield from set_limit(dut, FC_P, hdr=3, data=3)
            yield from send(dut, [MWR]*5)
            for _ in range(200):
                yield
            self.assertEqual(len(started), 3)
            self.assertEqual([s[0] for s in started], [0, 1, 2])
            # UpdateFC: 2 more.
            yield from set_limit(dut, FC_P, hdr=5, data=5, init=False)
            for _ in range(200):
                yield
            self.assertEqual([s[0] for s in started], [0, 1, 2, 3, 4])
        self.run_dut(script)

    def test_data_credits_limit(self):
        # Header credits available, data credits for 2 TLPs only.
        def script(dut, started):
            yield from set_limit(dut, FC_P, hdr=10, data=2)
            yield from send(dut, [MWR]*4)
            for _ in range(200):
                yield
            self.assertEqual(len(started), 2)
        self.run_dut(script)

    def test_mixed_types(self):
        # The next TLP is gated with its own type: Posted blocked, the Non-Posted before it not.
        def script(dut, started):
            yield from set_limit(dut, FC_NP, hdr=1, data=0)
            yield from set_limit(dut, FC_P,  hdr=1, data=1)
            yield from send(dut, [MRD, MWR, MWR])
            for _ in range(200):
                yield
            self.assertEqual([s[1] for s in started], [MRD, MWR])
        self.run_dut(script)

    def test_next_type_without_credits(self):
        # The previous TLP's type has credits, the next one's has none: ok must not be the previous one's.
        def script(dut, started):
            yield from set_limit(dut, FC_NP, hdr=5, data=0)
            yield from send(dut, [MRD, MWR])
            for _ in range(100):
                yield
            self.assertEqual([s[1] for s in started], [MRD])
        self.run_dut(script)

    def test_replay_does_not_consume(self):
        # A replay needs no credits and consumes none.
        def script(dut, started):
            yield from set_limit(dut, FC_P, hdr=2, data=2)
            yield from send(dut, [MWR]*2)
            for _ in range(100):
                yield
            self.assertEqual(len(started), 2)
            self.assertEqual((yield dut.fc.consumed_hdr[FC_P]), 2)
            yield dut.replay.nak.eq(1)
            yield dut.replay.ack.eq(1)
            yield dut.replay.ack_seq.eq(0xfff) # Nothing acknowledged.
            yield
            yield dut.replay.nak.eq(0)
            yield dut.replay.ack.eq(0)
            for _ in range(100):
                yield
            self.assertEqual([s[0] for s in started], [0, 1, 0, 1])
            self.assertEqual((yield dut.fc.consumed_hdr[FC_P]), 2)
        self.run_dut(script)

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
