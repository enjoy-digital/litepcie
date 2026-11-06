#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import random
import unittest

import pytest

from migen import *

from litepcie.phy.soft.common   import STP, SDP
from litepcie.phy.soft.dll.core import DataLinkLayer

from test.model.soft.crc import dllp_crc_bytes

pytestmark = pytest.mark.slow # About 2 minutes with the Migen simulator.

class DLLLink(Module):
    """Two Data Link Layers a and b connected by ideal lanes (Logical Idle filler, no word phase
    change), with error injection: corrupt_a2b (pulse) flips a bit in the first DW of the next TLP
    from a to b, drop_dllp_b2a (level) drops the DLLPs from b to a (Acks lost)."""
    def __init__(self):
        self.submodules.a = a = DataLinkLayer(125e6, rx_depth=128, tx_depth=128, descriptors=8,
            replay_timer=256, update_timer=1500)
        self.submodules.b = b = DataLinkLayer(125e6, rx_depth=128, tx_depth=128, descriptors=8,
            replay_timer=256, update_timer=1500)
        self.link_up      = Signal()
        self.corrupt_a2b  = Signal()
        self.drop_dllp_b2a = Signal()
        self.comb += [
            a.link_up.eq(self.link_up), a.l0.eq(self.link_up),
            b.link_up.eq(self.link_up), b.l0.eq(self.link_up),
        ]
        # a -> b with corruption.
        arm         = Signal()
        corrupt_now = Signal()
        is_stp      = a.phy_sink.valid & a.phy_sink.ctrl[0] & (a.phy_sink.data[0:8] == STP.value)
        self.sync += [
            corrupt_now.eq(0),
            If(self.corrupt_a2b, arm.eq(1)),
            If(arm & is_stp,
                arm.eq(0),
                corrupt_now.eq(1),
            )
        ]
        self.comb += [
            a.phy_sink.ready.eq(1),
            b.phy_source.valid.eq(1),
            If(a.phy_sink.valid,
                b.phy_source.data.eq(a.phy_sink.data ^ (corrupt_now << 13)),
                b.phy_source.ctrl.eq(a.phy_sink.ctrl),
            )
        ]
        # b -> a with DLLP drops (SDP word and the next one).
        dropping = Signal()
        is_sdp   = b.phy_sink.valid & b.phy_sink.ctrl[0] & (b.phy_sink.data[0:8] == SDP.value)
        drop     = Signal()
        self.comb += drop.eq(self.drop_dllp_b2a & (is_sdp | dropping))
        self.sync += If(b.phy_sink.valid, dropping.eq(self.drop_dllp_b2a & is_sdp))
        self.comb += [
            b.phy_sink.ready.eq(1),
            a.phy_source.valid.eq(1),
            If(b.phy_sink.valid & ~drop,
                a.phy_source.data.eq(b.phy_sink.data),
                a.phy_source.ctrl.eq(b.phy_sink.ctrl),
            )
        ]

def mwr_tlp(rng, ndws, tag):
    """Memory Write TLP DW words (byte 0 on bits 7:0): 3DW header + ndws DWs."""
    header = bytes([0x40, 0x00, (ndws >> 8) & 0x3, ndws & 0xff])       # Fmt 010 Type 00000, Length.
    header += bytes([0x01, 0x00, tag, 0x0f])                            # Requester ID, Tag, BE.
    header += bytes([0x00, 0x00, 0x10, 0x00])                           # Address.
    payload = bytes(rng.getrandbits(8) for _ in range(4*ndws))
    data = header + payload
    return [int.from_bytes(data[i:i+4], "little") for i in range(0, len(data), 4)]

