#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY debug CSRs (bring-up): LTSSM control/status, Training Sequence/error counters,
lane status and the LTSSM state tracer (LTSSMTracer, as the hard-IP PHYs).

The LTSSM runs in "pcie_link" and the lane in "pcie_pipe": levels are resynchronized to sys with
MultiReg (multi-bit counters sampled as they change: debug precision), pulses with PulseSynchronizer.
"""

from migen import *
from migen.genlib.cdc import MultiReg, PulseSynchronizer

from litex.gen import *

from litex.soc.interconnect.csr import *

from litepcie.phy.common      import LTSSMTracer
from litepcie.phy.soft.common import STP, SDP

# Soft PHY Debug -----------------------------------------------------------------------------------

class SoftPHYDebug(LiteXModule, AutoCSR):
    def __init__(self, phy, serdes, with_tracer=True, enable_reset=0, dll=None):
        lane  = serdes.lanes[0]
        ltssm = phy.ltssm

        self._control = CSRStorage(fields=[
            CSRField("enable",  size=1, offset=0, reset=enable_reset, description="LTSSM enable, write to apply. Without autostart (reset value), cleared by PERST#: a host reset comes back with the LTSSM disabled, so a design making a host hang cannot do it again at the next boot."),
            CSRField("retrain", size=1, offset=1, pulse=True, description="Link Retrain (Recovery)."),
            CSRField("speed_change", size=1, offset=2, pulse=True, description="Directed speed change, if the partner advertises a higher rate (Gen2 designs)."),
        ])
        if hasattr(phy, "lanes_ok"):
            self._lanes = CSRStatus(fields=[
                CSRField("ok",     size=8, offset=0, description="Lanes receiving Training Sequences with their Lane Number."),
                CSRField("locked", size=1, offset=8, description="Lanes deskewed."),
                CSRField("width",  size=5, offset=9, description="Negotiated link width."),
            ])
            self._lane_disable = CSRStorage(8, description="Lanes kept out of the link (Electrical Idle, receiver ignored).")
            self.comb += phy.lane_disable.eq(self._lane_disable.storage)
            self.specials += [
                MultiReg(phy.width,         self._lanes.fields.width,  "sys"),
                MultiReg(phy.lanes_ok,      self._lanes.fields.ok,     "sys"),
                MultiReg(phy.deskew.locked, self._lanes.fields.locked, "sys"),
            ]
        self._status = CSRStatus(fields=[
            CSRField("ltssm",        size=6, offset= 0, description="LTSSM state (Xilinx UltraScale encoding, L0 = 0x10)."),
            CSRField("l0",           size=1, offset= 8, description="LTSSM in L0."),
            CSRField("link_up",      size=1, offset= 9, description="Configuration done (L0 or Recovery)."),
            CSRField("serdes_ready", size=1, offset=10, description="Transceivers initialized."),
            CSRField("rx_elecidle",  size=1, offset=11, description="RX Electrical Idle."),
            CSRField("rx_polarity",  size=1, offset=12, description="RX polarity inverted."),
            CSRField("enabled",      size=1, offset=13, description="LTSSM enabled (cleared by PERST#, see control)."),
            CSRField("perst",        size=1, offset=14, description="PERST# asserted."),
            CSRField("rate",         size=1, offset=15, description="Link rate (``0b0``: 2.5 GT/s, ``0b1``: 5 GT/s, see gen3)."),
            CSRField("link",         size=8, offset=16, description="Negotiated Link Number."),
            CSRField("lane",         size=5, offset=24, description="Lane Number."),
            CSRField("gen3",         size=1, offset=29, description="Link rate 8.0 GT/s."),
        ])
        if hasattr(phy, "g3"):
            g3 = phy.g3
            self._g3_control = CSRStorage(fields=[
                CSRField("force", size=1, offset=0, description="8.0 GT/s with the transmitters on, LTSSM disabled (with loopback: checks the transceivers' rate switch and the Blocks without a partner)."),
                CSRField("snapshot", size=1, offset=1, pulse=True, description="Capture the raw words of Lane 0 (g3_raw_tx/g3_raw_rx)."),
                CSRField("eidle",    size=1, offset=2, description="Use the transceivers' Electrical Idle detection at 8.0 GT/s."),
                CSRField("trace",    size=1, offset=3, pulse=True, description="Start the rate trace (g3_trace_*)."),
                CSRField("lpm",      size=1, offset=4, reset=getattr(serdes, "gen3_lpm_default", 0), description="LPM receive equalizer at 8.0 GT/s (DFE otherwise, reset: the transceiver's default)."),
                CSRField("capture",  size=1, offset=5, pulse=True, description="Arm the raw capture of Lane 0 (g3_capture_*)."),
                CSRField("xyden",    size=1, offset=6, description="DFE XYD adaptation at 8.0 GT/s (RXDFEXYDEN, off in the Xilinx wrapper)."),
            ])
            self._g3_raw_tx = CSRStatus(40, description="Raw word transmitted on Lane 0 (snapshot).")
            self._g3_raw_rx = CSRStatus(40, description="Raw word received on Lane 0 (snapshot, bit 39: valid).")
            self._g3_counts = CSRStatus(64, description="Lane 0 at 8.0 GT/s (16-bit counters): Blocks, undefined Sync Headers, EIEOS, slips (bits 63:48).")
            self._g3_words  = CSRStatus(32, description="Lane 0 raw words received at 8.0 GT/s.")
            self._g3_status = CSRStatus(fields=[
                CSRField("locked",    size=1, offset=0,  description="Lanes aligned on EIEOS (8.0 GT/s)."),
                CSRField("aligned",   size=8, offset=1,  description="Block alignment of each lane."),
                CSRField("rate_done", size=1, offset=9,  description="Transceivers' rate applied."),
                CSRField("pll_lock",  size=1, offset=10, description="8.0 GT/s PLLs locked."),
                CSRField("timeouts",  size=8, offset=16, description="Rate sequence timeouts."),
            ])
            force = Signal()
            self.specials += MultiReg(self._g3_control.fields.force, force, "pcie_link")
            self.comb += phy.force_g3.eq(force)
            aligned = Signal(8)
            self.comb += aligned.eq(Cat(*[l.aligned for l in g3.lanes_rx]))
            # Raw words snapshot: captured in "pcie_g3", held, read in "sys".
            snapshot = PulseSynchronizer("sys", "pcie_g3")
            self.submodules += snapshot
            raw_tx = Signal(40)
            raw_rx = Signal(40)
            self.comb += snapshot.i.eq(self._g3_control.fields.snapshot)
            self.sync.pcie_g3 += If(snapshot.o,
                raw_tx.eq(serdes.lanes[0].raw_tx),
                raw_rx.eq(Cat(serdes.lanes[0].raw_rx[:39], serdes.lanes[0].raw_rx_valid)),
            )
            self.specials += [
                MultiReg(raw_tx, self._g3_raw_tx.status, "sys"),
                MultiReg(raw_rx, self._g3_raw_rx.status, "sys"),
            ]
            # Raw capture ("pcie_g3"): 1024 consecutive words of Lane 0 (bit 39: valid), from g3_capture_delay
            # cycles after the start (arm: at once with force, else on the entry in Recovery.Equalization).
            self._g3_capture_delay = CSRStorage(24, description="Raw capture: cycles of 200 MHz after the trigger.")
            self._g3_capture_index = CSRStorage(10, description="Raw capture: word to read.")
            self._g3_capture_data  = CSRStatus(40, description="Raw capture: word (bit 39: valid).")
            self._g3_capture_done  = CSRStatus(description="Raw capture done.")
            arm = PulseSynchronizer("sys", "pcie_g3")
            self.submodules += arm
            self.comb += arm.i.eq(self._g3_control.fields.capture)
            in_eq   = Signal()
            delay   = Signal(24)
            force_c = Signal()
            self.specials += [
                MultiReg(self._g3_control.fields.force, force_c, "pcie_g3"),
                MultiReg(ltssm.state[2:6] == (0x2c >> 2), in_eq, "pcie_g3"),
                MultiReg(self._g3_capture_delay.storage, delay, "pcie_g3"),
            ]
            cmem   = Memory(40, 1024)
            cwport = cmem.get_port(write_capable=True, clock_domain="pcie_g3")
            crport = cmem.get_port(clock_domain="sys")
            self.specials += cmem, cwport, crport
            armed   = Signal()
            waiting = Signal(24)
            running = Signal()
            cindex  = Signal(10)
            cdone   = Signal()
            self.sync.pcie_g3 += [
                If(arm.o,
                    armed.eq(1), running.eq(0), cdone.eq(0), cindex.eq(0), waiting.eq(0),
                ).Elif(armed & (force_c | in_eq),
                    If(waiting == delay,
                        armed.eq(0), running.eq(1),
                    ).Else(
                        waiting.eq(waiting + 1)
                    )
                ).Elif(running,
                    cindex.eq(cindex + 1),
                    If(cindex == 1023, running.eq(0), cdone.eq(1)),
                )
            ]
            self.comb += [
                cwport.adr.eq(cindex),
                cwport.dat_w.eq(Cat(serdes.lanes[0].raw_rx[:39], serdes.lanes[0].raw_rx_valid)),
                cwport.we.eq(running),
                crport.adr.eq(self._g3_capture_index.storage),
                self._g3_capture_data.status.eq(crport.dat_r),
            ]
            self.specials += MultiReg(cdone, self._g3_capture_done.status, "sys")

            # Lane 0 counters (sampled as they change: debug precision).
            gb    = g3.lanes_rx[0].gearbox
            undef = (gb.sync_header == 0b00) | (gb.sync_header == 0b11)
            counts = [Signal(16) for _ in range(4)]
            words  = Signal(32)
            self.sync.pcie_g3 += [
                If(gb.valid, counts[0].eq(counts[0] + 1)),
                If(gb.valid & undef, counts[1].eq(counts[1] + 1)),
                If(g3.lanes_rx[0].aligner.eieos, counts[2].eq(counts[2] + 1)),
                If(gb.slip, counts[3].eq(counts[3] + 1)),
                If(serdes.lanes[0].raw_rx_valid, words.eq(words + 1)),
            ]
            self.specials += [
                MultiReg(Cat(*counts), self._g3_counts.status, "sys"),
                MultiReg(words, self._g3_words.status, "sys"),
            ]
            rs = getattr(serdes, "rate_sequencer", None)
            self.specials += [
                MultiReg(g3.lrx.locked,     self._g3_status.fields.locked,    "sys"),
                MultiReg(aligned,           self._g3_status.fields.aligned,   "sys"),
                MultiReg(serdes.rate_done,  self._g3_status.fields.rate_done, "sys"),
            ]
            if rs is not None:
                self.specials += [
                    MultiReg(rs.pll_lock, self._g3_status.fields.pll_lock, "sys"),
                    MultiReg(rs.timeouts, self._g3_status.fields.timeouts, "sys"),
                ]
            eidle = Signal()
            self.specials += MultiReg(self._g3_control.fields.eidle, eidle, "pcie_link")
            self.comb += phy.g3_eidle.eq(eidle)
            if hasattr(serdes, "gen3_lpm"):
                self.comb += [
                    serdes.gen3_lpm.eq(self._g3_control.fields.lpm),
                    serdes.gen3_xyden.eq(self._g3_control.fields.xyden),
                    serdes.gen3_eidle.eq(self._g3_control.fields.eidle),
                ]

            # Rate trace ("pcie_link"): each change of the LTSSM state and rate, rate sequencer state and PLL
            # selection, Electrical Idle (transceiver, LTSSM), 8.0 GT/s lock, with a timestamp (1.024 us at
            # 125 MHz). The first trace_depth changes after the start are kept.
            if rs is not None:
                trace_depth = 1024
                self._g3_trace_index = CSRStorage(10, description="Rate trace entry to read.")
                self._g3_trace_data  = CSRStatus(48, description="Rate trace entry: timestamp (bits 47:26, 8.192 us), TS received in the state (25:22), last EC received (21:20) and its count (19:16), lock (15), LTSSM Electrical Idle (14), transceiver Electrical Idle (13), sequencer state (12:10), sequencer done (9), PLL selection (8), rate (7:6), LTSSM state (5:0).")
                self._g3_trace_count = CSRStatus(11, description="Rate trace entries.")
                seq_states = ["IDLE", "CLOCK", "PMA-HOLD", "DRP", "PMA-RELEASE", "GT", "RX-RESET", "RX-READY"]
                seq_state  = Signal(3)
                for i, name in enumerate(seq_states):
                    if name in rs.fsm.actions:
                        self.comb += If(rs.fsm.ongoing(name), seq_state.eq(i))
                locked = Signal()
                self.specials += MultiReg(g3.lrx.locked, locked, "pcie_link")
                ts_count = Signal(4)
                state_r  = Signal(6)
                self.sync.pcie_link += [
                    state_r.eq(ltssm.state),
                    If(ltssm.state != state_r,
                        ts_count.eq(0)
                    ).Elif(ltssm.rx_ts & (ts_count != 15),
                        ts_count.eq(ts_count + 1)
                    )
                ]
                # No constant bits (they would be trimmed from the memory).
                event   = Signal(26)
                event_r = Signal(26)
                stamp   = Signal(32)
                self.comb += event.eq(Cat(ltssm.state[:6], ltssm.rate, rs.pll_sel, rs.done, seq_state,
                    phy.rx_elecidle, ltssm.rx_elecidle, locked, ltssm.rx_ec_count, ltssm.rx_ec_last, ts_count))
                start = PulseSynchronizer("sys", "pcie_link")
                self.submodules += start
                self.comb += start.i.eq(self._g3_control.fields.trace)
                mem   = Memory(48, trace_depth)
                wport = mem.get_port(write_capable=True, clock_domain="pcie_link")
                rport = mem.get_port(clock_domain="sys")
                self.specials += mem, wport, rport
                count = Signal(11)
                self.sync.pcie_link += [
                    event_r.eq(event),
                    stamp.eq(stamp + 1),
                    If(start.o,
                        count.eq(0),
                        stamp.eq(0),
                    ).Elif(wport.we,
                        count.eq(count + 1),
                    )
                ]
                self.comb += [
                    wport.adr.eq(count),
                    wport.dat_w.eq(Cat(event, stamp[10:32])),
                    wport.we.eq(~start.o & (event != event_r) & (count != trace_depth)),
                    rport.adr.eq(self._g3_trace_index.storage),
                    self._g3_trace_data.status.eq(rport.dat_r),
                ]
                self.specials += MultiReg(count, self._g3_trace_count.status, "sys")
        self._rx_ts        = CSRStatus(32, description="Training Sequences received.")
        self._rx_ts_errors = CSRStatus(32, description="Corrupted Training Sequences received.")
        self._rx_errors    = CSRStatus(32, description="8b/10b errors received (words).")
        self._rx_overflows = CSRStatus(16, description="Elastic buffer overflows.")
        self._rx_dllp      = CSRStatus(32, description="DLLP starts (SDP) received in L0.")
        self._rx_tlp       = CSRStatus(32, description="TLP starts (STP) received in L0.")
        self._rx_rate      = CSRStatus(8,  description="Partner Data Rate Identifier.")
        self._loopback     = CSRStorage(3, description="Transceiver loopback mode (0: none, 2: near-end PMA).")

        # # #

        # Controls (sys -> pcie_link).
        enable  = Signal()
        enabled = Signal(reset=enable_reset) # sys.
        perst   = Signal()
        if hasattr(serdes, "perst"):
            self.comb += perst.eq(serdes.perst)
        self.sync += [
            If(self._control.re,
                enabled.eq(self._control.fields.enable)
            ).Elif(perst & (enable_reset == 0),
                enabled.eq(0)
            )
        ]
        self.comb += [
            self._status.fields.enabled.eq(enabled),
            self._status.fields.perst.eq(perst),
            serdes.loopback.eq(self._loopback.storage),
        ]
        retrain      = PulseSynchronizer("sys", "pcie_link")
        speed_change = PulseSynchronizer("sys", "pcie_link")
        self.submodules += retrain, speed_change
        self.specials += MultiReg(enabled, enable, "pcie_link")
        self.comb += [
            phy.enable.eq(enable),
            retrain.i.eq(self._control.fields.retrain),
            phy.retrain.eq(retrain.o),
            speed_change.i.eq(self._control.fields.speed_change),
            phy.speed_change.eq(speed_change.o),
        ]

        # Counters (pcie_link / pcie_pipe).
        rx_ts        = Signal(32)
        rx_ts_errors = Signal(32)
        rx_dllp      = Signal(32)
        rx_tlp       = Signal(32)
        rx_errors    = Signal(32)
        sdp_word = Signal()
        stp_word = Signal()
        # Registered first (timing): the source is muxed by the rate.
        self.sync.pcie_link += [
            sdp_word.eq(phy.source.valid & Reduce("OR", [phy.source.ctrl[i] & (phy.source.data[8*i:8*(i+1)] == SDP.value) for i in range(len(phy.source.ctrl))])),
            stp_word.eq(phy.source.valid & Reduce("OR", [phy.source.ctrl[i] & (phy.source.data[8*i:8*(i+1)] == STP.value) for i in range(len(phy.source.ctrl))])),
        ]
        self.sync.pcie_link += [
            If(ltssm.rx_ts,       rx_ts.eq(rx_ts + 1)),
            If(ltssm.rx_ts_error, rx_ts_errors.eq(rx_ts_errors + 1)),
            If(sdp_word, rx_dllp.eq(rx_dllp + 1)),
            If(stp_word, rx_tlp.eq(rx_tlp + 1)),
        ]
        self.sync.pcie_pipe += If(Reduce("OR", [l.rx_errors for l in serdes.lanes]), rx_errors.eq(rx_errors + 1))

        # Status (-> sys).
        for src, dst in [
            (ltssm.state,        self._status.fields.ltssm),
            (ltssm.l0,           self._status.fields.l0),
            (ltssm.link_up,      self._status.fields.link_up),
            (serdes.ready,       self._status.fields.serdes_ready),
            (ltssm.rx_elecidle,  self._status.fields.rx_elecidle),
            (ltssm.rate[0],      self._status.fields.rate),
            (ltssm.rate[1],      self._status.fields.gen3),
            (ltssm.rx_polarity,  self._status.fields.rx_polarity),
            (ltssm.link,         self._status.fields.link),
            (ltssm.lane,         self._status.fields.lane),
            (rx_ts,              self._rx_ts.status),
            (rx_ts_errors,       self._rx_ts_errors.status),
            (rx_errors,          self._rx_errors.status),
            (lane.rx_overflows,  self._rx_overflows.status),
            (rx_dllp,            self._rx_dllp.status),
            (rx_tlp,             self._rx_tlp.status),
            (ltssm.rx_rate,      self._rx_rate.status),
        ]:
            self.specials += MultiReg(src, dst, "sys")

        # Data Link Layer: what a stall or a lost link leaves behind.
        if dll is not None:
            self._dll_status = CSRStatus(fields=[
                CSRField("state",      size=2, offset=0, description="DLCMSM: 0 DL_Inactive, 1/2 DL_Init, 3 DL_Active."),
                CSRField("pending",    size=1, offset=2, description="TLPs transmitted and not acknowledged."),
                CSRField("fc_ok",      size=1, offset=3, description="Flow control allows the next TLP."),
                CSRField("tx_ready",   size=1, offset=4, description="Replay buffer accepts a word."),
                CSRField("rx_valid",   size=1, offset=5, description="A received TLP is waiting for the Transaction Layer."),
                CSRField("rx_ready",   size=1, offset=6, description="The Transaction Layer accepts it."),
            ])
            self._dll_replays     = CSRStatus(16, description="TLP replays.")
            self._dll_rx_errors   = CSRStatus(16, description="LCRC, sequence and framing errors.")
            self._dll_link_errors = CSRStatus(16, description="REPLAY_NUM rollovers (Recovery requested).")
            self._dll_tx_tlps     = CSRStatus(32, description="TLPs accepted from the Transaction Layer.")
            self._dll_rx_tlps     = CSRStatus(32, description="TLPs delivered to the Transaction Layer.")
            link_errors = Signal(16)
            tx_tlps     = Signal(32)
            rx_tlps     = Signal(32)
            self.sync.pcie_link += [
                If(dll.link_error, link_errors.eq(link_errors + 1)),
                If(dll.sink.valid & dll.sink.ready & dll.sink.last, tx_tlps.eq(tx_tlps + 1)),
                If(dll.source.valid & dll.source.ready & dll.source.last, rx_tlps.eq(rx_tlps + 1)),
            ]
            for src, dst in [
                (dll.state,             self._dll_status.fields.state),
                (dll.tx.replay.pending, self._dll_status.fields.pending),
                (dll.tx.replay.fc_ok,   self._dll_status.fields.fc_ok),
                (dll.sink.ready,        self._dll_status.fields.tx_ready),
                (dll.source.valid,      self._dll_status.fields.rx_valid),
                (dll.source.ready,      self._dll_status.fields.rx_ready),
                (dll.tx.replay.replays, self._dll_replays.status),
                (dll.rx.errors,         self._dll_rx_errors.status),
                (link_errors,           self._dll_link_errors.status),
                (tx_tlps,               self._dll_tx_tlps.status),
                (rx_tlps,               self._dll_rx_tlps.status),
            ]:
                self.specials += MultiReg(src, dst, "sys")

        # LTSSM tracer.
        if with_tracer:
            self.tracer = LTSSMTracer(self._status.fields.ltssm)
