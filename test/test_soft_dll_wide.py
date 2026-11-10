#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import random
import unittest

from migen import *

from litepcie.phy.soft.common   import COM, STP, SDP, END, EDB, PAD
from litepcie.phy.soft.dll.wide import WideRXFramer, WideTXFramer, RXPhaseAligner

def tlp_symbols(seq, dws, lcrc=0x11223344, edb=False):
    """Framed TLP: (byte, k) Symbols. dws: DWs as bytes lists."""
    out = [(STP.value, 1), ((seq >> 8) & 0xf, 0), (seq & 0xff, 0)]
    for dw in dws:
        out += [(b, 0) for b in dw]
    out += [(b, 0) for b in lcrc.to_bytes(4, "little")]
    out += [(EDB.value if edb else END.value, 1)]
    return out

def dllp_symbols(dllp):
    return [(SDP.value, 1)] + [(b, 0) for b in dllp] + [(END.value, 1)]

def random_dws(rng, n):
    return [[rng.randrange(256) for _ in range(4)] for _ in range(n)]

def to_beats(symbols, ndw):
    beats = []
    for i in range(0, len(symbols), 4*ndw):
        chunk = symbols[i:i+4*ndw] + [(0, 0)]*(4*ndw - len(symbols[i:i+4*ndw]))
        beats.append((sum(b << (8*j) for j, (b, k) in enumerate(chunk)), sum(k << j for j, (b, k) in enumerate(chunk))))
    return beats

def run_rx(ndw, symbols, ready=None):
    """Symbols through the RX framer: returns the TLPs and the DLLPs."""
    dut   = WideRXFramer(ndw)
    tlps, dllps, errors = [], [], []
    beats = to_beats(symbols, ndw) + [(0, 0)]*8
    done  = [False]
    def generator():
        yield dut.sink.valid.eq(1)
        for data, ctrl in beats:
            yield dut.sink.data.eq(data)
            yield dut.sink.ctrl.eq(ctrl)
            yield
        for _ in range(512):
            yield
        done[0] = True
    def monitor():
        cur = None
        yield dut.tlp.ready.eq(1)
        while not done[0]:
            if (yield dut.tlp.valid) and (yield dut.tlp.ready):
                data = (yield dut.tlp.data)
                n    = (yield dut.tlp.dws)
                if (yield dut.tlp.first):
                    cur = dict(seq=(yield dut.tlp.seq), dws=[])
                cur["dws"] += [[(data >> (32*i + 8*j)) & 0xff for j in range(4)] for i in range(n)]
                if (yield dut.tlp.last):
                    cur["edb"] = (yield dut.tlp.edb)
                    tlps.append(cur)
                    cur = None
            if (yield dut.dllp_valid):
                value = (yield dut.dllp)
                dllps.append([(value >> (8*j)) & 0xff for j in range(6)])
            if (yield dut.error):
                errors.append(1)
            yield
    run_simulation(dut, [generator(), monitor()])
    return tlps, dllps, errors

