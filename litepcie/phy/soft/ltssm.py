#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY Link Training and Status State Machine (PCIe Base 4.2.6), 2.5/5.0/8.0 GT/s.

States: Detect.Quiet/Active, Polling.Active/Configuration, Configuration.Linkwidth.Start/Accept,
Configuration.Lanenum.Wait/Accept, Configuration.Complete/Idle, L0, Recovery.RcvrLock/RcvrCfg/Idle,
Hot Reset and Disabled, for the upstream (endpoint) and downstream (root) roles, Recovery.Speed with
gen2_capable, Recovery.Equalization with gen3_capable (phases and their transitions here, presets and
coefficients per lane in the Physical Layer). Not implemented (back to Detect): Polling.Compliance,
Loopback, L0s/L1/L2.

The LTSSM runs in the "pcie_link" clock domain (fixed frequency: timers) and drives the Physical
Layer (pipe.py) through LTSSM_PIPE_INTERFACE: Training Sequence transmission/reception with their
fields, Logical Idle handshake, Electrical Idle, receiver detection, polarity. `state` follows the
Xilinx UltraScale LTSSM encoding (bench/test_ltssm_tracer.py, L0 = 0x10).
"""

from functools import reduce

from migen import *
from migen.genlib.misc import WaitTimer

from litex.gen import *

from litepcie.phy.soft.common import RATE_2_5GT, RATE_5_0GT, RATE_8_0GT, RATE_SPEED_CHANGE
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
    ("tx_ts_rate",        8, "o"),
    ("tx_ts_ctrl",        8, "o"),
    ("tx_ts_eq_info",     8, "o"), # Symbol 6: at 2.5/5.0 GT/s EQ TS2 (bit 7 set, downstream role), at
                                   # 8.0 GT/s the EC (bits 1:0), the PHY adds each lane's preset/coefficients.
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
    ("rx_ts_rate",        8, "i"),
    ("rx_ts_ctrl",        8, "i"),
    ("rx_ts_eq_info",     8, "i"), # Symbol 6: EQ TS2 (0: standard TS2), at 8.0 GT/s the TS1 one (EC: bits 1:0).
    ("eq_eval_done",      1, "i"), # Recovery.Equalization: the lanes' requests evaluated (requesting phase).
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
    "Recovery.Equalization.Phase0"  : 0x2c,
    "Recovery.Equalization.Phase1"  : 0x2d,
    "Recovery.Equalization.Phase2"  : 0x2e,
    "Recovery.Equalization.Phase3"  : 0x2f,
}

# LTSSM --------------------------------------------------------------------------------------------

@ResetInserter()
class PCIeLTSSM(LiteXModule):
    """Link Training and Status State Machine (4.2.6).

    upstream: endpoint role (Link/Lane numbers assigned by the partner), else downstream/root role
    (link_number proposed, Lane 0). timer_scale divides the timeouts (simulation acceleration).
    """
    def __init__(self, clk_freq, upstream=True, with_timers=True, timer_scale=1, gen2_capable=False,
        gen3_capable=False, ts1_min=1024, eq_ts2=0x80 | (7 << 3), eq_phases23=True):
        self.upstream = upstream
        gen2_capable  = gen2_capable or gen3_capable

        # PIPE interface.
        for name, width, direction in LTSSM_PIPE_INTERFACE:
            setattr(self, name, Signal(width, name=name))

        # Controls.
        self.enable      = Signal(reset=1)    # i: Held in Detect.Quiet when cleared.
        self.retrain     = Signal()           # i (Pulse): Directed Recovery (Link Retrain).
        self.hot_reset_req = Signal()         # i (Level, downstream): Directed Hot Reset (through Recovery).
        self.link_error  = Signal()           # i (Pulse): Data Link Layer error requiring Recovery.
        self.link_number = Signal(8)          # i (downstream): Link Number proposed.
        self.speed_change = Signal()          # i (Pulse): Directed speed change (gen2_capable).
        self.rate_done   = Signal(reset=1)    # i: Link rate change applied (gen2_capable).
        self.lanes_locked = Signal(reset=1)   # i: Multi-lane: all the lanes deskewed (the Training Sequences
                                              # followed are the ones of Lane 0).

        # Status.
        self.state       = Signal(6)  # o: LTSSM state (LTSSM_STATES).
        self.l0          = Signal()   # o: In L0.
        self.link_up     = Signal()   # o: Configuration done (L0 or Recovery).
        self.hot_reset   = Signal()   # o: In Hot Reset.
        self.disabled    = Signal()   # o: In Disabled.
        self.link        = Signal(8)  # o: Negotiated Link Number.
        self.lane        = Signal(5)  # o: Our Lane Number.
        self.rx_rate     = Signal(8)  # o: Partner Data Rate Identifier.
        self.rate        = Signal(2)  # o: Link rate (0: 2.5 GT/s, 1: 5.0 GT/s, 2: 8.0 GT/s).
        self.eq_done     = Signal()   # o: equalization_done_8GT_data_rate.
        self.select_deemph = Signal() # o: De-emphasis at 5.0 GT/s (0: -6 dB, 1: -3.5 dB).
        self.tx_eieos_reset = Signal() # o (Pulse): EIEOS interval restarted (first TS2 received).
        self.in_training = Signal()   # o: Detect or Polling: the lanes of the Link aren't known.
        self.in_config   = Signal()   # o: Configuration: the lanes of the Link are being negotiated.

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
        tx_after_r = Signal(6)
        # Values seen by the state conditions: already cleared on the first cycle of a state.
        rx_count   = Signal(4)
        tx_count   = Signal(max=max(ts1_min, 2) + 1)
        rx_seen    = Signal()
        tx_after   = Signal(6)
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
                    If(rx_seen_r & (tx_after_r != 63), tx_after_r.eq(tx_after_r + 1)),
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
            self.rx_rate.eq(self.rx_ts_rate),
        )
        rx_params_ok = Signal()
        self.comb += rx_params_ok.eq((rx_count == 0) | (self.rx_ts_rate == self.rx_rate))

        # RX polarity: inverted identifiers received (Polling.Active) toggle the polarity, held for
        # the inversion to take effect on the received stream.
        polarity_hold = WaitTimer(scaled(2e-6))
        self.submodules += polarity_hold
        polarity_check = self.polarity_check = Signal()
        self.comb += polarity_hold.wait.eq(1)
        self.sync += If(polarity_check & self.rx_ts & self.rx_ts_inverted & polarity_hold.done,
            self.rx_polarity.eq(~self.rx_polarity),
        )
        self.comb += If(polarity_check & self.rx_ts & self.rx_ts_inverted & polarity_hold.done,
            polarity_hold.wait.eq(0)
        )

        # Speed change variables (4.2.6.4): directed_speed_change, changed_speed_recovery,
        # successful_speed_negotiation, rate at the entry to Recovery from L0, rate after Recovery.Speed.
        directed   = Signal()
        changed    = Signal()
        successful = Signal()
        entry_rate = Signal(2)
        next_rate  = Signal(2)
        rx_speed   = (self.rx_ts_rate & RATE_SPEED_CHANGE) != 0

        # Common TX fields.
        self.comb += [
            self.tx_ts_rate.eq(RATE_2_5GT | (RATE_5_0GT if gen2_capable else 0) | (RATE_8_0GT if gen3_capable else 0) |
                Mux(directed, RATE_SPEED_CHANGE, 0)),
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
            If(self.enable & self.rate_done & (quiet_count == 2*rx_reset_cycles) & (done | ~self.rx_elecidle),
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
            If((rx_count >= 8) & (tx_count >= ts1_min) & self.lanes_locked,
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
            If((rx_count >= 8) & (tx_after >= 16) & self.lanes_locked,
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
            ),
            *([If(self.speed_change & (((self.rx_rate & RATE_5_0GT != 0) & (self.rate == 0)) |
                ((self.rx_rate & RATE_8_0GT != 0) & (self.rate != 2) if gen3_capable else 0)),
                NextValue(directed, 1),
                NextState("Recovery.RcvrLock")
            )] if gen2_capable else [])
        )

        # Recovery (4.2.6.5). rx_speed_count: Training Sequences with our numbers and the speed_change
        # bit set; last_*: fields of the last one received.
        rx_speed_count = Signal(4)
        rx_any_match   = Signal()
        last_speed     = Signal()
        last_hi        = Signal() # Partner supports a rate above 2.5 GT/s.
        rx_ts2_seen    = Signal()
        numbers_ok     = rx_link_ok & rx_lane_ok
        if gen2_capable:
            self.sync += [
                If(state_changed,
                    rx_speed_count.eq(0),
                    rx_any_match.eq(0),
                    rx_ts2_seen.eq(0),
                ).Elif(self.rx_ts,
                    If(numbers_ok & rx_speed,
                        If(rx_speed_count != 15, rx_speed_count.eq(rx_speed_count + 1))
                    ).Else(
                        rx_speed_count.eq(0)
                    ),
                    If(numbers_ok, rx_any_match.eq(1)),
                    If(ts2, rx_ts2_seen.eq(1)),
                ),
                If(self.rx_ts,
                    last_speed.eq(rx_speed),
                    last_hi.eq((self.rx_ts_rate & (RATE_5_0GT | RATE_8_0GT)) != 0),
                ),
                If(fsm.ongoing("L0"),
                    changed.eq(0),
                    entry_rate.eq(self.rate),
                ),
                # Variables reset by Detect (hot plug: partner's rates unknown, back to 2.5 GT/s).
                If(fsm.ongoing("Detect.Quiet"),
                    directed.eq(0),
                    changed.eq(0),
                    self.rate.eq(0),
                    self.select_deemph.eq(0),
                    self.eq_done.eq(0),
                ),
                # directed_speed_change also set by eight consecutive requests of the partner.
                If(fsm.ongoing("Recovery.RcvrLock") & ~state_changed & (rx_speed_count >= 8),
                    directed.eq(1)
                ),
                # EIEOS interval restarted by the first TS2 received in Recovery.RcvrCfg.
                self.tx_eieos_reset.eq(fsm.ongoing("Recovery.RcvrCfg") & self.rx_ts & ts2 & ~rx_ts2_seen),
            ]
        # Recovery.Equalization (4.2.6.4.2): consecutive TS1 with our numbers and the same EC (last one: rx_ec).
        rx_ec       = self.rx_ts_eq_info[0:2]
        rx_ec_last  = Signal(2)
        rx_ec_count = Signal(4)
        eq_entry    = Signal() # Downstream: equalization to start in Recovery.RcvrLock (new 8.0 GT/s rate).
        if gen3_capable:
            self.sync += [
                If(state_changed,
                    rx_ec_count.eq(0),
                ).Elif(self.rx_ts,
                    If(ts1 & numbers_ok & ~rx_speed,
                        rx_ec_last.eq(rx_ec),
                        If((rx_ec != rx_ec_last) | (rx_ec_count == 0),
                            rx_ec_count.eq(1)
                        ).Elif(rx_ec_count != 15,
                            rx_ec_count.eq(rx_ec_count + 1)
                        )
                    ).Else(
                        rx_ec_count.eq(0)
                    )
                ),
            ]
        def rx_ec_seen(ec, n):
            return (rx_ec_count >= n) & (rx_ec_last == ec)
        wait, done = timeout(24e-3)
        act("Recovery.RcvrLock",
            self.tx_ts_enable.eq(1),
            tx_link_ok.eq(1),
            tx_lane_ok.eq(1),
            NextValue(successful, 0),
            # At 8.0 GT/s, TS1 with an EC of 00b only (4.2.6.4.1).
            match.eq(numbers_ok & (rx_speed == directed if gen2_capable else 1) &
                ((self.rate != 2) | ts2 | (rx_ec == 0) if gen3_capable else 1)),
            *wait,
            *([If(self.rate == 2,
                # Upstream: eight TS1 with an EC (the downstream port in Phase 1). Downstream: after the
                # change to 8.0 GT/s (no more than 2 TS1 with EC 00b before).
                If((rx_ec_count >= 8) & (rx_ec_last != 0) if upstream else eq_entry,
                    NextValue(eq_entry, 0),
                    NextValue(self.eq_done, 1),
                    NextState("Recovery.Equalization.Phase0" if upstream else "Recovery.Equalization.Phase1")
                )
            )] if gen3_capable else []),
            # The partner keeps sending TS1 until it receives our TS2: time for the other lanes.
            If((rx_count >= 8) & self.lanes_locked & ~(eq_entry if gen3_capable else 0),
                NextState("Recovery.RcvrCfg")
            ).Elif(done,
                *([
                If((rx_speed_count >= 8) & ((self.rate != 0) | last_hi),
                    NextState("Recovery.RcvrCfg")
                ).Elif(~changed & (self.rate != 0),
                    # Unable to operate at the current rate: back to 2.5 GT/s.
                    NextValue(next_rate, 0),
                    NextState("Recovery.Speed")
                ).Elif(changed,
                    # Unable to operate at the negotiated rate: back to the entry rate.
                    NextValue(next_rate, entry_rate),
                    NextState("Recovery.Speed")
                ).Elif(rx_any_match & ((~directed & ~last_speed) | ((self.rate == 0) & ~last_hi)),
                    NextState("Configuration.Linkwidth.Start")
                ).Else(
                    NextState("Detect.Quiet")
                )] if gen2_capable else [NextState("Detect.Quiet")])
            )
        )
        wait, done = timeout(48e-3)
        speed_ok = self.rx_rate[7] & ((self.rate != 0) | self.rx_rate[2])
        # Eight TS2 requesting the speed change, remembered: the partner can leave for Electrical Idle
        # while the 32 TS2 we have to send after its first one are still going.
        speed_seen = Signal()
        if gen2_capable:
            self.sync += If(state_changed,
                speed_seen.eq(0)
            ).Elif(fsm.ongoing("Recovery.RcvrCfg") & (rx_count >= 8) & speed_ok,
                speed_seen.eq(1)
            )
        act("Recovery.RcvrCfg",
            self.tx_ts_enable.eq(1),
            self.tx_ts2.eq(1),
            *([If(directed & (self.rate != 2) & ~self.eq_done & (self.rx_rate & RATE_8_0GT != 0),
                self.tx_ts_eq_info.eq(eq_ts2)
            )] if gen3_capable and not upstream else []),
            tx_link_ok.eq(1),
            tx_lane_ok.eq(1),
            capture.eq(1),
            match.eq(ts2 & numbers_ok & rx_params_ok),
            *wait,
            *([
            If(speed_seen & (tx_after >= 32),
                # Highest common rate, de-emphasis selected by the root port's TS2.
                NextValue(next_rate, Mux(self.rx_rate[3] if gen3_capable else 0, 2, self.rx_rate[2])),
                NextValue(successful, 1),
                NextValue(self.select_deemph, self.rx_rate[6] if upstream else 0),
                NextState("Recovery.Speed")
            ).Elif((rx_count >= 8) & ~speed_ok & (tx_after >= 16),
                NextValue(changed, 0),
                NextState("Recovery.Idle")
            ).Elif((changed | self.rate) & (self.rx_eios | self.rx_elecidle) & ~rx_ts2_seen,
                # The partner could not achieve Symbol lock at this rate.
                NextValue(next_rate, Mux(changed, entry_rate, 0)),
                NextState("Recovery.Speed")
            ).Elif(done,
                NextState("Detect.Quiet")
            )] if gen2_capable else [
            If((rx_count >= 8) & (tx_after >= 16),
                NextState("Recovery.Idle")
            ).Elif(done,
                NextState("Detect.Quiet")
            )])
        )
        if gen2_capable:
            # Electrical Idle (EIOS first), at least 800 ns or 6 us on an unsuccessful negotiation,
            # rate changed once the receiver is in Electrical Idle (inferred without Training Sequence
            # for 1280 UI, or after the unsuccessful minimum), the transceivers report the new rate.
            speed_count  = Signal(max=max(int(6e-6*clk_freq), 2) + 1)
            speed_min_s  = int(800e-9*clk_freq)
            speed_min_u  = int(6e-6*clk_freq)
            rx_gap       = Signal(max=max(int(512e-9*clk_freq), 2) + 1)
            rx_gap_max   = int(512e-9*clk_freq)
            rx_idle      = Signal()
            rate_applied = Signal()
            rate_guard   = Signal(3)
            self.sync += [
                If(state_changed,
                    speed_count.eq(0),
                    rx_gap.eq(0),
                    rx_idle.eq(0),
                    rate_applied.eq(0),
                    rate_guard.eq(0),
                ).Elif(fsm.ongoing("Recovery.Speed"),
                    If(speed_count != speed_min_u, speed_count.eq(speed_count + 1)),
                    If(self.rx_ts,
                        rx_gap.eq(0)
                    ).Elif(rx_gap != rx_gap_max,
                        rx_gap.eq(rx_gap + 1)
                    ),
                    If(self.rx_eios | self.rx_elecidle | (rx_gap == rx_gap_max),
                        rx_idle.eq(1)
                    ),
                    If(rate_applied & (rate_guard != 7),
                        rate_guard.eq(rate_guard + 1)
                    ),
                )
            ]
            speed_min_done = Mux(successful, speed_count >= speed_min_s, speed_count == speed_min_u)
            wait, done = timeout(48e-3)
            act("Recovery.Speed",
                self.tx_elecidle.eq(1),
                *wait,
                If(speed_min_done & (rx_idle | ~successful) & ~rate_applied,
                    NextValue(self.rate, next_rate),
                    NextValue(rate_applied, 1)
                ),
                If((rate_guard == 7) & self.rate_done,
                    NextValue(directed, 0),
                    NextValue(changed, successful),
                    *([NextValue(eq_entry, successful & (self.rate == 2) & ~self.eq_done)] if gen3_capable and not upstream else []),
                    NextState("Recovery.RcvrLock")
                ).Elif(done,
                    NextState("Detect.Quiet")
                )
            )
        if gen3_capable:
            # Phases (upstream 0 to 3, downstream 1 to 3), TS1 with the phase's EC. Requesting phase (upstream 2,
            # downstream 3): the lanes' requests evaluated (eq_eval_done, 1 us at least per request). Timeouts:
            # unsuccessful, back through Recovery.Speed to the rate of the entry in Recovery.
            def phase(n, ec, t, *transitions):
                wait, done = timeout(t)
                hold, held = timeout(2e-6)
                act(f"Recovery.Equalization.Phase{n}",
                    self.tx_ts_enable.eq(1),
                    tx_link_ok.eq(1),
                    tx_lane_ok.eq(1),
                    self.tx_ts_eq_info.eq(ec),
                    *wait, *hold,
                    reduce(lambda a, t: a.Elif(*t(held)), transitions[1:], If(*transitions[0](held))).Elif(done,
                        NextValue(successful, 0),
                        NextValue(next_rate, Mux(changed, entry_rate, 0)),
                        NextState("Recovery.Speed")
                    )
                )
            requested = lambda held: held & self.eq_eval_done
            if upstream:
                phase(0, 0b00, 12e-3,
                    lambda held: (rx_ec_seen(0b01, 2), NextState("Recovery.Equalization.Phase1")))
                phase(1, 0b01, 12e-3,
                    lambda held: (rx_ec_seen(0b10, 2), NextState("Recovery.Equalization.Phase2")),
                    lambda held: (rx_ec_seen(0b00, 8), NextState("Recovery.RcvrLock")))
                phase(2, 0b10, 24e-3,
                    lambda held: (requested(held) & rx_ec_seen(0b10, 2), NextState("Recovery.Equalization.Phase3")))
                phase(3, 0b11, 32e-3,
                    lambda held: (rx_ec_seen(0b00, 2), NextState("Recovery.RcvrLock")))
            else:
                phase(1, 0b01, 24e-3,
                    lambda held: (rx_ec_seen(0b01, 2),
                        NextState("Recovery.Equalization.Phase2" if eq_phases23 else "Recovery.RcvrLock")))
                phase(2, 0b10, 32e-3,
                    lambda held: (rx_ec_seen(0b11, 2), NextState("Recovery.Equalization.Phase3")))
                phase(3, 0b11, 24e-3,
                    lambda held: (requested(held) & rx_ec_seen(0b11, 2), NextState("Recovery.RcvrLock")))

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

        # Link width negotiation phases.
        self.comb += [
            self.in_training.eq(Reduce("OR", [fsm.ongoing(s) for s in
                ["Detect.Quiet", "Detect.Active", "Polling.Active", "Polling.Configuration"]])),
            self.in_config.eq(Reduce("OR", [fsm.ongoing(s) for s in
                ["Configuration.Linkwidth.Start", "Configuration.Linkwidth.Accept", "Configuration.Lanenum.Wait",
                 "Configuration.Lanenum.Accept", "Configuration.Complete", "Configuration.Idle"]])),
        ]

        # Link up: Configuration done.
        self.comb += self.link_up.eq(Reduce("OR", [fsm.ongoing(s) for s in
            ["L0", "Recovery.RcvrLock", "Recovery.RcvrCfg", "Recovery.Idle"] + (["Recovery.Speed"] if gen2_capable else []) +
            ([f"Recovery.Equalization.Phase{n}" for n in (range(4) if upstream else range(1, 4))] if gen3_capable else [])]))
