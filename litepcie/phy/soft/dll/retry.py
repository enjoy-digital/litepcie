#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY Data Link Layer retry buffer (PCIe Base 3.5.2): TLPs stored from the Transaction
Layer until acknowledged, transmitted once complete (store-and-forward) and allowed by the flow
control, retransmitted on Nak or REPLAY_TIMER expiration (REPLAY_NUM, Link retrain on rollover).
"""

from migen import *

from litex.gen import *

from litex.soc.interconnect import stream

from litepcie.phy.soft.dll.flow_control import tlp_credits

# Replay Buffer ------------------------------------------------------------------------------------

class ReplayBuffer(LiteXModule):
    """depth: DWs (power of 2), descriptors: TLPs stored at most, replay_timer: cycles without
    acknowledgment before a replay. ndw: DWs per word, with dws the valid DWs of the last word of a TLP."""
    def __init__(self, depth=1024, descriptors=16, replay_timer=375, ndw=1):
        self.reset      = Signal()    # i: Data Link down (flush).
        self.enable     = Signal()    # i: TLPs transmission allowed (DL_Active).
        self.hold       = Signal()    # i: REPLAY_TIMER held (LTSSM not in L0).
        dws_layout      = [("dws", bits_for(ndw))] if ndw > 1 else []
        self.sink       = stream.Endpoint([("data", 32*ndw)] + dws_layout)
        self.source     = source = stream.Endpoint([("data", 32*ndw), ("seq", 12)] + dws_layout)
        self.ack        = Signal()    # i (Pulse): Ack or Nak received, ack_seq acknowledged.
        self.ack_seq    = Signal(12)  # i
        self.nak        = Signal()    # i (Pulse): Nak received (replay after the acknowledgment).
        self.fc_type    = Signal(2)   # o: credits of the TLP about to be transmitted (registered).
        self.fc_data    = Signal(9)   # o
        self.fc_ok      = Signal()    # i: flow control allows it (registered, one cycle after fc_type).
        self.fc_consume = Signal()    # o (Pulse): transmission started (not a replay).
        self.pending    = Signal()    # o: TLPs transmitted and not acknowledged.
        self.link_error = Signal()    # o (Pulse): REPLAY_NUM rollover.
        self.replays    = Signal(16)  # o: replays count.

        # # #

        depth //= ndw
        assert depth & (depth - 1) == 0
        assert descriptors & (descriptors - 1) == 0
        adr_width  = log2_int(depth)
        desc_width = log2_int(descriptors)

        mem = Memory(32*ndw, depth)
        wr_port = mem.get_port(write_capable=True)
        rd_port = mem.get_port(async_read=False)
        self.specials += mem, wr_port, rd_port

        # Input stage (timing, the credits of a TLP are computed from its first DW), flushed on reset.
        self.sink_pipe = sink_pipe = ResetInserter()(stream.PipeValid([("data", 32*ndw)] + dws_layout))
        if ndw > 1:
            self.comb += sink_pipe.sink.dws.eq(self.sink.dws)
        self.comb += [
            sink_pipe.reset.eq(self.reset),
            sink_pipe.sink.valid.eq(self.sink.valid & ~self.reset),
            sink_pipe.sink.first.eq(self.sink.first),
            sink_pipe.sink.last.eq(self.sink.last),
            sink_pipe.sink.data.eq(self.sink.data),
            self.sink.ready.eq(sink_pipe.sink.ready & ~self.reset),
        ]
        sink = sink_pipe.source

        # Descriptors (ring): in distributed memories (timing), one read by the transmitter, one by the
        # acknowledgments. The sent flags are written by the transmitter.
        tx_layout  = [("start", adr_width), ("length", adr_width + 1), ("seq", 12), ("type", 2), ("data", 9)] + dws_layout
        ack_layout = [("length", adr_width + 1), ("seq", 12)]
        d_wr       = Signal() # Descriptor written.
        d_tx_w     = Record(tx_layout)
        d_tx_r     = Record(tx_layout)
        d_ack_r    = Record(ack_layout)
        d_sent     = Array(Signal() for _ in range(descriptors))
        d_tx_mem   = Memory(len(d_tx_w), descriptors)
        d_ack_mem  = Memory(len(d_ack_r), descriptors)
        d_tx_wr    = d_tx_mem.get_port(write_capable=True, mode=READ_FIRST)
        d_tx_rd    = d_tx_mem.get_port(async_read=True, mode=READ_FIRST)
        d_ack_wr   = d_ack_mem.get_port(write_capable=True, mode=READ_FIRST)
        d_ack_rd   = d_ack_mem.get_port(async_read=True, mode=READ_FIRST)
        self.specials += d_tx_mem, d_tx_wr, d_tx_rd, d_ack_mem, d_ack_wr, d_ack_rd
        wr_desc  = Signal(desc_width + 1) # Next descriptor to write.
        tx_desc  = Signal(desc_width + 1) # Next descriptor to transmit.
        ack_desc = Signal(desc_width + 1) # Oldest descriptor not acknowledged.
        count    = Signal(desc_width + 1) # Stored descriptors.
        self.comb += count.eq(wr_desc - ack_desc)

        # Write (Transaction Layer) ----------------------------------------------------------------
        wr_ptr   = Signal(adr_width)
        start    = Signal(adr_width)
        pending  = Signal(adr_width + 1) # DWs of the TLP being written.
        free     = Signal(adr_width + 1, reset=depth) # DWs free (acknowledged ones freed).
        next_seq = Signal(12)
        tlp_type = Signal(2)
        tlp_data = Signal(9)
        statements, dw0_type, dw0_data = tlp_credits(sink.data)
        self.comb += statements
        self.comb += [
            sink.ready.eq(~self.reset & (free != 0) & (count != descriptors)),
            wr_port.adr.eq(wr_ptr),
            wr_port.dat_w.eq(sink.data),
            wr_port.we.eq(sink.valid & sink.ready),
        ]
        accepted = sink.valid & sink.ready
        self.comb += [
            d_wr.eq(accepted & sink.last),
            d_tx_w.start.eq(Mux(sink.first, wr_ptr, start)),
            d_tx_w.length.eq(Mux(sink.first, 1, pending + 1)),
            d_tx_w.seq.eq(next_seq),
            d_tx_w.type.eq(Mux(sink.first, dw0_type, tlp_type)),
            d_tx_w.data.eq(Mux(sink.first, dw0_data, tlp_data)),
            *([d_tx_w.dws.eq(sink.dws)] if ndw > 1 else []),
            d_tx_wr.adr.eq(wr_desc[:desc_width]),
            d_tx_wr.we.eq(d_wr),
            d_tx_wr.dat_w.eq(d_tx_w.raw_bits()),
            d_ack_wr.adr.eq(wr_desc[:desc_width]),
            d_ack_wr.we.eq(d_wr),
            d_ack_wr.dat_w.eq(Cat(d_tx_w.length, d_tx_w.seq)),
            d_tx_rd.adr.eq(tx_desc[:desc_width]),
            d_ack_rd.adr.eq(ack_desc[:desc_width]),
            d_tx_r.raw_bits().eq(d_tx_rd.dat_r),
            d_ack_r.raw_bits().eq(d_ack_rd.dat_r),
        ]
        self.sync += [
            If(self.reset,
                wr_ptr.eq(0),
                pending.eq(0),
                wr_desc.eq(0),
                next_seq.eq(0),
            ).Elif(accepted,
                wr_ptr.eq(wr_ptr + 1),
                If(sink.first,
                    start.eq(wr_ptr),
                    tlp_type.eq(dw0_type),
                    tlp_data.eq(dw0_data),
                    pending.eq(1),
                ).Else(
                    pending.eq(pending + 1)
                ),
                If(sink.last,
                    d_sent[wr_desc[:desc_width]].eq(0),
                    wr_desc.eq(wr_desc + 1),
                    next_seq.eq(next_seq + 1),
                    pending.eq(0),
                )
            )
        ]

        # Acknowledgments --------------------------------------------------------------------------
        # One descriptor freed per cycle while its sequence number is acknowledged.
        # A descriptor is freed once completely transmitted (tx_desc past it), so an acknowledgment
        # received during a replay holds until the replay has passed the acknowledged TLPs.
        ack_target  = Signal(12)
        acking      = Signal()
        ack_ok      = Signal() # The oldest descriptor is acknowledged.
        ack_free    = Signal()
        ack_diff    = Signal(12)
        progress    = Signal()
        self.comb += [
            ack_diff.eq(ack_target - d_ack_r.seq),
            ack_ok.eq(acking & (ack_desc != wr_desc) & d_sent[ack_desc[:desc_width]] & (ack_diff < 2048)),
            ack_free.eq(ack_ok & (ack_desc != tx_desc)),
        ]
        self.sync += [
            If(self.reset,
                acking.eq(0),
                ack_desc.eq(0),
                free.eq(depth),
            ).Else(
                If(self.ack,
                    acking.eq(1),
                    ack_target.eq(self.ack_seq),
                ).Elif(~ack_ok,
                    acking.eq(0)
                ),
                If(ack_free,
                    ack_desc.eq(ack_desc + 1),
                ),
                free.eq(free - Mux(accepted, 1, 0) + Mux(ack_free, d_ack_r.length, 0)),
            )
        ]
        self.comb += progress.eq(ack_free)

        # Replay requests: Nak (after its acknowledgment) or timer. REPLAY_TIMER (3.5.2.1) is held in
        # reset during a replay (restarts after its last TLP) and outside L0, else a replay longer than
        # the timer would restart forever.
        replay_req = Signal()
        replay_num = Signal(2)
        replaying  = Signal()
        replay_end = Signal(desc_width + 1)
        timer      = Signal(max=replay_timer + 1)
        self.comb += self.pending.eq(ack_desc != tx_desc)
        self.sync += [
            If(self.reset,
                replay_req.eq(0),
                replay_num.eq(0),
                replaying.eq(0),
                timer.eq(0),
                self.replays.eq(0),
            ).Else(
                If(self.nak,
                    replay_req.eq(1)
                ),
                # REPLAY_TIMER: runs with unacknowledged TLPs, restarts on progress and replays.
                If(replaying & (tx_desc == replay_end),
                    replaying.eq(0)
                ),
                If(~self.pending | progress | replaying | self.hold,
                    timer.eq(0)
                ).Elif(timer == replay_timer,
                    replay_req.eq(1),
                    timer.eq(0),
                ).Else(
                    timer.eq(timer + 1)
                ),
                If(progress,
                    replay_num.eq(0)
                ),
            )
        ]

        # Transmit ---------------------------------------------------------------------------------
        # source.data is the memory output, the next address is presented when a word is consumed.
        rd_ptr    = Signal(adr_width)
        remaining = Signal(adr_width + 1) # Words left, current one included.
        consumed  = source.valid & source.ready
        desc      = tx_desc[:desc_width]
        self.comb += [
            source.data.eq(rd_port.dat_r),
            source.last.eq(remaining == 1),
        ]
        # Descriptor to transmit, registered, then fc_ok: valid 2 cycles after tx_desc changed or the
        # descriptor was written, and after the credits consumed by the previous TLP are counted.
        # The credit limits only increase, so a fc_ok older than an UpdateFC is only late.
        cur_start = Signal(adr_width)
        cur_len   = Signal(adr_width + 1)
        cur_seq   = Signal(12)
        cur_sent  = Signal()
        settle    = Signal(2)
        settled   = Signal()
        replay    = Signal()
        self.comb += settled.eq(settle == 2)
        if ndw > 1:
            cur_dws = Signal(bits_for(ndw))
            self.sync += cur_dws.eq(d_tx_r.dws)
            last_dws = Signal(bits_for(ndw))
            self.comb += If(source.last, source.dws.eq(last_dws)).Else(source.dws.eq(ndw))
        self.sync += [
            cur_start.eq(d_tx_r.start),
            cur_len.eq(d_tx_r.length),
            cur_seq.eq(d_tx_r.seq),
            cur_sent.eq(d_sent[desc]),
            self.fc_type.eq(d_tx_r.type),
            self.fc_data.eq(d_tx_r.data),
        ]
        self.fsm = fsm = FSM(reset_state="IDLE")
        self.sync += [
            If(~fsm.ongoing("IDLE") | self.reset | replay | (tx_desc == wr_desc),
                settle.eq(0)
            ).Elif(~settled,
                settle.eq(settle + 1)
            )
        ]
        fsm.act("IDLE",
            rd_port.adr.eq(cur_start),
            If(self.reset,
                NextValue(tx_desc, 0),
            ).Elif(replay_req & ~acking,
                # Replay from the oldest unacknowledged TLP.
                replay.eq(1),
                NextValue(tx_desc, ack_desc),
                NextValue(replay_end, tx_desc),
                NextValue(replaying, tx_desc != ack_desc),
                NextValue(replay_req, 0),
                NextValue(self.replays, self.replays + 1),
                NextValue(replay_num, replay_num + 1),
                If(replay_num == 3,
                    self.link_error.eq(1)
                ),
            ).Elif(self.enable & settled & (cur_sent | self.fc_ok),
                self.fc_consume.eq(~cur_sent),
                NextValue(d_sent[desc], 1),
                NextValue(rd_ptr, cur_start),
                NextValue(remaining, cur_len),
                NextValue(source.first, 1),
                NextValue(source.seq, cur_seq),
                *([NextValue(last_dws, cur_dws)] if ndw > 1 else []),
                NextState("SEND"),
            )
        )
        fsm.act("SEND",
            source.valid.eq(1),
            rd_port.adr.eq(rd_ptr),
            If(consumed,
                NextValue(source.first, 0),
                If(source.last,
                    NextValue(tx_desc, tx_desc + 1),
                    NextState("IDLE"),
                ).Else(
                    rd_port.adr.eq(rd_ptr + 1),
                    NextValue(rd_ptr, rd_ptr + 1),
                    NextValue(remaining, remaining - 1),
                )
            ),
            If(self.reset,
                NextValue(tx_desc, 0),
                NextState("IDLE"),
            )
        )