class TestSoftDLLWide(unittest.TestCase):
    def test_rx_framer_back_to_back(self):
        # Packets on DWs without gaps: end and start in the same beat, several DLLPs in a beat.
        for ndw in [2, 4, 8]:
            with self.subTest(ndw=ndw):
                rng     = random.Random(ndw)
                symbols = []
                exp_t, exp_d = [], []
                for i in range(120):
                    if rng.random() < 0.3:
                        dllp = [rng.randrange(256) for _ in range(6)]
                        exp_d.append(dllp)
                        symbols += dllp_symbols(dllp)
                    else:
                        dws  = random_dws(rng, rng.randrange(3, 40))
                        lcrc = rng.getrandbits(32)
                        exp_t.append(dict(seq=i, dws=dws + [list(lcrc.to_bytes(4, "little"))], edb=0))
                        symbols += tlp_symbols(i, dws, lcrc)
                    # Logical Idle between some packets (DWs).
                    if rng.random() < 0.3:
                        symbols += [(0, 0)]*(4*rng.randrange(1, 4))
                tlps, dllps, errors = run_rx(ndw, symbols)
                self.assertEqual(errors, [])
                self.assertEqual(tlps, exp_t)
                self.assertEqual(dllps, exp_d)

    def test_rx_framer_select_8b10b_half_width(self):
        # Gen3-capable link at 2.5/5.0 GT/s: the 8b/10b framer at half the width, beats split in two (input
        # back to back here: back-pressure), TLPs and DLLPs as with a full width framer.
        from litepcie.phy.soft.dll.wide import RXFramerSelect
        for ndw in [4, 8, 16]:
            with self.subTest(ndw=ndw):
                rng     = random.Random(100 + ndw)
                symbols = []
                exp_t, exp_d = [], []
                for i in range(80):
                    if rng.random() < 0.3:
                        dllp = [rng.randrange(256) for _ in range(6)]
                        exp_d.append(dllp)
                        symbols += dllp_symbols(dllp)
                    else:
                        dws  = random_dws(rng, rng.randrange(3, 40))
                        lcrc = rng.getrandbits(32)
                        exp_t.append(dict(seq=i, dws=dws + [list(lcrc.to_bytes(4, "little"))], edb=0))
                        symbols += tlp_symbols(i, dws, lcrc)
                    if rng.random() < 0.3:
                        symbols += [(0, 0)]*(4*rng.randrange(1, 4))
                dut   = RXFramerSelect(ndw)
                beats = to_beats(symbols, ndw) + [(0, 0)]*8
                tlps, dllps, errors = [], [], []
                done  = [False]
                def generator():
                    yield dut.gen3.eq(0)
                    for data, ctrl in beats:
                        yield dut.sink.valid.eq(1)
                        yield dut.sink.data.eq(data)
                        yield dut.sink.ctrl.eq(ctrl)
                        yield
                        while not (yield dut.sink.ready):
                            yield
                    yield dut.sink.valid.eq(0)
                    for _ in range(512):
                        yield
                    done[0] = True
                def monitor():
                    cur = None
                    while not done[0]:
                        if (yield dut.tlp.valid):
                            data = (yield dut.tlp.data)
                            n    = (yield dut.tlp.dws)
                            if (yield dut.tlp.first):
                                cur = dict(seq=(yield dut.tlp.seq), dws=[])
                            cur["dws"] += [[(data >> (32*i + 8*j)) & 0xff for j in range(4)] for i in range(n)]
                            if (yield dut.tlp.last):
                                cur["edb"] = (yield dut.tlp.edb)
                                tlps.append(cur)
                                cur = None
                            elif n != ndw:
                                partial.append(n) # Beats are full but the last one of a TLP.
                        if (yield dut.dllp_valid):
                            value = (yield dut.dllp)
                            dllps.append([(value >> (8*j)) & 0xff for j in range(6)])
                        if (yield dut.error):
                            errors.append(1)
                        yield
                partial = []
                run_simulation(dut, [generator(), monitor()])
                self.assertEqual(errors, [])
                self.assertEqual(partial, [])
                self.assertEqual(tlps, exp_t)
                self.assertEqual(dllps, exp_d)

    def test_wide_lcrc(self):
        # Sequence Number and DWs of TLPs of any length (last beat with 1 to ndw DWs, beats without data),
        # against zlib.crc32.
        import zlib
        from litepcie.phy.soft.dll.wide import WideLCRC
        for ndw in [2, 4, 16]:
            with self.subTest(ndw=ndw):
                rng = random.Random(ndw)
                dut = WideLCRC(ndw)
                tlps = []
                for _ in range(30):
                    seq = rng.randrange(4096)
                    dws = random_dws(rng, rng.randrange(1, 3*ndw + 2))
                    tlps.append((seq, dws))
                values = []
                def generator():
                    for seq, dws in tlps:
                        beats = [dws[i:i + ndw] for i in range(0, len(dws), ndw)]
                        for i, beat in enumerate(beats):
                            # A beat without data in the middle of the TLP changes nothing.
                            if i == 1:
                                yield dut.ce.eq(1)
                                yield dut.first.eq(0)
                                yield dut.dws.eq(0)
                                yield
                            yield dut.ce.eq(1)
                            yield dut.first.eq(i == 0)
                            yield dut.seq.eq(((seq & 0xff) << 8) | (seq >> 8))
                            yield dut.data.eq(sum(int.from_bytes(bytes(dw), "little") << (32*j) for j, dw in enumerate(beat)))
                            yield dut.dws.eq(len(beat))
                            yield
                        yield dut.ce.eq(0)
                        yield
                        values.append((yield dut.value))
                run_simulation(dut, generator())
                for (seq, dws), value in zip(tlps, values):
                    ref = zlib.crc32(seq.to_bytes(2, "big") + bytes(sum(dws, [])))
                    self.assertEqual(value, ref)

    def test_rx_framer_edb(self):
        tlps, dllps, errors = run_rx(4, tlp_symbols(5, random_dws(random.Random(1), 3), edb=True))
        self.assertEqual(errors, [])
        self.assertEqual(tlps[0]["edb"], 1)

    def test_rx_framer_short_tlps(self):
        # Sizes needing more output beats than input ones, without gaps: the FIFO absorbs a burst.
        for ndw in [4, 8]:
            with self.subTest(ndw=ndw):
                rng     = random.Random(7)
                symbols = []
                for i in range(40):
                    symbols += tlp_symbols(i, random_dws(rng, ndw + 1 - 1))
                tlps, dllps, errors = run_rx(ndw, symbols + [(0, 0)]*256)
                self.assertEqual(errors, [])
                self.assertEqual([t["seq"] for t in tlps], list(range(40)))

    def test_rx_framer_overflow(self):
        # x8, a long burst of very short TLPs fills the FIFO: reported, TLPs received after a gap.
        rng     = random.Random(7)
        symbols = []
        for i in range(600):
            symbols += tlp_symbols(i, random_dws(rng, 3))
        symbols += [(0, 0)]*8*400
        last = tlp_symbols(1000, random_dws(rng, 12))
        tlps, dllps, errors = run_rx(8, symbols + last)
        self.assertGreaterEqual(len(errors), 1)
        self.assertLess(len(tlps), 601)
        self.assertEqual(tlps[-1]["seq"], 1000)
        self.assertEqual(len(tlps[-1]["dws"]), 13)

    def test_rx_framer_errors(self):
        # END without a packet, a K Symbol inside a TLP: reported, next packet received.
        rng  = random.Random(2)
        good = tlp_symbols(1, random_dws(rng, 4))
        bad  = tlp_symbols(2, random_dws(rng, 4))
        bad[9] = (0x1c, 1)
        for symbols, name in [([(0, 0)]*3 + [(END.value, 1)] + good, "end"), (bad + [(0, 0)]*(4 - len(bad) % 4) + good, "k")]:
            with self.subTest(name):
                tlps, dllps, errors = run_rx(4, symbols)
                self.assertGreaterEqual(len(errors), 1)
                self.assertEqual(tlps[-1]["seq"], 1)

    def test_rx_framer_ordered_set(self):
        # Training Sequence between packets (Recovery entered from L0, received before the LTSSM leaves L0):
        # not a framing error. A COM inside a TLP is one.
        rng = random.Random(3)
        ts1 = [(COM.value, 1)] + [(0, 0)]*2 + [(0xff, 0), (0x8e, 0), (0, 0)] + [(0x4a, 0)]*10
        a   = tlp_symbols(1, random_dws(rng, 4))
        b   = tlp_symbols(2, random_dws(rng, 4))
        for ndw in [2, 4]:
            with self.subTest(ndw=ndw):
                tlps, dllps, errors = run_rx(ndw, a + ts1*2 + b)
                self.assertEqual(errors, [])
                self.assertEqual([t["seq"] for t in tlps], [1, 2])
        bad = list(a)
        bad[9] = (COM.value, 1)
        tlps, dllps, errors = run_rx(4, bad + [(0, 0)]*(4 - len(bad) % 4) + b)
        self.assertGreaterEqual(len(errors), 1)
        self.assertEqual([t["seq"] for t in tlps], [2])

    def test_tx_rx_loopback(self):
        # TX framer to RX framer, all the TLP lengths around the beat boundaries.
        for ndw, nlanes in [(2, 2), (4, 4), (8, 8)]:
            with self.subTest(ndw=ndw):
                self.tx_rx_loopback(ndw, nlanes)

    def tx_rx_loopback(self, ndw, nlanes):
        class DUT(Module):
            def __init__(self):
                self.submodules.tx = WideTXFramer(ndw, nlanes)
                self.submodules.rx = WideRXFramer(ndw)
                self.comb += [
                    self.rx.sink.valid.eq(1), # Logical Idle between the packets, never stopped.
                    self.rx.sink.data.eq(self.tx.source.data),
                    self.rx.sink.ctrl.eq(self.tx.source.ctrl),
                    self.tx.source.ready.eq(1),
                    self.rx.tlp.ready.eq(1),
                ]
        dut  = DUT()
        rng  = random.Random(ndw)
        tlps = []
        for i, n in enumerate(list(range(3, 3*ndw + 6))*2):
            tlps.append(dict(seq=i, dws=random_dws(rng, n), lcrc=rng.getrandbits(32)))
        dllps = [[rng.randrange(256) for _ in range(6)] for _ in range(8)]
        out_t, out_d = [], []
        done = [False]
        def generator():
            for t in tlps:
                beats = [t["dws"][i:i+ndw] for i in range(0, len(t["dws"]), ndw)]
                for i, beat in enumerate(beats):
                    yield dut.tx.tlp.valid.eq(1)
                    yield dut.tx.tlp.first.eq(i == 0)
                    yield dut.tx.tlp.last.eq(i == len(beats) - 1)
                    yield dut.tx.tlp.seq.eq(t["seq"])
                    yield dut.tx.tlp.dws.eq(len(beat))
                    yield dut.tx.tlp.data.eq(sum(b << (32*k + 8*j) for k, dw in enumerate(beat) for j, b in enumerate(dw)))
                    yield dut.tx.lcrc.eq(t["lcrc"])
                    yield
                    while not (yield dut.tx.tlp.ready):
                        yield
                yield dut.tx.tlp.valid.eq(0)
                if rng.random() < 0.2 and dllps:
                    d = dllps.pop()
                    out_d.append(d)
                    yield dut.tx.dllp.eq(sum(b << (8*j) for j, b in enumerate(d)))
                    yield dut.tx.dllp_valid.eq(1)
                    yield
                    while not (yield dut.tx.dllp_ready):
                        yield
                    yield dut.tx.dllp_valid.eq(0)
            for _ in range(32):
                yield
            done[0] = True
        got_d = []
        errors = []
        def monitor():
            cur = None
            while not done[0]:
                if (yield dut.rx.tlp.valid):
                    data = (yield dut.rx.tlp.data)
                    n    = (yield dut.rx.tlp.dws)
                    if (yield dut.rx.tlp.first):
                        cur = dict(seq=(yield dut.rx.tlp.seq), dws=[])
                    cur["dws"] += [[(data >> (32*i + 8*j)) & 0xff for j in range(4)] for i in range(n)]
                    if (yield dut.rx.tlp.last):
                        out_t.append(cur)
                        cur = None
                if (yield dut.rx.dllp_valid):
                    value = (yield dut.rx.dllp)
                    got_d.append([(value >> (8*j)) & 0xff for j in range(6)])
                if (yield dut.rx.error):
                    errors.append(1)
                yield
        run_simulation(dut, [generator(), monitor()])
        self.assertEqual(errors, [])
        self.assertEqual(len(out_t), len(tlps))
        for t, o in zip(tlps, out_t):
            self.assertEqual(o["seq"], t["seq"])
            self.assertEqual(o["dws"][:-1], t["dws"])
            self.assertEqual(o["dws"][-1], list(t["lcrc"].to_bytes(4, "little")))
        self.assertEqual(got_d, out_d)

    def test_tx_pad_above_x4(self):
        # x8: END not ending a Symbol time is followed by PAD up to the end of the Symbol time.
        dut = WideTXFramer(8, 8)
        out = {}
        def generator():
            yield dut.source.ready.eq(1)
            yield dut.dllp.eq(0x112233445566)
            yield dut.dllp_valid.eq(1)
            yield
            out["data"], out["ctrl"] = (yield dut.source.data), (yield dut.source.ctrl)
        run_simulation(dut, generator())
        data, ctrl = out["data"], out["ctrl"]
        self.assertEqual(data & 0xff, SDP.value)
        self.assertEqual((data >> 56) & 0xff, END.value)
        self.assertEqual(ctrl & 0xff, 0x81)
        # A DLLP is a whole Symbol time at x8: no PAD.
        self.assertEqual(ctrl >> 8, 0)

    def test_x2_phase_aligner(self):
        # Packets starting 2 Symbols into a DW after 1 Symbol time of Logical Idle: realigned.
        rng     = random.Random(4)
        symbols = []
        exp     = []
        for i in range(30):
            dws  = random_dws(rng, rng.randrange(3, 12))
            lcrc = rng.getrandbits(32)
            exp.append(dict(seq=i, dws=dws + [list(lcrc.to_bytes(4, "little"))], edb=0))
            symbols += tlp_symbols(i, dws, lcrc)
            symbols += [(0, 0)]*(2*rng.randrange(1, 6))
        class DUT(Module):
            def __init__(self):
                self.submodules.al = RXPhaseAligner()
                self.submodules.rx = WideRXFramer(2)
                self.comb += [self.al.source.connect(self.rx.sink), self.rx.tlp.ready.eq(1)]
        dut = DUT()
        beats = to_beats(symbols, 2) + [(0, 0)]*8
        tlps, errors, done = [], [], [False]
        def generator():
            yield dut.al.sink.valid.eq(1)
            for data, ctrl in beats:
                yield dut.al.sink.data.eq(data)
                yield dut.al.sink.ctrl.eq(ctrl)
                yield
            for _ in range(16):
                yield
            done[0] = True
        def monitor():
            cur = None
            while not done[0]:
                if (yield dut.rx.tlp.valid):
                    data = (yield dut.rx.tlp.data)
                    n    = (yield dut.rx.tlp.dws)
                    if (yield dut.rx.tlp.first):
                        cur = dict(seq=(yield dut.rx.tlp.seq), dws=[])
                    cur["dws"] += [[(data >> (32*i + 8*j)) & 0xff for j in range(4)] for i in range(n)]
                    if (yield dut.rx.tlp.last):
                        cur["edb"] = (yield dut.rx.tlp.edb)
                        tlps.append(cur)
                        cur = None
                if (yield dut.rx.error):
                    errors.append(1)
                yield
        run_simulation(dut, [generator(), monitor()])
        self.assertEqual(errors, [])
        self.assertEqual(tlps, exp)

