#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY packet framing for wide links (PCIe Base 4.2.2), ndw DWs per cycle (x2 and above).

On links wider than x1 a packet starts on Lane 0 (Lane 4*N above x4) and is a multiple of 4 Symbols, so
all the packets start on a DW of the link stream at x4 and above. At x2 they can also start 2 Symbols
into a DW: RXPhaseAligner realigns them, only Logical Idle Symbols are lost or duplicated.

The K Symbols are only found at the packets' boundaries, so the DW slots of a beat are classified in
parallel instead of following the stream Symbol by Symbol as the x1 framers do.
"""

from migen import *

from litex.gen import *

from litex.soc.interconnect import stream

from litepcie.phy.soft.common import STP, SDP, END, EDB, PAD, lane_layout
from litepcie.phy.soft.dll.buffer       import PacketBuffer
from litepcie.phy.soft.dll.crc          import crc_next, crc_value, LCRC_POLYNOM, LCRC_INIT
from litepcie.phy.soft.dll.flow_control import tlp_credits
from litepcie.phy.soft.dll.retry        import ReplayBuffer

# Layouts ------------------------------------------------------------------------------------------

def tlp_beat_layout(ndw):
    """TLP beats: first DW of the TLP on data[0:32], byte 0 on bits 7:0 as on the lane. dws: valid DWs
    of the beat (ndw except on the last one)."""
    return [("data", 32*ndw), ("dws", bits_for(ndw)), ("seq", 12), ("edb", 1)]

# RX Phase Aligner ---------------------------------------------------------------------------------

class RXPhaseAlignerX1(LiteXModule):
    """x1: packets aligned on the DWs of the output. A packet can start on any Symbol. A word holds at most
    one packet start, and a packet being a multiple of 4 Symbols a change of phase only comes after Logical
    Idle: the Symbols before the start are dropped, it comes out at the start of a word."""
    def __init__(self):
        self.sink   = sink   = stream.Endpoint(lane_layout(4))
        self.source = source = stream.Endpoint(lane_layout(4))

        # # #

        self.comb += sink.ready.eq(1)
        phase = Signal(2)  # Symbols of the previous word to output first.
        carry = Signal(32, reset_less=True)
        cctrl = Signal(4,  reset_less=True)
        starts = [sink.ctrl[i] & ((sink.data[8*i:8*(i+1)] == STP.value) | (sink.data[8*i:8*(i+1)] == SDP.value)) for i in range(4)]
        k = Signal(2)
        self.comb += If(starts[0], k.eq(0)).Elif(starts[1], k.eq(1)).Elif(starts[2], k.eq(2)).Else(k.eq(3))
        has_start = Reduce("OR", starts)
        change    = Signal()
        self.comb += change.eq(has_start & (((phase + k) & 3) != 0))

        # Previous Symbols then the current ones: output without a change of phase.
        data_cases, ctrl_cases = {}, {}
        out_data = Signal(32)
        out_ctrl = Signal(4)
        for p in range(4):
            data_cases[p] = out_data.eq(Cat(carry[32 - 8*p:32], sink.data[:32 - 8*p]) if p else sink.data)
            ctrl_cases[p] = out_ctrl.eq(Cat(cctrl[4 - p:4], sink.ctrl[:4 - p]) if p else sink.ctrl)
        self.comb += [Case(phase, data_cases), Case(phase, ctrl_cases)]

        # On a change: the Symbols from the start on are kept for the next word, or come out now if it's the
        # first Symbol of the word; what comes before stays (end of a packet, Logical Idle).
        self.sync += [
            source.valid.eq(sink.valid),
            If(sink.valid,
                carry.eq(sink.data),
                cctrl.eq(sink.ctrl),
                If(change,
                    phase.eq(-k),
                    If(k == 0,
                        source.data.eq(sink.data),
                        source.ctrl.eq(sink.ctrl),
                    ).Else(
                        # The part of the output from the current word, before the start, is Logical Idle
                        # or the end of a packet: what is at or after the start isn't output.
                        source.data.eq(out_data),
                        source.ctrl.eq(out_ctrl),
                        self._blank(source, k, phase),
                    )
                ).Else(
                    source.data.eq(out_data),
                    source.ctrl.eq(out_ctrl),
                )
            )
        ]

    def _blank(self, source, k, phase):
        # Output positions holding Symbols at or after the start: Logical Idle.
        statements = []
        for p in range(4):
            for kk in range(1, 4):
                for position in range(4):
                    if position >= p + kk:
                        statements.append(If((phase == p) & (k == kk),
                            source.data[8*position:8*(position + 1)].eq(0),
                            source.ctrl[position].eq(0),
                        ))
        return If(1, *statements)

class RXPhaseAligner(LiteXModule):
    """x2: packets aligned on the DWs of the output. A beat has 4 Symbol times and holds at most one
    packet start (a packet is at least 4 Symbol times). When a start needs the other phase, a Symbol time
    is inserted or deleted right before it: there is at least one of Logical Idle there, since two
    packets following each other keep the same phase."""
    def __init__(self):
        self.sink   = sink   = stream.Endpoint(lane_layout(8))
        self.source = source = stream.Endpoint(lane_layout(8))

        # # #

        self.comb += sink.ready.eq(1)
        phase  = Signal()          # Symbol time delay.
        carry  = Signal(18, reset_less=True) # Last Symbol time of the previous beat, with its K flags.
        units  = [Cat(sink.data[16*i:16*(i+1)], sink.ctrl[2*i:2*(i+1)]) for i in range(4)]
        idle   = Constant(0, 18)
        starts = []
        for i in range(4):
            byte = sink.data[16*i:16*i + 8]
            starts.append(sink.ctrl[2*i] & ((byte == STP.value) | (byte == SDP.value)))
        out       = [Signal(18) for _ in range(4)]
        carry_n   = Signal(18)
        phase_n   = Signal()
        position  = Signal(2)
        has_start = Reduce("OR", starts)
        selection = If(starts[0], position.eq(0)).Elif(starts[1], position.eq(1)).Elif(starts[2], position.eq(2)).Else(position.eq(3))
        change    = Signal()
        self.comb += [
            selection,
            change.eq(has_start & (position[0] != phase)),
            phase_n.eq(Mux(change, ~phase, phase)),
        ]
        plain_0 = [units[0], units[1], units[2], units[3]]
        plain_1 = [carry, units[0], units[1], units[2]]
        # Phase 0 to 1: idle inserted before the start. Phase 1 to 0: Symbol time before it deleted.
        insert = {k: units[:k] + [idle] + units[k:3] for k in [1, 3]}
        delete = {
            0: [units[0], units[1], units[2], units[3]],
            2: [carry, units[0], units[2], units[3]],
        }
        cases = {}
        for k, values in list(insert.items()):
            cases[k] = [o.eq(v) for o, v in zip(out, values)]
        for k, values in list(delete.items()):
            cases[k] = [o.eq(v) for o, v in zip(out, values)]
        self.comb += If(change,
            Case(position, cases)
        ).Elif(phase,
            *[o.eq(v) for o, v in zip(out, plain_1)]
        ).Else(
            *[o.eq(v) for o, v in zip(out, plain_0)]
        )
        self.comb += carry_n.eq(units[3])
        self.sync += [
            source.valid.eq(sink.valid),
            If(sink.valid,
                phase.eq(phase_n),
                carry.eq(carry_n),
                source.data.eq(Cat(*[o[0:16] for o in out])),
                source.ctrl.eq(Cat(*[o[16:18] for o in out])),
            )
        ]

# RX Framer ----------------------------------------------------------------------------------------

class WideRXFramer(LiteXModule):
    """sink: lane words, packets starting on a DW. tlp: TLP beats starting on data[0:32] (TLP and LCRC,
    seq with first, edb with last). dllp/dllp_valid: received DLLPs, one per cycle. error pulses on
    framing errors; tlp_abort when a TLP already started is dropped."""
    def __init__(self, ndw, fifo_depth=64):
        assert ndw >= 2
        self.sink       = sink = stream.Endpoint(lane_layout(4*ndw))
        self.tlp        = tlp  = stream.Endpoint(tlp_beat_layout(ndw))
        self.dllp       = Signal(48) # o
        self.dllp_valid = Signal()   # o (Pulse)
        self.error      = Signal()   # o (Pulse)
        self.tlp_abort  = Signal()   # o (Pulse)

        # # #

        self.comb += sink.ready.eq(1)

        # K Symbols decoded on capture, the word processed is the previous one: the slot after its
        # last one (END of the packet, end of a DLLP) is in the current word.
        def flags(data, ctrl):
            byte = lambda i: data[8*i:8*(i+1)]
            is_k = lambda i, s: ctrl[i] & (byte(i) == s.value)
            is_pad = [is_k(i, PAD) for i in range(4)]
            return dict(
                stp = is_k(0, STP),
                sdp = is_k(0, SDP),
                end = is_k(3, END),
                edb = is_k(3, EDB),
                # Any other K Symbol than a whole PAD slot is a framing error.
                bad = (ctrl[1] & ~is_pad[1]) | (ctrl[2] & ~is_pad[2]) | (ctrl[0] & ~is_k(0, STP) & ~is_k(0, SDP) & ~is_pad[0]) |
                      (ctrl[3] & ~is_k(3, END) & ~is_k(3, EDB) & ~is_pad[3]),
            )
        prev_valid = Signal()
        prev_data  = Signal(32*ndw)
        cur        = [{k: Signal() for k in ["stp", "sdp", "end", "edb", "bad"]} for _ in range(ndw)]
        process    = Signal()
        self.comb += process.eq(prev_valid & sink.valid)
        decoded = [flags(sink.data[32*i:32*(i+1)], sink.ctrl[4*i:4*(i+1)]) for i in range(ndw)]
        self.sync += If(sink.valid,
            prev_valid.eq(1),
            prev_data.eq(sink.data),
            *[cur[i][k].eq(decoded[i][k]) for i in range(ndw) for k in cur[i]]
        )
        next_slot = decoded[0]
        slots = [prev_data[32*i:32*(i+1)] for i in range(ndw)] + [sink.data[0:32]]
        ends  = [cur[i]["end"] for i in range(ndw)] + [next_slot["end"]]
        edbs  = [cur[i]["edb"] for i in range(ndw)] + [next_slot["edb"]]

        # Slots classification.
        IDLE, TLP, DLLP = range(3)
        state    = Signal(2)
        state_c  = state
        tlp_v    = [Signal() for _ in range(ndw)] # Slot i starts a DW of the TLP.
        tlp_f    = [Signal() for _ in range(ndw)]
        tlp_l    = [Signal() for _ in range(ndw)]
        dllp_v   = [Signal() for _ in range(ndw)]
        errors   = [Signal() for _ in range(ndw)]
        aborts   = [Signal() for _ in range(ndw)]
        for i in range(ndw):
            state_n = Signal(2)
            f = cur[i]
            is_end = ends[i + 1] | edbs[i + 1]
            self.comb += [
                state_n.eq(state_c),
                Case(state_c, {
                    IDLE: [
                        If(f["stp"],
                            tlp_v[i].eq(1),
                            tlp_f[i].eq(1),
                            tlp_l[i].eq(is_end),
                            state_n.eq(TLP),
                        ).Elif(f["sdp"],
                            If(ends[i + 1],
                                dllp_v[i].eq(1),
                                state_n.eq(DLLP),
                            ).Else(
                                errors[i].eq(1)
                            )
                        ).Elif(f["bad"] | f["end"] | f["edb"],
                            errors[i].eq(1)
                        )
                    ],
                    TLP: [
                        If(f["end"] | f["edb"],
                            state_n.eq(IDLE)
                        ).Elif(f["stp"] | f["sdp"] | f["bad"],
                            errors[i].eq(1),
                            aborts[i].eq(1),
                            state_n.eq(IDLE),
                        ).Else(
                            tlp_v[i].eq(1),
                            tlp_l[i].eq(is_end),
                        )
                    ],
                    DLLP: [
                        state_n.eq(IDLE)
                    ],
                    "default": state_n.eq(IDLE),
                })
            ]
            state_c = state_n
        self.sync += If(process, state.eq(state_c))

        # DLLPs: more than one per beat is possible, queued and delivered one per cycle.
        dllps    = Array(Signal(48) for _ in range(8))
        wr       = Signal(3)
        rd       = Signal(3)
        wr_c     = wr
        for i in range(ndw):
            # Registered (timing): the slots classification is on the way.
            wr_n   = Signal(3)
            valid  = Signal()
            value  = Signal(48, reset_less=True)
            self.sync += [
                valid.eq(process & dllp_v[i]),
                value.eq(Cat(slots[i][8:32], slots[i + 1][0:24])),
            ]
            self.comb += wr_n.eq(wr_c + valid)
            self.sync += If(valid, dllps[wr_c].eq(value))
            wr_c = wr_n
        self.sync += [
            wr.eq(wr_c),
            self.dllp_valid.eq(rd != wr),
            If(rd != wr,
                self.dllp.eq(dllps[rd]),
                rd.eq(rd + 1),
            )
        ]

        # TLP DWs to first-aligned beats.
        # The beats go through a FIFO first: a first-aligned TLP of 4*k+1 DWs needs k+1 output beats for
        # k+1/2 input beats, the FIFO absorbs it during the bursts, limited by the credits we advertise.
        # An abort stays in order with the data, and is also how a full FIFO is reported.
        beat_layout = [("valid_", ndw), ("first_", ndw), ("last_", ndw), ("edb", ndw), ("abort", 1),
                       ("data", 32*ndw), ("seq", 12*ndw)]
        self.fifo = fifo = stream.SyncFIFO(beat_layout, fifo_depth, buffered=True)
        self.repacker = repacker = TLPRepacker(ndw)
        tlp_any = Signal()
        abort   = Signal()
        missed  = Signal() # Beat lost, FIFO full.
        self.comb += [
            tlp_any.eq(Reduce("OR", tlp_v)),
            abort.eq(Reduce("OR", aborts)),
            fifo.source.ready.eq(repacker.sink_ready),
            repacker.sink_en.eq(fifo.source.valid),
            repacker.sink_valid.eq(fifo.source.valid_),
            repacker.sink_first.eq(fifo.source.first_),
            repacker.sink_last.eq(fifo.source.last_),
            repacker.sink_edb.eq(fifo.source.edb),
            repacker.sink_data.eq(fifo.source.data),
            repacker.sink_seq.eq(fifo.source.seq),
            repacker.flush.eq(fifo.source.abort),
        ]
        self.sync += [
            fifo.sink.valid.eq(process & (tlp_any | abort | missed)),
            fifo.sink.valid_.eq(Cat(*tlp_v)),
            fifo.sink.first_.eq(Cat(*tlp_f)),
            fifo.sink.last_.eq(Cat(*tlp_l)),
            fifo.sink.edb.eq(Cat(*[edbs[i + 1] for i in range(ndw)])),
            fifo.sink.abort.eq(abort | missed),
            fifo.sink.data.eq(Cat(*[Cat(slots[i][24:32], slots[i + 1][0:24]) for i in range(ndw)])),
            fifo.sink.seq.eq(Cat(*[Cat(slots[i][16:24], slots[i][8:12]) for i in range(ndw)])),
            If(fifo.sink.valid & ~fifo.sink.ready,
                missed.eq(1)
            ).Elif(fifo.sink.valid & fifo.sink.abort,
                missed.eq(0)
            ),
            self.tlp_abort.eq(repacker.flushed),
            self.error.eq((process & Reduce("OR", errors)) | (fifo.sink.valid & ~fifo.sink.ready)),
        ]
        self.comb += [
            tlp.valid.eq(repacker.source.valid),
            tlp.first.eq(repacker.source.first),
            tlp.last.eq(repacker.source.last),
            tlp.data.eq(repacker.source.data),
            tlp.dws.eq(repacker.source.dws),
            tlp.seq.eq(repacker.source.seq),
            tlp.edb.eq(repacker.source.edb),
            repacker.source.ready.eq(tlp.ready),
        ]

class TLPRepacker(LiteXModule):
    """DWs of the slots of a beat to TLP beats starting on data[0:32]: a beat can hold the end of a TLP
    and the start of the next one. sink_ready drops while the buffer can't take a whole beat. flush
    (with a beat, in order): the buffer is dropped, and the slots up to the next TLP start ignored.

    The DWs stay in place in a ring buffer: what is written doesn't depend on what is read (timing),
    and the output beats are registered."""
    def __init__(self, ndw, depth=None):
        self.sink_en    = Signal()    # i: beat present.
        self.sink_ready = Signal()    # o
        self.sink_valid = Signal(ndw)
        self.sink_first = Signal(ndw)
        self.sink_last  = Signal(ndw)
        self.sink_edb   = Signal(ndw)
        self.sink_data  = Signal(32*ndw)
        self.sink_seq   = Signal(12*ndw)
        self.flush      = Signal()    # i
        self.flushed    = Signal()    # o (Pulse): a TLP being received was dropped.
        self.source     = source = stream.Endpoint(tlp_beat_layout(ndw))

        # # #

        depth = 2**log2_int(3*ndw, need_pow2=False) if depth is None else depth
        adr   = log2_int(depth)
        fields = dict(data=(0, 32), first=(32, 1), last=(33, 1), edb=(34, 1), seq=(35, 12))
        width  = 47
        field  = lambda s, name: s[fields[name][0]:fields[name][0] + fields[name][1]]
        buf    = [Signal(width, reset_less=True) for _ in range(depth)]
        wr     = Signal(adr + 1)
        rd     = Signal(adr + 1)
        used   = Signal(adr + 1)
        # A beat in the input stage has its place reserved as well.
        self.comb += [
            used.eq(wr - rd),
            self.sink_ready.eq(used + 2*ndw <= depth),
        ]

        # Input stage: valid slots and their offset from the write position, which don't depend on it
        # (timing). While dropping, the slots of a beat are ignored up to the first TLP start.
        beat       = self.sink_en & self.sink_ready
        dropping   = Signal()
        dropping_c = dropping
        offset_c   = Constant(0, bits_for(ndw))
        valids     = [Signal() for _ in range(ndw)]
        offsets    = [Signal(bits_for(ndw), reset_less=True) for _ in range(ndw)]
        total      = Signal(bits_for(ndw))
        entries    = [Signal(width, reset_less=True) for _ in range(ndw)]
        for i in range(ndw):
            dropping_n = Signal()
            valid      = Signal()
            offset_n   = Signal(bits_for(ndw))
            self.comb += [
                dropping_n.eq(dropping_c & ~(self.sink_valid[i] & self.sink_first[i])),
                valid.eq(beat & self.sink_valid[i] & ~dropping_n),
                offset_n.eq(offset_c + valid),
            ]
            self.sync += [
                valids[i].eq(valid & ~self.flush),
                offsets[i].eq(offset_c),
                entries[i].eq(Cat(self.sink_data[32*i:32*(i+1)], self.sink_first[i], self.sink_last[i],
                    self.sink_edb[i], self.sink_seq[12*i:12*(i+1)])),
            ]
            dropping_c, offset_c = dropping_n, offset_n
        self.sync += total.eq(Mux(self.flush, 0, offset_c))

        # Write.
        for i in range(ndw):
            position = Signal(adr)
            self.comb += position.eq(wr[:adr] + offsets[i])
            self.sync += If(valids[i],
                Case(position, {j: buf[j].eq(entries[i]) for j in range(depth)})
            )

        # Read: up to the end of the TLP or a full beat.
        # Read index of each DW (rd + i) kept in its own register: no adder, and less fanout on rd (timing).
        head    = [Signal(width) for _ in range(ndw)]
        indexes = [Signal(adr, reset=i % depth) for i in range(ndw)]
        for i in range(ndw):
            self.comb += Case(indexes[i], {j: head[i].eq(buf[j]) for j in range(depth)})
        lasts = [field(head[i], "last") for i in range(ndw)]
        count = Signal(max=ndw + 1)
        count_case = count.eq(ndw)
        for i in reversed(range(ndw - 1)):
            count_case = If(lasts[i], count.eq(i + 1)).Else(count_case)
        self.comb += count_case
        out_avail = (used >= ndw) | ((used >= count) & (used != 0))
        take      = Signal()
        self.comb += take.eq(out_avail & (~source.valid | source.ready))
        self.comb += self.flushed.eq(beat & self.flush)
        self.sync += [
            If(source.ready, source.valid.eq(0)),
            If(self.flushed,
                wr.eq(0),
                rd.eq(0),
                *[indexes[i].eq(i % depth) for i in range(ndw)],
                dropping.eq(1),
                source.valid.eq(0),
            ).Else(
                If(beat, dropping.eq(dropping_c)),
                wr.eq(wr + total),
                If(take,
                    rd.eq(rd + count),
                    *[indexes[i].eq(indexes[i] + count) for i in range(ndw)],
                    source.valid.eq(1),
                )
            ),
            # Payload loaded whenever the output is free: its enable doesn't depend on the decision (timing).
            If(~source.valid | source.ready,
                source.first.eq(field(head[0], "first")),
                source.seq.eq(field(head[0], "seq")),
                source.dws.eq(count),
                source.data.eq(Cat(*[field(head[i], "data") for i in range(ndw)])),
                Case(count, {n: [
                    source.last.eq(field(head[n - 1], "last")),
                    source.edb.eq(field(head[n - 1], "edb")),
                ] for n in range(1, ndw + 1)}),
            ),
        ]

# TX Framer ----------------------------------------------------------------------------------------

class WideTXFramer(LiteXModule):
    """tlp: TLP beats, lcrc valid with last, framed as STP, Sequence Number, DWs, LCRC, END (edb: EDB) from
    the first DW of a beat, one packet per beat. dllp/dllp_valid (ready: dllp_ready): DLLPs framed as SDP,
    6 bytes, END. Rest of the beat: Logical Idle, with above x4 PAD up to the end of the Symbol time."""
    def __init__(self, ndw, nlanes):
        self.tlp        = tlp    = stream.Endpoint(tlp_beat_layout(ndw))
        self.lcrc       = Signal(32) # i
        self.dllp       = Signal(48) # i
        self.dllp_valid = Signal()   # i (Level, cleared by dllp_ready)
        self.dllp_ready = Signal()   # o (Pulse)
        self.pad_enable = Signal(reset=1) # i: Link running above x4.
        self.source     = source = stream.Endpoint(lane_layout(4*ndw))

        # # #

        nbytes = 4*ndw
        carry  = Signal(24)
        tail   = Signal(64)
        tail_k = Signal(8)

        # Bytes following the carry: the data, then for the last beat the LCRC and END.
        ext   = Signal(8*(nbytes + 8))
        ext_k = Signal(nbytes + 8)
        end   = Mux(tlp.edb, Constant(EDB.value, 8), Constant(END.value, 8))
        cases = {}
        for d in range(1, ndw + 1):
            cases[d] = [
                ext.eq(Cat(tlp.data[0:32*d], self.lcrc, end)),
                ext_k[4*d + 4].eq(1),
            ]
        self.comb += If(tlp.last,
            Case(tlp.dws, cases)
        ).Else(
            ext.eq(tlp.data)
        )

        data = Signal(8*nbytes)
        ctrl = Signal(nbytes)
        self.fsm = fsm = FSM(reset_state="IDLE")
        tail_needed = ext_k[nbytes - 3:] != 0
        fsm.act("IDLE",
            If(self.dllp_valid,
                source.valid.eq(1),
                source.first.eq(1),
                source.last.eq(1),
                data.eq(Cat(Constant(SDP.value, 8), self.dllp, Constant(END.value, 8))),
                ctrl[0].eq(1),
                ctrl[7].eq(1),
                self.dllp_ready.eq(source.ready),
            ).Elif(tlp.valid & tlp.first,
                source.valid.eq(1),
                source.first.eq(1),
                source.last.eq(tlp.last & ~tail_needed),
                data.eq(Cat(Constant(STP.value, 8), tlp.seq[8:12], Constant(0, 4), tlp.seq[0:8], ext[:8*(nbytes - 3)])),
                ctrl.eq(Cat(Constant(1, 3), ext_k[:nbytes - 3])),
                If(source.ready,
                    tlp.ready.eq(1),
                    NextValue(carry, ext[8*(nbytes - 3):8*nbytes]),
                    NextValue(tail, ext[8*(nbytes - 3):]),
                    NextValue(tail_k, ext_k[nbytes - 3:]),
                    If(tlp.last,
                        If(tail_needed, NextState("TAIL"))
                    ).Else(
                        NextState("TLP")
                    )
                )
            ).Elif(tlp.valid,
                tlp.ready.eq(1) # Drop beats outside a packet.
            )
        )
        fsm.act("TLP",
            source.valid.eq(tlp.valid),
            source.last.eq(tlp.last & ~tail_needed),
            data.eq(Cat(carry, ext[:8*(nbytes - 3)])),
            ctrl.eq(Cat(Constant(0, 3), ext_k[:nbytes - 3])),
            If(source.valid & source.ready,
                tlp.ready.eq(1),
                NextValue(carry, ext[8*(nbytes - 3):8*nbytes]),
                NextValue(tail, ext[8*(nbytes - 3):]),
                NextValue(tail_k, ext_k[nbytes - 3:]),
                If(tlp.last,
                    If(tail_needed,
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
            data.eq(tail),
            ctrl.eq(tail_k),
            If(source.ready,
                NextState("IDLE")
            )
        )

        # Above x4: PAD after an END not ending a Symbol time (bytes after END are 0 there).
        pad_slots = []
        if nlanes > 4:
            slots_per_time = nlanes//4
            for s in range(ndw):
                ends_before = Signal()
                pad_slots.append(ends_before)
                # This slot is in the same Symbol time as an END in a previous slot.
                t = s % slots_per_time
                self.comb += ends_before.eq(self.pad_enable & Reduce("OR", [ctrl[4*(s - o) + 3] for o in range(1, t + 1)]) if t else 0)
        out_data = []
        out_ctrl = []
        for s in range(ndw):
            d, c = data[32*s:32*(s+1)], ctrl[4*s:4*(s+1)]
            if nlanes > 4:
                out_data.append(Mux(pad_slots[s], Replicate(Constant(PAD.value, 8), 4), d))
                out_ctrl.append(Mux(pad_slots[s], Constant(0xf, 4), c))
            else:
                out_data.append(d)
                out_ctrl.append(c)
        self.comb += [
            source.data.eq(Cat(*out_data)),
            source.ctrl.eq(Cat(*out_ctrl)),
        ]

# LCRC ---------------------------------------------------------------------------------------------

class WideLCRC(LiteXModule):
    """LCRC over the Sequence Number and DWs of a TLP, a beat per cycle. first: the Sequence Number
    starts a new CRC. dws: DWs of data processed (0: none). value: registered CRC, next_value: with the
    current beat."""
    def __init__(self, ndw):
        self.ce         = Signal()    # i
        self.first      = Signal()    # i
        self.seq        = Signal(16)  # i: the 2 bytes of the Sequence Number.
        self.data       = Signal(32*ndw) # i
        self.dws        = Signal(bits_for(ndw)) # i
        self.value      = Signal(32)  # o
        self.next_value = Signal(32)  # o

        # # #

        state = Signal(32, reset=LCRC_INIT)
        start = Signal(32)
        new   = Signal(32)
        init  = Constant(LCRC_INIT, 32)
        # A statement per bit: the wide expressions are long.
        steps = [Signal(32) for _ in range(ndw)]
        for n in range(1, ndw + 1):
            for bit, expression in enumerate(crc_next(32, LCRC_POLYNOM, start, self.data[:32*n])):
                self.comb += steps[n - 1][bit].eq(expression)
        self.comb += [
            If(self.first,
                start.eq(Cat(*crc_next(32, LCRC_POLYNOM, init, self.seq)))
            ).Else(
                start.eq(state)
            ),
            Case(self.dws, dict(
                [(0, new.eq(start))] +
                [(n, new.eq(steps[n - 1])) for n in range(1, ndw + 1)] +
                [("default", new.eq(start))])),
            self.value.eq(crc_value(32, state)),
            self.next_value.eq(crc_value(32, new)),
        ]
        self.sync += If(self.ce, state.eq(new))

# Framers of both encodings --------------------------------------------------------------------------

class RXFramerSelect(LiteXModule):
    """8b/10b (WideRXFramer) and 8.0 GT/s (Gen3RXFramer) framers, the one of the rate selected by gen3 (the
    other one held in reset). Same interface as a framer."""
    def __init__(self, ndw):
        from litepcie.phy.soft.gen3 import Gen3RXFramer
        self.gen3       = Signal()   # i
        self.sink       = sink = stream.Endpoint(lane_layout(4*ndw))
        self.tlp        = tlp  = stream.Endpoint(tlp_beat_layout(ndw))
        self.dllp       = Signal(48) # o
        self.dllp_valid = Signal()   # o (Pulse)
        self.error      = Signal()   # o (Pulse)
        self.tlp_abort  = Signal()   # o (Pulse)

        # # #

        self.f8 = f8 = ResetInserter()(WideRXFramer(ndw))
        self.f3 = f3 = ResetInserter()(Gen3RXFramer(ndw))
        self.comb += [
            f8.reset.eq(self.gen3),
            f3.reset.eq(~self.gen3),
            sink.ready.eq(1),
        ]
        # Outputs registered (timing; the TLP beats are always taken).
        for f in [f8, f3]:
            sel = self.gen3 if f is f3 else ~self.gen3
            self.comb += [
                f.sink.valid.eq(sink.valid & sel),
                f.sink.first.eq(sink.first),
                f.sink.last.eq(sink.last),
                f.sink.data.eq(sink.data),
                f.tlp.ready.eq(1),
            ]
            self.sync += If(sel,
                tlp.valid.eq(f.tlp.valid),
                tlp.first.eq(f.tlp.first),
                tlp.last.eq(f.tlp.last),
                tlp.data.eq(f.tlp.data),
                tlp.dws.eq(f.tlp.dws),
                tlp.seq.eq(f.tlp.seq),
                tlp.edb.eq(f.tlp.edb),
                self.dllp.eq(f.dllp),
                self.dllp_valid.eq(f.dllp_valid),
                self.error.eq(f.error),
                self.tlp_abort.eq(f.tlp_abort),
            )
        self.comb += f8.sink.ctrl.eq(sink.ctrl)

class TXFramerSelect(LiteXModule):
    """8b/10b (WideTXFramer) and 8.0 GT/s (Gen3TXFramer) framers, the one of the rate selected by gen3 (the
    other one held in reset). Same interface as a framer, idle: Gen3TXFramer's."""
    def __init__(self, ndw, nlanes):
        from litepcie.phy.soft.gen3 import Gen3TXFramer
        self.gen3       = Signal()   # i
        self.tlp        = tlp    = stream.Endpoint(tlp_beat_layout(ndw))
        self.lcrc       = Signal(32) # i
        self.dllp       = Signal(48) # i
        self.dllp_valid = Signal()   # i
        self.dllp_ready = Signal()   # o (Pulse)
        self.pad_enable = Signal(reset=1) # i
        self.idle       = Signal()   # o
        self.source     = source = stream.Endpoint(lane_layout(4*ndw))

        # # #

        self.f8 = f8 = ResetInserter()(WideTXFramer(ndw, nlanes))
        self.f3 = f3 = ResetInserter()(Gen3TXFramer(ndw))
        self.comb += [
            f8.reset.eq(self.gen3),
            f3.reset.eq(~self.gen3),
            f8.pad_enable.eq(self.pad_enable),
            self.idle.eq(f3.idle),
        ]
        for f in [f8, f3]:
            sel = self.gen3 if f is f3 else ~self.gen3
            self.comb += [
                f.lcrc.eq(self.lcrc),
                f.dllp.eq(self.dllp),
                f.dllp_valid.eq(self.dllp_valid & sel),
                f.tlp.valid.eq(tlp.valid & sel),
                f.tlp.first.eq(tlp.first),
                f.tlp.last.eq(tlp.last),
                f.tlp.data.eq(tlp.data),
                f.tlp.dws.eq(tlp.dws),
                f.tlp.seq.eq(tlp.seq),
                If(sel,
                    tlp.ready.eq(f.tlp.ready),
                    self.dllp_ready.eq(f.dllp_ready),
                    f.source.connect(source, omit={"ctrl"}),
                ),
            ]
        self.comb += If(~self.gen3, source.ctrl.eq(f8.source.ctrl))

