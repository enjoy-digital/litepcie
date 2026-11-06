#
# This file is part of LitePCIe.
#
# Copyright (c) 2019-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY 8b/10b scrambling (PCIe Base 4.2.1.3, Appendix C).

G(X) = X^16 + X^5 + X^4 + X^3 + 1, seed FFFFh on every lane:
- D Symbols are XORed with the LFSR output (D15 first), K Symbols are not scrambled.
- The LFSR advances 8 serial shifts on every Symbol (scrambled or not) except SKP.
- The LFSR is initialized to the seed after a COM (transmitted or received).
- TS1/TS2 and the Compliance Pattern are not scrambled, the LFSR keeps advancing. They are the only
  Ordered Sets with a D Symbol (or PAD) right after the COM, so the Scrambler/Descrambler bypass
  that Symbol and the 14 following ones automatically (with_ts_bypass): the descrambled stream
  carries the Training Sequences unchanged (fields readable). enable=0 is Disable Scrambling.

Ported from the USB3 PIPE project (same LFSR, Gen 1 x1 rules), 4 Symbols per lane word.
"""

from migen import *

from litex.gen import *

from litex.soc.interconnect import stream

from litepcie.phy.soft.common import COM, SKP, PAD, TS_LENGTH, lane_layout

# LFSR helpers -------------------------------------------------------------------------------------

LFSR_SEED = 0xffff

def lfsr_advance(state):
    """Advance the X^16 + X^5 + X^4 + X^3 + 1 LFSR by one serial shift.

    state is a list of 16 masks: each bit of the LFSR is the XOR of the bits of a reference state
    selected by its mask.
    """
    msb = state[15]
    new = [msb] + state[:15]
    for i in [3, 4, 5]:
        new[i] ^= msb
    return new

def lfsr_shift(lfsr, shifts):
    """LFSR state (integer) after shifts serial shifts."""
    for _ in range(shifts):
        msb  = (lfsr >> 15) & 0x1
        lfsr = (lfsr << 1) & 0xffff
        if msb:
            lfsr ^= 0x0039
    return lfsr

def lfsr_value(lfsr):
    """Scrambling value (integer) of a Symbol from the LFSR state: D15 on each of the 8 shifts."""
    return sum((((lfsr_shift(lfsr, n) >> 15) & 0x1) << n) for n in range(8))

def lfsr_xor(signal, mask):
    bits = [signal[i] for i in range(len(signal)) if (mask >> i) & 0x1]
    return Reduce("XOR", bits) if bits else 0

# Scrambler Unit -----------------------------------------------------------------------------------

@ResetInserter()
@CEInserter()
class ScramblerUnit(LiteXModule):
    """Scrambler Unit

    Generates the scrambling values of the 4 Symbols of a lane word. The LFSR advances 8 serial
    shifts on each Symbol except SKP and is initialized to the seed after each COM, including in the
    middle of a word.

    with_skp=False: no SKP Symbols in the stream (TX before the SKP Ordered Set insertion, RX after
    its removal): the LFSR state of each Symbol is computed directly from the current state (or is a
    constant after a COM) instead of Symbol after Symbol (logic depth). with_com=False: no COM
    Symbols either.
    """
    def __init__(self, reset=LFSR_SEED, seed=LFSR_SEED, with_skp=True, with_com=True):
        self.skp   = Signal(4)  # i: SKP Symbol i.
        self.com   = Signal(4)  # i: COM Symbol i.
        self.value = Signal(32) # o: Scrambling value of Symbol i: value[8*i:8*(i+1)].

        # # #

        if not with_skp:
            self.add_direct(reset, seed, with_com)
            return

        cur   = Signal(16, reset=reset)
        state = cur
        for i in range(4):
            # Symbol i value: LFSR output (D15) on each of its 8 serial shifts.
            masks = [1 << n for n in range(16)]
            for n in range(8):
                self.comb += self.value[8*i + n].eq(lfsr_xor(state, masks[15]))
                masks = lfsr_advance(masks)

            # LFSR state after Symbol i.
            new = Signal(16)
            self.comb += [
                If(self.com[i],
                    new.eq(seed)
                ).Elif(self.skp[i],
                    new.eq(state)
                ).Else(
                    new.eq(Cat(*[lfsr_xor(state, mask) for mask in masks]))
                )
            ]
            state = new
        self.sync += cur.eq(state)

    def add_direct(self, reset, seed, with_com):
        def advance(masks, shifts):
            for _ in range(shifts):
                masks = lfsr_advance(masks)
            return masks

        cur = Signal(16, reset=reset)
        ref = [1 << n for n in range(16)] # LFSR bits as masks over cur.
        for i in range(4):
            # Symbol i value: from cur advanced i Symbols or, after a COM on Symbol j < i, constant
            # (seed advanced i - 1 - j Symbols).
            value = Signal(8)
            self.comb += [value[n].eq(lfsr_xor(cur, advance(ref, 8*i + n)[15])) for n in range(8)]
            if with_com:
                for j in range(i):
                    self.comb += If(self.com[j], value.eq(lfsr_value(lfsr_shift(seed, 8*(i - 1 - j)))))
            self.comb += self.value[8*i:8*(i+1)].eq(value)
        # Next state: cur advanced 4 Symbols or, after the last COM on Symbol j, constant.
        new = Signal(16)
        self.comb += new.eq(Cat(*[lfsr_xor(cur, mask) for mask in advance(ref, 32)]))
        if with_com:
            for j in range(4):
                self.comb += If(self.com[j], new.eq(lfsr_shift(seed, 8*(3 - j))))
        self.sync += cur.eq(new)

# Scrambler ----------------------------------------------------------------------------------------

class Scrambler(LiteXModule):
    """Scrambler

    Scrambles the TX data/ctrl stream: K Symbols are not scrambled, the LFSR does not advance on
    SKP and is initialized after COM (with_skp/with_com: see ScramblerUnit). with_ts_bypass: the
    Training Sequences (COM followed by a D Symbol or PAD, 16 Symbols) pass unscrambled while the
    LFSR keeps advancing. enable=0 (Disable Scrambling) passes everything unscrambled.
    """
    def __init__(self, reset=LFSR_SEED, seed=LFSR_SEED, with_skp=True, with_com=True, with_ts_bypass=True):
        self.enable = Signal(reset=1)
        self.sink   =   sink = stream.Endpoint(lane_layout(4))
        self.source = source = stream.Endpoint(lane_layout(4))

        # # #

        self.unit = unit = ScramblerUnit(reset=reset, seed=seed, with_skp=with_skp, with_com=with_com)
        self.comb += unit.ce.eq(sink.valid & sink.ready)
        self.comb += sink.connect(source)

        # Training Sequence bypass: Symbol by Symbol, the Symbol after a COM starts a bypass of
        # TS_LENGTH - 1 Symbols when it is a D Symbol or PAD.
        prev_com = Signal()
        count    = Signal(max=TS_LENGTH)
        prev_com_i, count_i = prev_com, count
        for i in range(4):
            sym = sink.data[8*i:8*(i+1)]
            k   = sink.ctrl[i]
            com = k & (sym == COM.value)
            self.comb += [
                unit.skp[i].eq(k & (sym == SKP.value)),
                unit.com[i].eq(com),
            ]
            bypass = Signal()
            if with_ts_bypass:
                start       = prev_com_i & (~k | (sym == PAD.value))
                prev_com_n  = Signal()
                count_n     = Signal(max=TS_LENGTH)
                self.comb += [
                    bypass.eq(start | (count_i != 0)),
                    prev_com_n.eq(com),
                    If(start,
                        count_n.eq(TS_LENGTH - 2)
                    ).Elif(count_i != 0,
                        count_n.eq(count_i - 1)
                    )
                ]
                prev_com_i, count_i = prev_com_n, count_n
            self.comb += [
                If(~self.enable | k | bypass, # K Symbols/Training Sequences are not scrambled.
                    source.data[8*i:8*(i+1)].eq(sym)
                ).Else(
                    source.data[8*i:8*(i+1)].eq(sym ^ unit.value[8*i:8*(i+1)])
                )
            ]
        if with_ts_bypass:
            self.sync += If(sink.valid & sink.ready,
                prev_com.eq(prev_com_i),
                count.eq(count_i),
            )

# Descrambler --------------------------------------------------------------------------------------

class Descrambler(LiteXModule):
    """Descrambler

    Descrambles the RX data/ctrl stream (scrambling is its own inverse): K Symbols are not
    descrambled, the LFSR does not advance on SKP, the Training Sequences are bypassed. The
    descrambler synchronizes itself to the incoming stream: the LFSR is initialized after each
    received COM.
    """
    def __init__(self, reset=LFSR_SEED, seed=LFSR_SEED, with_skp=True, with_ts_bypass=True):
        self.enable = Signal(reset=1)
        self.sink   =   sink = stream.Endpoint(lane_layout(4))
        self.source = source = stream.Endpoint(lane_layout(4))

        # # #

        self.scrambler = scrambler = Scrambler(reset=reset, seed=seed, with_skp=with_skp,
            with_ts_bypass=with_ts_bypass)
        self.comb += [
            scrambler.enable.eq(self.enable),
            sink.connect(scrambler.sink),
            scrambler.source.connect(source),
        ]
