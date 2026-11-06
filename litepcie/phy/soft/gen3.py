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

class Gen3RXFramer(LiteXModule):
    """Data Stream of the Data Blocks to TLP beats and DLLPs, ndw DWs per cycle, same interface as
    WideRXFramer. There are no K Symbols: the Tokens give the location of the next one. Tokens are on a DW
    from x4 on, this framer doesn't handle the other positions possible at x1 and x2 after IDL Tokens."""
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

        # The word processed is the previous one, slot 0 of the current one tells if an EDB follows.
        prev_valid = Signal()
        prev_data  = Signal(32*ndw)
        process    = Signal()
        self.comb += process.eq(prev_valid & sink.valid)
        self.sync += If(sink.valid,
            prev_valid.eq(1),
            prev_data.eq(sink.data),
        )
        slots = [prev_data[32*i:32*(i+1)] for i in range(ndw)] + [sink.data[0:32]]
        edb   = [slots[i] == 0xc0c0c0c0 for i in range(ndw + 1)]

        # A Token at a slot sets what the next slots are: TLP DWs (remaining counter) or the end of a
        # DLLP. The counter is decremented by the whole beat when the TLP goes past it.
        remaining  = Signal(11)
        dllp_tail  = Signal()
        skip_edb   = Signal()
        remaining_c, dllp_c, skip_c = remaining, dllp_tail, skip_edb
        tlp_v  = [Signal() for _ in range(ndw)]
        tlp_f  = [Signal() for _ in range(ndw)]
        tlp_l  = [Signal() for _ in range(ndw)]
        dllp_v = [Signal() for _ in range(ndw)]
        errors = [Signal() for _ in range(ndw)]
        seqs   = [Signal(12) for _ in range(ndw)]
        seq_c  = Signal(12)
        seq_r  = seq_c
        first_c = Signal()
        first_r = first_c
        for i in range(ndw):
            slot = slots[i]
            s0   = slot[0:8]
            is_stp = s0[0:4] == 0xf
            is_sdp = slot[0:16] == 0xacf0
            is_eds = slot == 0x0090801f
            is_idl = s0 == 0
            length = Cat(slot[4:8], slot[8:15])
            fcrc, parity = _stp_check(length)
            stp_ok = (slot[20:24] == fcrc) & (slot[15] == parity) & (length >= 5)
            remaining_n = Signal(11)
            dllp_n      = Signal()
            skip_n      = Signal()
            seq_n       = Signal(12)
            first_n     = Signal()
            self.comb += [
                remaining_n.eq(remaining_c),
                dllp_n.eq(0),
                skip_n.eq(0),
                seq_n.eq(seq_c),
                first_n.eq(first_c),
                seqs[i].eq(seq_c),
                If(remaining_c != 0,
                    tlp_v[i].eq(1),
                    tlp_f[i].eq(first_c),
                    first_n.eq(0),
                    tlp_l[i].eq(remaining_c == 1),
                    remaining_n.eq(remaining_c - 1),
                    # An EDB confirms a nullified TLP, it follows the last DW.
                    skip_n.eq((remaining_c == 1) & edb[i + 1]),
                ).Elif(dllp_c,
                    # Second DW of the DLLP.
                ).Elif(skip_c,
                    # EDB Token.
                ).Elif(is_eds,
                    # Next Block is an Ordered Set Block, the Data Stream resumes after it.
                ).Elif(is_stp,
                    If(stp_ok,
                        remaining_n.eq(length - 1),
                        seq_n.eq(Cat(slot[24:32], slot[16:20])),
                        first_n.eq(1),
                    ).Else(
                        errors[i].eq(1)
                    )
                ).Elif(is_sdp,
                    dllp_v[i].eq(1),
                    dllp_n.eq(1),
                ).Elif(~is_idl,
                    errors[i].eq(1)
                )
            ]
            remaining_c, dllp_c, skip_c, seq_c, first_c = remaining_n, dllp_n, skip_n, seq_n, first_n
        self.sync += If(process,
            remaining.eq(remaining_c),
            dllp_tail.eq(dllp_c),
            skip_edb.eq(skip_c),
            seq_r.eq(seq_c),
            first_r.eq(first_c),
        )

        # DLLPs: 2 bytes in the Token's DW, 4 in the next one. Queued, one per cycle.
        dllps = Array(Signal(48) for _ in range(8))
        wr, rd = Signal(3), Signal(3)
        wr_c = wr
        for i in range(ndw):
            wr_n = Signal(3)
            self.comb += wr_n.eq(wr_c + (process & dllp_v[i]))
            self.sync += If(process & dllp_v[i], dllps[wr_c].eq(Cat(slots[i][16:32], slots[i + 1])))
            wr_c = wr_n
        self.sync += [
            wr.eq(wr_c),
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
            fifo.sink.data.eq(prev_data),
            fifo.sink.seq.eq(Cat(*seqs)),
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
