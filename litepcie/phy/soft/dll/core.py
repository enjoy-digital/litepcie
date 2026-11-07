#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY Data Link Layer (PCIe Base chapter 3): DLCMSM (DL_Inactive, DL_Init with the flow
control initialization, DL_Active), DLLP scheduling (Nak, Ack, InitFC, UpdateFC), TLP transmission
with retry and reception with checks and credits.

Streams (pcie_link clock domain): sink/source are the Transaction Layer TLPs (DW words, byte 0 of
the TLP on bits 7:0 of the first word), phy_sink/phy_source the lane words of the Physical Layer.
"""

from migen import *
from migen.genlib.misc import WaitTimer

from litex.gen import *

from litex.soc.interconnect import stream

from litepcie.phy.soft.common           import lane_layout
from litepcie.phy.soft.dll.dllp         import DLLPEncoder, DLLPDecoder
from litepcie.phy.soft.dll.dllp         import DLLP_ACK, DLLP_NAK, DLLP_INITFC1_P, DLLP_INITFC2_P, DLLP_UPDATEFC_P
from litepcie.phy.soft.dll.flow_control import FlowControlTX, FlowControlRX
from litepcie.phy.soft.dll.rx           import DLLRX
from litepcie.phy.soft.dll.tx           import DLLTX

# Data Link Layer ----------------------------------------------------------------------------------

class DataLinkLayer(LiteXModule):
    """link_up: the Physical Layer link is up (LTSSM Configuration done); dl_active: the Data Link
    Layer is active (TLPs flow). Receiver credits advertised: p_hdr/p_data, np_hdr/np_data,
    Completions infinite (an endpoint must). update_timer: UpdateFC period (cycles, 30 us).
    replay_timer: REPLAY_TIMER limit (cycles), default for a 512-byte Max Payload Size at 2.5 GT/s x1
    (1677 Symbol times, to check against the specification table with the speed/width milestones)."""
    def __init__(self, clk_freq, p_hdr=16, p_data=128, np_hdr=8, np_data=8, rx_depth=2048, tx_depth=1024,
        descriptors=16, replay_timer=None, update_timer=None):
        self.link_up    = Signal()   # i
        self.l0         = Signal()   # i: LTSSM in L0 (lane traffic).
        self.dl_active  = Signal()   # o
        self.state      = Signal(2)  # o: DLCMSM: 0 DL_Inactive, 1/2 DL_Init (FC_INIT1/FC_INIT2), 3 DL_Active.
        self.link_error = Signal()   # o (Pulse): Link retrain requested (replay rollover).
        self.sink       = sink   = stream.Endpoint([("data", 32)])
        self.source     = source = stream.Endpoint([("data", 32)])
        self.phy_sink   = stream.Endpoint(lane_layout(4)) # o: to the Physical Layer.
        self.phy_source = stream.Endpoint(lane_layout(4)) # i: from the Physical Layer.

        # # #

        if update_timer is None:
            update_timer = int(30e-6*clk_freq)
        if replay_timer is None:
            replay_timer = int(1677*4e-9*clk_freq)

        reset = Signal()
        self.comb += reset.eq(~self.link_up)

        # RX/TX ------------------------------------------------------------------------------------
        self.rx = rx = DLLRX(depth=rx_depth, packets=64)
        self.tx = tx = DLLTX(depth=tx_depth, descriptors=descriptors, replay_timer=replay_timer)
        self.comb += [
            rx.reset.eq(reset),
            tx.reset.eq(reset),
            tx.replay.hold.eq(~self.l0),
            self.phy_source.connect(rx.sink),
            tx.source.connect(self.phy_sink),
            rx.source.connect(source),
            sink.connect(tx.sink),
            self.link_error.eq(tx.replay.link_error),
        ]

        # Flow Control -----------------------------------------------------------------------------
        self.fc_tx = fc_tx = FlowControlTX()
        self.fc_rx = fc_rx = FlowControlRX(p_hdr, p_data, np_hdr, np_data)
        self.comb += [
            fc_tx.reset.eq(reset),
            fc_rx.reset.eq(reset),
            fc_tx.tlp_type.eq(tx.replay.fc_type),
            fc_tx.tlp_data.eq(tx.replay.fc_data),
            tx.replay.fc_ok.eq(fc_tx.ok),
            fc_tx.consume.eq(tx.replay.fc_consume),
            fc_rx.deliver.eq(rx.deliver),
            fc_rx.deliver_type.eq(rx.deliver_type),
            fc_rx.deliver_data.eq(rx.deliver_data),
        ]

        # Received DLLPs ---------------------------------------------------------------------------
        self.decoder = decoder = DLLPDecoder()
        init1_rx  = Signal(3)
        init2_rx  = Signal(3)
        update_rx = Signal()
        self.comb += [
            decoder.dllp.eq(rx.dllp),
            tx.replay.ack.eq(rx.dllp_valid & (decoder.ack | decoder.nak)),
            tx.replay.ack_seq.eq(decoder.seq),
            tx.replay.nak.eq(rx.dllp_valid & decoder.nak),
            fc_tx.fc_type.eq(decoder.fc_type),
            fc_tx.fc_hdr.eq(decoder.hdr_fc),
            fc_tx.fc_data.eq(decoder.data_fc),
            fc_tx.init.eq(rx.dllp_valid & (decoder.init1 | decoder.init2)),
            fc_tx.update.eq(rx.dllp_valid & decoder.update),
        ]
        for t in range(3):
            self.sync += [
                If(reset,
                    init1_rx[t].eq(0),
                    init2_rx[t].eq(0),
                ).Else(
                    If(rx.dllp_valid & (decoder.init1 | decoder.init2) & (decoder.fc_type == t), init1_rx[t].eq(1)),
                    If(rx.dllp_valid & decoder.init2 & (decoder.fc_type == t), init2_rx[t].eq(1)),
                )
            ]
        self.sync += If(reset, update_rx.eq(0)).Elif(rx.dllp_valid & decoder.update, update_rx.eq(1))

        # DLCMSM (3.2) -----------------------------------------------------------------------------
        self.encoder = encoder = DLLPEncoder()
        initial_hdr  = Array(Constant(v, 8)  for v in fc_rx.initial_hdr)
        initial_data = Array(Constant(v, 12) for v in fc_rx.initial_data)
        fc_init_type  = Signal(2) # P, NP, Cpl in turn.
        fc_init_type_n = Signal(2)
        self.comb += fc_init_type_n.eq(Mux(fc_init_type == 2, 0, fc_init_type + 1))
        dllp_req   = Signal() # A DLLP is selected on the encoder.
        dllp_taken = Signal() # It's captured: the next one can be selected.
        ack_taken  = Signal()
        nak_taken  = Signal()
        ack_pending  = Signal()
        nak_pending  = Signal()
        self.sync += [
            If(reset,
                ack_pending.eq(0),
                nak_pending.eq(0),
            ).Else(
                # A request wins over a capture in the same cycle: its Ack/Nak is still to send.
                If(ack_taken,  ack_pending.eq(0)),
                If(nak_taken,  nak_pending.eq(0)),
                If(rx.ack_req, ack_pending.eq(1)),
                If(rx.nak_req, nak_pending.eq(1)),
            )
        ]
        # UpdateFC: on allocation changes and periodically (P and NP, Completions infinite).
        update_period = WaitTimer(update_timer)
        self.submodules += update_period
        update_due = Signal(2) # P, NP due by the timer.
        self.comb += update_period.wait.eq(self.dl_active & ~update_period.done)
        self.sync += [
            If(reset | ~self.dl_active,
                update_due.eq(0)
            ).Elif(update_period.done,
                update_due.eq(0b11)
            ),
        ]
        update_type = Signal(2)
        update_req  = Signal()
        self.comb += [
            If(fc_rx.changed[0] | update_due[0],
                update_req.eq(1), update_type.eq(0)
            ).Elif(fc_rx.changed[1] | update_due[1],
                update_req.eq(1), update_type.eq(1)
            )
        ]
        fc_rx_sent = Signal()
        self.comb += [
            fc_rx.sent.eq(fc_rx_sent),
            fc_rx.sent_type.eq(update_type),
        ]
        self.sync += If(fc_rx_sent,
            If(update_type == 0, update_due[0].eq(0)).Else(update_due[1].eq(0))
        )

        # DLLP captured once and held while it's on the lane (2 words): the Sequence Number, credits
        # and selection on the encoder can change at any time.
        self.comb += [
            dllp_taken.eq(dllp_req & ~tx.dllp_valid),
            encoder.seq.eq(rx.ack_seq),
            encoder.vc.eq(0),
        ]
        self.sync += [
            If(tx.dllp_ready, tx.dllp_valid.eq(0)),
            If(dllp_taken,
                tx.dllp.eq(encoder.dllp),
                tx.dllp_valid.eq(1),
            ),
            If(reset | ~self.l0, tx.dllp_valid.eq(0)),
        ]
        self.fsm = fsm = FSM(reset_state="DL-INACTIVE")
        fsm.act("DL-INACTIVE",
            self.state.eq(0),
            NextValue(fc_init_type, 0),
            If(self.link_up,
                NextState("DL-INIT-FC1")
            )
        )
        # FC_INIT1: InitFC1-P/NP/Cpl until InitFC1 or InitFC2 received for the three types.
        fsm.act("DL-INIT-FC1",
            self.state.eq(1),
            dllp_req.eq(self.l0),
            encoder.type.eq(DLLP_INITFC1_P | (fc_init_type << 4)),
            encoder.hdr_fc.eq(initial_hdr[fc_init_type]),
            encoder.data_fc.eq(initial_data[fc_init_type]),
            If(dllp_taken, NextValue(fc_init_type, fc_init_type_n)),
            If(~self.link_up,
                NextState("DL-INACTIVE")
            ).Elif(init1_rx == 0b111,
                NextValue(fc_init_type, 0),
                NextState("DL-INIT-FC2")
            )
        )
        # FC_INIT2: InitFC2-P/NP/Cpl until InitFC2 received for the three types, or any UpdateFC
        # or TLP received.
        fsm.act("DL-INIT-FC2",
            self.state.eq(2),
            dllp_req.eq(self.l0),
            encoder.type.eq(DLLP_INITFC2_P | (fc_init_type << 4)),
            encoder.hdr_fc.eq(initial_hdr[fc_init_type]),
            encoder.data_fc.eq(initial_data[fc_init_type]),
            If(dllp_taken, NextValue(fc_init_type, fc_init_type_n)),
            If(~self.link_up,
                NextState("DL-INACTIVE")
            ).Elif((init2_rx == 0b111) | update_rx | rx.ack_req,
                NextState("DL-ACTIVE")
            )
        )
        fsm.act("DL-ACTIVE",
            self.state.eq(3),
            self.dl_active.eq(1),
            tx.enable.eq(1),
            # DLLP priorities: Nak, Ack, UpdateFC.
            If(nak_pending,
                dllp_req.eq(self.l0),
                encoder.type.eq(DLLP_NAK),
                nak_taken.eq(dllp_taken),
            ).Elif(ack_pending,
                dllp_req.eq(self.l0),
                encoder.type.eq(DLLP_ACK),
                ack_taken.eq(dllp_taken),
            ).Elif(update_req,
                dllp_req.eq(self.l0),
                encoder.type.eq(DLLP_UPDATEFC_P | (update_type << 4)),
                encoder.hdr_fc.eq(fc_rx.allocated_hdr[update_type]),
                encoder.data_fc.eq(fc_rx.allocated_data[update_type]),
                fc_rx_sent.eq(dllp_taken),
            ),
            If(~self.link_up,
                NextState("DL-INACTIVE")
            )
        )
