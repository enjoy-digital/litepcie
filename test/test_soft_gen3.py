#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import random
import unittest

from migen import *

from litepcie.phy.soft.gen3 import *

# Values of the LFSR following a reset for Lane 0 (Appendix C.2, first row of the table).
LFSR_LANE0 = [0x1dbfbc, 0x498c2e, 0x1186e9, 0x0fc5ad, 0x7cb75d, 0x3d8da2, 0x0ecc8f, 0x379717]

def blocks_to_bits(blocks):
    bits = []
    for sync, payload in blocks:
        bits += [(sync >> i) & 1 for i in range(2)]
        bits += [(payload >> i) & 1 for i in range(128)]
    return bits

def bits_to_words(bits):
    words = []
    for i in range(0, len(bits) - 39, 40):
        words.append(sum(b << j for j, b in enumerate(bits[i:i+40])))
    return words

def random_blocks(rng, n, eieos_every=0):
    blocks = []
    for i in range(n):
        if eieos_every and (i % eieos_every) == 0:
            blocks.append((SYNC_OS, EIEOS_PAYLOAD))
        else:
            blocks.append((rng.choice([SYNC_DATA, SYNC_OS]), rng.getrandbits(128)))
    return blocks

class TestSoftGen3(unittest.TestCase):
    def test_lfsr_reference(self):
        # Equations of the specification against its table: first values after a reset of Lane 0.
        state = LFSR_SEEDS[0]
        for expected in LFSR_LANE0:
            self.assertEqual(state, expected)
            state = lfsr_next(state)

    def test_scrambler_model(self):
        # Parallel scrambler against the Symbol by Symbol model, bypass and SKP (no advance) included.
        for nsymbols in [8, 16]:
            with self.subTest(nsymbols=nsymbols):
                rng = random.Random(nsymbols)
                dut = Gen3Scrambler(LFSR_SEEDS[3], nsymbols=nsymbols)
                def generator():
                    state = LFSR_SEEDS[3]
                    yield dut.ce.eq(1)
                    for i in range(40):
                        data    = rng.getrandbits(8*nsymbols)
                        bypass  = rng.getrandbits(nsymbols) if i % 3 == 0 else 0
                        advance = 0 if i % 7 == 6 else 1
                        yield dut.data_in.eq(data)
                        yield dut.bypass.eq(bypass)
                        yield dut.advance.eq(advance)
                        yield
                        out = (yield dut.data_out)
                        expected = 0
                        s = state
                        for j in range(nsymbols):
                            byte = (data >> (8*j)) & 0xff
                            if advance and not (bypass >> j) & 1:
                                byte ^= lfsr_out(s)
                            expected |= byte << (8*j)
                            if advance:
                                s = lfsr_next(s)
                        self.assertEqual(out, expected, f"cycle {i}")
                        state = s
                run_simulation(dut, generator())

    def test_scrambler_roundtrip(self):
        class DUT(Module):
            def __init__(self):
                self.submodules.tx = Gen3Scrambler(LFSR_SEEDS[5])
                self.submodules.rx = Gen3Scrambler(LFSR_SEEDS[5])
                self.comb += [
                    self.rx.data_in.eq(self.tx.data_out),
                    self.tx.ce.eq(1),
                    self.rx.ce.eq(1),
                ]
        dut = DUT()
        rng = random.Random(1)
        def generator():
            for _ in range(32):
                data = rng.getrandbits(64)
                yield dut.tx.data_in.eq(data)
                yield
                self.assertEqual((yield dut.rx.data_out), data)
                self.assertNotEqual((yield dut.tx.data_out), data)
        run_simulation(dut, generator())

    def run_rx(self, words, slips=None):
        dut = RXBlockGearbox()
        out = []
        def generator():
            for word in words:
                yield dut.data.eq(word)
                yield
                if (yield dut.valid):
                    out.append(((yield dut.sync_header), (yield dut.block)))
            for _ in range(8):
                yield
                if (yield dut.valid):
                    out.append(((yield dut.sync_header), (yield dut.block)))
        run_simulation(dut, generator())
        return out

    def test_rx_gearbox(self):
        # Blocks in order at the 4 offsets, 13 words for 4 Blocks, for one of the 13 word phases.
        rng    = random.Random(2)
        blocks = random_blocks(rng, 40)
        words  = bits_to_words(blocks_to_bits(blocks))
        best   = 0
        for phase in range(13):
            out = self.run_rx([0]*phase + words)
            if blocks[0] in out:
                start = out.index(blocks[0])
                n     = min(len(out) - start, len(blocks))
                if out[start:start + n] == blocks[:n]:
                    best = max(best, n)
        self.assertGreater(best, 30)

    def test_tx_gearbox(self):
        # Blocks to words and back through the bit stream.
        rng    = random.Random(3)
        blocks = random_blocks(rng, 60)
        dut    = TXBlockGearbox()
        words  = []
        def generator():
            index = 0
            for _ in range(190):
                sync, payload = blocks[min(index, len(blocks) - 1)]
                yield dut.sync_header.eq(sync)
                yield dut.block.eq(payload)
                yield
                words.append((yield dut.data))
                if (yield dut.ready):
                    index += 1
        run_simulation(dut, generator())
        # Stream of bits: must hold the Blocks in order.
        stream = sum(w << (40*i) for i, w in enumerate(words))
        total  = 40*len(words)
        rate   = 13*130*4//(40*13) # Sanity of the ratio: 130 bits per 3.25 words.
        self.assertEqual(rate, 13)
        expected = sum(b << i for i, b in enumerate(blocks_to_bits(blocks[:50])))
        size     = 130*50
        found    = [o for o in range(0, 400) if (stream >> o) & ((1 << size) - 1) == expected]
        self.assertTrue(found, "Blocks not found in the stream")

    def test_aligner(self):
        # Any bit offset: aligned on the EIEOS, the Blocks then come out in order.
        for offset in [0, 1, 7, 39, 40, 63, 129]:
            with self.subTest(offset=offset):
                rng    = random.Random(offset)
                blocks = random_blocks(rng, 3000, eieos_every=33)
                bits   = [rng.getrandbits(1) for _ in range(offset)] + blocks_to_bits(blocks)
                words  = bits_to_words(bits)
                class DUT(Module):
                    def __init__(self):
                        self.submodules.gearbox = RXBlockGearbox()
                        self.submodules.aligner = BlockAligner(self.gearbox)
                dut = DUT()
                out = []
                state = {}
                def generator():
                    for i, word in enumerate(words):
                        yield dut.gearbox.data.eq(word)
                        yield
                        if (yield dut.aligner.aligned) and "at" not in state:
                            state["at"] = i
                        if "at" in state and (yield dut.gearbox.valid):
                            out.append(((yield dut.gearbox.sync_header), (yield dut.gearbox.block)))
                run_simulation(dut, generator())
                self.assertIn("at", state)
                self.assertGreater(len(out), 100)
                # Found in the transmitted sequence, in order.
                start = blocks.index(out[8])
                self.assertEqual(out[8:60], blocks[start:start + 52])

