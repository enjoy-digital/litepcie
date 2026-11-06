#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY packet framing on the lane (PCIe Base 4.2.2.1, Gen1/Gen2 8b/10b).

TLP: STP, TLP Sequence Number (2 bytes), TLP DWs, LCRC DW, END (or EDB: nullified). DLLP: SDP,
4 bytes, 2 CRC bytes, END. Both are multiples of 4 Symbols, so a transmitter building its stream in
4-Symbol words keeps them word aligned, while the receiver sees them at any Symbol position (word
phase of the link).

RXFramer extracts the packets Symbol by Symbol (4 per cycle, one word of lookahead for the END):
TLPs as DW words (Sequence Number with first, EDB flag with last), DLLPs as 48-bit values. TXFramer
frames TLP DW words (Sequence Number with first, LCRC included) and DLLPs into lane words with
first/last (SKP Ordered Set insertion between them).
"""

from migen import *

from litex.gen import *

from litex.soc.interconnect import stream

from litepcie.phy.soft.common import STP, SDP, END, EDB, lane_layout

# Layouts ------------------------------------------------------------------------------------------

def tlp_layout():
    """TLP DW stream: data (DW, byte 0 on bits 7:0 as on the lane), seq (Sequence Number, valid with
    first), edb (nullified, valid with last)."""
    return [("data", 32), ("seq", 12), ("edb", 1)]

# RX Framer ----------------------------------------------------------------------------------------

class RXFramer(LiteXModule):
    """RX Framer

    sink: received lane words (any word phase, no SKP Ordered Sets). tlp: TLP DW words (TLP and
    LCRC, first/last), dllp/dllp_valid: received DLLPs (48 bits, CRC not checked here). error pulses
    on framing errors (unexpected K Symbol, TLP not a DW multiple), the packet is dropped (tlp_abort
    pulses when a TLP already started was dropped).
    """
    def __init__(self):
        self.sink       = sink = stream.Endpoint(lane_layout(4))
        self.tlp        = tlp  = stream.Endpoint(tlp_layout())
        self.dllp       = Signal(48) # o
        self.dllp_valid = Signal()   # o (Pulse)
        self.error      = Signal()   # o (Pulse)
        self.tlp_abort  = Signal()   # o (Pulse)

        # # #

        # Lookahead: the word being processed is the previous one, Symbol 0 of the current one is
        # the Symbol after its last Symbol.
        prev_valid = Signal()
        prev_data  = Signal(32)
        prev_ctrl  = Signal(4)
        process    = Signal()
        self.comb += [
            process.eq(prev_valid & sink.valid),
            sink.ready.eq(~prev_valid | process),
        ]
        self.sync += [
            If(sink.valid & sink.ready,
                prev_valid.eq(1),
                prev_data.eq(sink.data),
                prev_ctrl.eq(sink.ctrl),
            ).Elif(process,
                prev_valid.eq(0)
            )
        ]
        syms  = [(prev_data[8*i:8*(i+1)], prev_ctrl[i]) for i in range(4)] + [(sink.data[0:8], sink.ctrl[0])]

        # Kept bytes to DW words.
        self.repacker = repacker = WordRepacker()

        # Symbol by Symbol state machine.
        IDLE, SEQ_HI, SEQ_LO, TLP, DLLP, DLLP_END = range(6)
        state   = Signal(3)
        seq     = Signal(12)
        dllp    = Signal(48)
        dllp_i  = Signal(3) # DLLP byte index.
        started = Signal()  # A TLP payload byte was kept (for tlp_abort).

        keep       = Signal(4)
        start      = Signal()
        end        = Signal()
        end_edb    = Signal() # The packet ends with EDB (valid with end).
        error      = Signal()
        abort      = Signal()
        dllp_done  = Signal()
        dllp_done_value = Signal(48) # The completed DLLP (valid with dllp_done).
        state_c, dllp_i_c, started_c, dllp_c = state, dllp_i, started, dllp
        for i in range(4):
            sym, k   = syms[i]
            nsym, nk = syms[i + 1]
            is_end    = nk & ((nsym == END.value) | (nsym == EDB.value)) # Next Symbol ends the packet.
            state_n   = Signal(3)
            dllp_i_n  = Signal(3)
            started_n = Signal()
            dllp_n    = Signal(48)
            self.comb += [
                state_n.eq(state_c),
                dllp_i_n.eq(dllp_i_c),
                started_n.eq(started_c),
                dllp_n.eq(dllp_c),
                Case(state_c, {
                    IDLE: [
                        If(k & (sym == STP.value),
                            state_n.eq(SEQ_HI),
                            started_n.eq(0),
                        ).Elif(k & (sym == SDP.value),
                            state_n.eq(DLLP),
                            dllp_i_n.eq(0),
                        )
                    ],
                    SEQ_HI: [
                        If(k, error.eq(1), state_n.eq(IDLE)).Else(state_n.eq(SEQ_LO))
                    ],
                    SEQ_LO: [
                        If(k, error.eq(1), state_n.eq(IDLE)).Else(state_n.eq(TLP))
                    ],
                    TLP: [
                        If(k,
                            # END/EDB consumed (the last byte was flagged with the previous Symbol),
                            # any other K Symbol is a framing error.
                            If((sym == END.value) | (sym == EDB.value),
                                state_n.eq(IDLE)
                            ).Else(
                                error.eq(1),
                                abort.eq(started_c),
                                state_n.eq(IDLE),
                            )
                        ).Else(
                            keep[i].eq(1),
                            If(~started_c, start.eq(1)),
                            started_n.eq(1),
                            If(is_end,
                                end.eq(1),
                                end_edb.eq(nsym == EDB.value),
                            ),
                        )
                    ],
                    DLLP: [
                        If(k,
                            error.eq(1),
                            state_n.eq(IDLE),
                        ).Else(
                            Case(dllp_i_c, {j: dllp_n[8*j:8*(j+1)].eq(sym) for j in range(6)}),
                            dllp_i_n.eq(dllp_i_c + 1),
                            If(dllp_i_c == 5, state_n.eq(DLLP_END)),
                        )
                    ],
                    DLLP_END: [
                        If(k & (sym == END.value),
                            dllp_done.eq(1),
                            dllp_done_value.eq(dllp_c),
                        ).Else(
                            error.eq(1),
                        ),
                        state_n.eq(IDLE),
                    ],
                }),
            ]
            # Sequence Number capture.
            self.sync += If(process,
                If(state_c == SEQ_HI, seq[8:12].eq(sym[0:4])),
                If(state_c == SEQ_LO, seq[0:8].eq(sym)),
            )
            state_c, dllp_i_c, started_c, dllp_c = state_n, dllp_i_n, started_n, dllp_n
        self.sync += [
            If(process,
                state.eq(state_c),
                dllp_i.eq(dllp_i_c),
                started.eq(started_c),
                dllp.eq(dllp_c),
                # The completed DLLP latched apart: the next one may start in the same word.
                If(dllp_done, self.dllp.eq(dllp_done_value)),
            ),
            self.dllp_valid.eq(process & dllp_done),
            self.error.eq((process & error) | repacker.length_error),
            self.tlp_abort.eq(process & abort),
        ]

        self.comb += [
            repacker.sink.valid.eq(process),
            repacker.sink.data.eq(prev_data),
            repacker.sink.keep.eq(keep),
            repacker.sink.start.eq(start),
            repacker.sink.end.eq(end),
            repacker.sink.abort.eq(abort),
            repacker.source.connect(tlp, omit={"seq", "edb"}),
            tlp.seq.eq(seq),
            tlp.edb.eq(end_edb),
        ]

# Word Repacker ------------------------------------------------------------------------------------

class WordRepacker(LiteXModule):
    """Repacks the kept bytes (keep mask) of 4-byte words into full 4-byte words: packets (start/end
    on the fragments holding their first/last byte) are DW multiples and start on an empty buffer,
    first/last are set on their first/last word. A packet ending with pending bytes is a length error
    (bytes dropped). abort drops the pending bytes. No back-pressure (one word in, at most one out)."""
    def __init__(self):
        self.sink   = sink   = stream.Endpoint([("data", 32), ("keep", 4), ("start", 1), ("end", 1), ("abort", 1)])
        self.source = source = stream.Endpoint([("data", 32)])
        self.length_error = Signal() # o (Pulse)

        # # #

        self.comb += sink.ready.eq(1)

        # Fragment: kept bytes packed.
        frag_data  = Signal(32)
        frag_bytes = Signal(3)
        cases = {}
        for mask in range(16):
            datas = [sink.data[8*j:8*(j+1)] for j in range(4) if (mask >> j) & 1]
            cases[mask] = [
                frag_data.eq(Cat(*datas) if datas else 0),
                frag_bytes.eq(len(datas)),
            ]
        self.comb += Case(sink.keep, cases)

        # Shift register (up to 3 pending bytes), a word output when 4 bytes are available: the
        # pending bytes then the fragment bytes, oldest first.
        sr_data  = Signal(24, reset_less=True)
        sr_bytes = Signal(2)
        first    = Signal()
        total    = Signal(3) # Bytes available this cycle.
        self.comb += [
            total.eq(sr_bytes + frag_bytes),
            source.valid.eq(sink.valid & (total >= 4)),
            source.first.eq(first | sink.start),
            source.last.eq(sink.end & (total == 4)),
            self.length_error.eq(sink.valid & sink.end & (total != 4)),
        ]
        out_cases  = {}
        keep_cases = {}
        rem_cases  = {}
        for n in range(4):
            combined = Cat(sr_data[0:8*n], frag_data) if n else frag_data # 8n + 32 bits.
            out_cases[n]  = source.data.eq(combined[0:32])
            keep_cases[n] = sr_data.eq(combined)         # total < 4: everything pending.
            rem_cases[n]  = sr_data.eq(combined[32:]) if n else sr_data.eq(0) # Remaining after a word.
        self.comb += Case(sr_bytes, out_cases)
        self.sync += If(sink.valid,
            If(sink.abort | (sink.end & (total != 4)),
                sr_bytes.eq(0),
                first.eq(0),
            ).Elif(total >= 4,
                sr_bytes.eq(total - 4),
                first.eq(0),
                Case(sr_bytes, rem_cases),
            ).Else(
                sr_bytes.eq(total),
                If(sink.start, first.eq(1)),
                Case(sr_bytes, keep_cases),
            )
        )

# TX Framer ----------------------------------------------------------------------------------------

class TXFramer(LiteXModule):
    """TX Framer

    tlp: TLP DW words (TLP then LCRC, first/last, seq with first) framed as STP, Sequence Number,
    DWs, END (edb: EDB). dllp/dllp_valid (ready: dllp_ready): DLLPs framed as SDP, 6 bytes, END. The
    lane words carry first/last per packet. DLLPs have priority between TLPs.
    """
    def __init__(self):
        self.tlp        = tlp    = stream.Endpoint(tlp_layout())
        self.dllp       = Signal(48) # i
        self.dllp_valid = Signal()   # i (Level, cleared by dllp_ready)
        self.dllp_ready = Signal()   # o (Pulse)
        self.source     = source = stream.Endpoint(lane_layout(4))

        # # #

        self.fsm = fsm = FSM(reset_state="IDLE")
        carry = Signal(24) # Upper 3 bytes of the previous DW.
        half  = Signal()   # DLLP second word.
        fsm.act("IDLE",
            If(self.dllp_valid,
                NextState("DLLP")
            ).Elif(tlp.valid & tlp.first,
                # First word: STP, Sequence Number, first byte of the first DW.
                source.valid.eq(1),
                source.first.eq(1),
                source.data.eq(Cat(Constant(STP.value, 8), Constant(0, 4), tlp.seq[8:12], tlp.seq[0:8], tlp.data[0:8])),
                source.ctrl.eq(0b0001),
                If(source.ready,
                    tlp.ready.eq(1),
                    NextValue(carry, tlp.data[8:32]),
                    If(tlp.last,
                        NextState("TLP-END")
                    ).Else(
                        NextState("TLP")
                    )
                )
            ).Elif(tlp.valid,
                tlp.ready.eq(1) # Drop words outside a packet.
            )
        )
        fsm.act("TLP",
            source.valid.eq(tlp.valid),
            source.data.eq(Cat(carry, tlp.data[0:8])),
            source.ctrl.eq(0),
            If(source.valid & source.ready,
                tlp.ready.eq(1),
                NextValue(carry, tlp.data[8:32]),
                If(tlp.last,
                    NextState("TLP-END")
                )
            )
        )
        fsm.act("TLP-END",
            source.valid.eq(1),
            source.last.eq(1),
            source.data.eq(Cat(carry, Constant(0, 8))),
            source.ctrl.eq(0b1000),
            If(tlp.edb,
                source.data[24:32].eq(EDB.value)
            ).Else(
                source.data[24:32].eq(END.value)
            ),
            If(source.ready,
                NextState("IDLE")
            )
        )
        fsm.act("DLLP",
            source.valid.eq(1),
            If(~half,
                source.first.eq(1),
                source.data.eq(Cat(Constant(SDP.value, 8), self.dllp[0:24])),
                source.ctrl.eq(0b0001),
            ).Else(
                source.last.eq(1),
                source.data.eq(Cat(self.dllp[24:48], Constant(END.value, 8))),
                source.ctrl.eq(0b1000),
            ),
            If(source.ready,
                NextValue(half, ~half),
                If(half,
                    self.dllp_ready.eq(1),
                    NextState("IDLE"),
                )
            )
        )