def x1_aligned(symbols):
    """Symbols through the x1 aligner, as 4-Symbol words of (byte, k)."""
    from litepcie.phy.soft.dll.wide import RXPhaseAlignerX1
    dut = RXPhaseAlignerX1()
    out = []
    words = [symbols[i:i+4] for i in range(0, len(symbols) - 3, 4)]
    def generator():
        yield dut.sink.valid.eq(1)
        for word in words + [[(0, 0)]*4]*4:
            yield dut.sink.data.eq(sum(b << (8*j) for j, (b, k) in enumerate(word)))
            yield dut.sink.ctrl.eq(sum(k << j for j, (b, k) in enumerate(word)))
            yield
            if (yield dut.source.valid):
                d, c = (yield dut.source.data), (yield dut.source.ctrl)
                out.append([((d >> (8*j)) & 0xff, (c >> j) & 1) for j in range(4)])
    run_simulation(dut, generator())
    return out

class TestSoftAlignerX1(unittest.TestCase):
    def test_any_position(self):
        # Packets after any number of Logical Idle Symbols: each one starts on a word, complete.
        rng = random.Random(9)
        for gap in [0, 1, 2, 3, 5, 6, 7]:
            with self.subTest(gap=gap):
                symbols, packets = [], []
                for i in range(30):
                    dws  = random_dws(rng, rng.randrange(3, 8))
                    pkt  = tlp_symbols(i, dws, rng.getrandbits(32)) if i % 3 else dllp_symbols([rng.randrange(256) for _ in range(6)])
                    packets.append(pkt)
                    symbols += pkt + [(0, 0)]*((gap*(i + 1)) % 11 if gap else 0)
                symbols += [(0, 0)]*(4 - len(symbols) % 4)
                out = sum(x1_aligned(symbols), [])
                found = 0
                index = 0
                while index < len(out) and found < len(packets):
                    if out[index][1] and out[index][0] in (STP.value, SDP.value):
                        self.assertEqual(index % 4, 0, f"packet {found} not on a word")
                        pkt = packets[found]
                        self.assertEqual(out[index:index + len(pkt)], pkt, f"packet {found}")
                        found += 1
                        index += len(pkt)
                    else:
                        self.assertEqual(out[index], (0, 0), "not Logical Idle between the packets")
                        index += 1
                self.assertEqual(found, len(packets))