class TestSoftDLL(unittest.TestCase):
    def run_link(self, tlps, corrupt=(), drop_acks=None, drop_cycles=400, budget=6000):
        """Send tlps from a to b; corrupt: indexes of the TLPs corrupted on the lane; drop_acks:
        (start, end) TLP indexes during which the DLLPs from b are dropped, then drop_cycles more. Returns the TLPs received
        by b and the link statistics."""
        dut   = DLLLink()
        outs  = []
        stats = {}
        done  = []
        def generator():
            for _ in range(4):
                yield
            yield dut.link_up.eq(1)
            for cycle in range(budget):
                if (yield dut.a.dl_active) and (yield dut.b.dl_active):
                    stats["dl_active"] = cycle
                    break
                yield
            else:
                stats["dl_active"] = None
                done.append(True)
                return
            for i, words in enumerate(tlps):
                if drop_acks is not None:
                    yield dut.drop_dllp_b2a.eq(int(drop_acks[0] <= i < drop_acks[1]))
                if i in corrupt:
                    yield dut.corrupt_a2b.eq(1)
                    yield
                    yield dut.corrupt_a2b.eq(0)
                for j, word in enumerate(words):
                    yield dut.a.sink.data.eq(word)
                    yield dut.a.sink.first.eq(j == 0)
                    yield dut.a.sink.last.eq(j == len(words) - 1)
                    yield dut.a.sink.valid.eq(1)
                    yield
                    while not (yield dut.a.sink.ready):
                        yield
                yield dut.a.sink.valid.eq(0)
            yield dut.a.sink.valid.eq(0)
            if drop_acks is not None:
                # All the Acks lost long enough for the REPLAY_TIMER to expire.
                for _ in range(drop_cycles):
                    yield
            yield dut.drop_dllp_b2a.eq(0)
            for cycle in range(budget):
                if len(outs) >= len(tlps) and not (yield dut.a.tx.replay.pending):
                    for _ in range(64):
                        yield
                    break
                yield
            stats["replays"]   = (yield dut.a.tx.replay.replays)
            stats["rx_errors"] = (yield dut.b.rx.errors)
            stats["pending"]   = (yield dut.a.tx.replay.pending)
            done.append(True)
        def monitor():
            current = []
            yield dut.b.source.ready.eq(1)
            yield dut.a.source.ready.eq(1)
            while not done:
                if (yield dut.b.source.valid):
                    if (yield dut.b.source.first):
                        current = []
                    current.append((yield dut.b.source.data))
                    if (yield dut.b.source.last):
                        outs.append(list(current))
                yield
        def dllp_monitor():
            # DLLPs from b, as they are on the lane.
            dllps = stats["dllps"] = []
            first = None
            while not done:
                if (yield dut.b.phy_sink.valid):
                    data = (yield dut.b.phy_sink.data)
                    if first is not None:
                        dllps.append(first + (data & 0xffffff).to_bytes(3, "little"))
                        first = None
                    elif ((yield dut.b.phy_sink.ctrl) & 1) and (data & 0xff) == SDP.value:
                        first = (data >> 8).to_bytes(3, "little")
                yield
        run_simulation(dut, [generator(), monitor(), dllp_monitor()])
        return outs, stats

    def test_init_and_tlps(self):
        rng  = random.Random(0)
        tlps = [mwr_tlp(rng, rng.randrange(1, 9), i) for i in range(10)]
        outs, stats = self.run_link(tlps)
        self.assertIsNotNone(stats["dl_active"], "DL_Active not reached")
        self.assertEqual(outs, tlps)
        self.assertEqual(stats["replays"], 0)
        self.assertEqual(stats["pending"], 0)

    def test_corrupted_tlp_replayed(self):
        # Corrupted TLPs: Nak, replayed, received exactly once in order.
        rng  = random.Random(1)
        tlps = [mwr_tlp(rng, rng.randrange(1, 6), i) for i in range(8)]
        outs, stats = self.run_link(tlps, corrupt={2})
        self.assertIsNotNone(stats["dl_active"])
        self.assertEqual(outs, tlps)
        self.assertGreaterEqual(stats["replays"], 1)
        self.assertGreaterEqual(stats["rx_errors"], 1)
        self.assertEqual(stats["pending"], 0)

    def test_lost_acks_replay_timer(self):
        # Acks dropped for a while: REPLAY_TIMER replays, duplicates discarded by the receiver.
        rng  = random.Random(2)
        tlps = [mwr_tlp(rng, rng.randrange(1, 4), i) for i in range(8)]
        outs, stats = self.run_link(tlps, drop_acks=(0, 8), budget=8000)
        self.assertIsNotNone(stats["dl_active"])
        self.assertEqual(outs, tlps)
        self.assertGreaterEqual(stats["replays"], 1)
        self.assertEqual(stats["pending"], 0)

    def test_dllps_under_load(self):
        # Ack sequence number and credits changing all the time: each DLLP is consistent on the lane
        # and one sent while another one is requested doesn't take its place (no Ack lost, no replay).
        rng  = random.Random(3)
        tlps = [mwr_tlp(rng, rng.randrange(1, 4), i) for i in range(64)]
        outs, stats = self.run_link(tlps, budget=20000)
        self.assertIsNotNone(stats["dl_active"])
        self.assertEqual(outs, tlps)
        self.assertGreater(len(stats["dllps"]), 64)
        bad = [dllp.hex() for dllp in stats["dllps"] if dllp_crc_bytes(dllp[:4]) != dllp[4:]]
        self.assertEqual(bad, [])
        self.assertEqual(stats["replays"], 0)
        self.assertEqual(stats["pending"], 0)
