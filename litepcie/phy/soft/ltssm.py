#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY Link Training and Status State Machine (PCIe Base 4.2.6), 2.5 GT/s, x1.

States: Detect.Quiet/Active, Polling.Active/Configuration, Configuration.Linkwidth.Start/Accept,
Configuration.Lanenum.Wait/Accept, Configuration.Complete/Idle, L0, Recovery.RcvrLock/RcvrCfg/Idle,
Hot Reset and Disabled, for the upstream (endpoint) and downstream (root) roles. Not implemented
(back to Detect): Polling.Compliance, Loopback, L0s/L1/L2, speed change (later milestones).

The LTSSM runs in the "pcie_link" clock domain (fixed frequency: timers) and drives the Physical
Layer (pipe.py) through LTSSM_PIPE_INTERFACE: Training Sequence transmission/reception with their
fields, Logical Idle handshake, Electrical Idle, receiver detection, polarity. `state` follows the
Xilinx UltraScale LTSSM encoding (bench/test_ltssm_tracer.py, L0 = 0x10).
"""

from migen import *
from migen.genlib.misc import WaitTimer

from litex.gen import *

from litepcie.phy.soft.common import RATE_2_5GT, RATE_5_0GT
from litepcie.phy.soft.common import CTRL_HOT_RESET, CTRL_DISABLE_LINK, CTRL_LOOPBACK, CTRL_COMPLIANCE_RECEIVE

# LTSSM <-> PIPE Interface -------------------------------------------------------------------------

# (name, width, direction from the LTSSM: "o": LTSSM -> PIPE, "i": PIPE -> LTSSM). Levels unless
# noted (Pulse). Both sides declare these signals, the PHY connects them (connect_ltssm_pipe).
LTSSM_PIPE_INTERFACE = [
    # TX.
    ("tx_elecidle",       1, "o"), # TX Electrical Idle (the PIPE sends an EIOS first).
    ("tx_ts_enable",      1, "o"), # Training Sequences transmission.
    ("tx_ts2",            1, "o"), # TS2 (0: TS1).
    ("tx_ts_link",        8, "o"), # Transmitted Link Number...
    ("tx_ts_link_pad",    1, "o"), # ...or PAD.
    ("tx_ts_lane",        5, "o"), # Transmitted Lane Number...
    ("tx_ts_lane_pad",    1, "o"), # ...or PAD.
    ("tx_ts_n_fts",       8, "o"),
    ("tx_ts_rate",        8, "o"),
    ("tx_ts_ctrl",        8, "o"),
    ("tx_ts_done",        1, "i"), # (Pulse) One Training Sequence transmitted.
    ("tx_data_enable",    1, "o"), # Data Link Layer packets transmission allowed (L0).
    ("rx_data_enable",    1, "o"), # Received packets delivered to the Data Link Layer (L0).
    # Logical Idle handshake (Configuration.Idle/Recovery.Idle): the PIPE transmits Logical Idle and
    # reports 8 consecutive Idle Symbols received then 16 transmitted after the first ones.
    ("idle_hs",           1, "o"), # Logical Idle handshake in progress.
    ("idle_hs_done",      1, "i"), # Logical Idle handshake completed (while idle_hs).
    # RX.
    ("rx_ts",             1, "i"), # (Pulse) Training Sequence received, with the fields:
    ("rx_ts_ts2",         1, "i"),
    ("rx_ts_link",        8, "i"),
    ("rx_ts_link_pad",    1, "i"),
    ("rx_ts_lane",        5, "i"),
    ("rx_ts_lane_pad",    1, "i"),
    ("rx_ts_n_fts",       8, "i"),
    ("rx_ts_rate",        8, "i"),
    ("rx_ts_ctrl",        8, "i"),
    ("rx_ts_inverted",    1, "i"), # Received with inverted identifiers (lane polarity).
    ("rx_ts_error",       1, "i"), # (Pulse) Corrupted Training Sequence.
    ("rx_eios",           1, "i"), # (Pulse) EIOS received.
    ("rx_elecidle",       1, "i"), # RX Electrical Idle.
    ("rx_detected",       1, "i"), # Receiver detected (with detect_done).
    ("detect_done",       1, "i"), # (Pulse) Receiver detection done.
    ("tx_detect_rx",      1, "o"), # (Pulse) Receiver detection request.
    ("rx_polarity",       1, "o"), # RX polarity inversion.
    ("rx_reset",          1, "o"), # RX re-initialization (link down).
    ("scrambling_enable", 1, "o"),
    ("skp_enable",        1, "o"),
]

# States (Xilinx UltraScale encoding) --------------------------------------------------------------

LTSSM_STATES = {
    "Detect.Quiet"                  : 0x00,
    "Detect.Active"                 : 0x01,
    "Polling.Active"                : 0x02,
    "Polling.Compliance"            : 0x03,
    "Polling.Configuration"         : 0x04,
    "Configuration.Linkwidth.Start" : 0x05,
    "Configuration.Linkwidth.Accept": 0x06,
    "Configuration.Lanenum.Accept"  : 0x07,
    "Configuration.Lanenum.Wait"    : 0x08,
    "Configuration.Complete"        : 0x09,
    "Configuration.Idle"            : 0x0a,
    "Recovery.RcvrLock"             : 0x0b,
    "Recovery.Speed"                : 0x0c,
    "Recovery.RcvrCfg"              : 0x0d,
    "Recovery.Idle"                 : 0x0e,
    "L0"                            : 0x10,
    "Disabled"                      : 0x20,
    "Hot_Reset"                     : 0x27,
}

# LTSSM --------------------------------------------------------------------------------------------

@ResetInserter()
class PCIeLTSSM(LiteXModule):
    """Link Training and Status State Machine (4.2.6).

    upstream: endpoint role (Link/Lane numbers assigned by the partner), else downstream/root role
    (link_number proposed, Lane 0). timer_scale divides the timeouts (simulation acceleration).
    """
    def __init__(self, clk_freq, upstream=True, with_timers=True, timer_scale=1, gen2_capable=False,
        ts1_min=1024):
        self.upstream = upstream

        # PIPE interface.
        for name, width, direction in LTSSM_PIPE_INTERFACE:
            setattr(self, name, Signal(width, name=name))

        # Controls.
        self.enable      = Signal(reset=1)    # i: Held in Detect.Quiet when cleared.
        self.retrain     = Signal()           # i (Pulse): Directed Recovery (Link Retrain).
        self.hot_reset_req = Signal()         # i (Level, downstream): Directed Hot Reset (through Recovery).
        self.link_error  = Signal()           # i (Pulse): Data Link Layer error requiring Recovery.
        self.link_number = Signal(8)          # i (downstream): Link Number proposed.
        self.n_fts       = Signal(8, reset=0xff) # i: N_FTS advertised.

        # Status.
        self.state       = Signal(6)  # o: LTSSM state (LTSSM_STATES).
        self.l0          = Signal()   # o: In L0.
        self.link_up     = Signal()   # o: Configuration done (L0 or Recovery).
        self.hot_reset   = Signal()   # o: In Hot Reset.
        self.disabled    = Signal()   # o: In Disabled.
        self.link        = Signal(8)  # o: Negotiated Link Number.
        self.lane        = Signal(5)  # o: Our Lane Number.
        self.rx_n_fts    = Signal(8)  # o: Partner N_FTS.
        self.rx_rate     = Signal(8)  # o: Partner Data Rate Identifier.

        # # #

        scaled = lambda t: max(1, int(t*clk_freq)//timer_scale)

        # State change detection (counters/timers restart).
        state_r       = Signal(6, reset=0x3f)
        state_changed = Signal()
        self.sync += state_r.eq(self.state)
        self.comb += state_changed.eq(self.state != state_r)

        # Timers (shared by states, restarted on state changes).
        timers = {}
        def timeout(t):
            if t not in timers:
                timer = WaitTimer(scaled(t))
                self.submodules += timer
                timers[t] = timer
            timer = timers[t]
            return [timer.wait.eq(with_timers & ~state_changed)], timer.done

        # Counters, restarted on state changes:
        # - rx_count: consecutive Training Sequences matching the state's expectation (match).
        # - tx_count: Training Sequences transmitted.
        # - rx_seen/tx_after: first match received, Training Sequences transmitted after it.
        match      = Signal() # Current received Training Sequence matches (comb, per state).
        rx_count_r = Signal(4)
        tx_count_r = Signal(max=max(ts1_min, 2) + 1)
        rx_seen_r  = Signal()
        tx_after_r = Signal(5)
        # Values seen by the state conditions: already cleared on the first cycle of a state.
        rx_count   = Signal(4)
        tx_count   = Signal(max=max(ts1_min, 2) + 1)
        rx_seen    = Signal()
        tx_after   = Signal(5)
        self.comb += [
            rx_count.eq(Mux(state_changed, 0, rx_count_r)),
            tx_count.eq(Mux(state_changed, 0, tx_count_r)),
            rx_seen.eq( Mux(state_changed, 0, rx_seen_r)),
            tx_after.eq(Mux(state_changed, 0, tx_after_r)),
        ]
        self.sync += [
            If(state_changed,
                rx_count_r.eq(0),
                tx_count_r.eq(0),
                rx_seen_r.eq(0),
                tx_after_r.eq(0),
            ).Else(
                If(self.rx_ts,
                    If(match,
                        If(rx_count_r != 15, rx_count_r.eq(rx_count_r + 1)),
                        rx_seen_r.eq(1),
                    ).Else(
                        rx_count_r.eq(0)
                    )
                ),
                If(self.rx_ts_error,
                    rx_count_r.eq(0)
                ),
                If(self.tx_ts_done,
                    If(tx_count_r != ts1_min, tx_count_r.eq(tx_count_r + 1)),
                    If(rx_seen_r & (tx_after_r != 31), tx_after_r.eq(tx_after_r + 1)),
                ),
            )
        ]

        # Received Training Sequence helpers.
        rx_pad_pad   = Signal()
        rx_link_ok   = Signal() # Link Number is the negotiated/proposed one.
        rx_lane_ok   = Signal() # Lane Number is ours.
        rx_hot_reset = Signal()
        rx_disable   = Signal()
        rx_loopback  = Signal()
        rx_compl     = Signal()
        self.comb += [
            rx_pad_pad.eq(self.rx_ts_link_pad & self.rx_ts_lane_pad),
            rx_link_ok.eq(~self.rx_ts_link_pad & (self.rx_ts_link == self.link)),
            rx_lane_ok.eq(~self.rx_ts_lane_pad & (self.rx_ts_lane == self.lane)),
            rx_hot_reset.eq((self.rx_ts_ctrl & CTRL_HOT_RESET) != 0),
            rx_disable.eq((self.rx_ts_ctrl & CTRL_DISABLE_LINK) != 0),
            rx_loopback.eq((self.rx_ts_ctrl & CTRL_LOOPBACK) != 0),
            rx_compl.eq((self.rx_ts_ctrl & CTRL_COMPLIANCE_RECEIVE) != 0),
        ]
        ts1 = ~self.rx_ts_ts2
        ts2 =  self.rx_ts_ts2

        # Partner parameters capture (Configuration.Complete, Recovery.RcvrCfg).
        capture = Signal()
        self.sync += If(self.rx_ts & capture,
            self.rx_n_fts.eq(self.rx_ts_n_fts),
            self.rx_rate.eq(self.rx_ts_rate),
        )
        rx_params_ok = Signal()
        self.comb += rx_params_ok.eq((rx_count == 0) |
            ((self.rx_ts_n_fts == self.rx_n_fts) & (self.rx_ts_rate == self.rx_rate)))

        # RX polarity: inverted identifiers received (Polling.Active) toggle the polarity, held for
        # the inversion to take effect on the received stream.
        polarity_hold = WaitTimer(scaled(2e-6))
        self.submodules += polarity_hold
        polarity_check = Signal()
        self.comb += polarity_hold.wait.eq(1)
        self.sync += If(polarity_check & self.rx_ts & self.rx_ts_inverted & polarity_hold.done,
            self.rx_polarity.eq(~self.rx_polarity),
        )
        self.comb += If(polarity_check & self.rx_ts & self.rx_ts_inverted & polarity_hold.done,
            polarity_hold.wait.eq(0)
        )

        # Common TX fields.
        self.comb += [
            self.tx_ts_n_fts.eq(self.n_fts),
            self.tx_ts_rate.eq(RATE_2_5GT | (RATE_5_0GT if gen2_capable else 0)),
            self.scrambling_enable.eq(1),
            self.skp_enable.eq(1),
        ]
        tx_link    = Signal(8)
        tx_link_ok = Signal() # Transmit the Link Number (else PAD).
        tx_lane_ok = Signal() # Transmit the Lane Number (else PAD).
        self.comb += [
            self.tx_ts_link.eq(self.link),
            self.tx_ts_link_pad.eq(~tx_link_ok),
            self.tx_ts_lane.eq(self.lane),
            self.tx_ts_lane_pad.eq(~tx_lane_ok),
        ]

        # FSM --------------------------------------------------------------------------------------
        self.fsm = fsm = FSM(reset_state="Detect.Quiet")

        def act(name, *statements):
            fsm.act(name, self.state.eq(LTSSM_STATES[name]), *statements)

        # Detect (4.2.6.1).
        # The RX is re-initialized on entry (2 us pulse, a training failure can be a bad transceiver
        # init). enable depends on the transceivers being ready: held in the state for the status
        # of the re-initialization to be seen.
        rx_reset_cycles = max(4, int(2e-6*clk_freq))
        quiet_count = Signal(max=2*rx_reset_cycles + 1)
        self.sync += If(state_changed,
            quiet_count.eq(0)
        ).Elif(fsm.ongoing("Detect.Quiet") & (quiet_count != 2*rx_reset_cycles),
            quiet_count.eq(quiet_count + 1)
        )
        wait, done = timeout(12e-3)
        act("Detect.Quiet",
            self.tx_elecidle.eq(1),
            self.rx_reset.eq(quiet_count < rx_reset_cycles),
            *wait,
            If(self.enable & (quiet_count == 2*rx_reset_cycles) & (done | ~self.rx_elecidle),
                NextState("Detect.Active")
            )
        )
        act("Detect.Active",
            self.tx_elecidle.eq(1),
            self.tx_detect_rx.eq(state_changed),
            If(self.detect_done & ~state_changed,
                If(self.rx_detected,
                    NextState("Polling.Active")
                ).Else(
                    NextState("Detect.Quiet")
                )
            )
        )

        # Polling (4.2.6.2).
        wait, done = timeout(24e-3)
        act("Polling.Active",
            self.tx_ts_enable.eq(1),
            polarity_check.eq(1),
            match.eq(rx_pad_pad & ~rx_compl & ~rx_loopback),
            *wait,
            If((rx_count >= 8) & (tx_count >= ts1_min),
                NextState("Polling.Configuration")
            ).Elif(done,
                NextState("Detect.Quiet")
            )
        )
        wait, done = timeout(48e-3)
        act("Polling.Configuration",
            self.tx_ts_enable.eq(1),
            self.tx_ts2.eq(1),
            match.eq(ts2 & rx_pad_pad),
            *wait,
            If((rx_count >= 8) & (tx_after >= 16),
                NextState("Configuration.Linkwidth.Start")
            ).Elif(done,
                NextState("Detect.Quiet")
            )
        )

        # Configuration (4.2.6.3).
        wait, done = timeout(24e-3)
        if upstream:
            # Link Number from the partner.
            act("Configuration.Linkwidth.Start",
                self.tx_ts_enable.eq(1),
                match.eq(ts1 & ~self.rx_ts_link_pad & self.rx_ts_lane_pad &
                    ((rx_count == 0) | (self.rx_ts_link == self.link))),
                If(self.rx_ts & match, NextValue(self.link, self.rx_ts_link)),
                *wait,
                If(rx_count >= 2,
                    NextState("Configuration.Linkwidth.Accept")
                ).Elif(done,
                    NextState("Detect.Quiet")
                )
            )
        else:
            act("Configuration.Linkwidth.Start",
                self.tx_ts_enable.eq(1),
                tx_link_ok.eq(1),
                NextValue(self.link, self.link_number),
                NextValue(self.lane, 0),
                match.eq(ts1 & rx_link_ok & self.rx_ts_lane_pad),
                *wait,
                If(rx_count >= 2,
                    NextState("Configuration.Linkwidth.Accept")
                ).Elif(done,
                    NextState("Detect.Quiet")
                )
            )
        wait, done = timeout(2e-3)
        if upstream:
            # Lane Number from the partner.
            act("Configuration.Linkwidth.Accept",
                self.tx_ts_enable.eq(1),
                tx_link_ok.eq(1),
                match.eq(ts1 & rx_link_ok & ~self.rx_ts_lane_pad &
                    ((rx_count == 0) | (self.rx_ts_lane == self.lane))),
                If(self.rx_ts & match, NextValue(self.lane, self.rx_ts_lane)),
                *wait,
                If(rx_count >= 2,
                    NextState("Configuration.Lanenum.Wait")
                ).Elif(done,
                    NextState("Detect.Quiet")
                )
            )
            act("Configuration.Lanenum.Wait",
                self.tx_ts_enable.eq(1),
                tx_link_ok.eq(1),
                tx_lane_ok.eq(1),
                match.eq(ts2 & rx_link_ok & rx_lane_ok),
                *wait,
                If(rx_count >= 2,
                    NextState("Configuration.Lanenum.Accept")
                ).Elif(done,
                    NextState("Detect.Quiet")
                )
            )
            act("Configuration.Lanenum.Accept",
                self.tx_ts_enable.eq(1),
                tx_link_ok.eq(1),
                tx_lane_ok.eq(1),
                match.eq(ts2 & rx_link_ok & rx_lane_ok),
                *wait,
                If(rx_count >= 2,
                    NextState("Configuration.Complete")
                ).Elif(done,
                    NextState("Detect.Quiet")
                )
            )
        else:
            act("Configuration.Linkwidth.Accept",
                self.tx_ts_enable.eq(1),
                tx_link_ok.eq(1),
                tx_lane_ok.eq(1),
                match.eq(ts1 & rx_link_ok & ~self.rx_ts_lane_pad),
                *wait,
                If(rx_count >= 2,
                    NextState("Configuration.Lanenum.Wait")
                ).Elif(done,
                    NextState("Detect.Quiet")
                )
            )
            act("Configuration.Lanenum.Wait",
                self.tx_ts_enable.eq(1),
                tx_link_ok.eq(1),
                tx_lane_ok.eq(1),
                match.eq(ts1 & rx_link_ok & rx_lane_ok),
                *wait,
                If(rx_count >= 2,
                    NextState("Configuration.Lanenum.Accept")
                ).Elif(done,
                    NextState("Detect.Quiet")
                )
            )
            act("Configuration.Lanenum.Accept",
                self.tx_ts_enable.eq(1),
                tx_link_ok.eq(1),
                tx_lane_ok.eq(1),
                NextState("Configuration.Complete")
            )
        act("Configuration.Complete",
            self.tx_ts_enable.eq(1),
            self.tx_ts2.eq(1),
            tx_link_ok.eq(1),
            tx_lane_ok.eq(1),
            capture.eq(1),
            match.eq(ts2 & rx_link_ok & rx_lane_ok & rx_params_ok),
            *wait,
            If((rx_count >= 8) & (tx_after >= 16),
                NextState("Configuration.Idle")
            ).Elif(done,
                NextState("Detect.Quiet")
            )
        )
        act("Configuration.Idle",
            self.idle_hs.eq(1),
            tx_link_ok.eq(1),
            tx_lane_ok.eq(1),
            *wait,
            If(self.idle_hs_done & ~state_changed,
                NextState("L0")
            ).Elif(done,
                NextState("Detect.Quiet")
            )
        )

        # L0 (4.2.6.4).
        act("L0",
            self.l0.eq(1),
            self.tx_data_enable.eq(1),
            self.rx_data_enable.eq(1),
            If(self.rx_ts | self.retrain | self.link_error | self.rx_eios | self.rx_elecidle |
               self.hot_reset_req,
                NextState("Recovery.RcvrLock")
            )
        )

        # Recovery (4.2.6.5).
        wait, done = timeout(24e-3)
        act("Recovery.RcvrLock",
            self.tx_ts_enable.eq(1),
            tx_link_ok.eq(1),
            tx_lane_ok.eq(1),
            match.eq(rx_link_ok & rx_lane_ok),
            *wait,
            If(rx_count >= 8,
                NextState("Recovery.RcvrCfg")
            ).Elif(done,
                NextState("Detect.Quiet")
            )
        )
        wait, done = timeout(48e-3)
        act("Recovery.RcvrCfg",
            self.tx_ts_enable.eq(1),
            self.tx_ts2.eq(1),
            tx_link_ok.eq(1),
            tx_lane_ok.eq(1),
            capture.eq(1),
            match.eq(ts2 & rx_link_ok & rx_lane_ok & rx_params_ok),
            *wait,
            If((rx_count >= 8) & (tx_after >= 16),
                NextState("Recovery.Idle")
            ).Elif(done,
                NextState("Detect.Quiet")
            )
        )
        wait, done = timeout(2e-3)
        act("Recovery.Idle",
            self.idle_hs.eq(1),
            tx_link_ok.eq(1),
            tx_lane_ok.eq(1),
            match.eq(ts1 & (rx_pad_pad | rx_hot_reset | rx_disable)),
            *wait,
            If(self.hot_reset_req & ~upstream,
                NextState("Hot_Reset")
            ).Elif(self.idle_hs_done & ~state_changed,
                NextState("L0")
            ).Elif(rx_count >= 2,
                If(rx_hot_reset,
                    NextState("Hot_Reset")
                ).Elif(rx_disable,
                    NextState("Disabled")
                ).Else(
                    NextState("Configuration.Linkwidth.Start")
                )
            ).Elif(done,
                NextState("Detect.Quiet")
            )
        )

        # Hot Reset (4.2.6.11): Training Sequences with the Hot Reset bit (2 ms), then Detect.
        act("Hot_Reset",
            self.hot_reset.eq(1),
            self.tx_ts_enable.eq(1),
            tx_link_ok.eq(1),
            tx_lane_ok.eq(1),
            self.tx_ts_ctrl.eq(CTRL_HOT_RESET),
            *wait,
            If(done,
                NextState("Detect.Quiet")
            )
        )

        # Disabled (4.2.6.9): Electrical Idle until the partner exits Electrical Idle.
        act("Disabled",
            self.disabled.eq(1),
            self.tx_elecidle.eq(1),
            *wait,
            If(done & ~self.rx_elecidle,
                NextState("Detect.Quiet")
            )
        )

        # Link up: Configuration done.
        self.comb += self.link_up.eq(Reduce("OR", [fsm.ongoing(s) for s in
            ["L0", "Recovery.RcvrLock", "Recovery.RcvrCfg", "Recovery.Idle"]]))
