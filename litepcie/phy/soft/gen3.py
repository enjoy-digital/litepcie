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

from litex.soc.interconnect import stream

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
        cases = {l: buffer.eq(Cat(rest[:l], block)) for l in [10, 20, 30]}
        cases[0] = buffer.eq(block)
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

# Framing Tokens -----------------------------------------------------------------------------------

def stp_token(length, seq):
    """STP Token (4.2.2.3.1) as a Python model: length: DWs of the TLP, Token and LCRC included."""
    l = [(length >> i) & 1 for i in range(11)]
    c = [
        l[10] ^ l[7] ^ l[6] ^ l[4] ^ l[2] ^ l[1] ^ l[0],
        l[10] ^ l[9] ^ l[7] ^ l[5] ^ l[4] ^ l[3] ^ l[2],
        l[9] ^ l[8] ^ l[6] ^ l[4] ^ l[3] ^ l[2] ^ l[1],
        l[8] ^ l[7] ^ l[5] ^ l[3] ^ l[2] ^ l[1] ^ l[0],
    ]
    p = l[10] ^ l[9] ^ l[8] ^ l[6] ^ l[5] ^ l[2] ^ l[0]
    fcrc = sum(c[i] << i for i in range(4))
    return bytes([((length & 0xf) << 4) | 0xf, (p << 7) | ((length >> 4) & 0x7f), (fcrc << 4) | ((seq >> 8) & 0xf), seq & 0xff])

def _stp_check(length):
    """Expected FCRC and Frame Parity, from the Length bits: gateware."""
    l = length
    c = [
        l[10] ^ l[7] ^ l[6] ^ l[4] ^ l[2] ^ l[1] ^ l[0],
        l[10] ^ l[9] ^ l[7] ^ l[5] ^ l[4] ^ l[3] ^ l[2],
        l[9] ^ l[8] ^ l[6] ^ l[4] ^ l[3] ^ l[2] ^ l[1],
        l[8] ^ l[7] ^ l[5] ^ l[3] ^ l[2] ^ l[1] ^ l[0],
    ]
    p = l[10] ^ l[9] ^ l[8] ^ l[6] ^ l[5] ^ l[2] ^ l[0]
    return Cat(*c), p

SDP_TOKEN = bytes([0xf0, 0xac])
EDS_TOKEN = bytes([0x1f, 0x80, 0x90, 0x00])
EDB_TOKEN = bytes([0xc0]*4)

TOKEN_IDL, TOKEN_STP, TOKEN_SDP, TOKEN_EDS, TOKEN_EDB, TOKEN_ERR = range(6)