# Framing ------------------------------------------------------------------------------------------

def mwr_dws(rng, n, is_4dw=False):
    """Memory Write header and data as DW bytes."""
    fmt = 0x60 if is_4dw else 0x40
    header = [[fmt, 0, (n >> 8) & 3, n & 0xff]] + [[rng.randrange(256) for _ in range(4)] for _ in range(3 if is_4dw else 2)]
    return header + [[rng.randrange(256) for _ in range(4)] for _ in range(n)]

def to_stream(symbols, ndw):
    beats = []
    for i in range(0, len(symbols), 4*ndw):
        chunk = symbols[i:i+4*ndw] + [0]*(4*ndw - len(symbols[i:i+4*ndw]))
        beats.append(int.from_bytes(bytes(chunk), "little"))
    return beats

class TestSoftGen3Framing(unittest.TestCase):
    def test_stp_token(self):
        # Example of the specification: 3 DW header, 1 DW data: length 6, the check values are consistent.
        token = stp_token(6, 0x123)
        self.assertEqual(token[0] & 0xf, 0xf)
        self.assertEqual((token[0] >> 4) | ((token[1] & 0x7f) << 4), 6)
        self.assertEqual(((token[2] & 0xf) << 8) | token[3], 0x123)
        # Frame Parity: even over the Length and the Frame CRC.
        l = 6
        fcrc = token[2] >> 4
        self.assertEqual((bin(l).count("1") + bin(fcrc).count("1") + (token[1] >> 7)) % 2, 0)

    def run_rx(self, ndw, symbols):
        from litepcie.phy.soft.gen3 import Gen3RXFramer
        dut = Gen3RXFramer(ndw)
        tlps, dllps, errors = [], [], []
        done = [False]
        def generator():
            yield dut.sink.valid.eq(1)
            for word in to_stream(symbols, ndw) + [0]*8:
                yield dut.sink.data.eq(word)
                yield
            for _ in range(256):
                yield
            done[0] = True
        def monitor():
            cur = None
            yield dut.tlp.ready.eq(1)
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
                if (yield dut.dllp_valid):
                    value = (yield dut.dllp)
                    dllps.append(list(value.to_bytes(6, "little")))
                if (yield dut.error):
                    errors.append(1)
                yield
        run_simulation(dut, [generator(), monitor()])
        return tlps, dllps, errors

    def test_rx_framer(self):
        # Tokens on DWs, back to back, IDL Tokens, EDS, nullified TLPs.
        for ndw in [8, 16]:
            with self.subTest(ndw=ndw):
                rng = random.Random(ndw)
                symbols, exp_t, exp_d = [], [], []
                for i in range(100):
                    r = rng.random()
                    if r < 0.3:
                        dllp = [rng.randrange(256) for _ in range(6)]
                        exp_d.append(dllp)
                        symbols += list(SDP_TOKEN) + dllp
                    else:
                        dws  = mwr_dws(rng, rng.randrange(1, 40))
                        lcrc = [rng.randrange(256) for _ in range(4)]
                        nullified = r > 0.9
                        exp_t.append(dict(seq=i, dws=dws + [lcrc], edb=int(nullified)))
                        symbols += list(stp_token(len(dws) + 2, i)) + sum(dws, []) + lcrc
                        if nullified:
                            symbols += list(EDB_TOKEN)
                    if rng.random() < 0.2:
                        symbols += [0]*(4*rng.randrange(1, 4))
                    if rng.random() < 0.05:
                        symbols += list(EDS_TOKEN)
                tlps, dllps, errors = self.run_rx(ndw, symbols)
                self.assertEqual(errors, [])
                self.assertEqual(tlps, exp_t)
                self.assertEqual(dllps, exp_d)

    def test_rx_framer_dllp_bursts(self):
        # Back to back DLLPs from any DW (up to a DLLP per pair of slots in a beat), then IDL Tokens to empty the
        # queue, a TLP between the bursts.
        for ndw in [2, 4, 8, 16]:
            with self.subTest(ndw=ndw):
                rng = random.Random(100 + ndw)
                symbols, exp_t, exp_d = [], [], []
                for i in range(40):
                    symbols += [0]*(4*rng.randrange(0, ndw))
                    for _ in range(rng.randrange(1, max(8, ndw)//2 + 1)):
                        dllp = [rng.randrange(256) for _ in range(6)]
                        exp_d.append(dllp)
                        symbols += list(SDP_TOKEN) + dllp
                    symbols += [0]*(4*4*max(8, ndw))
                    dws  = mwr_dws(rng, rng.randrange(1, 8))
                    lcrc = [rng.randrange(256) for _ in range(4)]
                    exp_t.append(dict(seq=i, dws=dws + [lcrc], edb=0))
                    symbols += list(stp_token(len(dws) + 2, i)) + sum(dws, []) + lcrc
                tlps, dllps, errors = self.run_rx(ndw, symbols)
                self.assertEqual(errors, [])
                self.assertEqual(tlps, exp_t)
                self.assertEqual(dllps, exp_d)

    def test_rx_framer_bad_token(self):
        # A wrong Frame CRC is a framing error: the Length isn't used.
        rng   = random.Random(1)
        token = bytearray(stp_token(9, 1))
        token[2] ^= 0x10
        good  = mwr_dws(rng, 4)
        tlps, dllps, errors = self.run_rx(8, list(token) + [0]*28 + list(stp_token(len(good) + 2, 2)) + sum(good, []) + [1, 2, 3, 4])
        self.assertGreaterEqual(len(errors), 1)
        self.assertEqual([t["seq"] for t in tlps], [2])

    def random_stream(self, rng, n, unit, with_tokens=False):
        """Tokens with IDL Tokens of any count of Symbol Times between them (x1: a byte, x2: two bytes)."""
        symbols, kept, exp_t, exp_d, tokens = [], [], [], [], []
        for i in range(n):
            if rng.random() < 0.5:
                idl = [0]*(unit*rng.randrange(1, 9))
                symbols += idl
            r = rng.random()
            if r < 0.3:
                dllp = [rng.randrange(256) for _ in range(6)]
                exp_d.append(dllp)
                tok = list(SDP_TOKEN) + dllp
            else:
                dws  = mwr_dws(rng, rng.randrange(0, 40))
                lcrc = [rng.randrange(256) for _ in range(4)]
                nullified = r > 0.9
                exp_t.append(dict(seq=i, dws=dws + [lcrc], edb=int(nullified)))
                tok = list(stp_token(len(dws) + 2, i)) + sum(dws, []) + lcrc
                if nullified:
                    tok += list(EDB_TOKEN)
            symbols += tok
            kept    += tok
            tokens.append(tok)
        if with_tokens:
            return symbols, kept, exp_t, exp_d, tokens
        return symbols, kept, exp_t, exp_d

    def test_rx_token_aligner(self):
        # IDL Tokens removed, the other Tokens on DWs; input with holes.
        from litepcie.phy.soft.gen3 import Gen3RXTokenAligner
        for ndw, unit in [(2, 1), (4, 2)]:
            with self.subTest(ndw=ndw, unit=unit):
                rng = random.Random(ndw)
                symbols, kept, _, _, tokens = self.random_stream(rng, 80, unit, with_tokens=True)
                dut = Gen3RXTokenAligner(ndw, unit=unit)
                out = []
                beats = to_stream(symbols, ndw) + [0]*16
                def generator():
                    for word in beats:
                        while rng.random() < 0.3:
                            yield dut.sink.valid.eq(0)
                            yield
                        yield dut.sink.valid.eq(1)
                        yield dut.sink.data.eq(word)
                        yield
                    yield dut.sink.valid.eq(0)
                    for _ in range(32):
                        yield
                def monitor():
                    for _ in range(4*len(beats) + 64):
                        if (yield dut.source.valid):
                            out.extend(((yield dut.source.data)).to_bytes(4*ndw, "little"))
                        yield
                run_simulation(dut, [generator(), monitor()])
                # Beats completed with IDL Tokens between Tokens: removed again for the comparison.
                rest = list(out)
                for tok in tokens:
                    while rest and rest[:4] == [0]*4 and tok[:4] != [0]*4:
                        rest = rest[4:]
                    self.assertEqual(rest[:len(tok)], tok)
                    rest = rest[len(tok):]

    def test_rx_framer_x1_x2(self):
        # x1/x2: Tokens after IDL Tokens on any Symbol (Time), through the aligner.
        from litepcie.phy.soft.gen3 import Gen3RXTokenAligner, Gen3RXFramer
        for ndw, unit in [(2, 1), (4, 2)]:
            with self.subTest(ndw=ndw, unit=unit):
                rng = random.Random(10 + ndw)
                symbols, kept, exp_t, exp_d = self.random_stream(rng, 60, unit)
                class DUT(Module):
                    def __init__(self):
                        self.submodules.aligner = Gen3RXTokenAligner(ndw, unit=unit)
                        self.submodules.framer  = Gen3RXFramer(ndw)
                        self.comb += self.aligner.source.connect(self.framer.sink)
                dut = DUT()
                tlps, dllps, errors = [], [], []
                done = [False]
                def generator():
                    yield dut.aligner.sink.valid.eq(1)
                    for word in to_stream(symbols, ndw) + [0]*16:
                        yield dut.aligner.sink.data.eq(word)
                        yield
                    for _ in range(256):
                        yield
                    done[0] = True
                def monitor():
                    cur = None
                    yield dut.framer.tlp.ready.eq(1)
                    while not done[0]:
                        f = dut.framer
                        if (yield f.tlp.valid):
                            data = (yield f.tlp.data)
                            n    = (yield f.tlp.dws)
                            if (yield f.tlp.first):
                                cur = dict(seq=(yield f.tlp.seq), dws=[])
                            cur["dws"] += [[(data >> (32*i + 8*j)) & 0xff for j in range(4)] for i in range(n)]
                            if (yield f.tlp.last):
                                cur["edb"] = (yield f.tlp.edb)
                                tlps.append(cur)
                                cur = None
                        if (yield f.dllp_valid):
                            dllps.append(list(((yield f.dllp)).to_bytes(6, "little")))
                        if (yield f.error):
                            errors.append(1)
                        yield
                run_simulation(dut, [generator(), monitor()])
                self.assertEqual(errors, [])
                self.assertEqual(tlps, exp_t)
                self.assertEqual(dllps, exp_d)

    def test_tx_rx_loopback(self):
        from litepcie.phy.soft.gen3 import Gen3TXFramer, Gen3RXFramer
        for ndw in [8, 16]:
            with self.subTest(ndw=ndw):
                class DUT(Module):
                    def __init__(self):
                        self.submodules.tx = Gen3TXFramer(ndw)
                        self.submodules.rx = Gen3RXFramer(ndw)
                        self.comb += [
                            self.rx.sink.valid.eq(1),
                            self.rx.sink.data.eq(self.tx.source.data),
                            self.tx.source.ready.eq(1),
                            self.rx.tlp.ready.eq(1),
                        ]
                dut  = DUT()
                rng  = random.Random(ndw)
                tlps = []
                for i, n in enumerate(list(range(1, ndw + 6)) + [32, 64]):
                    is_4dw = bool(i % 3 == 0)
                    tlps.append(dict(seq=i, dws=mwr_dws(rng, n, is_4dw), lcrc=rng.getrandbits(32)))
                out, errors, done = [], [], [False]
                def generator():
                    for t in tlps:
                        beats = [t["dws"][j:j+ndw] for j in range(0, len(t["dws"]), ndw)]
                        for j, beat in enumerate(beats):
                            yield dut.tx.tlp.valid.eq(1)
                            yield dut.tx.tlp.first.eq(j == 0)
                            yield dut.tx.tlp.last.eq(j == len(beats) - 1)
                            yield dut.tx.tlp.seq.eq(t["seq"])
                            yield dut.tx.tlp.dws.eq(len(beat))
                            yield dut.tx.tlp.data.eq(sum(b << (32*k + 8*m) for k, dw in enumerate(beat) for m, b in enumerate(dw)))
                            yield dut.tx.lcrc.eq(t["lcrc"])
                            yield
                            while not (yield dut.tx.tlp.ready):
                                yield
                        yield dut.tx.tlp.valid.eq(0)
                    for _ in range(64):
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
                            cur["dws"] += [[(data >> (32*k + 8*m)) & 0xff for m in range(4)] for k in range(n)]
                            if (yield dut.rx.tlp.last):
                                out.append(cur)
                                cur = None
                        if (yield dut.rx.error):
                            errors.append(1)
                        yield
                run_simulation(dut, [generator(), monitor()])
                self.assertEqual(errors, [])
                self.assertEqual(len(out), len(tlps))
                for t, o in zip(tlps, out):
                    self.assertEqual(o["seq"], t["seq"])
                    self.assertEqual(o["dws"][:-1], t["dws"])
                    self.assertEqual(o["dws"][-1], list(t["lcrc"].to_bytes(4, "little")))

class TestSoftGen3Tester(unittest.TestCase):
    def run_loop(self, offset, inject=None, cycles=6000):
        from litepcie.phy.soft.gen3 import Gen3TXTester, Gen3RXChecker
        class DUT(Module):
            def __init__(self):
                self.submodules.tx = Gen3TXTester(LFSR_SEEDS[1])
                self.submodules.rx = Gen3RXChecker(LFSR_SEEDS[1])
                self.flip = Signal()
                self.bits = Signal(80)
                self.sync += self.bits.eq(Cat(self.bits[40:], self.tx.data))
                self.comb += self.rx.data.eq(self.bits[offset:offset + 40] ^ self.flip)
        dut = DUT()
        res = {}
        def generator():
            for i in range(cycles):
                if inject is not None and i == inject:
                    yield dut.flip.eq(1)
                    yield
                    yield dut.flip.eq(0)
                yield
            res.update(aligned=(yield dut.rx.aligned), blocks=(yield dut.rx.blocks), errors=(yield dut.rx.errors), eieos=(yield dut.rx.eieos))
        run_simulation(dut, generator())
        return res

    def test_loop(self):
        # Clean link, any bit offset: aligned, many Blocks, no error.
        for offset in [0, 1, 17, 39]:
            with self.subTest(offset=offset):
                res = self.run_loop(offset)
                self.assertEqual(res["aligned"], 1)
                self.assertGreater(res["blocks"], 500)
                self.assertGreater(res["eieos"], 10)
                self.assertEqual(res["errors"], 0)

    def test_detects_errors(self):
        # The checker has to see a flipped bit.
        res = self.run_loop(5, inject=4000)
        self.assertEqual(res["aligned"], 1)
        self.assertGreaterEqual(res["errors"], 1)

class TestSoftGen3Lane(unittest.TestCase):
    def test_tx_rx_blocks(self):
        # TX to RX through the 40-bit words: kinds and contents of the Blocks, TS fields, scrambling rules
        # (the LFSR follows over SKP and is reinitialized by EIEOS on both sides), DC Balance not breaking TS.
        from litepcie.phy.soft.gen3 import Gen3LaneTX, Gen3LaneRX, ts3_layout, ts3_symbols
        from litepcie.phy.soft.gen3 import BLOCK_DATA, BLOCK_TS, BLOCK_EIEOS, BLOCK_SKP, BLOCK_SDS
        rng = random.Random(5)
        class DUT(Module):
            def __init__(self):
                self.submodules.tx = Gen3LaneTX(LFSR_SEEDS[2])
                self.submodules.rx = Gen3LaneRX(LFSR_SEEDS[2])
                self.ts = Record(ts3_layout())
                self.ts_data = Signal(128)
                self.comb += self.ts_data.eq(Cat(*ts3_symbols(self.ts)))
                self.bits = Signal(80)
                self.sync += self.bits.eq(Cat(self.bits[40:], self.tx.data))
                self.comb += self.rx.data.eq(self.bits[13:53])
        dut = DUT()
        # A sequence as on a link: EIEOS, TS, SKP, SDS, Data Blocks with SKP between.
        seq = []
        for i in range(800):
            if i % 33 == 0:
                seq.append((BLOCK_EIEOS, 0))
            elif i < 120:
                seq.append((BLOCK_TS, None))
            elif i == 120:
                seq.append((BLOCK_SDS, 0))
            elif i % 17 == 0:
                seq.append((BLOCK_SKP, 0))
            else:
                seq.append((BLOCK_DATA, rng.getrandbits(128)))
        sent, got, errors = [], [], []
        done = [False]
        def generator():
            yield dut.ts.link.eq(0x12)
            yield dut.ts.lane.eq(3)
            yield dut.ts.rate.eq(0x0e)
            yield dut.ts.eq_ctrl.eq(0x29)
            yield dut.ts.pre.eq(5)
            yield dut.ts.cur.eq(40)
            yield dut.ts.post.eq(7)
            ts_data = None
            index = 0
            for _ in range(800*4):
                kind, data = seq[min(index, len(seq) - 1)]
                if kind == BLOCK_TS:
                    data = (yield dut.ts_data)
                yield dut.tx.sink.valid.eq(1)
                yield dut.tx.sink.kind.eq(kind)
                yield dut.tx.sink.data.eq(data)
                yield
                if (yield dut.tx.sink.ready):
                    sent.append((kind, data))
                    index += 1
            done[0] = True
        def monitor():
            while not done[0]:
                if (yield dut.rx.source.valid):
                    got.append(((yield dut.rx.source.kind), (yield dut.rx.source.data)))
                if (yield dut.rx.error):
                    errors.append(1)
                yield
        run_simulation(dut, [generator(), monitor()])
        self.assertEqual(errors, [])
        # Received from the first EIEOS after alignment on: same Blocks, TS without Symbols 14/15.
        start = next(i for i, (k, d) in enumerate(got) if k == BLOCK_EIEOS)
        rx = got[start:]
        # Find the matching EIEOS in what was sent: the one followed by the same kinds.
        kinds_rx = [k for k, d in rx[:60]]
        offset = next(i for i in range(len(sent)) if [k for k, d in sent[i:i + 60]] == kinds_rx)
        mask = (1 << 112) - 1
        n = 0
        for (k1, d1), (k2, d2) in zip(sent[offset:], rx):
            self.assertEqual(k1, k2)
            if k1 == BLOCK_DATA:
                self.assertEqual(d1, d2)
            if k1 == BLOCK_TS:
                self.assertEqual(d1 & mask, d2 & mask)
            n += 1
        self.assertGreater(n, 400)

class TestSoftGen3Link(unittest.TestCase):
    def run_link(self, nlanes, tlps=40, cycles=30000):
        # Two Data Link Layers with 8.0 GT/s framing, through the Blocks of the lanes and the transceivers'
        # words (another bit offset per lane): EIEOS and TS, then SDS and the Data Stream with SKP Ordered Sets.
        from litepcie.phy.soft.gen3 import Gen3LaneTX, Gen3LaneRX, Gen3LinkTX, Gen3LinkRX
        from litepcie.phy.soft.dll.core import DataLinkLayer
        ndw = 2*nlanes
        class Side(Module):
            def __init__(self, name):
                self.submodules.dll = DataLinkLayer(125e6, ndw=ndw, nlanes=nlanes, framing="gen3", rx_depth=2048, tx_depth=2048)
                self.submodules.ltx = Gen3LinkTX(nlanes, skp_interval=40)
                self.submodules.lrx = Gen3LinkRX(nlanes)
                self.lanes_tx = [Gen3LaneTX(LFSR_SEEDS[i]) for i in range(nlanes)]
                self.lanes_rx = [Gen3LaneRX(LFSR_SEEDS[i]) for i in range(nlanes)]
                self.submodules += self.lanes_tx + self.lanes_rx
                self.comb += [
                    self.dll.phy_sink.connect(self.ltx.sink, omit={"ctrl"}),
                    self.ltx.idle.eq(self.dll.tx.framer.idle),
                    self.lrx.source.connect(self.dll.phy_source, omit={"ctrl"}),
                ]
                for i in range(nlanes):
                    self.comb += [
                        self.ltx.blocks[i].connect(self.lanes_tx[i].sink),
                        self.lanes_rx[i].source.connect(self.lrx.blocks[i]),
                        self.lanes_rx[i].locked.eq(self.lrx.locked),
                    ]
        class DUT(Module):
            def __init__(self):
                self.submodules.a = a = Side("a")
                self.submodules.b = b = Side("b")
                for x, y in [(a, b), (b, a)]:
                    for i in range(nlanes):
                        bits = Signal(80)
                        offset = (7*i + (3 if x is a else 11)) % 40
                        self.sync += bits.eq(Cat(bits[40:], x.lanes_tx[i].data))
                        self.comb += y.lanes_rx[i].data.eq(bits[offset:offset + 40])
                self.data_enable = Signal()
                self.comb += [
                    a.ltx.data_enable.eq(self.data_enable), b.ltx.data_enable.eq(self.data_enable),
                    a.dll.link_up.eq(self.data_enable), b.dll.link_up.eq(self.data_enable),
                    a.dll.l0.eq(self.data_enable), b.dll.l0.eq(self.data_enable),
                ]
        dut = DUT()
        rng = random.Random(nlanes)
        tlp_list = []
        for i in range(tlps):
            n = rng.randrange(1, 24)
            tlp_list.append([0x40 | ((n & 0xff) << 24), i, 0x1000] + [rng.getrandbits(32) for _ in range(n)])
        out, stats, done = [], {}, [False]
        def generator():
            for _ in range(3000):
                yield
            stats["locked"] = ((yield dut.a.lrx.locked), (yield dut.b.lrx.locked))
            yield dut.data_enable.eq(1)
            for _ in range(cycles):
                if (yield dut.a.dll.dl_active) and (yield dut.b.dll.dl_active):
                    break
                yield
            stats["dl_active"] = (yield dut.a.dll.dl_active)
            for tlp in tlp_list:
                beats = [tlp[j:j+ndw] for j in range(0, len(tlp), ndw)]
                for j, beat in enumerate(beats):
                    yield dut.a.dll.sink.valid.eq(1)
                    yield dut.a.dll.sink.first.eq(j == 0)
                    yield dut.a.dll.sink.last.eq(j == len(beats) - 1)
                    yield dut.a.dll.sink.dws.eq(len(beat))
                    yield dut.a.dll.sink.data.eq(sum(dw << (32*k) for k, dw in enumerate(beat)))
                    yield
                    while not (yield dut.a.dll.sink.ready):
                        yield
                yield dut.a.dll.sink.valid.eq(0)
            for _ in range(cycles):
                if len(out) >= len(tlp_list):
                    break
                yield
            stats["replays"] = (yield dut.a.dll.tx.replay.replays)
            stats["errors"]  = ((yield dut.a.lrx.error), (yield dut.b.dll.rx.errors))
            done[0] = True
        def monitor():
            cur = []
            yield dut.b.dll.source.ready.eq(1)
            while not done[0]:
                if (yield dut.b.dll.source.valid):
                    data = (yield dut.b.dll.source.data)
                    n    = (yield dut.b.dll.source.dws)
                    cur += [(data >> (32*k)) & 0xffffffff for k in range(n)]
                    if (yield dut.b.dll.source.last):
                        out.append(cur)
                        cur = []
                yield
        run_simulation(dut, [generator(), monitor()])
        return out, tlp_list, stats

    def test_link(self):
        for nlanes in [1, 2, 4]:
            with self.subTest(nlanes=nlanes):
                out, tlps, stats = self.run_link(nlanes, tlps=8, cycles=8000)
                self.assertEqual(stats["locked"], (1, 1))
                self.assertEqual(stats["dl_active"], 1)
                self.assertEqual(out, tlps)


class TestSoftGen3LaneEQ(unittest.TestCase):
    def test_lane_eq(self):
        from litepcie.phy.soft.gen3 import Gen3LaneEQ
        dut = Gen3LaneEQ(upstream=True)
        res = {}
        def send(ec, use=0, preset=0, pre=0, cur=0, post=0, reject=0, n=2):
            for _ in range(n):
                yield dut.rx.eq_ctrl.eq(ec | (preset << 3) | (use << 7))
                yield dut.rx.pre.eq(pre)
                yield dut.rx.cur.eq(cur)
                yield dut.rx.post.eq(post)
                yield dut.rx.reject.eq(reject)
                yield dut.rx_valid.eq(1)
                yield
                yield dut.rx_valid.eq(0)
                for _ in range(4):
                    yield
        def state():
            return ((yield dut.preset), (yield dut.c_pre), (yield dut.c_cur), (yield dut.c_post),
                ((yield dut.tx.eq_ctrl) >> 3) & 0xf, (yield dut.tx.reject))
        def generator():
            # Phase 0: preset 7 of the EQ TS2.
            yield dut.eq_ts2.eq(0x80 | (7 << 3) | 2)
            yield dut.load.eq(1)
            yield
            yield dut.load.eq(0)
            yield
            res["load"] = (yield from state())
            # Phase 1: FS, LF, Post-cursor.
            yield dut.ec.eq(0b01)
            yield
            yield
            res["phase1"] = ((yield dut.tx.pre), (yield dut.tx.cur), (yield dut.tx.post), (yield dut.tx.eq_ctrl) & 3)
            # Phase 2 (requesting): keep the partner's Coefficients (the ones of its last TS1).
            yield from send(0b10, pre=3, cur=30, post=7, n=1)
            yield dut.ec.eq(0b10)
            yield
            yield
            res["request"] = ((yield dut.tx.pre), (yield dut.tx.cur), (yield dut.tx.post), (yield dut.tx.eq_ctrl) >> 7)
            yield from send(0b10, pre=3, cur=30, post=7, n=2)
            res["eval"] = ((yield dut.eval_done), (yield dut.accepted))
            # Phase 3 (responding): presets and Coefficients, legal or not.
            yield dut.ec.eq(0b11)
            yield
            yield
            yield from send(0b11, use=1, preset=8)
            res["p8"] = (yield from state())
            yield from send(0b11, use=1, preset=12)
            res["p12"] = (yield from state())
            yield from send(0b11, pre=6, cur=28, post=6)
            res["c_ok"] = (yield from state())
            yield from send(0b11, pre=12, cur=22, post=6)
            res["c_bad"] = (yield from state()) + ((yield dut.tx.pre), (yield dut.tx.cur), (yield dut.tx.post))
        run_simulation(dut, generator())
        self.assertEqual(res["load"],   (7, 4, 28, 8, 7, 0))
        self.assertEqual(res["phase1"], (40, 15, 8, 0b01))
        self.assertEqual(res["request"], (3, 30, 7, 0))
        self.assertEqual(res["eval"],   (1, 1))
        self.assertEqual(res["p8"],     (8, 5, 30, 5, 8, 0))
        self.assertEqual(res["p12"],    (8, 5, 30, 5, 12, 1))
        self.assertEqual(res["c_ok"],   (8, 6, 28, 6, 12, 0))
        self.assertEqual(res["c_bad"],  (8, 6, 28, 6, 12, 1, 12, 22, 6))


class TestSoftGen3TSSymbols(unittest.TestCase):
    def test_ts_symbols(self):
        # TS1 and TS2 Symbols (4.2.4.1, Tables 4-5/4-6), each on 8 bits, then decoded back.
        from litepcie.phy.soft.gen3 import ts3_layout, ts3_symbols, ts3_fields
        class DUT(Module):
            def __init__(self):
                self.ts  = Record(ts3_layout())
                self.out = Record(ts3_layout())
                self.data = Signal(128)
                self.comb += self.data.eq(Cat(*ts3_symbols(self.ts)))
                self.comb += ts3_fields(self.data, self.out)
        dut = DUT()
        res = {}
        def generator():
            for ts2 in [0, 1]:
                yield dut.ts.ts2.eq(ts2)
                yield dut.ts.link.eq(5)
                yield dut.ts.lane.eq(3)
                yield dut.ts.n_fts.eq(0xff)
                yield dut.ts.rate.eq(0x0e)
                yield dut.ts.ctrl.eq(0)
                yield dut.ts.eq_ctrl.eq(0x0 if ts2 else 0x39)
                yield dut.ts.pre.eq(4)
                yield dut.ts.cur.eq(28)
                yield dut.ts.post.eq(8)
                yield dut.ts.reject.eq(0)
                yield
                data = (yield dut.data)
                res[ts2] = ([(data >> (8*k)) & 0xff for k in range(16)],
                    ((yield dut.out.ts2), (yield dut.out.link), (yield dut.out.lane), (yield dut.out.rate),
                     (yield dut.out.eq_ctrl), (yield dut.out.pre), (yield dut.out.cur), (yield dut.out.post)))
        run_simulation(dut, generator())
        ts1, ts2 = res[0][0], res[1][0]
        parity = bin(0x39 ^ 4 ^ 28 ^ 8).count("1") & 1
        self.assertEqual(ts1[:9], [0x1e, 5, 3, 0xff, 0x0e, 0, 0x39, 4, 28])
        self.assertEqual(ts1[9], 8 | (parity << 7))
        self.assertEqual(ts1[10:], [0x4a]*6)
        self.assertEqual(ts2, [0x2d, 5, 3, 0xff, 0x0e, 0, 0] + [0x45]*9)
        self.assertEqual(res[0][1], (0, 5, 3, 0x0e, 0x39, 4, 28, 8))
        self.assertEqual(res[1][1][:5], (1, 5, 3, 0x0e, 0))
