#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY Physical Layer (x1): a lane of a PCIeSerDes with the LTSSM.

In the lane clock domain ("pcie_pipe"): TX multiplexing (EIOS then Electrical Idle, Training
Sequences, Data Link Layer packets, Logical Idle), Training Sequence/EIOS detection and the Logical
Idle handshake. In the "pcie_link" clock domain: the LTSSM and the Data Link Layer streams (sink:
packets to transmit with first/last, source: received Symbols in L0, framing done by the Data Link
Layer). Clock domain crossings: levels with MultiReg, pulses with PulseSynchronizer, received
Training Sequences and data through AsyncFIFOs.
"""

from migen import *
from migen.genlib.cdc import MultiReg, PulseSynchronizer

from litex.gen import *

from litex.soc.interconnect import stream

from litepcie.phy.soft.common       import EIOS, lane_layout
from litepcie.phy.soft.datapath     import ordered_set_words
from litepcie.phy.soft.ordered_sets import TSGenerator, TSChecker, OrderedSetDetector, ts_layout
from litepcie.phy.soft.ltssm        import PCIeLTSSM

EIOS_WORD = ordered_set_words(EIOS)[0]

# Physical Layer -----------------------------------------------------------------------------------

class PCIePhysicalLayer(LiteXModule):
    def __init__(self, serdes, clk_freq, upstream=True, with_timers=True, timer_scale=1,
        gen2_capable=False, ts1_min=1024, tx_depth=16, rx_depth=16):
        assert serdes.nlanes == 1
        lane = serdes.lanes[0]
        self.sink   = sink   = stream.Endpoint(lane_layout(4)) # "pcie_link": packets to transmit.
        self.source = source = stream.Endpoint(lane_layout(4)) # "pcie_link": received Symbols (L0).

        # Controls ("pcie_link").
        self.enable      = Signal(reset=1) # i: LTSSM enable.
        self.retrain     = Signal()        # i (Pulse): Link Retrain.
        self.link_error  = Signal()        # i (Pulse): Data Link Layer error (Recovery).
        self.link_number = Signal(8)       # i (downstream): Link Number.
        self.speed_change = Signal()       # i (Pulse): Directed speed change (gen2_capable).

        # # #

        # LTSSM ------------------------------------------------------------------------------------
        self.ltssm = ltssm = ClockDomainsRenamer("pcie_link")(PCIeLTSSM(clk_freq,
            upstream     = upstream,
            with_timers  = with_timers,
            timer_scale  = timer_scale,
            gen2_capable = gen2_capable,
            ts1_min      = ts1_min,
        ))
        serdes_ready = Signal()
        self.specials += MultiReg(serdes.ready, serdes_ready, "pcie_link")
        self.comb += [
            ltssm.enable.eq(self.enable & serdes_ready),
            ltssm.retrain.eq(self.retrain),
            ltssm.link_error.eq(self.link_error),
            ltssm.link_number.eq(self.link_number),
            ltssm.speed_change.eq(self.speed_change),
            serdes.rate.eq(ltssm.rate),
            ltssm.rate_done.eq(serdes.rate_done),
        ]

        # LTSSM levels in the lane clock domain.
        levels = {}
        for name in ["tx_elecidle", "tx_ts_enable", "tx_ts2", "tx_ts_link", "tx_ts_link_pad",
                     "tx_ts_lane", "tx_ts_lane_pad", "tx_ts_rate", "tx_ts_ctrl",
                     "tx_data_enable", "rx_data_enable", "idle_hs", "rx_polarity", "rx_reset",
                     "scrambling_enable", "skp_enable"]:
            level = Signal(len(getattr(ltssm, name)), name="pipe_" + name)
            self.specials += MultiReg(getattr(ltssm, name), level, "pcie_pipe")
            levels[name] = level

        # Rate and de-emphasis: -3.5 dB at 2.5 GT/s, selected by the LTSSM at 5.0 GT/s.
        rate          = Signal()
        select_deemph = Signal()
        self.specials += [
            MultiReg(ltssm.rate,          rate,          "pcie_pipe"),
            MultiReg(ltssm.select_deemph, select_deemph, "pcie_pipe"),
        ]

        # Lane controls.
        tx_detect_rx = PulseSynchronizer("pcie_link", "pcie_pipe")
        self.submodules += tx_detect_rx
        self.comb += [
            tx_detect_rx.i.eq(ltssm.tx_detect_rx),
            lane.tx_detect_rx.eq(tx_detect_rx.o),
            lane.rx_polarity.eq(levels["rx_polarity"]),
            lane.rx_reset.eq(levels["rx_reset"]),
            lane.skp_enable.eq(levels["skp_enable"]),
            lane.scrambling_enable.eq(levels["scrambling_enable"]),
            lane.tx_deemph.eq(~rate | select_deemph),
        ]

        # Lane status to the LTSSM.
        detect_done = PulseSynchronizer("pcie_pipe", "pcie_link")
        self.submodules += detect_done
        self.specials += [
            MultiReg(lane.rx_elecidle, ltssm.rx_elecidle, "pcie_link"),
            MultiReg(lane.rx_detected, ltssm.rx_detected, "pcie_link"),
        ]
        self.comb += [
            detect_done.i.eq(lane.detect_done),
            ltssm.detect_done.eq(detect_done.o),
        ]

        # TX ("pcie_pipe") -------------------------------------------------------------------------
        self.ts_gen = ts_gen = ClockDomainsRenamer("pcie_pipe")(TSGenerator())
        eieos_reset = PulseSynchronizer("pcie_link", "pcie_pipe")
        self.submodules += eieos_reset
        self.comb += [
            eieos_reset.i.eq(ltssm.tx_eieos_reset),
            ts_gen.eieos.eq(rate),
            ts_gen.eieos_reset.eq(eieos_reset.o),
            ts_gen.enable.eq(levels["tx_ts_enable"]),
            ts_gen.ts.ts2.eq(levels["tx_ts2"]),
            ts_gen.ts.link.eq(levels["tx_ts_link"]),
            ts_gen.ts.link_pad.eq(levels["tx_ts_link_pad"]),
            ts_gen.ts.lane.eq(levels["tx_ts_lane"]),
            ts_gen.ts.lane_pad.eq(levels["tx_ts_lane_pad"]),
            ts_gen.ts.n_fts.eq(0xff), # L0s not supported: fixed value, the partner's one is ignored.
            ts_gen.ts.rate.eq(levels["tx_ts_rate"]),
            ts_gen.ts.ctrl.eq(levels["tx_ts_ctrl"]),
        ]
        tx_ts_done = PulseSynchronizer("pcie_pipe", "pcie_link")
        self.submodules += tx_ts_done
        self.comb += [
            tx_ts_done.i.eq(ts_gen.done),
            ltssm.tx_ts_done.eq(tx_ts_done.o),
        ]

        self.tx_fifo = tx_fifo = ClockDomainsRenamer({"write": "pcie_link", "read": "pcie_pipe"})(
            stream.AsyncFIFO(lane_layout(4), tx_depth, buffered=True))
        self.comb += sink.connect(tx_fifo.sink)

        # EIOS before Electrical Idle.
        tx_elecidle   = levels["tx_elecidle"]
        tx_elecidle_r = Signal()
        eios_pending  = Signal()
        eios_sent     = Signal()
        self.sync.pcie_pipe += [
            tx_elecidle_r.eq(tx_elecidle),
            If(tx_elecidle & ~tx_elecidle_r,
                eios_pending.eq(1)
            ).Elif(eios_sent,
                eios_pending.eq(0)
            )
        ]
        self.comb += lane.tx_elecidle.eq(tx_elecidle & ~eios_pending)

        # Multiplexing: EIOS, Electrical Idle, Training Sequences, packets, Logical Idle.
        tx_idle = Signal() # Logical Idle word transmitted.
        self.comb += [
            If(eios_pending,
                lane.sink.valid.eq(1),
                lane.sink.first.eq(1),
                lane.sink.last.eq(1),
                lane.sink.data.eq(EIOS_WORD[0]),
                lane.sink.ctrl.eq(EIOS_WORD[1]),
                eios_sent.eq(lane.sink.ready),
            ).Elif(tx_elecidle,
                lane.sink.valid.eq(0),
            ).Elif(levels["tx_ts_enable"] | ts_gen.busy,
                ts_gen.source.connect(lane.sink),
            ).Elif(levels["tx_data_enable"] & tx_fifo.source.valid,
                tx_fifo.source.connect(lane.sink),
            ).Else(
                lane.sink.valid.eq(1),
                tx_idle.eq(lane.sink.ready),
            )
        ]

        # RX ("pcie_pipe") -------------------------------------------------------------------------
        self.comb += lane.source.ready.eq(1)
        self.ts_chk   = ts_chk   = ClockDomainsRenamer("pcie_pipe")(TSChecker())
        self.eios_det = eios_det = ClockDomainsRenamer("pcie_pipe")(OrderedSetDetector(EIOS))
        self.comb += [
            lane.source.connect(ts_chk.sink,   omit={"ready"}),
            lane.source.connect(eios_det.sink, omit={"ready"}),
        ]

        # Received Training Sequences to the LTSSM.
        rx_ts_layout = [field for field in ts_layout if field[0] != "n_fts"]
        self.ts_fifo = ts_fifo = ClockDomainsRenamer({"write": "pcie_pipe", "read": "pcie_link"})(
            stream.AsyncFIFO(rx_ts_layout + [("inverted", 1)], 4, buffered=True))
        self.comb += [
            ts_fifo.sink.valid.eq(ts_chk.detected),
            ts_fifo.sink.inverted.eq(ts_chk.inverted),
            ts_fifo.source.ready.eq(1),
            ltssm.rx_ts.eq(ts_fifo.source.valid),
            ltssm.rx_ts_inverted.eq(ts_fifo.source.inverted),
        ]
        for name, width in rx_ts_layout:
            self.comb += [
                getattr(ts_fifo.sink, name).eq(getattr(ts_chk.ts, name)),
                getattr(ltssm, "rx_ts_" + name).eq(getattr(ts_fifo.source, name)),
            ]
        rx_ts_error = PulseSynchronizer("pcie_pipe", "pcie_link")
        rx_eios     = PulseSynchronizer("pcie_pipe", "pcie_link")
        self.submodules += rx_ts_error, rx_eios
        self.comb += [
            rx_ts_error.i.eq(ts_chk.error),
            ltssm.rx_ts_error.eq(rx_ts_error.o),
            rx_eios.i.eq(eios_det.detected),
            ltssm.rx_eios.eq(rx_eios.o),
        ]

        # Received Symbols to the Data Link Layer (L0, no back-pressure).
        self.rx_fifo = rx_fifo = ClockDomainsRenamer({"write": "pcie_pipe", "read": "pcie_link"})(
            stream.AsyncFIFO(lane_layout(4), rx_depth, buffered=True))
        self.comb += [
            rx_fifo.sink.valid.eq(lane.source.valid & levels["rx_data_enable"]),
            rx_fifo.sink.data.eq(lane.source.data),
            rx_fifo.sink.ctrl.eq(lane.source.ctrl),
            rx_fifo.source.connect(source),
        ]

        # Logical Idle handshake: 8 Idle Symbols received (2 Idle words), then 16 transmitted.
        idle_hs       = levels["idle_hs"]
        rx_idle_word  = Signal()
        rx_idle_words = Signal(2)
        rx_idle_seen  = Signal()
        tx_idle_after = Signal(3)
        idle_hs_done  = Signal()
        self.comb += rx_idle_word.eq(lane.source.valid & (lane.source.data == 0) & (lane.source.ctrl == 0))
        self.sync.pcie_pipe += [
            If(lane.source.valid,
                If(rx_idle_word,
                    If(rx_idle_words != 3, rx_idle_words.eq(rx_idle_words + 1))
                ).Else(
                    rx_idle_words.eq(0)
                )
            ),
            If(~idle_hs,
                rx_idle_seen.eq(0),
                tx_idle_after.eq(0),
            ).Else(
                If(rx_idle_words >= 2, rx_idle_seen.eq(1)),
                If(tx_idle & rx_idle_seen & (tx_idle_after != 7), tx_idle_after.eq(tx_idle_after + 1)),
            )
        ]
        self.comb += idle_hs_done.eq(idle_hs & rx_idle_seen & (tx_idle_after >= 4))
        self.specials += MultiReg(idle_hs_done, ltssm.idle_hs_done, "pcie_link")
