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

    def test_rx_framer_bad_token(self):
        # A wrong Frame CRC is a framing error: the Length isn't used.
        rng   = random.Random(1)
        token = bytearray(stp_token(9, 1))
        token[2] ^= 0x10
        good  = mwr_dws(rng, 4)
        tlps, dllps, errors = self.run_rx(8, list(token) + [0]*28 + list(stp_token(len(good) + 2, 2)) + sum(good, []) + [1, 2, 3, 4])
        self.assertGreaterEqual(len(errors), 1)
        self.assertEqual([t["seq"] for t in tlps], [2])

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