class Gen3RXFramer(LiteXModule):
    """Data Stream of the Data Blocks to TLP beats and DLLPs, ndw DWs per cycle, same interface as
    WideRXFramer. There are no K Symbols: the Tokens give the location of the next one. Tokens are on a DW
    from x4 on, this framer doesn't handle the other positions possible at x1 and x2 after IDL Tokens.

    Pipelined (timing): each DW slot classified as if a Token started there (kind, position of the next
    Token), then for every start slot the Tokens reached in the beat and the position after them (pointer
    doubling, a stage per level), then the only loop from a beat to the next: the start in the beat, then the
    slots labelled from the Token before them (TLP DWs, first/last, sequence number, DLLPs, errors)."""
    def __init__(self, ndw, fifo_depth=64):
        from litepcie.phy.soft.dll.wide import TLPRepacker, tlp_beat_layout
        self.sink       = sink = stream.Endpoint([("data", 32*ndw)])
        self.tlp        = tlp  = stream.Endpoint(tlp_beat_layout(ndw))
        self.dllp       = Signal(48) # o
        self.dllp_valid = Signal()   # o (Pulse)
        self.error      = Signal()   # o (Pulse): framing error (the LTSSM goes to Recovery).
        self.tlp_abort  = Signal()   # o (Pulse)

        # # #

        self.comb += sink.ready.eq(1)
        pw = 12 # Positions: up to a TLP Length (11 bits) past the last slot.
        iw = bits_for(ndw - 1)

        # The word processed is the previous one, slot 0 of the current one is its lookahead (second DW of a
        # DLLP, EDB after a TLP).
        prev_valid = Signal()
        prev_data  = Signal(32*ndw)
        self.sync += If(sink.valid,
            prev_valid.eq(1),
            prev_data.eq(sink.data),
        )

        # Stage A: slots classified.
        a_valid = Signal()
        a_data  = Signal(32*(ndw + 1))
        a_kind  = [Signal(3)  for _ in range(ndw)]
        a_next  = [Signal(pw) for _ in range(ndw)]
        a_seq   = [Signal(12) for _ in range(ndw)]
        self.sync += [
            a_valid.eq(prev_valid & sink.valid),
            a_data.eq(Cat(prev_data, sink.data[0:32])),
        ]
        for i in range(ndw):
            slot   = prev_data[32*i:32*(i+1)]
            length = Cat(slot[4:8], slot[8:15])
            fcrc, parity = _stp_check(length)
            stp_ok = (slot[20:24] == fcrc) & (slot[15] == parity) & (length >= 5)
            self.sync += [
                a_seq[i].eq(Cat(slot[24:32], slot[16:20])),
                a_next[i].eq(i + 1),
                If(slot == 0x0090801f,
                    a_kind[i].eq(TOKEN_EDS)
                ).Elif(slot == 0xc0c0c0c0,
                    a_kind[i].eq(TOKEN_EDB)
                ).Elif(slot[0:4] == 0xf,
                    If(stp_ok,
                        a_kind[i].eq(TOKEN_STP),
                        a_next[i].eq(i + length),
                    ).Else(
                        a_kind[i].eq(TOKEN_ERR)
                    )
                ).Elif(slot[0:16] == 0xacf0,
                    a_kind[i].eq(TOKEN_SDP),
                    a_next[i].eq(i + 2),
                ).Elif(slot[0:8] == 0,
                    a_kind[i].eq(TOKEN_IDL)
                ).Else(
                    a_kind[i].eq(TOKEN_ERR)
                )
            ]

        # Stage B: pointer doubling. J[s]: position after the Tokens followed from s (in the beat: not done),
        # M[s]: Tokens reached from s.
        valid, data, kinds, nexts, seqs = a_valid, a_data, a_kind, a_next, a_seq
        J = list(a_next)
        M = [Constant(1 << i, ndw) for i in range(ndw)]
        steps = 1
        while steps < ndw:
            J_n = [Signal(pw)  for _ in range(ndw)]
            M_n = [Signal(ndw) for _ in range(ndw)]
            J_a = Array(J)
            M_a = Array(M)
            for i in range(ndw):
                inb = J[i] < ndw
                self.sync += [
                    J_n[i].eq(Mux(inb, J_a[J[i][:iw]], J[i])),
                    M_n[i].eq(M[i] | Mux(inb, M_a[J[i][:iw]], 0)),
                ]
            # Beat data along.
            valid_n = Signal()
            data_n  = Signal(len(data))
            kinds_n = [Signal(3)  for _ in range(ndw)]
            nexts_n = [Signal(pw) for _ in range(ndw)]
            seqs_n  = [Signal(12) for _ in range(ndw)]
            self.sync += [valid_n.eq(valid), data_n.eq(data)] + \
                [kinds_n[i].eq(kinds[i]) for i in range(ndw)] + \
                [nexts_n[i].eq(nexts[i]) for i in range(ndw)] + \
                [seqs_n[i].eq(seqs[i]) for i in range(ndw)]
            valid, data, kinds, nexts, seqs = valid_n, data_n, kinds_n, nexts_n, seqs_n
            J, M = J_n, M_n
            steps *= 2

        # Stage C: start in the beat (the loop), Token carried from the previous beats (the last one: its kind,
        # sequence number, and if it was on the last slot).
        start   = Signal(pw)   # First Token of the beat (>= ndw: none).
        c_kind  = Signal(3, reset=TOKEN_IDL)
        c_seq   = Signal(12)
        c_last  = Signal()     # The carried Token was on the last slot of the previous beat.
        inb     = start < ndw
        tokens  = Signal(ndw)
        J_a     = Array(J)
        M_a     = Array(M)
        self.comb += tokens.eq(Mux(inb, M_a[start[:iw]], 0))
        last_kind = Signal(3)
        last_seq  = Signal(12)
        last_pos  = Signal(iw)
        for i in range(ndw): # Highest Token of the beat.
            self.comb += If(tokens[i], last_kind.eq(kinds[i]), last_seq.eq(seqs[i]), last_pos.eq(i))
        d_valid  = Signal()
        d_data   = Signal(len(data))
        d_tokens = Signal(ndw)
        d_start  = Signal(pw)
        d_kind   = Signal(3)
        d_seq    = Signal(12)
        d_last   = Signal()
        d_kinds  = [Signal(3)  for _ in range(ndw)]
        d_nexts  = [Signal(pw) for _ in range(ndw)]
        d_seqs   = [Signal(12) for _ in range(ndw)]
        self.sync += [
            d_valid.eq(valid),
            If(valid,
                d_data.eq(data),
                d_tokens.eq(tokens),
                d_start.eq(start),
                d_kind.eq(c_kind),
                d_seq.eq(c_seq),
                d_last.eq(c_last),
                *[d_kinds[i].eq(kinds[i]) for i in range(ndw)],
                *[d_nexts[i].eq(nexts[i]) for i in range(ndw)],
                *[d_seqs[i].eq(seqs[i]) for i in range(ndw)],
                start.eq(Mux(inb, J_a[start[:iw]], start) - ndw),
                If(tokens != 0,
                    c_kind.eq(last_kind),
                    c_seq.eq(last_seq),
                    c_last.eq(last_pos == ndw - 1),
                ).Else(
                    c_last.eq(0)
                )
            )
        ]

        # Stage D: slots labelled from the Token before them (or the carried one).
        slots  = [d_data[32*i:32*(i+1)] for i in range(ndw + 1)]
        edb    = [slots[i] == 0xc0c0c0c0 for i in range(ndw + 1)]
        tlp_v  = [Signal() for _ in range(ndw)]
        tlp_f  = [Signal() for _ in range(ndw)]
        tlp_l  = [Signal() for _ in range(ndw)]
        dllp_v = [Signal() for _ in range(ndw)]
        errors = [Signal() for _ in range(ndw)]
        tseqs  = [Signal(12) for _ in range(ndw)]
        for k in range(ndw):
            o_kind  = Signal(3)
            o_seq   = Signal(12)
            o_first = Signal()
            o_last  = Signal()
            # Carried Token: TLP DWs up to the start, the first one on slot 0 if the STP was on the last slot.
            statements = [
                o_kind.eq(d_kind),
                o_seq.eq(d_seq),
                o_first.eq(d_last & (k == 0)),
                o_last.eq(d_start == k + 1),
            ]
            for j in range(k + 1): # Latest Token at or before slot k.
                statements.append(If(d_tokens[j],
                    o_kind.eq(d_kinds[j]),
                    o_seq.eq(d_seqs[j]),
                    o_first.eq(k == j + 1),
                    o_last.eq(d_nexts[j] == k + 1),
                ))
            self.comb += statements
            self.comb += [
                tlp_v[k].eq((o_kind == TOKEN_STP) & ~d_tokens[k]),
                tlp_f[k].eq(o_first & tlp_v[k]),
                tlp_l[k].eq(o_last & tlp_v[k]),
                tseqs[k].eq(o_seq),
                dllp_v[k].eq(d_tokens[k] & (d_kinds[k] == TOKEN_SDP)),
                errors[k].eq(d_tokens[k] & (d_kinds[k] == TOKEN_ERR)),
            ]
        process = d_valid

        # DLLPs: 2 bytes in the Token's DW, 4 in the next one. Queued, one per cycle.
        # Index of each one: the write pointer plus the DLLPs before it in the beat (power of 2 queue).
        nq = max(8, ndw)
        qw = log2_int(nq)
        dllps = Array(Signal(48) for _ in range(nq))
        wr, rd = Signal(qw), Signal(qw)
        for i in range(ndw):
            index = Signal(qw)
            self.comb += index.eq(wr + (popcount(Cat(*dllp_v[:i])) if i else 0))
            self.sync += If(process & dllp_v[i], dllps[index].eq(Cat(slots[i][16:32], slots[i + 1])))
        self.sync += [
            If(process, wr.eq(wr + popcount(Cat(*dllp_v)))),
            self.dllp_valid.eq(rd != wr),
            If(rd != wr,
                self.dllp.eq(dllps[rd]),
                rd.eq(rd + 1),
            )
        ]

        # First-aligned TLP beats.
        beat_layout = [("valid_", ndw), ("first_", ndw), ("last_", ndw), ("edb", ndw), ("abort", 1),
                       ("data", 32*ndw), ("seq", 12*ndw)]
        self.fifo = fifo = stream.SyncFIFO(beat_layout, fifo_depth, buffered=True)
        self.repacker = repacker = TLPRepacker(ndw)
        tlp_any = Signal()
        missed  = Signal()
        any_err = Signal()
        self.comb += [
            tlp_any.eq(Reduce("OR", tlp_v)),
            any_err.eq(Reduce("OR", errors)),
            fifo.source.ready.eq(repacker.sink_ready),
            repacker.sink_en.eq(fifo.source.valid),
            repacker.sink_valid.eq(fifo.source.valid_),
            repacker.sink_first.eq(fifo.source.first_),
            repacker.sink_last.eq(fifo.source.last_),
            repacker.sink_edb.eq(fifo.source.edb),
            repacker.sink_data.eq(fifo.source.data),
            repacker.sink_seq.eq(fifo.source.seq),
            repacker.flush.eq(fifo.source.abort),
            tlp.valid.eq(repacker.source.valid),
            tlp.first.eq(repacker.source.first),
            tlp.last.eq(repacker.source.last),
            tlp.data.eq(repacker.source.data),
            tlp.dws.eq(repacker.source.dws),
            tlp.seq.eq(repacker.source.seq),
            tlp.edb.eq(repacker.source.edb),
            repacker.source.ready.eq(tlp.ready),
        ]
        self.sync += [
            fifo.sink.valid.eq(process & (tlp_any | missed)),
            fifo.sink.valid_.eq(Cat(*tlp_v)),
            fifo.sink.first_.eq(Cat(*tlp_f)),
            fifo.sink.last_.eq(Cat(*tlp_l)),
            fifo.sink.edb.eq(Cat(*[edb[i + 1] for i in range(ndw)])),
            fifo.sink.abort.eq(missed),
            fifo.sink.data.eq(d_data[:32*ndw]),
            fifo.sink.seq.eq(Cat(*tseqs)),
            If(fifo.sink.valid & ~fifo.sink.ready,
                missed.eq(1)
            ).Elif(fifo.sink.valid & fifo.sink.abort,
                missed.eq(0)
            ),
            self.tlp_abort.eq(repacker.flushed),
            self.error.eq((process & any_err) | (fifo.sink.valid & ~fifo.sink.ready)),
        ]

