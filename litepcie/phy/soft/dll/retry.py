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
    acknowledgment before a replay."""
    def __init__(self, depth=1024, descriptors=16, replay_timer=375):
        self.reset      = Signal()    # i: Data Link down (flush).
        self.enable     = Signal()    # i: TLPs transmission allowed (DL_Active).
        self.sink       = sink   = stream.Endpoint([("data", 32)])
        self.source     = source = stream.Endpoint([("data", 32), ("seq", 12)])
        self.ack        = Signal()    # i (Pulse): Ack or Nak received, ack_seq acknowledged.
        self.ack_seq    = Signal(12)  # i
        self.nak        = Signal()    # i (Pulse): Nak received (replay after the acknowledgment).
        self.fc_type    = Signal(2)   # o: credits of the TLP about to be transmitted.
        self.fc_data    = Signal(9)   # o
        self.fc_ok      = Signal()    # i: flow control allows it.
        self.fc_consume = Signal()    # o (Pulse): transmission started (not a replay).
        self.pending    = Signal()    # o: TLPs transmitted and not acknowledged.
        self.link_error = Signal()    # o (Pulse): REPLAY_NUM rollover.
        self.replays    = Signal(16)  # o: replays count.

        # # #

        assert depth & (depth - 1) == 0
        assert descriptors & (descriptors - 1) == 0
        adr_width  = log2_int(depth)
        desc_width = log2_int(descriptors)

        mem = Memory(32, depth)
        wr_port = mem.get_port(write_capable=True)
        rd_port = mem.get_port(async_read=False)
        self.specials += mem, wr_port, rd_port

        # Descriptors (ring).
        d_start  = Array(Signal(adr_width)     for _ in range(descriptors))
        d_length = Array(Signal(adr_width + 1) for _ in range(descriptors))
        d_seq    = Array(Signal(12)            for _ in range(descriptors))
        d_type   = Array(Signal(2)             for _ in range(descriptors))
        d_data   = Array(Signal(9)             for _ in range(descriptors))
        d_sent   = Array(Signal()              for _ in range(descriptors))
        wr_desc  = Signal(desc_width + 1) # Next descriptor to write.
        tx_desc  = Signal(desc_width + 1) # Next descriptor to transmit.
        ack_desc = Signal(desc_width + 1) # Oldest descriptor not acknowledged.
        count    = Signal(desc_width + 1) # Stored descriptors.
        self.comb += count.eq(wr_desc - ack_desc)

        # Write (Transaction Layer) ----------------------------------------------------------------
        wr_ptr   = Signal(adr_width)
        start    = Signal(adr_width)
        pending  = Signal(adr_width + 1) # DWs of the TLP being written.
        used     = Signal(adr_width + 1) # DWs stored (acknowledged ones excluded).
        next_seq = Signal(12)
        tlp_type = Signal(2)
        tlp_data = Signal(9)
        statements, dw0_type, dw0_data = tlp_credits(sink.data)
        self.comb += statements
        self.comb += [
            sink.ready.eq(~self.reset & (used + pending != depth) & (count != descriptors)),
            wr_port.adr.eq(wr_ptr),
            wr_port.dat_w.eq(sink.data),
            wr_port.we.eq(sink.valid & sink.ready),
        ]
        accepted = sink.valid & sink.ready
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
                    d_start[wr_desc[:desc_width]].eq(Mux(sink.first, wr_ptr, start)),
                    d_length[wr_desc[:desc_width]].eq(Mux(sink.first, 1, pending + 1)),
                    d_seq[wr_desc[:desc_width]].eq(next_seq),
                    d_type[wr_desc[:desc_width]].eq(Mux(sink.first, dw0_type, tlp_type)),
                    d_data[wr_desc[:desc_width]].eq(Mux(sink.first, dw0_data, tlp_data)),
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
            ack_diff.eq(ack_target - d_seq[ack_desc[:desc_width]]),
            ack_ok.eq(acking & (ack_desc != wr_desc) & d_sent[ack_desc[:desc_width]] & (ack_diff < 2048)),
            ack_free.eq(ack_ok & (ack_desc != tx_desc)),
        ]
        self.sync += [
            If(self.reset,
                acking.eq(0),
                ack_desc.eq(0),
                used.eq(0),
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
                # Stored DWs: + written, - freed.
                used.eq(used + Mux(accepted, 1, 0) - Mux(ack_free, d_length[ack_desc[:desc_width]], 0)),
            )
        ]
        self.comb += progress.eq(ack_free)

        # Replay requests: Nak (after its acknowledgment) or timer.
        replay_req = Signal()
        replay_num = Signal(2)
        timer      = Signal(max=replay_timer + 1)
        self.comb += self.pending.eq(ack_desc != tx_desc)
        self.sync += [
            If(self.reset,
                replay_req.eq(0),
                replay_num.eq(0),
                timer.eq(0),
                self.replays.eq(0),
            ).Else(
                If(self.nak,
                    replay_req.eq(1)
                ),
                # REPLAY_TIMER: runs with unacknowledged TLPs, restarts on progress and replays.
                If(~self.pending | progress,
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
            self.fc_type.eq(d_type[desc]),
            self.fc_data.eq(d_data[desc]),
        ]
        self.fsm = fsm = FSM(reset_state="IDLE")
        fsm.act("IDLE",
            rd_port.adr.eq(d_start[desc]),
            If(self.reset,
                NextValue(tx_desc, 0),
            ).Elif(replay_req & ~acking,
                # Replay from the oldest unacknowledged TLP.
                NextValue(tx_desc, ack_desc),
                NextValue(replay_req, 0),
                NextValue(self.replays, self.replays + 1),
                NextValue(replay_num, replay_num + 1),
                If(replay_num == 3,
                    self.link_error.eq(1)
                ),
            ).Elif(self.enable & (tx_desc != wr_desc) & (d_sent[desc] | self.fc_ok),
                self.fc_consume.eq(~d_sent[desc]),
                NextValue(d_sent[desc], 1),
                NextValue(rd_ptr, d_start[desc]),
                NextValue(remaining, d_length[desc]),
                NextValue(source.first, 1),
                NextValue(source.seq, d_seq[desc]),
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
