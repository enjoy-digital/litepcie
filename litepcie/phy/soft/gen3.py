#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY 8.0 GT/s lane blocks (PCIe Base 4.2.2, 128b/130b): scrambler, gearboxes between the
transceiver's 40-bit words and the 130-bit blocks, Block alignment. Building blocks, not used by
SoftPCIEPHY yet.

A Block is a 2-bit Sync Header (H0 first) and 16 Symbols (bit 0 first). 13 words of 40 bits hold exactly 4
Blocks, so they start on 4 bit offsets only (0, 10, 20, 30) with the bit alignment done once at the input.
"""

from migen import *

from litex.gen import *

# Sync Headers (H1H0).
SYNC_DATA = 0b10
SYNC_OS   = 0b01

# Ordered Sets Symbol 0 (4.2.4.1, 4.2.4.3, 4.2.4.6, 4.2.7.2).
OS_TS1   = 0x1e
OS_TS2   = 0x2d
OS_EIOS  = 0x66
OS_EIEOS = 0x00
OS_SDS   = 0xe1
OS_SKP   = 0xaa

EIEOS_PAYLOAD = int.from_bytes(bytes([0x00, 0xff]*8), "little")

# Scrambler ----------------------------------------------------------------------------------------

# LFSR seed per Lane Number modulo 8 (4.2.2.4).
LFSR_SEEDS = [0x1dbfbc, 0x0607bb, 0x1ec760, 0x18c0db, 0x010f12, 0x19cfc9, 0x0277ce, 0x1bb807]

# G(X) = X^23 + X^21 + X^16 + X^8 + X^5 + X^2 + 1, advanced by a Symbol (Appendix C.2): next state bit,
# from the state bits. Data bit, XORed with the state bits.
LFSR_NEXT = {
    22: [14, 16, 18, 20, 21, 22], 21: [13, 15, 17, 19, 20, 21], 20: [12, 19, 21], 19: [11, 18, 20, 22],
    18: [10, 17, 19, 21], 17: [9, 16, 18, 20, 22], 16: [8, 15, 17, 19, 21, 22], 15: [7, 22], 14: [6, 21],
    13: [5, 20, 22], 12: [4, 19, 21, 22], 11: [3, 18, 20, 21, 22], 10: [2, 17, 19, 20, 21, 22],
    9: [1, 16, 18, 19, 20, 21], 8: [0, 15, 17, 18, 19, 20], 7: [17, 19, 20, 21], 6: [16, 18, 19, 20, 22],
    5: [15, 17, 18, 19, 21, 22], 4: [17], 3: [16], 2: [15, 22], 1: [16, 18, 20, 22], 0: [15, 17, 19, 21, 22],
}
LFSR_OUT = {
    7: [15, 17, 19, 21, 22], 6: [16, 18, 20, 22], 5: [17, 19, 21], 4: [18, 20, 22], 3: [19, 21], 2: [20, 22],
    1: [21], 0: [22],
}

def lfsr_next(state):
    """Python model: state advanced by a Symbol."""
    value = 0
    for bit, taps in LFSR_NEXT.items():
        value |= (sum((state >> t) & 1 for t in taps) & 1) << bit
    return value

def lfsr_out(state):
    """Python model: byte XORed with a Symbol."""
    value = 0
    for bit, taps in LFSR_OUT.items():
        value |= (sum((state >> t) & 1 for t in taps) & 1) << bit
    return value

def lfsr_equations(nsymbols):
    """Parallel equations over the state bits (masks): the state after nsymbols, and the bits XORed with
    the nsymbols Symbols."""
    state = [1 << i for i in range(23)]
    out   = []
    for _ in range(nsymbols):
        for bit in range(8):
            mask = 0
            for t in LFSR_OUT[bit]:
                mask ^= state[t]
            out.append(mask)
        next_state = [0]*23
        for bit, taps in LFSR_NEXT.items():
            for t in taps:
                next_state[bit] ^= state[t]
        state = next_state
    return state, out

class Gen3Scrambler(LiteXModule):
    """nsymbols Symbols per cycle (the same for scrambling and descrambling). ce: Symbols of this cycle
    are processed, the LFSR advances. bypass: Symbols passed as they are (the LFSR still advances).
    advance=0: nothing scrambled and the LFSR holds (SKP Ordered Sets). init: LFSR reloaded with the seed
    of the Lane, after this cycle."""
    def __init__(self, seed, nsymbols=8):
        self.ce       = Signal()
        self.advance  = Signal(reset=1)
        self.init     = Signal()
        self.bypass   = Signal(nsymbols)
        self.data_in  = Signal(8*nsymbols)
        self.data_out = Signal(8*nsymbols)

        # # #

        state = Signal(23, reset=seed)
        next_masks, out_masks = lfsr_equations(nsymbols)
        def xor(mask):
            return Reduce("XOR", [state[i] for i in range(23) if (mask >> i) & 1])
        next_state = Signal(23)
        for bit in range(23):
            self.comb += next_state[bit].eq(xor(next_masks[bit]))
        for bit in range(8*nsymbols):
            symbol = bit//8
            self.comb += self.data_out[bit].eq(self.data_in[bit] ^ (xor(out_masks[bit]) & ~self.bypass[symbol] & self.advance))
        self.sync += If(self.init,
            state.eq(seed)
        ).Elif(self.ce & self.advance,
            state.eq(next_state)
        )

# RX Gearbox ---------------------------------------------------------------------------------------

class RXBlockGearbox(LiteXModule):
    """40-bit words to Blocks. slip (Pulse): the Block position moves one bit further, after 40 of them
    a word further: all the 130 positions are reached with 130 slips."""
    def __init__(self):
        self.data   = Signal(40)  # i
        self.ce     = Signal(reset=1) # i: word present.
        self.slip   = Signal()    # i
        self.valid  = Signal()    # o (Pulse)
        self.sync_header = Signal(2) # o
        self.block  = Signal(128) # o

        # # #

        # Bit alignment.
        previous = Signal(40)
        shift    = Signal(6)
        aligned  = Signal(40)
        self.comb += Case(shift, {s: aligned.eq(Cat(previous, self.data)[s:s + 40]) for s in range(40)})
        self.sync += If(self.ce, previous.eq(self.data))

        # Last 4 words, Blocks at words 3, 6, 9 and 12 of 13.
        words = Signal(160)
        count = Signal(4)
        skip  = Signal()
        self.sync += [
            self.valid.eq(0),
            If(self.slip,
                If(shift == 39,
                    shift.eq(0),
                    skip.eq(1),
                ).Else(
                    shift.eq(shift + 1)
                )
            ),
            If(self.ce,
                words.eq(Cat(words[40:], aligned)),
                If(skip,
                    skip.eq(self.slip & (shift == 39))
                ).Elif(count == 12,
                    count.eq(0)
                ).Else(
                    count.eq(count + 1)
                ),
            )
        ]
        # Blocks taken from the 4 words once the last one is in: the count of that word, one cycle later.
        block_bits = Signal(130)
        offsets    = {3: 0, 6: 10, 9: 20, 12: 30}
        count_r    = Signal(4)
        ce_r       = Signal()
        skip_r     = Signal()
        self.sync += [
            count_r.eq(count),
            ce_r.eq(self.ce),
            skip_r.eq(skip),
        ]
        cases = {c: block_bits.eq(words[o:o + 130]) for c, o in offsets.items()}
        cases["default"] = block_bits.eq(0)
        self.comb += Case(count_r, cases)
        ready = Signal()
        self.comb += ready.eq(ce_r & ~skip_r & ((count_r == 3) | (count_r == 6) | (count_r == 9) | (count_r == 12)))
        self.sync += [
            self.valid.eq(ready),
            If(ready,
                self.sync_header.eq(block_bits[0:2]),
                self.block.eq(block_bits[2:130]),
            )
        ]

# TX Gearbox ---------------------------------------------------------------------------------------

class TXBlockGearbox(LiteXModule):
    """Blocks to 40-bit words. A Block is taken when ready is set, it has to be there."""
    def __init__(self):
        self.data  = Signal(40)  # o
        self.ready = Signal()    # o
        self.sync_header = Signal(2) # i
        self.block = Signal(128) # i

        # # #

        buffer = Signal(170)
        level  = Signal(8)
        block  = Cat(self.sync_header, self.block)
        self.comb += [
            self.data.eq(buffer[:40]),
            self.ready.eq(level < 80),
        ]
        rest = Signal(170)
        self.comb += rest.eq(buffer[40:])
        cases = {l: buffer.eq(rest[:l] | (block << l)) for l in [0, 10, 20, 30]}
        self.sync += [
            If(level >= 80,
                buffer.eq(rest),
                level.eq(level - 40),
            ).Else(
                # At this point 40 to 70 bits are in the buffer, after this word 0 to 30.
                Case(level - 40, cases),
                level.eq(level - 40 + 130),
            )
        ]

# Block Aligner ------------------------------------------------------------------------------------

class BlockAligner(LiteXModule):
    """Block alignment (4.2.2.2.1), on the RX gearbox. Unaligned: an undefined Sync Header, or no EIEOS
    for search_blocks Blocks, moves the position by a bit. An EIEOS at the expected place: Aligned, left
    on an undefined Sync Header unless locked (Data Stream, directed by the Physical Layer: SDS)."""
    def __init__(self, gearbox, search_blocks=128):
        self.locked  = Signal() # i: Locked phase (no adjustment).
        self.aligned = Signal() # o
        self.eieos   = Signal() # o (Pulse)

        # # #

        count     = Signal(max=search_blocks + 1)
        settling  = Signal()
        undefined = (gearbox.sync_header == 0b00) | (gearbox.sync_header == 0b11)
        is_eieos  = (gearbox.sync_header == SYNC_OS) & (gearbox.block == EIEOS_PAYLOAD)
        self.comb += self.eieos.eq(gearbox.valid & is_eieos)
        self.sync += [
            If(gearbox.valid & ~settling,
                If(is_eieos,
                    self.aligned.eq(1),
                    count.eq(0),
                ).Elif(undefined,
                    If(~self.locked, self.aligned.eq(0)),
                    count.eq(0),
                ).Elif(~self.aligned,
                    If(count == search_blocks,
                        count.eq(0)
                    ).Else(
                        count.eq(count + 1)
                    )
                )
            )
        ]
        # The Block after a slip mixes bits of both positions: not looked at.
        self.comb += gearbox.slip.eq(gearbox.valid & ~settling & ~self.aligned & ~is_eieos & (undefined | (count == search_blocks)))
        self.sync += If(gearbox.slip,
            settling.eq(1)
        ).Elif(gearbox.valid,
            settling.eq(0)
        )