class Gen3TXFramer(LiteXModule):
    """TLP beats (lcrc valid with last, first DW of the header on data[0:32]) and DLLPs to the Data Stream,
    one packet per beat and from the first DW of a beat, the rest of the beat in IDL Tokens. The STP Token's
    TLP Length comes from the header: 3 or 4 DWs, the data, the LCRC and the Token."""
    def __init__(self, ndw):
        from litepcie.phy.soft.dll.wide import tlp_beat_layout
        self.tlp        = tlp    = stream.Endpoint(tlp_beat_layout(ndw))
        self.lcrc       = Signal(32) # i
        self.dllp       = Signal(48) # i
        self.dllp_valid = Signal()   # i (Level, cleared by dllp_ready)
        self.dllp_ready = Signal()   # o (Pulse)
        self.source     = source = stream.Endpoint([("data", 32*ndw)])

        # # #

        # TLP Length from the first DW of the header (byte 0 on bits 7:0).
        dw0      = tlp.data[0:32]
        has_data = dw0[6]
        is_4dw   = dw0[5]
        hdr_len  = Cat(dw0[24:32], dw0[16:18])
        data_len = Signal(11)
        length   = Signal(11)
        self.comb += [
            If(~has_data,
                data_len.eq(0)
            ).Elif(hdr_len == 0,
                data_len.eq(1024)
            ).Else(
                data_len.eq(hdr_len)
            ),
            length.eq(data_len + Mux(is_4dw, 6, 5)), # Header, LCRC, Token.
        ]
        fcrc, parity = _stp_check(length)
        token = Cat(Constant(0xf, 4), length[0:4], length[4:11], parity, tlp.seq[8:12], fcrc, tlp.seq[0:8])

        # DWs following the previous one: data, then the LCRC with the last beat.
        ext = Signal(32*(ndw + 1))
        self.comb += If(tlp.last,
            Case(tlp.dws, {d: ext.eq(Cat(tlp.data[0:32*d], self.lcrc)) for d in range(1, ndw + 1)})
        ).Else(
            ext.eq(tlp.data)
        )
        # With the Token, the last DWs and the LCRC can go past the beat: up to 2 DWs in a last one.
        carry = Signal(64)
        tail  = tlp.last & (tlp.dws >= ndw - 1)
        self.fsm = fsm = FSM(reset_state="IDLE")
        fsm.act("IDLE",
            source.valid.eq(1),
            If(self.dllp_valid,
                source.first.eq(1),
                source.last.eq(1),
                source.data.eq(Cat(Constant(0xacf0, 16), self.dllp)),
                self.dllp_ready.eq(source.ready),
            ).Elif(tlp.valid & tlp.first,
                source.first.eq(1),
                source.last.eq(tlp.last & ~tail),
                source.data.eq(Cat(token, ext[:32*(ndw - 1)])),
                If(source.ready,
                    tlp.ready.eq(1),
                    NextValue(carry, ext[32*(ndw - 1):]),
                    If(tlp.last,
                        If(tail, NextState("TAIL"))
                    ).Else(
                        NextState("TLP")
                    )
                )
            ).Else(
                source.data.eq(0) # IDL Tokens.
            )
        )
        # Between packets: the next beat is IDL Tokens (an EDS Token can be placed).
        self.idle = Signal() # o
        self.comb += self.idle.eq(fsm.ongoing("IDLE") & ~self.dllp_valid & ~(tlp.valid & tlp.first))
        fsm.act("TLP",
            source.valid.eq(tlp.valid),
            source.last.eq(tlp.last & ~tail),
            source.data.eq(Cat(carry[:32], ext[:32*(ndw - 1)])),
            If(source.valid & source.ready,
                tlp.ready.eq(1),
                NextValue(carry, ext[32*(ndw - 1):]),
                If(tlp.last,
                    If(tail,
                        NextState("TAIL")
                    ).Else(
                        NextState("IDLE")
                    )
                )
            )
        )
        fsm.act("TAIL",
            source.valid.eq(1),
            source.last.eq(1),
            source.data.eq(carry),
            If(source.ready,
                NextState("IDLE")
            )
        )

# Lane Tester --------------------------------------------------------------------------------------

class Gen3TXTester(LiteXModule):
    """Blocks for a transceiver without a host: an EIEOS every `interval` Blocks, Data Blocks in between
    carrying scrambled Logical Idle (the LFSR initialized after each EIEOS, as on a link)."""
    def __init__(self, seed, interval=33):
        self.data  = Signal(40) # o

        # # #

        self.gearbox   = gearbox   = TXBlockGearbox()
        self.scrambler = scrambler = Gen3Scrambler(seed, nsymbols=16)
        count = Signal(max=interval)
        eieos = count == 0
        self.comb += [
            self.data.eq(gearbox.data),
            scrambler.ce.eq(gearbox.ready & ~eieos),
            scrambler.init.eq(gearbox.ready & eieos),
            If(eieos,
                gearbox.sync_header.eq(SYNC_OS),
                gearbox.block.eq(EIEOS_PAYLOAD),
            ).Else(
                gearbox.sync_header.eq(SYNC_DATA),
                gearbox.block.eq(scrambler.data_out),
            )
        ]
        self.sync += If(gearbox.ready,
            If(count == interval - 1,
                count.eq(0)
            ).Else(
                count.eq(count + 1)
            )
        )

