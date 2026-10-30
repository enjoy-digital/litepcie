#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

# The 128-bit receive interface of some hard IPs reports packet boundaries through is_sof/is_eof
# markers and keeps tkeep all-ones on every beat. The depacketizer relies on the byte enables of
# the last beat to tell valid DWs from padding, so the PHY has to rebuild them from the EOF marker.
# These tests drive the 128-bit RX path (byte-enable reconstruction, aligner, depacketizer) with
# beats shaped like the hard IP output and check that every TLP comes out with exactly its payload.

import random
import unittest

from migen import *
from migen.sim import run_simulation, passive

from litex.gen import *
from litex.soc.interconnect import stream

from litepcie.common import phy_layout
from litepcie.phy.common import PHYRX128BAligner, rx_128b_byte_enable_from_eof
from litepcie.tlp.depacketizer import LitePCIeTLPDepacketizer

from test.model.tlp import CPLD, WR32, RD32

# Helpers ------------------------------------------------------------------------------------------

def _rev32(dw):
    return int.from_bytes(dw.to_bytes(4, "little"), "big")

def _pack(dws):
    v = 0
    for i, dw in enumerate(dws):
        v |= (dw & 0xffffffff) << (32*i)
    return v

def _cpld(payload, tag=0):
    cpl = CPLD()
    cpl.fmt           = 0b10
    cpl.type          = 0b01010
    cpl.length        = len(payload) & 0x3ff
    cpl.byte_count    = (4*len(payload)) & 0xfff
    cpl.lower_address = 0
    cpl.requester_id  = 0x0100
    cpl.completer_id  = 0x0400
    cpl.tag           = tag
    return cpl.encode_dwords(payload)

def _wr32(payload, address):
    wr = WR32()
    wr.fmt          = 0b10
    wr.type         = 0b00000
    wr.length       = len(payload)
    wr.first_be     = 0xf
    wr.last_be      = 0xf if len(payload) > 1 else 0x0
    wr.address      = address
    wr.requester_id = 0x0100
    wr.tag          = 0x11
    return wr.encode_dwords(payload)

def _rd32(length, address):
    rd = RD32()
    rd.fmt          = 0b00
    rd.type         = 0b00000
    rd.length       = length
    rd.first_be     = 0xf
    rd.last_be      = 0xf if length > 1 else 0x0
    rd.address      = address
    rd.requester_id = 0x0100
    rd.tag          = 0x22
    return rd.encode_dwords()

def _hard_ip_beats(tlps, straddle):
    """Lay TLPs on a 128-bit stream the way the hard IP presents them.

    Each TLP starts at DW0 of a new beat, except that when the previous TLP ended in DW0 or DW1
    and straddling is enabled, the next TLP starts at DW2 of that same beat. Each beat carries the
    is_sof (bit 4: present, 0b11000: start at DW2) and is_eof (bit 4: present, bits 3:0: byte
    offset of the last byte) markers; tkeep is not modelled since the hard IP keeps it all-ones.
    """
    beats = []
    pos   = 4

    def new_beat():
        beats.append({"dws": [0, 0, 0, 0], "is_sof": 0, "is_eof": 0})
        return beats[-1]

    for dws in tlps:
        if straddle and beats and pos in (1, 2):
            beat = beats[-1]
            pos  = 2
            beat["is_sof"] = 0b11000
        else:
            beat = new_beat()
            pos  = 0
            beat["is_sof"] = 0b10000
        for dw in dws:
            if pos == 4:
                beat = new_beat()
                pos  = 0
            beat["dws"][pos] = dw
            pos += 1
        beat["is_eof"] = 0b10000 | (4*(pos - 1) + 3)
    return beats

# DUT ----------------------------------------------------------------------------------------------

