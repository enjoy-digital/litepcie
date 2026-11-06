#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY Ordered Sets generation and detection (PCIe Base 4.2.4.1): TS1/TS2 with their
fields, and the 4-Symbol Ordered Sets (FTS, EIOS, SKP).

Generation is word aligned (COM on Symbol 0): the TX stream is built in 4-Symbol units. Detection
works at any Symbol position on the descrambled stream (Training Sequences are not scrambled, SKP
Ordered Sets already removed): Symbol by Symbol state machines, 4 Symbols per cycle.
"""

from migen import *
from migen.genlib.record import Record

from litex.gen import *

from litex.soc.interconnect import stream

from litepcie.phy.soft.common import COM, PAD, TS_LENGTH, TS1_ID, TS2_ID, TS1_ID_INV, TS2_ID_INV
from litepcie.phy.soft.common import lane_layout

# Training Sequence fields -------------------------------------------------------------------------

ts_layout = [
    ("ts2",      1), # TS2 (0: TS1).
    ("link",     8), # Link Number (link_pad: PAD).
    ("link_pad", 1),
    ("lane",     5), # Lane Number (lane_pad: PAD).
    ("lane_pad", 1),
    ("n_fts",    8), # N_FTS.
    ("rate",     8), # Data Rate Identifier.
    ("ctrl",     8), # Training Control.
]

def ts_identifier(ts2, inverted=False):
    """TS1/TS2 identifier Symbol (Symbols 6 to 15), as received with an inverted lane polarity."""
    return Mux(inverted, Mux(ts2, TS2_ID_INV, TS1_ID_INV), Mux(ts2, TS2_ID, TS1_ID))

# Training Sequence Generator ----------------------------------------------------------------------

class TSGenerator(LiteXModule):
    """Training Sequence Generator

    Generates TS1/TS2 Ordered Sets back-to-back while enable is set (the current Ordered Set is
    completed when it is cleared), 4 words each, with the ts fields sampled at the start of each
    Ordered Set. first/last delimit the Ordered Sets (SKP insertion between them), done pulses when
    the last word of an Ordered Set is accepted, busy is set inside an Ordered Set.
    """
    def __init__(self):
        self.enable = Signal()           # i (Level)
        self.ts     = Record(ts_layout)  # i
        self.busy   = Signal()           # o (Level)
        self.done   = Signal()           # o (Pulse)
        self.source = source = stream.Endpoint(lane_layout(4))

        # # #

        word   = Signal(2)
        run    = Signal()
        fields = Record(ts_layout) # Sampled at the start of the Ordered Set.
        cur    = Record(ts_layout) # Fields of the word being output.

        accepted = source.valid & source.ready
        self.comb += [
            If(word == 0, cur.eq(self.ts)).Else(cur.eq(fields)),
            source.valid.eq(self.enable | run),
            source.first.eq(word == 0),
            source.last.eq(word == 3),
            self.busy.eq(run),
            self.done.eq(accepted & (word == 3)),
        ]
        self.sync += [
            If(accepted,
                word.eq(word + 1),
                If(word == 0,
                    run.eq(1),
                    fields.eq(self.ts),
                ),
                If(word == 3,
                    run.eq(0),
                ),
            )
        ]

        # Words.
        ident = ts_identifier(cur.ts2)
        link  = Mux(cur.link_pad, PAD.value, cur.link)
        lane  = Mux(cur.lane_pad, PAD.value, Cat(cur.lane, Constant(0, 3)))
        self.comb += Case(word, {
            0: [source.data.eq(Cat(Constant(COM.value, 8), link, lane, cur.n_fts)),
                source.ctrl.eq(Cat(Constant(1, 1), cur.link_pad, cur.lane_pad, Constant(0, 1)))],
            1: [source.data.eq(Cat(cur.rate, cur.ctrl, ident, ident)),
                source.ctrl.eq(0)],
            2: [source.data.eq(Replicate(ident, 4)),
                source.ctrl.eq(0)],
            3: [source.data.eq(Replicate(ident, 4)),
                source.ctrl.eq(0)],
        })

# Training Sequence Checker ------------------------------------------------------------------------

class TSChecker(LiteXModule):
    """Training Sequence Checker

    Detects TS1/TS2 Ordered Sets at any Symbol position on the descrambled stream: a COM (re)starts
    the sequence, then Link Number (D or PAD), Lane Number (D 0-31 or PAD), N_FTS, Data Rate
    Identifier, Training Control and 10 identifiers (TS1 D10.2, TS2 D5.2, or their inverted lane
    polarity values D21.5/D26.5). detected pulses on the word carrying the last Symbol, with ts
    (fields) and inverted updated; error pulses when a started sequence does not match.
    """
    def __init__(self):
        self.sink     = sink = stream.Endpoint(lane_layout(4))
        self.detected = Signal()          # o (Pulse)
        self.error    = Signal()          # o (Pulse)
        self.inverted = Signal()          # o (Level): last detected Ordered Set with inverted polarity.
        self.ts       = Record(ts_layout) # o (Level): fields of the last detected Ordered Set.

        # # #

        self.comb += sink.ready.eq(1)

        # Input register (timing).
        valid = Signal()
        data  = Signal(32)
        ctrl  = Signal(4)
        self.sync += [
            valid.eq(sink.valid),
            data.eq(sink.data),
            ctrl.eq(sink.ctrl),
        ]

        # Symbol by Symbol state: idx is the index of the expected Symbol (0: waiting for a COM).
        idx = Signal(max=TS_LENGTH)
        ts2 = Signal()
        inv = Signal()
        cap = Record(ts_layout)

        idx_c, ts2_c, inv_c = idx, ts2, inv
        detected = []
        errors   = []
        for i in range(4):
            sym    = data[8*i:8*(i+1)]
            k      = ctrl[i]
            com    = k & (sym == COM.value)
            is_d   = ~k
            is_pad = k & (sym == PAD.value)
            idx_n  = Signal(max=TS_LENGTH)
            ts2_n  = Signal()
            inv_n  = Signal()
            det    = Signal()
            err    = Signal()
            ident  = ts_identifier(ts2_c, inv_c)
            def step(ok, *captures):
                return If(ok, idx_n.eq(idx_c + 1), *captures).Else(err.eq(1), idx_n.eq(0))
            self.comb += [
                idx_n.eq(idx_c),
                ts2_n.eq(ts2_c),
                inv_n.eq(inv_c),
                If(com,
                    idx_n.eq(1),
                    err.eq(idx_c > 1), # Training Sequence interrupted by a new COM.
                ).Elif(idx_c == 0,
                    # Waiting for a COM.
                ).Elif(idx_c == 1,
                    # D Symbol or PAD: Training Sequence, other K Symbols: other Ordered Sets.
                    If(is_d | is_pad, idx_n.eq(2)).Else(idx_n.eq(0))
                ).Elif(idx_c == 2,
                    step((is_d & (sym < 32)) | is_pad)
                ).Elif(idx_c <= 5,
                    step(is_d)
                ).Elif(idx_c == 6,
                    If(is_d & (sym == TS1_ID),     idx_n.eq(7), ts2_n.eq(0), inv_n.eq(0)
                    ).Elif(is_d & (sym == TS2_ID), idx_n.eq(7), ts2_n.eq(1), inv_n.eq(0)
                    ).Elif(is_d & (sym == TS1_ID_INV), idx_n.eq(7), ts2_n.eq(0), inv_n.eq(1)
                    ).Elif(is_d & (sym == TS2_ID_INV), idx_n.eq(7), ts2_n.eq(1), inv_n.eq(1)
                    ).Else(err.eq(1), idx_n.eq(0))
                ).Else(
                    If(is_d & (sym == ident),
                        If(idx_c == (TS_LENGTH - 1),
                            det.eq(1),
                            idx_n.eq(0)
                        ).Else(
                            idx_n.eq(idx_c + 1)
                        )
                    ).Else(
                        err.eq(1),
                        idx_n.eq(0)
                    )
                )
            ]
            # Fields capture.
            self.sync += If(valid & ~com,
                If(idx_c == 1, cap.link.eq(Mux(is_pad, 0, sym)), cap.link_pad.eq(is_pad)),
                If(idx_c == 2, cap.lane.eq(Mux(is_pad, 0, sym)), cap.lane_pad.eq(is_pad)),
                If(idx_c == 3, cap.n_fts.eq(sym)),
                If(idx_c == 4, cap.rate.eq(sym)),
                If(idx_c == 5, cap.ctrl.eq(sym)),
            )
            detected.append(valid & det)
            errors.append(valid & err)
            idx_c, ts2_c, inv_c = idx_n, ts2_n, inv_n

        self.sync += [
            If(valid,
                idx.eq(idx_c),
                ts2.eq(ts2_c),
                inv.eq(inv_c),
            ),
            self.detected.eq(Reduce("OR", detected)),
            self.error.eq(Reduce("OR", errors)),
            If(Reduce("OR", detected),
                self.ts.eq(cap),
                self.ts.ts2.eq(ts2_c),
                self.inverted.eq(inv_c),
            )
        ]

# Ordered Set Detector -----------------------------------------------------------------------------

class OrderedSetDetector(LiteXModule):
    """Ordered Set Detector

    Detects a 4-Symbol Ordered Set (FTS, EIOS, SKP: COM + 3 identical K Symbols) at any Symbol
    position: detected pulses on the word carrying its last Symbol.
    """
    def __init__(self, ordered_set):
        self.sink     = sink = stream.Endpoint(lane_layout(4))
        self.detected = Signal() # o (Pulse)

        # # #

        symbols = ordered_set.to_symbols()
        assert len(symbols) == 4
        self.comb += sink.ready.eq(1)

        # 8-Symbol window: previous word (Symbols 0-3) and current word (Symbols 4-7).
        prev_valid = Signal()
        prev_data  = Signal(32)
        prev_ctrl  = Signal(4)
        self.sync += If(sink.valid,
            prev_valid.eq(1),
            prev_data.eq(sink.data),
            prev_ctrl.eq(sink.ctrl),
        )
        window_data = Cat(prev_data, sink.data)
        window_ctrl = Cat(prev_ctrl, sink.ctrl)

        # Ordered Sets ending in the current word: positions 1 to 4.
        matches = []
        for p in range(1, 5):
            match = [(window_ctrl[p + j] == k) & (window_data[8*(p + j):8*(p + j + 1)] == value)
                for j, (value, k) in enumerate(symbols)]
            valid = sink.valid & (prev_valid if p < 4 else 1)
            matches.append(valid & Reduce("AND", match))
        self.sync += self.detected.eq(Reduce("OR", matches))