class Gen3RXChecker(LiteXModule):
    """Checks the Blocks of Gen3TXTester: Block alignment, then every Data Block has to descramble to
    Logical Idle. errors counts wrong Blocks, once aligned and after a first EIEOS."""
    def __init__(self, seed):
        self.data    = Signal(40) # i
        self.aligned = Signal()   # o
        self.blocks  = Signal(32) # o
        self.errors  = Signal(32) # o
        self.eieos   = Signal(32) # o

        # # #

        self.gearbox     = gearbox     = RXBlockGearbox()
        self.aligner     = aligner     = BlockAligner(gearbox)
        self.descrambler = descrambler = Gen3Scrambler(seed, nsymbols=16)
        synced = Signal()
        is_data = gearbox.sync_header == SYNC_DATA
        self.comb += [
            gearbox.data.eq(self.data),
            self.aligned.eq(aligner.aligned),
            descrambler.data_in.eq(gearbox.block),
            descrambler.ce.eq(gearbox.valid & is_data),
            descrambler.init.eq(aligner.eieos),
        ]
        self.sync += [
            If(~aligner.aligned,
                synced.eq(0)
            ).Elif(aligner.eieos,
                synced.eq(1),
                self.eieos.eq(self.eieos + 1),
            ),
            If(gearbox.valid & synced,
                self.blocks.eq(self.blocks + 1),
                If(~aligner.eieos & (~is_data | (descrambler.data_out != 0)),
                    self.errors.eq(self.errors + 1)
                )
            )
        ]

# Ordered Sets at 8.0 GT/s (4.2.4.1, 4.2.4.3, 4.2.4.6, 4.2.7.2) -------------------------------------

GEN3_PAD    = 0xf7
TS1_ID3     = 0x4a
TS2_ID3     = 0x45
SDS_BODY    = 0x55
SKP_END     = 0xe1

def ts3_layout():
    """Fields of a 8.0 GT/s Training Sequence. eq_ctrl: Symbol 6 (EC, Reset EIEOS Interval Count, Transmitter Preset,
    Use Preset), pre/cur/post: coefficients (or FS/LF), reject: Reject Coefficient Values (TS1 only)."""
    return [("ts2", 1), ("link", 8), ("link_pad", 1), ("lane", 5), ("lane_pad", 1), ("n_fts", 8), ("rate", 8),
            ("ctrl", 8), ("eq_ctrl", 8), ("pre", 6), ("cur", 6), ("post", 6), ("reject", 1)]

def ts3_symbols(ts):
    """The 16 Symbols of a Training Sequence (Symbol 0 first, bits 7:0), Symbols 14 and 15 as the identifier."""
    c8    = lambda v: Constant(v, 8) # Symbols on 8 bits (a Mux of constants takes the width of the largest).
    ident = Mux(ts.ts2, c8(TS2_ID3), c8(TS1_ID3))
    s7    = Mux(ts.ts2, c8(TS2_ID3), Cat(ts.pre, Constant(0, 2)))
    s8    = Mux(ts.ts2, c8(TS2_ID3), Cat(ts.cur, Constant(0, 2)))
    s9lo  = Cat(ts.post, ts.reject)
    parity = Reduce("XOR", [ts.eq_ctrl[i] for i in range(8)] + [ts.pre[i] for i in range(6)] +
        [ts.cur[i] for i in range(6)] + [s9lo[i] for i in range(7)])
    s9    = Mux(ts.ts2, c8(TS2_ID3), Cat(s9lo, parity))
    return [
        Mux(ts.ts2, c8(OS_TS2), c8(OS_TS1)),
        Mux(ts.link_pad, c8(GEN3_PAD), ts.link),
        Mux(ts.lane_pad, c8(GEN3_PAD), Cat(ts.lane, Constant(0, 3))),
        ts.n_fts, ts.rate, ts.ctrl, Mux(ts.ts2, c8(0), ts.eq_ctrl), s7, s8, s9,
    ] + [ident]*6

# Lane TX ------------------------------------------------------------------------------------------

BLOCK_DATA, BLOCK_TS, BLOCK_EIEOS, BLOCK_EIOS, BLOCK_SDS, BLOCK_SKP = range(6)

def block_layout():
    """Block to transmit: kind (BLOCK_*), the 16 Symbols (not scrambled) for Data and TS Blocks."""
    return [("kind", 3), ("data", 128)]

def popcount(bits):
    """Number of bits set, as a balanced adder tree."""
    terms = [bits[i] for i in range(len(bits))]
    while len(terms) > 1:
        terms = [terms[i] + terms[i + 1] if i + 1 < len(terms) else terms[i] for i in range(0, len(terms), 2)]
    return terms[0]

