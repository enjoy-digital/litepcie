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
    ident = Mux(ts.ts2, TS2_ID3, TS1_ID3)
    s7    = Mux(ts.ts2, TS2_ID3, Cat(ts.pre, Constant(0, 2)))
    s8    = Mux(ts.ts2, TS2_ID3, Cat(ts.cur, Constant(0, 2)))
    s9lo  = Cat(ts.post, ts.reject)
    parity = Reduce("XOR", [ts.eq_ctrl[i] for i in range(8)] + [ts.pre[i] for i in range(6)] +
        [ts.cur[i] for i in range(6)] + [s9lo[i] for i in range(7)])
    s9    = Mux(ts.ts2, TS2_ID3, Cat(s9lo, parity))
    return [
        Mux(ts.ts2, 0x2d, 0x1e),
        Mux(ts.link_pad, GEN3_PAD, ts.link),
        Mux(ts.lane_pad, GEN3_PAD, Cat(ts.lane, Constant(0, 3))),
        ts.n_fts, ts.rate, ts.ctrl, ts.eq_ctrl, s7, s8, s9,
    ] + [ident]*6

# Lane TX ------------------------------------------------------------------------------------------

BLOCK_DATA, BLOCK_TS, BLOCK_EIEOS, BLOCK_EIOS, BLOCK_SDS, BLOCK_SKP = range(6)

def block_layout():
    """Block to transmit: kind (BLOCK_*), the 16 Symbols (not scrambled) for Data and TS Blocks."""
    return [("kind", 3), ("data", 128)]

class Gen3LaneTX(LiteXModule):
    """Blocks to the transceiver's 40-bit words: Sync Header, scrambling (4.2.2.4), DC Balance (4.2.4.1).
    TS: Symbol 0 not scrambled, Symbols 1 to 13 scrambled, Symbols 14/15 scrambled or replaced by a DC Balance
    Symbol. EIEOS, EIOS, SDS: not scrambled, EIEOS reinitializes the LFSR after it. SKP: not scrambled, the
    LFSR doesn't advance. Data: scrambled. The Block is taken when sink.ready (it has to be there)."""
    def __init__(self, seed):
        self.sink  = sink = stream.Endpoint(block_layout())
        self.data  = Signal(40) # o
        self.reset_balance = Signal() # i: exit from Electrical Idle.

        # # #

        self.gearbox   = gearbox   = TXBlockGearbox()
        self.scrambler = scrambler = Gen3Scrambler(seed, nsymbols=16)
        kind = sink.kind
        is_ts = kind == BLOCK_TS
        is_data = kind == BLOCK_DATA
        payload = Signal(128)
        bypass  = Signal(16)
        self.comb += [
            Case(kind, {
                BLOCK_DATA:  [payload.eq(sink.data), bypass.eq(0)],
                BLOCK_TS:    [payload.eq(sink.data), bypass.eq(0b0000000000000001)],
                BLOCK_EIEOS: [payload.eq(EIEOS_PAYLOAD), bypass.eq(0xffff)],
                BLOCK_EIOS:  [payload.eq(Replicate(Constant(OS_EIOS, 8), 16)), bypass.eq(0xffff)],
                BLOCK_SDS:   [payload.eq(Cat(Constant(OS_SDS, 8), Replicate(Constant(SDS_BODY, 8), 15))), bypass.eq(0xffff)],
                # 12 SKP Symbols, SKP_END, then 3 Symbols: the LFSR value (the Data Parity bit isn't kept).
                BLOCK_SKP:   [payload.eq(Cat(Replicate(Constant(OS_SKP, 8), 12), Constant(SKP_END, 8), Constant(0, 24))),
                              bypass.eq(0xffff)],
            }),
            scrambler.data_in.eq(payload),
            scrambler.bypass.eq(bypass),
            scrambler.advance.eq(kind != BLOCK_SKP),
            scrambler.ce.eq(gearbox.ready & sink.valid),
            scrambler.init.eq(gearbox.ready & sink.valid & (kind == BLOCK_EIEOS)),
            sink.ready.eq(gearbox.ready),
            gearbox.sync_header.eq(Mux(is_data, SYNC_DATA, SYNC_OS)),
            self.data.eq(gearbox.data),
        ]

        # DC Balance: running difference of 1s and 0s on the lane, Symbols 14/15 of the TS replaced when it
        # is too large at the end of Symbol 11.
        balance  = Signal((10, True))
        scrambled = scrambler.data_out
        def ones(bits):
            return Reduce("ADD", [bits[i] for i in range(len(bits))])
        upto11 = Signal((10, True))
        self.comb += upto11.eq(balance + 2*ones(Cat(gearbox.sync_header, scrambled[0:96])) - (2 + 96))
        s14 = Signal(8)
        s15 = Signal(8)
        self.comb += [
            s14.eq(scrambled[112:120]),
            s15.eq(scrambled[120:128]),
            If(is_ts,
                If(upto11 > 31,
                    s14.eq(0x20), s15.eq(0x08)   # Fewer 1s.
                ).Elif(upto11 < -31,
                    s14.eq(0xdf), s15.eq(0xf7)   # Fewer 0s.
                ).Elif(upto11 > 15,
                    s15.eq(0x08)
                ).Elif(upto11 < -15,
                    s15.eq(0xf7)
                )
            ),
        ]
        block = Signal(128)
        self.comb += [
            block.eq(Cat(scrambled[:112], s14, s15)),
            gearbox.block.eq(block),
        ]
        self.sync += If(self.reset_balance,
            balance.eq(0)
        ).Elif(gearbox.ready & sink.valid,
            balance.eq(balance + 2*ones(Cat(gearbox.sync_header, block)) - 130)
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
                If(kind == BLOCK_TS, block.data.eq(ts_data[i])).Else(block.data.eq(data)),
            ]
        self.comb += [
            If(self.eios & ~in_stream,
                kind.eq(BLOCK_EIOS)
            ).Elif(after_eds,
                kind.eq(Mux(self.data_enable, BLOCK_SKP, BLOCK_EIEOS))
            ).Elif(in_stream,
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
        # A Data Block needs its two beats: the lanes wait (an Ordered Set or IDL would break the stream), at
        # 2 beats per Block the framer keeps ahead.
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
            ).Else(
                If(kind == BLOCK_EIEOS, os_count.eq(0)).Elif(os_count != eieos_interval, os_count.eq(os_count + 1)),
                If(self.data_enable, in_stream.eq(1), skp_count.eq(0)),
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
        drops = []
        for i, fifo in enumerate(fifos):
            drop = Signal()
            self.comb += drop.eq(Reduce("OR", [fifo.level > other.level + 1 for other in fifos if other is not fifo]) if nlanes > 1 else 0)
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