# Data Link Layer RX -------------------------------------------------------------------------------

class WideDLLRX(LiteXModule):
    """As DLLRX, on beats of ndw DWs. Same interface towards the Data Link Layer core."""
    def __init__(self, ndw, depth=2048, packets=32, framing="8b10b"):
        self.reset        = Signal()
        self.gen3         = Signal() # i: 8.0 GT/s framing (framing="both").
        self.sink         = sink   = stream.Endpoint(lane_layout(4*ndw))
        self.source       = source = stream.Endpoint([("data", 32*ndw), ("dws", bits_for(ndw))])
        self.dllp         = Signal(48)
        self.dllp_valid   = Signal()
        self.ack_req      = Signal()
        self.nak_req      = Signal()
        self.ack_seq      = Signal(12)
        self.deliver      = Signal()
        self.deliver_type = Signal(2)
        self.deliver_data = Signal(9)
        self.errors       = Signal(16)

        # # #

        # Framing.
        if framing == "gen3":
            from litepcie.phy.soft.gen3 import Gen3RXFramer
            self.framer = framer = Gen3RXFramer(ndw)
            self.comb += sink.connect(framer.sink, omit={"ctrl"})
        elif framing == "both":
            self.framer = framer = RXFramerSelect(ndw)
            self.comb += [sink.connect(framer.sink), framer.gen3.eq(self.gen3)]
        else:
            self.framer = framer = WideRXFramer(ndw)
            self.comb += sink.connect(framer.sink)
        self.comb += [
            self.dllp.eq(framer.dllp),
            self.dllp_valid.eq(framer.dllp_valid),
        ]

        # LCRC, the last received DW is the LCRC, compared on the next cycle.
        tlp = framer.tlp
        self.comb += tlp.ready.eq(1)
        self.lcrc = lcrc = WideLCRC(ndw)
        end       = tlp.valid & tlp.last
        data_dws  = Signal(bits_for(ndw))
        self.comb += [
            data_dws.eq(Mux(tlp.last, tlp.dws - 1, tlp.dws)),
            lcrc.ce.eq(tlp.valid),
            lcrc.first.eq(tlp.first),
            lcrc.seq.eq(Cat(tlp.seq[8:12], Constant(0, 4), tlp.seq[0:8])),
            lcrc.data.eq(tlp.data),
            lcrc.dws.eq(data_dws),
        ]
        rx_lcrc = Signal(32)
        self.sync += If(end, Case(tlp.dws, {n: rx_lcrc.eq(tlp.data[32*(n - 1):32*n]) for n in range(1, ndw + 1)}))

        # Store-and-forward buffer, beats delayed by one (the LCRC DW is not stored).
        self.buffer = buffer = PacketBuffer([("fc_type", 2), ("fc_data", 9)], depth=depth, packets=packets, ndw=ndw)
        statements, dw0_type, dw0_data = tlp_credits(tlp.data)
        self.comb += statements
        fc_type    = Signal(2)
        fc_data    = Signal(9)
        prev_valid = Signal()
        prev_data  = Signal(32*ndw)
        prev_dws   = Signal(bits_for(ndw))
        prev_first = Signal()
        lost       = Signal()
        lost_r     = Signal()
        end_r      = Signal()
        # The last beat holding only the LCRC: the previous beat stays the last one.
        only_lcrc  = tlp.last & (tlp.dws == 1)
        write_prev = tlp.valid & ~tlp.first & ~only_lcrc
        self.sync += [
            If(self.reset | end_r | framer.tlp_abort,
                lost_r.eq(0)
            ).Elif(lost,
                lost_r.eq(1)
            ),
            If(self.reset | framer.tlp_abort,
                prev_valid.eq(0)
            ).Elif(tlp.valid,
                If(~only_lcrc | tlp.first,
                    prev_valid.eq(1),
                    prev_data.eq(tlp.data),
                    prev_dws.eq(data_dws),
                    prev_first.eq(tlp.first),
                ),
                If(tlp.first,
                    fc_type.eq(dw0_type),
                    fc_data.eq(dw0_data),
                ),
            ).Elif(end_r,
                prev_valid.eq(0)
            )
        ]

        # Checks registered with the last beat, against the next expected Sequence Number including the
        # TLP accepted on this cycle: single-beat TLPs can follow each other.
        next_seq      = Signal(12)
        nak_scheduled = Signal()
        accept        = Signal()
        next_seq_c    = Signal(12)
        cur_seq       = Signal(12)
        seq_r         = Signal(12)
        seq_diff      = Signal(12)
        prev_valid_r  = Signal()
        edb_r         = Signal()
        in_order_r    = Signal()
        duplicate_r   = Signal()
        self.comb += [
            next_seq_c.eq(next_seq + accept),
            cur_seq.eq(Mux(tlp.first, tlp.seq, seq_r)),
            seq_diff.eq(next_seq_c - cur_seq),
        ]
        self.sync += [
            If(tlp.valid & tlp.first, seq_r.eq(tlp.seq)),
            end_r.eq(end & ~self.reset),
            prev_valid_r.eq(tlp.first | prev_valid),
            edb_r.eq(tlp.edb),
            in_order_r.eq(seq_diff == 0),
            duplicate_r.eq((seq_diff != 0) & (seq_diff < 2048)),
        ]
        lcrc_ok = Mux(edb_r, lcrc.value == ~rx_lcrc, lcrc.value == rx_lcrc)
        bad     = Signal()
        self.comb += [
            buffer.sink.valid.eq((write_prev & prev_valid) | (end_r & prev_valid_r)),
            buffer.sink.data.eq(prev_data),
            buffer.sink.dws.eq(prev_dws),
            buffer.sink.first.eq(prev_first),
            buffer.sink.last.eq(end_r),
            buffer.sink.fc_type.eq(fc_type),
            buffer.sink.fc_data.eq(fc_data),
            lost.eq(buffer.sink.valid & ~buffer.sink.ready),
            accept.eq(end_r & prev_valid_r & lcrc_ok & ~edb_r & in_order_r & ~lost & ~lost_r),
            bad.eq(end_r & (~prev_valid_r | ~lcrc_ok | lost | lost_r | (~edb_r & ~in_order_r & ~duplicate_r))),
            buffer.abort.eq((end_r & ~accept) | framer.tlp_abort),
            self.ack_seq.eq(next_seq - 1),
            self.ack_req.eq(accept | (end_r & lcrc_ok & ~edb_r & duplicate_r)),
            self.nak_req.eq((bad | framer.tlp_abort | framer.error) & ~nak_scheduled),
        ]
        self.sync += [
            If(prev_first & (write_prev | end_r),
                prev_first.eq(tlp.valid & tlp.first)
            ),
            If(self.reset,
                next_seq.eq(0),
                nak_scheduled.eq(0),
                self.errors.eq(0),
            ).Else(
                If(accept,
                    next_seq.eq(next_seq + 1),
                    nak_scheduled.eq(0),
                ),
                If(self.nak_req,
                    nak_scheduled.eq(1),
                    self.errors.eq(self.errors + 1),
                ),
            )
        ]

        # Transaction Layer delivery and credits.
        self.comb += [
            buffer.source.connect(source, omit={"fc_type", "fc_data"}),
            self.deliver.eq(source.valid & source.ready & source.last),
            self.deliver_type.eq(buffer.source.fc_type),
            self.deliver_data.eq(buffer.source.fc_data),
        ]