class Gen3LaneTX(LiteXModule):
    """Blocks to the transceiver's 40-bit words: Sync Header, scrambling (4.2.2.4), DC Balance (4.2.4.1).
    TS: Symbol 0 not scrambled, Symbols 1 to 13 scrambled, Symbols 14/15 scrambled or replaced by a DC Balance
    Symbol. EIEOS, EIOS, SDS: not scrambled, EIEOS reinitializes the LFSR after it. SKP: not scrambled, the
    LFSR doesn't advance. Data: scrambled. Pipelined (timing at 200 MHz): the Block registered, then scrambled
    with the counts of 1s of the DC Balance, then taken by the gearbox (sink.ready the same on all the lanes)."""
    def __init__(self, seed):
        self.sink  = sink = stream.Endpoint(block_layout())
        self.data  = Signal(40) # o
        self.reset_balance = Signal() # i: exit from Electrical Idle.

        # # #

        self.gearbox   = gearbox   = TXBlockGearbox()
        self.scrambler = scrambler = Gen3Scrambler(seed, nsymbols=16)

        # Stage 0: Block.
        v0 = Signal()
        k0 = Signal(3)
        d0 = Signal(128)
        # Stage 1: scrambled Block.
        v1   = Signal()
        ts1  = Signal()
        hdr1 = Signal(2)
        scr1 = Signal(128)
        # Stage 2: what the DC Balance needs: thresholds on the running balance for the 4 decisions (from the
        # 1s to Symbol 11), the balance change of the 5 possible Blocks.
        v2    = Signal()
        ts2   = Signal()
        hdr2  = Signal(2)
        scr2  = Signal(128)
        thr   = [Signal((10, True)) for _ in range(4)]
        delta = [Signal((10, True)) for _ in range(5)]
        take3 = Signal()
        take2 = Signal()
        take1 = Signal()
        self.comb += [
            take3.eq(gearbox.ready & v2),
            take2.eq(v1 & (~v2 | take3)),
            take1.eq(v0 & (~v1 | take2)),
            sink.ready.eq(~v0 | take1),
        ]
        self.sync += [
            If(sink.valid & sink.ready,
                v0.eq(1),
                k0.eq(sink.kind),
                d0.eq(sink.data),
            ).Elif(take1,
                v0.eq(0)
            )
        ]

        payload = Signal(128)
        bypass  = Signal(16)
        self.comb += [
            Case(k0, {
                BLOCK_DATA:  [payload.eq(d0), bypass.eq(0)],
                BLOCK_TS:    [payload.eq(d0), bypass.eq(0b0000000000000001)],
                BLOCK_EIEOS: [payload.eq(EIEOS_PAYLOAD), bypass.eq(0xffff)],
                BLOCK_EIOS:  [payload.eq(Replicate(Constant(OS_EIOS, 8), 16)), bypass.eq(0xffff)],
                BLOCK_SDS:   [payload.eq(Cat(Constant(OS_SDS, 8), Replicate(Constant(SDS_BODY, 8), 15))), bypass.eq(0xffff)],
                # 12 SKP Symbols, SKP_END, then 3 Symbols: the LFSR value (the Data Parity bit isn't kept).
                BLOCK_SKP:   [payload.eq(Cat(Replicate(Constant(OS_SKP, 8), 12), Constant(SKP_END, 8), Constant(0, 24))),
                              bypass.eq(0xffff)],
            }),
            scrambler.data_in.eq(payload),
            scrambler.bypass.eq(bypass),
            scrambler.advance.eq(k0 != BLOCK_SKP),
            scrambler.ce.eq(take1),
            scrambler.init.eq(take1 & (k0 == BLOCK_EIEOS)),
        ]
        self.sync += [
            If(take1,
                v1.eq(1),
                ts1.eq(k0 == BLOCK_TS),
                hdr1.eq(Mux(k0 == BLOCK_DATA, SYNC_DATA, SYNC_OS)),
                scr1.eq(scrambler.data_out),
            ).Elif(take2,
                v1.eq(0)
            )
        ]

        # Balance after Symbol 11: balance + 2*ones96 - 98, decisions at > 31, < -31, > 15, < -15: thresholds on
        # the balance. Balance change of a Block: 2*ones - 130, ones = ones112 + ones of Symbols 14/15 (as
        # scrambled, 0x20/0x08, 0xdf/0xf7, Symbol 14 with 0x08 or 0xf7).
        ones96  = Signal(8)
        ones112 = Signal(8)
        ones14  = Signal(4)
        ones15  = Signal(4)
        self.comb += [
            ones96.eq(popcount(Cat(hdr1, scr1[0:96]))),
            ones112.eq(popcount(Cat(hdr1, scr1[0:112]))),
            ones14.eq(popcount(scr1[112:120])),
            ones15.eq(popcount(scr1[120:128])),
        ]
        self.sync += [
            If(take2,
                v2.eq(1),
                ts2.eq(ts1),
                hdr2.eq(hdr1),
                scr2.eq(scr1),
                thr[0].eq(31 + 98 - 2*ones96),  # balance > thr[0]: fewer 1s.
                thr[1].eq(-31 + 98 - 2*ones96), # balance < thr[1]: fewer 0s.
                thr[2].eq(15 + 98 - 2*ones96),
                thr[3].eq(-15 + 98 - 2*ones96),
                delta[0].eq(2*(ones112 + ones14 + ones15) - 130),
                delta[1].eq(2*(ones112 + 2) - 130),
                delta[2].eq(2*(ones112 + 14) - 130),
                delta[3].eq(2*(ones112 + ones14 + 1) - 130),
                delta[4].eq(2*(ones112 + ones14 + 7) - 130),
            ).Elif(take3,
                v2.eq(0)
            )
        ]

        # Stage 3: DC Balance decision with the running balance, Block to the gearbox.
        balance = Signal((10, True))
        choice  = Signal(3)
        s14 = Signal(8)
        s15 = Signal(8)
        self.comb += [
            choice.eq(0),
            If(ts2,
                If(balance > thr[0],
                    choice.eq(1)
                ).Elif(balance < thr[1],
                    choice.eq(2)
                ).Elif(balance > thr[2],
                    choice.eq(3)
                ).Elif(balance < thr[3],
                    choice.eq(4)
                )
            ),
            s14.eq(scr2[112:120]),
            s15.eq(scr2[120:128]),
            Case(choice, {
                1: [s14.eq(0x20), s15.eq(0x08)], # Fewer 1s.
                2: [s14.eq(0xdf), s15.eq(0xf7)], # Fewer 0s.
                3: s15.eq(0x08),
                4: s15.eq(0xf7),
            }),
            gearbox.sync_header.eq(hdr2),
            gearbox.block.eq(Cat(scr2[:112], s14, s15)),
            self.data.eq(gearbox.data),
        ]
        self.sync += If(self.reset_balance,
            balance.eq(0)
        ).Elif(take3,
            balance.eq(balance + Array(delta)[choice])
        )

# Lane RX ------------------------------------------------------------------------------------------

class Gen3LaneRX(LiteXModule):
    """Transceiver's 40-bit words to descrambled Blocks: alignment on EIEOS, descrambling with the rules of the
    Ordered Sets from their Symbol 0 (not scrambled). source: Blocks with their kind; TS Blocks with Symbols 14
    and 15 as received (identifier or DC Balance Symbol). Undefined Sync Headers and unknown Ordered Sets: error."""
    def __init__(self, seed):
        self.data    = Signal(40) # i
        self.locked  = Signal()   # i: Block alignment kept (Data Stream).
        self.source  = source = stream.Endpoint(block_layout())
        self.aligned = Signal()   # o
        self.error   = Signal()   # o (Pulse)

        # # #

        self.gearbox     = gearbox     = RXBlockGearbox()
        self.aligner     = aligner     = BlockAligner(gearbox)
        self.descrambler = descrambler = Gen3Scrambler(seed, nsymbols=16)
        header = gearbox.sync_header
        block  = gearbox.block
        s0     = block[0:8]
        kind   = Signal(3)
        known  = Signal()
        bypass = Signal(16)
        self.comb += [
            gearbox.data.eq(self.data),
            aligner.locked.eq(self.locked),
            self.aligned.eq(aligner.aligned),
            known.eq(1),
            If(header == SYNC_DATA,
                kind.eq(BLOCK_DATA), bypass.eq(0),
            ).Elif(header == SYNC_OS,
                bypass.eq(0xffff),
                If((s0 == 0x1e) | (s0 == 0x2d),
                    kind.eq(BLOCK_TS), bypass.eq(0b1100000000000001),
                ).Elif(block == EIEOS_PAYLOAD,
                    kind.eq(BLOCK_EIEOS),
                ).Elif(s0 == OS_EIOS,
                    kind.eq(BLOCK_EIOS),
                ).Elif(s0 == OS_SDS,
                    kind.eq(BLOCK_SDS),
                ).Elif(s0 == OS_SKP,
                    kind.eq(BLOCK_SKP),
                ).Else(
                    known.eq(0)
                )
            ).Else(
                known.eq(0)
            ),
            descrambler.data_in.eq(block),
            descrambler.bypass.eq(bypass),
            descrambler.advance.eq(kind != BLOCK_SKP),
            descrambler.ce.eq(gearbox.valid & aligner.aligned),
            descrambler.init.eq(aligner.eieos),
        ]
        self.sync += [
            source.valid.eq(gearbox.valid & aligner.aligned & known),
            source.kind.eq(kind),
            source.data.eq(descrambler.data_out),
            self.error.eq(gearbox.valid & aligner.aligned & ~known),
        ]

