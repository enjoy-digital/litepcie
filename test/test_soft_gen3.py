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
