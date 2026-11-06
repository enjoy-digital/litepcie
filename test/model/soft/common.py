#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY reference models: Symbols/lane words helpers and the 8b/10b scrambler (PCIe Base
4.2.1.3, Appendix C).

Symbols are (value, k) tuples. Lane words are (data, ctrl) with Symbol 0 in data[7:0]/ctrl[0], as on
the lane streams.
"""

from litepcie.phy.soft.common import COM, SKP

# Symbols <-> Words --------------------------------------------------------------------------------

def words_to_symbols(words, nsymbols=4):
    """(data, ctrl) words to (value, k) Symbols (Symbol 0 first)."""
    symbols = []
    for data, ctrl in words:
        for i in range(nsymbols):
            symbols.append(((data >> 8*i) & 0xff, (ctrl >> i) & 0x1))
    return symbols

def symbols_to_words(symbols, nsymbols=4):
    """(value, k) Symbols to (data, ctrl) words (Symbol 0 first), len multiple of nsymbols."""
    assert len(symbols) % nsymbols == 0
    words = []
    for i in range(0, len(symbols), nsymbols):
        data = ctrl = 0
        for j, (value, k) in enumerate(symbols[i:i+nsymbols]):
            data |= value << 8*j
            ctrl |= k << j
        words.append((data, ctrl))
    return words

def ordered_set_words(ordered_set, nsymbols=4):
    """(data, ctrl) words of an Ordered Set."""
    return symbols_to_words(ordered_set.to_symbols(), nsymbols)

# Scrambler Reference Model (4.2.1.3) --------------------------------------------------------------

LFSR_SEED = 0xffff

def lfsr_advance(lfsr):
    """Advance the G(X) = X^16 + X^5 + X^4 + X^3 + 1 LFSR by one serial shift."""
    msb  = (lfsr >> 15) & 0x1
    lfsr = (lfsr << 1) & 0xffff
    if msb:
        lfsr ^= 0x0039 # X^5 + X^4 + X^3 + 1.
    return lfsr

def lfsr_scramble_byte(lfsr, value):
    """XOR a byte with the LFSR output (D15, bit 0 first), advancing 8 serial shifts."""
    out = 0
    for i in range(8):
        out  |= (((value >> i) & 0x1) ^ ((lfsr >> 15) & 0x1)) << i
        lfsr  = lfsr_advance(lfsr)
    return out, lfsr

class ScramblerModel:
    """Symbol-level (de)scrambler (scrambling is its own inverse).

    - D Symbols are scrambled (when enabled), K Symbols are not.
    - The LFSR advances 8 shifts on every Symbol except SKP, scrambled or not.
    - The LFSR is initialized (FFFFh) after a COM.
    """
    def __init__(self, seed=LFSR_SEED):
        self.lfsr = seed

    def process(self, symbols, enable=True):
        out = []
        for value, k in symbols:
            if k and value == SKP.value:
                out.append((value, k))
                continue
            scrambled, self.lfsr = lfsr_scramble_byte(self.lfsr, value)
            out.append((scrambled if (enable and not k) else value, k))
            if k and value == COM.value:
                self.lfsr = LFSR_SEED
        return out

    def process_words(self, words, enable=True, nsymbols=4):
        return symbols_to_words(self.process(words_to_symbols(words, nsymbols), enable), nsymbols)
