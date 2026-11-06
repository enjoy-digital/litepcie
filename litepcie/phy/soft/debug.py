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
    def __init__(self, phy, serdes, with_tracer=True, enable_reset=0):
        lane  = serdes.lanes[0]
        ltssm = phy.ltssm

        self._control = CSRStorage(fields=[
            CSRField("enable",  size=1, offset=0, reset=enable_reset, description="LTSSM enable, write to apply. Without autostart (reset value), cleared by PERST#: a host reset comes back with the LTSSM disabled, so a design making a host hang cannot do it again at the next boot."),
            CSRField("retrain", size=1, offset=1, pulse=True, description="Link Retrain (Recovery)."),
        ])
        self._status = CSRStatus(fields=[
            CSRField("ltssm",        size=6, offset= 0, description="LTSSM state (Xilinx UltraScale encoding, L0 = 0x10)."),
            CSRField("l0",           size=1, offset= 8, description="LTSSM in L0."),
            CSRField("link_up",      size=1, offset= 9, description="Configuration done (L0 or Recovery)."),
            CSRField("serdes_ready", size=1, offset=10, description="Transceivers initialized."),
            CSRField("rx_elecidle",  size=1, offset=11, description="RX Electrical Idle."),
            CSRField("rx_polarity",  size=1, offset=12, description="RX polarity inverted."),
            CSRField("enabled",      size=1, offset=13, description="LTSSM enabled (cleared by PERST#, see control)."),
            CSRField("perst",        size=1, offset=14, description="PERST# asserted."),
            CSRField("link",         size=8, offset=16, description="Negotiated Link Number."),
            CSRField("lane",         size=5, offset=24, description="Lane Number."),
        ])
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
        retrain = PulseSynchronizer("sys", "pcie_link")
        self.submodules += retrain
        self.specials += MultiReg(enabled, enable, "pcie_link")
        self.comb += [
            phy.enable.eq(enable),
            retrain.i.eq(self._control.fields.retrain),
            phy.retrain.eq(retrain.o),
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
            sdp_word.eq(Reduce("OR", [phy.source.ctrl[i] & (phy.source.data[8*i:8*(i+1)] == SDP.value) for i in range(4)])),
            stp_word.eq(Reduce("OR", [phy.source.ctrl[i] & (phy.source.data[8*i:8*(i+1)] == STP.value) for i in range(4)])),
        ]
        self.sync.pcie_link += [
            If(ltssm.rx_ts,       rx_ts.eq(rx_ts + 1)),
            If(ltssm.rx_ts_error, rx_ts_errors.eq(rx_ts_errors + 1)),
            If(phy.source.valid & sdp_word, rx_dllp.eq(rx_dllp + 1)),
            If(phy.source.valid & stp_word, rx_tlp.eq(rx_tlp + 1)),
        ]
        self.sync.pcie_pipe += If(lane.rx_errors, rx_errors.eq(rx_errors + 1))

        # Status (-> sys).
        for src, dst in [
            (ltssm.state,        self._status.fields.ltssm),
            (ltssm.l0,           self._status.fields.l0),
            (ltssm.link_up,      self._status.fields.link_up),
            (serdes.ready,       self._status.fields.serdes_ready),
            (ltssm.rx_elecidle,  self._status.fields.rx_elecidle),
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

        # LTSSM tracer.
        if with_tracer:
            self.tracer = LTSSMTracer(self._status.fields.ltssm)
