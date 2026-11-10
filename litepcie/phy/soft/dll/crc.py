#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY Data Link Layer CRCs: LCRC (32-bit, PCIe Base 3.5.2.1) and DLLP CRC (16-bit, 3.4.1).

Both are computed on the bytes in transmission order, bits LSB first within a byte (byte k of a word
is data[8*k:8*(k+1)]), from an all-ones seed. The remainder is complemented and bit-reversed: byte 0
of value (value[0:8]) is the first CRC byte transmitted. The LCRC covers the 16-bit TLP Sequence
Number (Reserved bits as 0, most significant byte first) and the TLP; with these conventions it is
zlib.crc32(sequence_number.to_bytes(2, "big") + tlp) transmitted least significant byte first (the
Ethernet FCS convention, used as the reference in the tests). The DLLP CRC follows the same rules on
the 4 DLLP bytes with G(X) = X^16 + X^12 + X^3 + X + 1 (100Bh).

The parallel equations are generated from the polynom (symbolic serial computation), as in the USB3
PIPE project CRCs.
"""

from migen import *

from litex.gen import *

# Constants ----------------------------------------------------------------------------------------

LCRC_POLYNOM     = 0x04c11db7
LCRC_INIT        = 0xffffffff
DLLP_CRC_POLYNOM = 0x100b
DLLP_CRC_INIT    = 0xffff

# CRC Equations ------------------------------------------------------------------------------------

def crc_equations(width, poly, nbits):
    """Parallel CRC equations: for each bit of the next state, a mask over the current state bits
    (bits 0..width-1) and the data bits (bits width..width+nbits-1), data bit 0 entering first."""
    state = [1 << i for i in range(width)]
    for i in range(nbits):
        msb   = state[width - 1]
        state = [0] + state[:-1]
        fb    = msb ^ (1 << (width + i))
        for j in range(width):
            if (poly >> j) & 0x1:
                state[j] ^= fb
    return state

def crc_xor(bits, mask):
    terms = [bits[i] for i in range(len(bits)) if (mask >> i) & 0x1]
    return Reduce("XOR", terms) if terms else 0

def crc_next(width, poly, state, data):
    """Next CRC state expressions (list of width bits) from state/data Signals."""
    bits = [state[i] for i in range(width)] + [data[i] for i in range(len(data))]
    return [crc_xor(bits, mask) for mask in crc_equations(width, poly, len(data))]

def crc_rewind_equations(width, poly, nbits):
    """Masks over the state bits giving, for each bit, the state before nbits zero data bits: the
    inverse of the state transition (invertible, the polynom has its X^0 term)."""
    mask  = (1 << width) - 1
    rows  = [m & mask for m in crc_equations(width, poly, nbits)]
    # Gaussian elimination of [rows | identity] over GF(2).
    aug = [(rows[i], 1 << i) for i in range(width)]
    for col in range(width):
        pivot = next(r for r in range(col, width) if (aug[r][0] >> col) & 1)
        aug[col], aug[pivot] = aug[pivot], aug[col]
        for r in range(width):
            if r != col and (aug[r][0] >> col) & 1:
                aug[r] = (aug[r][0] ^ aug[col][0], aug[r][1] ^ aug[col][1])
    return [aug[i][1] for i in range(width)]

def crc_value(width, state_bits):
    """CRC value from the state bits: complemented remainder, bit-reversed."""
    return Cat(*[~state_bits[width - 1 - i] for i in range(width)])

# CRC Combinatorial --------------------------------------------------------------------------------

class CRCComb(LiteXModule):
    """Combinatorial CRC of a fixed size data."""
    def __init__(self, width, poly, init, data_width):
        self.data  = Signal(data_width) # i
        self.value = Signal(width)      # o

        # # #

        init_bits = Constant(init, width)
        self.comb += self.value.eq(crc_value(width, crc_next(width, poly, init_bits, self.data)))

# DLLP CRC (3.4.1) ---------------------------------------------------------------------------------

class DLLPCRC(CRCComb):
    """16-bit CRC of the 4 DLLP bytes (data[0:8] first). value[0:8] is the first CRC byte of the
    DLLP (bytes 4 and 5)."""
    def __init__(self):
        CRCComb.__init__(self,
            width      = 16,
            poly       = DLLP_CRC_POLYNOM,
            init       = DLLP_CRC_INIT,
            data_width = 32,
        )

# LCRC (3.5.2.1) -----------------------------------------------------------------------------------

class LCRC(LiteXModule):
    """32-bit LCRC of a TLP computed word by word on a data_width datapath.

    clear: initialize the CRC (before the first word), ce: process the data word: bytes valid bytes
    (data[0:8] first, 0: no data), sizes: the supported bytes values (default: 2 for the TLP Sequence
    Number word and the multiples of 4 up to the datapath width, TLPs are DW multiples). value: CRC
    of the processed data (registered state), next_value: CRC including the current data.
    """
    def __init__(self, data_width=32, sizes=None):
        assert data_width in [32, 64, 128]
        nbytes = data_width//8
        if sizes is None:
            sizes = [2] + [4*n for n in range(1, nbytes//4 + 1)]
        assert all(1 <= size <= nbytes for size in sizes)
        self.clear      = Signal()                 # i
        self.ce         = Signal()                 # i
        self.data       = Signal(data_width)       # i
        self.bytes      = Signal(max=nbytes + 1)   # i: Valid bytes.
        self.value      = Signal(32)               # o
        self.next_value = Signal(32)               # o

        # # #

        state = Signal(32, reset=LCRC_INIT)
        new   = Signal(32)
        cases = {n: new.eq(Cat(*crc_next(32, LCRC_POLYNOM, state, self.data[:8*n]))) for n in sizes}
        cases["default"] = new.eq(state)
        self.comb += Case(self.bytes, cases)
        self.sync += [
            If(self.clear,
                state.eq(LCRC_INIT)
            ).Elif(self.ce,
                state.eq(new)
            )
        ]
        self.comb += [
            self.value.eq(crc_value(32, state)),
            self.next_value.eq(crc_value(32, new)),
        ]