# Link Blocks --------------------------------------------------------------------------------------

def _stream_symbol(beats, nlanes, h, k):
    """Symbol k of half h of a Block of the Data Stream (8*nlanes Symbols per half)."""
    return beats[h][8*k:8*(k+1)]

class Gen3LinkTX(LiteXModule):
    """Data Stream and Ordered Sets to the Blocks of the lanes (4.2.2.3), ndw = 2*nlanes DWs per beat: a Data
    Block on all the lanes is 2 beats, Symbol k of the Data Stream on Lane k mod nlanes. Out of the Data Stream:
    an EIEOS then Training Sequences (lane numbers from `lane`), an EIEOS every eieos_interval. data_enable: SDS
    then the Data Stream, a SKP Ordered Set every skp_interval Blocks (EDS Token in the last DW of the Data
    Block before it, placed between packets). Leaving the Data Stream: EDS then the Ordered Sets."""
    def __init__(self, nlanes, skp_interval=370, eieos_interval=32):
        ndw = 2*nlanes
        self.sink        = sink = stream.Endpoint([("data", 32*ndw)])
        self.idle        = Signal(reset=1) # i: the framer is between packets (EDS can be placed).
        self.blocks      = [stream.Endpoint(block_layout()) for _ in range(nlanes)]
        self.data_enable = Signal()        # i
        self.ts          = Record(ts3_layout()) # i
        self.lane_pad    = Signal(nlanes)  # i: Lane Number PAD per lane.
        self.lane_eq     = [Record(ts3_layout()) for _ in range(nlanes)] # i: equalization fields per lane...
        self.lane_eq_enable = Signal()     # i: ...used instead of the ones of ts.
        self.eios        = Signal()        # i (Level): send EIOS (then the lanes go to Electrical Idle).

        # # #

        take = self.blocks[0].ready # All the lanes take their Block at the same time.

        # Two beats buffered: a Data Block.
        beats  = [Signal(32*ndw) for _ in range(2)]
        filled = Signal(2)
        eds    = Signal() # The buffered Block is IDL then EDS.
        skp_count = Signal(max=skp_interval + 1)
        skp_due   = skp_count >= skp_interval
        in_stream = Signal()
        leaving   = Signal()
        self.comb += leaving.eq(in_stream & ~self.data_enable)

        # Training Sequences per lane.
        ts_data = []
        for i in range(nlanes):
            ts = Record(ts3_layout())
            self.comb += [ts.eq(self.ts), ts.lane.eq(i), ts.lane_pad.eq(self.ts.lane_pad | self.lane_pad[i])]
            self.comb += If(self.lane_eq_enable, *[getattr(ts, f).eq(getattr(self.lane_eq[i], f))
                for f in ["eq_ctrl", "pre", "cur", "post", "reject"]])
            ts_data.append(Cat(*ts3_symbols(ts)))

        # Fill: from the framer, or IDL/EDS when a SKP is due (or the Data Stream ends) between packets.
        idl_eds = Cat(Constant(0, 32*ndw - 32), Constant(int.from_bytes(EDS_TOKEN, "little"), 32))
        self.comb += sink.ready.eq(in_stream & (filled != 2) & ~eds & ~((filled == 0) & (skp_due | leaving) & self.idle))
        self.sync += [
            If(in_stream & (filled == 0) & (skp_due | leaving) & self.idle & ~eds,
                beats[0].eq(0),
                beats[1].eq(idl_eds),
                filled.eq(2),
                eds.eq(1),
            ).Elif(sink.valid & sink.ready,
                If(filled == 0, beats[0].eq(sink.data)).Else(beats[1].eq(sink.data)),
                filled.eq(filled + 1),
            )
        ]

        # Blocks.
        os_count  = Signal(max=eieos_interval + 1, reset=eieos_interval)
        sds_sent  = Signal()
        after_eds = Signal()
        kind      = Signal(3)
        for i, block in enumerate(self.blocks):
            data = Cat(*[beats[p//8][8*((p % 8)*nlanes + i):8*((p % 8)*nlanes + i + 1)] for p in range(16)])
            self.comb += [
                block.valid.eq(1),
                block.kind.eq(kind),
                # Data Block without its two beats (the framer late): IDL Tokens, the packets aren't split.
                If(kind == BLOCK_TS, block.data.eq(ts_data[i])).Elif(filled == 2, block.data.eq(data)).Else(block.data.eq(0)),
            ]
        self.comb += [
            If(self.eios & ~in_stream,
                kind.eq(BLOCK_EIOS)
            ).Elif(after_eds,
                kind.eq(Mux(self.data_enable, BLOCK_SKP, BLOCK_EIEOS))
            ).Elif(in_stream | self.data_enable,
                # SDS as soon as the Data Stream is enabled (no Training Sequence with fields of the next state).
                If(~sds_sent,
                    kind.eq(BLOCK_SDS)
                ).Else(
                    kind.eq(BLOCK_DATA)
                )
            ).Elif(os_count == eieos_interval,
                kind.eq(BLOCK_EIEOS)
            ).Else(
                kind.eq(BLOCK_TS)
            )
        ]
        # A Data Block takes its two beats, the framer keeps ahead at 2 beats per Block (else IDL Tokens).
        self.sync += If(take,
            If(after_eds,
                after_eds.eq(0),
                skp_count.eq(0),
                If(~self.data_enable, in_stream.eq(0), sds_sent.eq(0), os_count.eq(eieos_interval)),
            ).Elif(in_stream,
                If(~sds_sent,
                    sds_sent.eq(1)
                ).Elif(filled == 2,
                    filled.eq(0),
                    If(eds,
                        eds.eq(0),
                        after_eds.eq(1),
                    ).Else(
                        skp_count.eq(skp_count + 1)
                    )
                )
            ).Elif(kind == BLOCK_SDS,
                in_stream.eq(1),
                sds_sent.eq(1),
                skp_count.eq(0),
            ).Else(
                If(kind == BLOCK_EIEOS, os_count.eq(0)).Elif(os_count != eieos_interval, os_count.eq(os_count + 1)),
            )
        )

class Gen3LinkRX(LiteXModule):
    """Blocks of the lanes to the Data Stream (2 beats per Data Block) and the Training Sequences of each lane.
    Lanes aligned on an EIEOS received on all of them, the kinds then have to match on every Block (else not
    locked anymore). SKP Ordered Sets dropped."""
    def __init__(self, nlanes, depth=64):
        ndw = 2*nlanes
        self.blocks  = [stream.Endpoint(block_layout()) for _ in range(nlanes)]
        self.source  = source = stream.Endpoint([("data", 32*ndw)])
        self.ts_valid = Signal()       # o (Pulse): TS Blocks on all the lanes.
        self.ts_data  = Signal(128*nlanes) # o
        self.eios     = Signal()       # o (Pulse)
        self.sds      = Signal()       # o (Pulse)
        self.locked   = Signal()       # o
        self.error    = Signal()       # o (Pulse)

        # # #

        fifos = []
        for block in self.blocks:
            fifo = stream.SyncFIFO(block_layout(), depth, buffered=True)
            self.submodules += fifo
            self.comb += block.connect(fifo.sink)
            fifos.append(fifo)
        heads   = [fifo.source for fifo in fifos]
        all_v   = Reduce("AND", [h.valid for h in heads])
        all_eie = Reduce("AND", [h.kind == BLOCK_EIEOS for h in heads])
        same    = Signal()
        self.comb += same.eq(Reduce("AND", [h.kind == heads[0].kind for h in heads[1:]]) if nlanes > 1 else 1)
        kind    = heads[0].kind
        half    = Signal() # Second beat of a Data Block pending.
        pop     = Signal()
        self.comb += pop.eq(all_v & ~half & (~source.valid | source.ready))
        # A lane whose FIFO is deeper than another's by more than a Block has older Blocks (its receiver
        # aligned first): its EIEOS isn't the one of the others, it goes to its next one.
        # Registered (timing): only used before the lanes are aligned.
        drops = []
        for i, fifo in enumerate(fifos):
            drop = Signal()
            self.sync += drop.eq(Reduce("OR", [fifo.level > other.level + 1 for other in fifos if other is not fifo]) if nlanes > 1 else 0)
            drops.append(drop)
        any_drop = Signal()
        self.comb += any_drop.eq(Reduce("OR", drops))
        for i, h in enumerate(heads):
            self.comb += If(self.locked,
                h.ready.eq(pop)
            ).Else(
                h.ready.eq(h.valid & ((h.kind != BLOCK_EIEOS) | drops[i] | (all_v & all_eie & ~any_drop)))
            )
        # Data Stream beats: half 0 from Symbols 0-7 of the lanes, half 1 from 8-15.
        block_data = [h.data for h in heads]
        second = Signal(32*ndw)
        def beat(h):
            return Cat(*[block_data[k % nlanes][8*(8*h + k//nlanes):8*(8*h + k//nlanes + 1)] for k in range(8*nlanes)])
        self.sync += [
            If(source.valid & source.ready, source.valid.eq(0)),
            self.ts_valid.eq(0),
            self.eios.eq(0),
            self.sds.eq(0),
            self.error.eq(0),
            If(half & (~source.valid | source.ready),
                source.valid.eq(1),
                source.data.eq(second),
                half.eq(0),
            ),
            If(~self.locked,
                If(all_v & all_eie & ~any_drop, self.locked.eq(1))
            ).Elif(pop,
                If(~same,
                    self.locked.eq(0),
                    self.error.eq(1),
                ).Elif(kind == BLOCK_DATA,
                    source.valid.eq(1),
                    source.data.eq(beat(0)),
                    second.eq(beat(1)),
                    half.eq(1),
                ).Elif(kind == BLOCK_TS,
                    self.ts_valid.eq(1),
                    self.ts_data.eq(Cat(*block_data)),
                ).Elif(kind == BLOCK_EIOS,
                    self.eios.eq(1),
                ).Elif(kind == BLOCK_SDS,
                    self.sds.eq(1),
                )
            )
        ]

# Training Sequence fields -------------------------------------------------------------------------

def ts3_fields(data, ts):
    """Statements decoding the 16 received Symbols of a Training Sequence (descrambled, data: Symbol 0 in
    the LSBs) into ts (ts3_layout())."""
    s = [data[8*k:8*(k+1)] for k in range(16)]
    return [
        ts.ts2.eq(s[0] == OS_TS2),
        ts.link.eq(s[1]),
        ts.link_pad.eq(s[1] == GEN3_PAD),
        ts.lane.eq(s[2][:5]),
        ts.lane_pad.eq(s[2] == GEN3_PAD),
        ts.n_fts.eq(s[3]),
        ts.rate.eq(s[4]),
        ts.ctrl.eq(s[5]),
        ts.eq_ctrl.eq(s[6]),
        ts.pre.eq(s[7][:6]),
        ts.cur.eq(s[8][:6]),
        ts.post.eq(s[9][:6]),
        ts.reject.eq(s[9][6] & (s[0] == OS_TS1)),
    ]

# Lane Equalization --------------------------------------------------------------------------------

# Presets (4.2.3.2, Table 4-17) as Pre-cursor/Post-cursor Coefficients for a Full Swing of 40 (P10: the
# boost limit, (FS - LF)/2).
GEN3_FS = 40
GEN3_LF = 15
GEN3_PRESETS = {0: (0, 10), 1: (0, 7), 2: (0, 8), 3: (0, 5), 4: (0, 0), 5: (4, 0), 6: (5, 0), 7: (4, 8),
    8: (5, 5), 9: (7, 0), 10: (0, (GEN3_FS - GEN3_LF)//2)}

class Gen3LaneEQ(LiteXModule):
    """Transmitter equalization of a lane (4.2.3, 4.2.6.4.2): the Transmitter settings (Coefficients for a Full
    Swing of fs) and the equalization fields of the transmitted TS1, from the phase (EC transmitted) and the
    Training Sequences received on the lane.

    - load (Pulse): preset from the EQ TS2 received (eq_ts2: Symbol 6, bit 7 set), reserved or no EQ TS2:
      reject set, P4 used.
    - EC 01b: FS, LF and the Post-cursor in the Coefficient fields.
    - Responding phase (upstream: EC 11b, downstream: EC 10b): two identical consecutive requests (TS1 with the
      EC) are evaluated, a legal preset or Coefficients are applied and reflected, else rejected (reject set,
      the request reflected).
    - Requesting phase (upstream: EC 10b, downstream: EC 11b): request_preset (bit 4: use it, bits 3:0) or the
      partner's current Coefficients (no change), eval_done once reflected by two consecutive TS1."""
    def __init__(self, upstream=True, fs=GEN3_FS, lf=GEN3_LF):
        self.ec        = Signal(2) # i: EC transmitted.
        self.load      = Signal()  # i (Pulse)
        self.eq_ts2    = Signal(8) # i
        self.rx_valid  = Signal()  # i (Pulse): TS received...
        self.rx        = Record(ts3_layout()) # i: ...with its fields.
        self.request_preset = Signal(5) # i
        self.tx        = Record(ts3_layout()) # o: eq_ctrl, pre, cur, post, reject.
        self.preset    = Signal(4) # o: current preset (when applied by a preset).
        self.c_pre     = Signal(6) # o: current Coefficients.
        self.c_cur     = Signal(6) # o
        self.c_post    = Signal(6) # o
        self.eval_done = Signal()  # o
        self.accepted  = Signal()  # o: request accepted (with eval_done).

        # # #

        responding = Signal()
        requesting = Signal()
        self.comb += [
            responding.eq(self.ec == (0b11 if upstream else 0b10)),
            requesting.eq(self.ec == (0b10 if upstream else 0b11)),
        ]

        # Preset table lookups.
        def preset_coeffs(preset, pre, post):
            return Case(preset, {**{p: [pre.eq(c[0]), post.eq(c[1])] for p, c in GEN3_PRESETS.items()},
                "default": [pre.eq(0), post.eq(0)]})
        legal_preset = lambda preset: preset <= 10

        # Received request (TS1 with our EC), two identical consecutive ones.
        rx_ec   = self.rx.eq_ctrl[0:2]
        rx_use  = self.rx.eq_ctrl[7]
        rx_pre  = self.rx.eq_ctrl[3:7]
        req     = Signal(1 + 4 + 18) # use_preset, preset, Coefficients.
        req_new = Signal(len(req))
        req_cnt = Signal(2)
        handled = Signal()
        self.comb += req_new.eq(Cat(rx_use, Mux(rx_use, rx_pre, 0), Mux(rx_use, 0, Cat(self.rx.pre, self.rx.cur, self.rx.post))))
        ec_r    = Signal(2)
        self.sync += ec_r.eq(self.ec)

        # Current settings and reflected fields.
        tx_preset = Signal(4) # Transmitter Preset field.
        tx_reject = Signal()
        refl_pre  = Signal(6) # Coefficient fields (current settings or a rejected request).
        refl_cur  = Signal(6)
        refl_post = Signal(6)
        refl_req  = Signal()  # Reflect a rejected Coefficients request.
        p_pre     = Signal(6)
        p_post    = Signal(6)
        e_pre     = Signal(6) # Preset of the EQ TS2.
        e_post    = Signal(6)
        self.comb += [
            preset_coeffs(self.eq_ts2[3:7], e_pre, e_post),
            preset_coeffs(req[1:5], p_pre, p_post),
            self.c_cur.eq(fs - self.c_pre - self.c_post),
        ]
        c_req_pre  = req[5:11]
        c_req_cur  = req[11:17]
        c_req_post = req[17:23]
        legal_coeffs = Signal()
        self.comb += legal_coeffs.eq((c_req_pre + c_req_cur + c_req_post == fs) & (c_req_pre <= fs//4) &
            (c_req_cur >= lf + c_req_pre + c_req_post))
        self.sync += [
            If(self.load,
                If(self.eq_ts2[7] & legal_preset(self.eq_ts2[3:7]),
                    self.preset.eq(self.eq_ts2[3:7]),
                    tx_preset.eq(self.eq_ts2[3:7]),
                    self.c_pre.eq(e_pre),
                    self.c_post.eq(e_post),
                    tx_reject.eq(0),
                ).Else(
                    # Reserved preset (reflected) or no EQ TS2 (Fh): implementation preset P4.
                    self.preset.eq(4),
                    tx_preset.eq(Mux(self.eq_ts2[7], self.eq_ts2[3:7], 0xf)),
                    self.c_pre.eq(0),
                    self.c_post.eq(0),
                    tx_reject.eq(1),
                ),
                refl_req.eq(0),
            ),
            # Requests: restarted on a phase change.
            If(self.ec != ec_r,
                req_cnt.eq(0),
                handled.eq(0),
                If(responding | requesting, tx_reject.eq(0)),
            ).Elif(self.rx_valid & ~self.rx.ts2 & (rx_ec == self.ec),
                req.eq(req_new),
                If((req_cnt != 0) & (req_new == req),
                    If(req_cnt != 3, req_cnt.eq(req_cnt + 1)),
                ).Else(
                    req_cnt.eq(1),
                    handled.eq(0),
                )
            ),
            # Responding: evaluation of a request received twice.
            If(responding & (req_cnt >= 2) & ~handled,
                handled.eq(1),
                If(req[0],
                    tx_preset.eq(req[1:5]),
                    refl_req.eq(0),
                    If(legal_preset(req[1:5]),
                        self.preset.eq(req[1:5]),
                        self.c_pre.eq(p_pre),
                        self.c_post.eq(p_post),
                        tx_reject.eq(0),
                    ).Else(
                        tx_reject.eq(1),
                    )
                ).Else(
                    If(legal_coeffs,
                        self.c_pre.eq(c_req_pre),
                        self.c_post.eq(c_req_post),
                        tx_reject.eq(0),
                        refl_req.eq(0),
                    ).Else(
                        tx_reject.eq(1),
                        refl_req.eq(1),
                        refl_pre.eq(c_req_pre),
                        refl_cur.eq(c_req_cur),
                        refl_post.eq(c_req_post),
                    )
                )
            ),
        ]

        # Requesting: the request (on entry, keeping the partner's Coefficients: the ones of the last TS1
        # received, which made the phase change), done when reflected by two consecutive TS1.
        my_req_use  = Signal()
        my_req_pre  = Signal(4)
        my_req_c    = Signal(18)
        last_rx_c   = Signal(18)
        refl_cnt    = Signal(2)
        reflected   = Signal()
        self.comb += reflected.eq(Mux(my_req_use, rx_pre == my_req_pre,
            Cat(self.rx.pre, self.rx.cur, self.rx.post) == my_req_c))
        self.sync += [
            If(self.rx_valid & ~self.rx.ts2, last_rx_c.eq(Cat(self.rx.pre, self.rx.cur, self.rx.post))),
            If(~requesting | (self.ec != ec_r),
                my_req_use.eq(self.request_preset[4]),
                my_req_pre.eq(self.request_preset[0:4]),
                my_req_c.eq(last_rx_c),
                refl_cnt.eq(0),
                self.eval_done.eq(0),
            ).Elif(self.rx_valid & ~self.rx.ts2 & (rx_ec == self.ec),
                If(reflected,
                    If(refl_cnt != 3, refl_cnt.eq(refl_cnt + 1)),
                    If(refl_cnt >= 1,
                        self.eval_done.eq(1),
                        self.accepted.eq(~self.rx.reject),
                    )
                ).Else(
                    refl_cnt.eq(0)
                )
            )
        ]

        # Transmitted fields.
        self.comb += [
            self.tx.eq_ctrl.eq(Cat(self.ec, Constant(0, 1), tx_preset, Constant(0, 1))),
            self.tx.pre.eq(Mux(refl_req & responding, refl_pre, self.c_pre)),
            self.tx.cur.eq(Mux(refl_req & responding, refl_cur, self.c_cur)),
            self.tx.post.eq(Mux(refl_req & responding, refl_post, self.c_post)),
            self.tx.reject.eq(tx_reject),
            If(self.ec == 0b01,
                self.tx.pre.eq(fs),
                self.tx.cur.eq(lf),
                self.tx.reject.eq(0),
            ),
            If(requesting,
                self.tx.eq_ctrl.eq(Cat(self.ec, Constant(0, 1), Mux(my_req_use, my_req_pre, self.preset), my_req_use)),
                self.tx.pre.eq(my_req_c[0:6]),
                self.tx.cur.eq(my_req_c[6:12]),
                self.tx.post.eq(my_req_c[12:18]),
                self.tx.reject.eq(0),
            ),
        ]
