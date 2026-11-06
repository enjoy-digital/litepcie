#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import random
import unittest

from migen import *

from litex.soc.cores.code_8b10b import Encoder, Decoder

from litepcie.phy.soft.coding import K_CODES, encode_8b10b, code_8b10b_table, RX8b10bChecker

def reverse10(code):
    return int(f"{code:010b}"[::-1], 2)

def random_symbols(rng, n):
    symbols = []
    for _ in range(n):
        if rng.random() < 0.2:
            x, y = rng.choice(K_CODES)
            symbols.append((x | (y << 5), 1))
        else:
            symbols.append((rng.getrandbits(8), 0))
    return symbols

class TestSoftCoding(unittest.TestCase):
    def test_encode_model_matches_litex_encoder(self):
        # The Python model reproduces the LiteX Encoder codes and running disparity.
        rng     = random.Random(0)
        symbols = random_symbols(rng, 256)
        dut     = Encoder(1, True)
        outputs = []
        def generator():
            for d, k in symbols:
                yield dut.d[0].eq(d)
                yield dut.k[0].eq(k)
                yield
                outputs.append((yield dut.output[0]))
            for _ in range(4):
                yield
                outputs.append((yield dut.output[0]))
        run_simulation(dut, generator())
        rd       = 0
        expected = []
        for d, k in symbols:
            code, rd = encode_8b10b(d, k, rd)
            expected.append(reverse10(code))
        # The encoder outputs are registered (latency found from the first code).
        latency = outputs.index(expected[0])
        self.assertEqual(outputs[latency:latency + len(expected)], expected)

    def test_table(self):
        table = code_8b10b_table()
        valid = [code for code, e in enumerate(table) if e[0] or e[1]]
        # 256 D + 12 K codes, each valid in at least one column, 2 codes for the unbalanced ones.
        self.assertTrue(268 <= len(valid) <= 2*268)
        for d, k in [(0x4a, 0), (0xbc, 1), (0x1c, 1)]:
            for rd in [0, 1]:
                code, rd_out = encode_8b10b(d, k, rd)
                self.assertEqual(table[reverse10(code)][rd], 1)
                self.assertEqual(table[reverse10(code)][2 + rd], rd_out)

    def test_checker(self):
        # Valid stream: no error. Then an invalid code and a valid code in the wrong disparity
        # column are flagged, the disparity re-synchronizes afterwards.
        rng     = random.Random(1)
        symbols = random_symbols(rng, 64)
        class DUT(Module):
            def __init__(self):
                self.submodules.decoder = Decoder(True)
                self.submodules.checker = RX8b10bChecker([self.decoder])
        dut   = DUT()
        codes = []
        rd    = 0
        for d, k in symbols:
            code, rd = encode_8b10b(d, k, rd)
            codes.append(reverse10(code))
        # Invalid code (no valid 8b/10b code is all zeros).
        codes.append(0)
        # Resynchronization on a balanced symbol, then a code of the wrong column: D0.0 is
        # unbalanced (different codes for RD- and RD+).
        code_m, _ = encode_8b10b(0x4a, 0, rd=0) # D10.2 balanced? use D0.0 for the error below.
        codes.append(reverse10(code_m))
        d00_m, rd_m = encode_8b10b(0x00, 0, rd=0)
        d00_p, rd_p = encode_8b10b(0x00, 0, rd=1)
        self.assertNotEqual(d00_m, d00_p)
        codes.append(reverse10(d00_m)) # Current disparity set by the previous code.
        codes.append(reverse10(d00_m if rd_m else d00_p)) # Same column again: wrong one.
        results = []
        def generator():
            for code in codes:
                yield dut.decoder.input.eq(code)
                yield
                results.append(((yield dut.checker.invalid), (yield dut.checker.disparity_error)))
            for _ in range(2):
                yield
                results.append(((yield dut.checker.invalid), (yield dut.checker.disparity_error)))
        run_simulation(dut, generator())
        # Outputs are registered: one cycle of latency.
        results = results[1:]
        n = len(symbols)
        for invalid, disparity_error in results[:n]:
            self.assertEqual((invalid, disparity_error), (0, 0))
        self.assertEqual(results[n][0], 1)      # Invalid code.
        self.assertEqual(results[n + 3][1], 1)  # Wrong disparity column.