# Data Link Layer TX -------------------------------------------------------------------------------

class WideDLLTX(LiteXModule):
    """As DLLTX, on beats of ndw DWs. The LCRC is computed in a stage before the framer (timing)."""
    def __init__(self, ndw, nlanes, depth=1024, descriptors=16, replay_timer=375, framing="8b10b"):
        self.reset      = Signal()
        self.gen3       = Signal() # i: 8.0 GT/s framing (framing="both").
        self.enable     = Signal()
        self.sink       = sink   = stream.Endpoint([("data", 32*ndw), ("dws", bits_for(ndw))])
        self.source     = source = stream.Endpoint(lane_layout(4*ndw))
        self.dllp       = Signal(48)
        self.dllp_valid = Signal()
        self.dllp_ready = Signal()

        # # #

        self.replay = replay = ReplayBuffer(depth=depth, descriptors=descriptors, replay_timer=replay_timer, ndw=ndw)
        self.comb += [
            replay.reset.eq(self.reset),
            replay.enable.eq(self.enable),
            sink.connect(replay.sink),
        ]

        # LCRC stage.
        self.lcrc   = lcrc   = WideLCRC(ndw)
        if framing == "gen3":
            from litepcie.phy.soft.gen3 import Gen3TXFramer
            self.framer = framer = Gen3TXFramer(ndw)
        elif framing == "both":
            self.framer = framer = TXFramerSelect(ndw, nlanes)
            self.comb += framer.gen3.eq(self.gen3)
        else:
            self.framer = framer = WideTXFramer(ndw, nlanes)
        tlp = framer.tlp
        rs  = replay.source
        out_valid = Signal()
        self.comb += [
            rs.ready.eq(~out_valid | tlp.ready),
            lcrc.ce.eq(rs.valid & rs.ready),
            lcrc.first.eq(rs.first),
            lcrc.seq.eq(Cat(rs.seq[8:12], Constant(0, 4), rs.seq[0:8])),
            lcrc.data.eq(rs.data),
            lcrc.dws.eq(rs.dws),
            tlp.valid.eq(out_valid),
        ]
        self.sync += [
            If(self.reset,
                out_valid.eq(0)
            ).Elif(rs.ready,
                out_valid.eq(rs.valid),
                tlp.first.eq(rs.first),
                tlp.last.eq(rs.last),
                tlp.data.eq(rs.data),
                tlp.dws.eq(rs.dws),
                tlp.seq.eq(rs.seq),
                framer.lcrc.eq(lcrc.next_value),
            )
        ]

        # DLLPs.
        self.comb += [
            framer.dllp.eq(self.dllp),
            framer.dllp_valid.eq(self.dllp_valid),
            self.dllp_ready.eq(framer.dllp_ready),
            framer.source.connect(source, omit={"ctrl"} if framing == "gen3" else set()),
        ]
