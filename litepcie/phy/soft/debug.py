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
        self.comb += [
            sdp_word.eq(Reduce("OR", [phy.source.ctrl[i] & (phy.source.data[8*i:8*(i+1)] == SDP.value) for i in range(len(phy.source.ctrl))])),
            stp_word.eq(Reduce("OR", [phy.source.ctrl[i] & (phy.source.data[8*i:8*(i+1)] == STP.value) for i in range(len(phy.source.ctrl))])),
        ]
        self.sync.pcie_link += [
            If(ltssm.rx_ts,       rx_ts.eq(rx_ts + 1)),
            If(ltssm.rx_ts_error, rx_ts_errors.eq(rx_ts_errors + 1)),
            If(phy.source.valid & sdp_word, rx_dllp.eq(rx_dllp + 1)),
            If(phy.source.valid & stp_word, rx_tlp.eq(rx_tlp + 1)),
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
