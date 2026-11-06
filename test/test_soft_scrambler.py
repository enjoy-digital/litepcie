#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import random
import unittest

from migen import *

from litepcie.phy.soft.common    import COM, SKP, STP, END, SKP_OS, TS1, TS2, LOGICAL_IDLE
from litepcie.phy.soft.scrambler import Scrambler, Descrambler, LFSR_SEED, lfsr_shift, lfsr_value

from test.model.soft.common import ScramblerModel, symbols_to_words, words_to_symbols, ordered_set_words

# LFSR keystream from FFFFh (scrambled Logical Idle), Symbol 0 in bits 7:0 (PCIe Base Appendix C).
keystream_ref = [
    0x14c017ff, 0x8202e7b2, 0xa6286e72, 0x8dbf6dbe,
    0xe6a740be, 0xb2e2d32c, 0x2a770207, 0xe0be34cd,
    0xb1245da7, 0x22bda19b, 0xd31d45d4, 0xee76ead7,
    0xfa1ada2c, 0x3b362d28, 0x676f0e3a, 0x264c06cf,
    0xcd3ae9d3, 0xfc307627, 0xde038b94, 0xf65206d3,
    0x9580884f, 0xf2666ac4, 0x35a10c9f, 0x27cf41e2,
    0x9e7e4074, 0x84fe58a5, 0xa9086009, 0x626f0bf1,
    0xed5c4317, 0xd43f3948, 0xb30ef55a, 0x9b9d03c7,
    0x5c8e0d8b, 0xae779833, 0x3e0bac2d, 0x7a420bda,
    0xa8cfd17c, 0x41ee121c, 0x7a383fc2, 0x01f4690d,
    0xc57231da, 0x0e93d7a0, 0x55a4afdc, 0x1672f0e7,
    0x8438d568, 0x18cd00dd, 0x5930ca9e, 0x771b754c,
    0xcfedc531, 0x3d6e6491, 0x0429e8fe, 0xc4fc6ccf,
    0x62da5e0b, 0xdfab5bba, 0x377db759, 0xc61ae35e,
    0x4ff51488, 0xcb56c88b, 0x634210d3, 0xf7b48a04,
    0x01a00184, 0xee674983, 0xa48b2a3e, 0xd514af76,
]

def run_stream(dut, words, enables=None, valid_rate=1.0, ready_rate=1.0, seed=0):
    """Drive (data, ctrl) words on dut.sink (dut.enable per word) with random valid/ready gaps and
    return the (data, ctrl) words accepted on dut.source."""
    rng     = random.Random(seed)
    enables = enables or [1]*len(words)
    outs    = []
    def generator():
        for (data, ctrl), enable in zip(words, enables):
            yield dut.sink.data.eq(data)
            yield dut.sink.ctrl.eq(ctrl)
            yield dut.enable.eq(enable)
            yield dut.sink.valid.eq(1)
            while True:
                yield dut.source.ready.eq(int(rng.random() < ready_rate))
                yield
                if (yield dut.sink.valid) and (yield dut.sink.ready):
                    outs.append(((yield dut.source.data), (yield dut.source.ctrl)))
                    break
            yield dut.sink.valid.eq(0)
            for _ in range(rng.choice([0, 0, 1, 2]) if valid_rate < 1.0 else 0):
                yield
    run_simulation(dut, generator())
    return outs