class _RX128bDUT(LiteXModule):
    """128-bit RX path as wired in the 7-series PHY: markers -> first/last/be -> aligner -> depacketizer."""
    def __init__(self):
        self.valid  = Signal()
        self.ready  = Signal()
        self.dat    = Signal(128)
        self.is_sof = Signal(5)
        self.is_eof = Signal(5)

        # # #

        self.aligner      = aligner      = PHYRX128BAligner()
        self.depacketizer = depacketizer = LitePCIeTLPDepacketizer(128, "big")

        raw = stream.Endpoint(phy_layout(128))
        self.comb += [
            raw.valid.eq(self.valid),
            self.ready.eq(raw.ready),
            raw.dat.eq(self.dat),
            raw.first.eq(self.is_sof[4]),
            raw.last.eq(self.is_eof[4]),
            If(self.is_sof == 0b11000, aligner.first_dword.eq(2)),
            raw.connect(aligner.sink),
            aligner.source.connect(depacketizer.sink),
        ]
        self.comb += rx_128b_byte_enable_from_eof(raw.be, self.is_eof)

# Tests --------------------------------------------------------------------------------------------

class TestRX128bEOFByteEnables(unittest.TestCase):
    def test_byte_enables_follow_eof_marker(self):
        class DUT(Module):
            def __init__(self):
                self.is_eof = Signal(5)
                self.be     = Signal(16)
                self.comb += rx_128b_byte_enable_from_eof(self.be, self.is_eof)

        dut      = DUT()
        expected = {0b00000: 0xffff, 0b01111: 0xffff, 0b10011: 0x000f, 0b10111: 0x00ff, 0b11011: 0x0fff, 0b11111: 0xffff}
        seen     = {}

        def generator():
            for is_eof in expected:
                yield dut.is_eof.eq(is_eof)
                yield
                seen[is_eof] = (yield dut.be)

        run_simulation(dut, generator())
        self.assertEqual(seen, expected)

    def _run(self, tlps, expected, straddle, seed):
        dut   = _RX128bDUT()
        beats = _hard_ip_beats([dws for dws, _ in tlps], straddle)
        rng   = random.Random(seed)
        cmps  = []
        reqs  = []

        def driver():
            for beat in beats:
                for _ in range(rng.randrange(3)):
                    yield dut.valid.eq(0)
                    yield
                yield dut.dat.eq(_pack(beat["dws"]))
                yield dut.is_sof.eq(beat["is_sof"])
                yield dut.is_eof.eq(beat["is_eof"])
                yield dut.valid.eq(1)
                yield
                while not (yield dut.ready):
                    yield
            yield dut.valid.eq(0)
            for _ in range(256):
                yield

        @passive
        def cmp_monitor():
            source = dut.depacketizer.cmp_source
            packet = []
            while True:
                if (yield source.valid) and (yield source.ready):
                    dat = (yield source.dat)
                    be  = (yield source.be)
                    packet.append({
                        "dws"   : [(dat >> (32*i)) & 0xffffffff for i in range(4)],
                        "be"    : [(be >> (4*i)) & 0xf for i in range(4)],
                        "first" : (yield source.first),
                        "last"  : (yield source.last),
                        "len"   : (yield source.len),
                        "tag"   : (yield source.tag),
                    })
                    if packet[-1]["last"]:
                        cmps.append(packet)
                        packet = []
                yield source.ready.eq(rng.randrange(4) != 0)
                yield

        @passive
        def req_monitor():
            source = dut.depacketizer.req_source
            packet = []
            while True:
                if (yield source.valid) and (yield source.ready):
                    dat = (yield source.dat)
                    packet.append({
                        "dws"   : [(dat >> (32*i)) & 0xffffffff for i in range(4)],
                        "we"    : (yield source.we),
                        "len"   : (yield source.len),
                        "adr"   : (yield source.adr),
                        "first" : (yield source.first),
                        "last"  : (yield source.last),
                    })
                    if packet[-1]["last"]:
                        reqs.append(packet)
                        packet = []
                yield source.ready.eq(rng.randrange(4) != 0)
                yield

        run_simulation(dut, [driver(), cmp_monitor(), req_monitor()])

        exp_cmps = [e for kind, e in expected if kind == "cmp"]
        exp_reqs = [e for kind, e in expected if kind == "req"]
        self.assertEqual(len(cmps), len(exp_cmps), f"completions: {len(cmps)} received, {len(exp_cmps)} expected")
        self.assertEqual(len(reqs), len(exp_reqs), f"requests: {len(reqs)} received, {len(exp_reqs)} expected")

        for packet, (payload, tag) in zip(cmps, exp_cmps):
            # Exactly ceil(N/4) beats, every payload DW present once, no padding DW marked valid.
            self.assertEqual(len(packet), (len(payload) + 3)//4)
            self.assertEqual([b["first"] for b in packet], [1] + [0]*(len(packet) - 1))
            valid_dws = [dw for b in packet for dw, be in zip(b["dws"], b["be"]) if be]
            self.assertTrue(all(be in (0x0, 0xf) for b in packet for be in b["be"]))
            self.assertEqual(valid_dws, [_rev32(dw) for dw in payload])
            self.assertTrue(all(b["len"] == len(payload) for b in packet))
            self.assertTrue(all(b["tag"] == tag for b in packet))

        for packet, (we, payload, length, address) in zip(reqs, exp_reqs):
            self.assertTrue(all(b["we"] == we for b in packet))
            self.assertTrue(all(b["len"] == length for b in packet))
            self.assertTrue(all(b["adr"] == address for b in packet))
            if we:
                self.assertEqual(len(packet), (len(payload) + 3)//4)
                dws = [dw for b in packet for dw in b["dws"]][:len(payload)]
                self.assertEqual(dws, [_rev32(dw) for dw in payload])
            else:
                self.assertEqual(len(packet), 1)

    def test_aligned_completions_keep_their_length(self):
        # Completions of the sizes a host returns for DMA reads (3DW header + 16/32/64/128 DWs): the
        # last beat always carries a padding DW that must not become an extra data beat.
        rng  = random.Random(1)
        tlps = []
        for tag, n in enumerate([16, 32, 64, 128, 16, 16]):
            payload = [rng.getrandbits(32) for _ in range(n)]
            tlps.append((_cpld(payload, tag=tag), ("cmp", (payload, tag))))
        payload = [rng.getrandbits(32)]
        tlps.append((_wr32(payload, 0x1000), ("req", (1, payload, 1, 0x1000))))
        tlps.append((_rd32(1, 0x2000),       ("req", (0, [], 1, 0x2000))))
        payload = [rng.getrandbits(32) for _ in range(32)]
        tlps.append((_cpld(payload, tag=7),  ("cmp", (payload, 7))))
        self._run([(dws, None) for dws, _ in tlps], [e for _, e in tlps], straddle=False, seed=2)

    def test_straddled_packets_keep_their_length(self):
        # A write ending in DW0 lets the next TLPs start at DW2 of the same beat; the aligner shifts
        # them back and the byte enables rebuilt from the EOF marker must follow the shift.
        rng  = random.Random(3)
        tlps = []
        payload = [rng.getrandbits(32) for _ in range(2)]
        tlps.append((_wr32(payload, 0x3000), ("req", (1, payload, 2, 0x3000))))
        payload = [rng.getrandbits(32) for _ in range(16)]
        tlps.append((_cpld(payload, tag=3),  ("cmp", (payload, 3))))
        payload = [rng.getrandbits(32)]
        tlps.append((_wr32(payload, 0x4000), ("req", (1, payload, 1, 0x4000))))
        tlps.append((_rd32(4, 0x5000),       ("req", (0, [], 4, 0x5000))))
        payload = [rng.getrandbits(32) for _ in range(32)]
        tlps.append((_cpld(payload, tag=4),  ("cmp", (payload, 4))))
        payload = [rng.getrandbits(32) for _ in range(64)]
        tlps.append((_cpld(payload, tag=5),  ("cmp", (payload, 5))))
        payload = [rng.getrandbits(32)]
        tlps.append((_wr32(payload, 0x6000), ("req", (1, payload, 1, 0x6000))))
        self._run([(dws, None) for dws, _ in tlps], [e for _, e in tlps], straddle=True, seed=4)

if __name__ == "__main__":
    unittest.main()