class TestSoftScrambler(unittest.TestCase):
    def test_model_keystream(self):
        # Scrambled Logical Idle from the seed is the reference keystream.
        symbols = ScramblerModel().process([(LOGICAL_IDLE, 0)]*4*len(keystream_ref))
        self.assertEqual([data for data, ctrl in symbols_to_words(symbols)], keystream_ref)

    def test_lfsr_helpers(self):
        # lfsr_value/lfsr_shift (used for the direct constants) match the keystream.
        lfsr = LFSR_SEED
        for word in keystream_ref[:8]:
            for i in range(4):
                self.assertEqual(lfsr_value(lfsr), (word >> 8*i) & 0xff)
                lfsr = lfsr_shift(lfsr, 8)

    def test_scrambler_keystream(self):
        words = [(0, 0)]*len(keystream_ref)
        outs  = run_stream(Scrambler(), words)
        self.assertEqual([data for data, ctrl in outs], keystream_ref)

    def test_scrambler_k_symbols_not_scrambled(self):
        # K Symbols pass unchanged but advance the LFSR.
        words = [(0xbcbcbcbc, 0b1111)]*4 + [(0, 0)]*8
        outs  = run_stream(Scrambler(), words)
        model = ScramblerModel().process_words(words)
        self.assertEqual(outs, model)
        self.assertEqual(outs[:4], words[:4])

    def test_scrambler_backpressure(self):
        words = [(0, 0)]*len(keystream_ref)
        outs  = run_stream(Scrambler(), words, valid_rate=0.5, ready_rate=0.5, seed=1)
        self.assertEqual([data for data, ctrl in outs], keystream_ref)

    def test_scrambler_mixed_ctrl(self):
        rng   = random.Random(2)
        words = [(rng.getrandbits(32), rng.getrandbits(4)) for _ in range(64)]
        outs  = run_stream(Scrambler(), words)
        self.assertEqual(outs, ScramblerModel().process_words(words))

    def test_scrambler_com_resets_skp_holds(self):
        # SKP Ordered Sets (COM + 3 SKP): the COM initializes the LFSR, the SKPs don't advance it
        # (4.2.1.3), the Symbol after the Ordered Set is scrambled with the first keystream byte.
        words  = [(0, 0)]*8 + ordered_set_words(SKP_OS) + [(0, 0)]*8
        outs   = run_stream(Scrambler(), words)
        self.assertEqual(outs, ScramblerModel().process_words(words))
        self.assertEqual(outs[9][0], keystream_ref[0])
        # COM in the middle of a word (x1 Ordered Sets at any Symbol position).
        words  = [(0, 0)]*3 + [(COM.value << 16, 0b0100)] + [(0, 0)]*8
        outs   = run_stream(Scrambler(), words)
        self.assertEqual(outs, ScramblerModel().process_words(words))
        self.assertEqual(outs[3][0] >> 24, keystream_ref[0] & 0xff)

    def test_scrambler_training_sequences_not_scrambled(self):
        # TS1/TS2 are sent with enable=0: not scrambled, the LFSR still advances and the COM
        # initializes it; the Logical Idle after the last TS2 is scrambled accordingly.
        ts_words   = ordered_set_words(TS1)*2 + ordered_set_words(TS2)*2
        idle_words = [(0, 0)]*8
        words      = ts_words + idle_words
        enables    = [0]*len(ts_words) + [1]*len(idle_words)
        outs       = run_stream(Scrambler(), words, enables)
        model      = ScramblerModel()
        expected   = model.process_words(ts_words, enable=False) + model.process_words(idle_words)
        self.assertEqual(outs, expected)
        self.assertEqual(outs[:len(ts_words)], ts_words)
        # After COM + 15 Symbols, the LFSR is the seed advanced 15 Symbols.
        self.assertEqual(outs[len(ts_words)][0] & 0xff, lfsr_value(lfsr_shift(LFSR_SEED, 15*8)))

    def test_scrambler_direct(self):
        # with_skp=False (direct LFSR states, with/without COM) == generic Scrambler on a stream
        # without SKP, random valid/ready.
        for with_com in [False, True]:
            rng   = random.Random(3)
            words = []
            for _ in range(128):
                data, ctrl = rng.getrandbits(32), 0
                for i in range(4):
                    if with_com and rng.random() < 0.1:
                        data = (data & ~(0xff << 8*i)) | (COM.value << 8*i)
                        ctrl |= 1 << i
                words.append((data, ctrl))
            ref    = run_stream(Scrambler(), words, valid_rate=0.7, ready_rate=0.7, seed=4)
            direct = run_stream(Scrambler(with_skp=False, with_com=with_com), words, valid_rate=0.7, ready_rate=0.7, seed=4)
            self.assertEqual(direct, ref)
            self.assertEqual(ref, ScramblerModel().process_words(words))

    def test_descrambler_synchronizes_on_com(self):
        # The descrambler locks on any received COM (at any Symbol position): the Logical Idle
        # scrambled from the seed after it, including in the same word, descrambles to zeros.
        for position in range(4):
            unsynced  = [(word, 0) for word in keystream_ref[8:16]]
            tx        = ScramblerModel(seed=0x1234)
            symbols   = [(SKP.value, 1)]*position
            symbols  += tx.process([(COM.value, 1)] + [(0, 0)]*(4*8 + 3 - position))
            words     = unsynced + symbols_to_words(symbols)
            outs      = run_stream(Descrambler(), words)
            out_syms  = words_to_symbols(outs)
            com_index = 4*len(unsynced) + position
            self.assertEqual(out_syms[com_index], (COM.value, 1))
            self.assertEqual(out_syms[com_index + 1:], [(0, 0)]*(4*8 + 3 - position))

    def test_descrambler_training_sequences(self):
        # Scrambler and Descrambler back-to-back: TS1/TS2 unscrambled, then DLLP/TLP framing with
        # K Symbols and a SKP Ordered Set, all recovered.
        class DUT(Module):
            def __init__(self):
                self.submodules.scrambler   = Scrambler()
                self.submodules.descrambler = Descrambler()
                self.comb += self.scrambler.source.connect(self.descrambler.sink)
                self.sink   = self.scrambler.sink
                self.source = self.descrambler.source
                self.enable = self.scrambler.enable
        rng      = random.Random(5)
        ts_words = ordered_set_words(TS1) + ordered_set_words(TS2)
        packet   = [(STP.value, 1)] + [(rng.getrandbits(8), 0) for _ in range(14)] + [(END.value, 1)]
        words    = ts_words + symbols_to_words(packet) + ordered_set_words(SKP_OS) + [(0, 0)]*4
        enables  = [0]*len(ts_words) + [1]*(len(words) - len(ts_words))
        outs     = run_stream(DUT(), words, enables, valid_rate=0.5, ready_rate=0.5, seed=6)
        # The descrambler runs on everything: the unscrambled TS words come out meaningless (TS
        # detection uses the raw Symbols), everything after them is recovered.
        self.assertNotEqual(outs[:len(ts_words)], ts_words)
        self.assertEqual(outs[len(ts_words):], words[len(ts_words):])

    def test_scrambler_disable_scrambling(self):
        # enable=0 everywhere (Disable Scrambling): data passes through.
        rng   = random.Random(7)
        words = [(rng.getrandbits(32), rng.getrandbits(4)) for _ in range(32)]
        outs  = run_stream(Scrambler(), words, enables=[0]*len(words))
        self.assertEqual(outs, words)
