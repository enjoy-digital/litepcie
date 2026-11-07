#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY multi-lane Physical Layer (PCIe Base 4.2.2, 4.2.4.9).

Each lane keeps its own datapaths (scrambling, SKP Ordered Sets, 8b/10b). Ordered Sets are sent at the
same time on all the lanes, and the Symbols of the link stream go to the lanes in order: Symbol k on Lane
k mod nlanes. On the receive side RXLaneDeskew compensates the Symbol phase and the skew of the lanes with
the COM Symbols of the Training Sequences (they arrive at the same time, modulo the skew).

The link width is the width of the design, there is no width negotiation yet: a partner bringing up
fewer lanes won't reach L0. Lane reversal isn't handled either.
"""

from migen import *
from migen.genlib.cdc import MultiReg, PulseSynchronizer
from migen.genlib.misc import WaitTimer

from litex.gen import *

from litex.soc.interconnect import stream

from litepcie.phy.soft.common       import COM, EIOS, lane_layout
from litepcie.phy.soft.ltssm        import PCIeLTSSM
from litepcie.phy.soft.ordered_sets import TSGenerator, TSChecker, OrderedSetDetector, ts_layout
from litepcie.phy.soft.pipe         import EIOS_WORD

# RX Lane Deskew -----------------------------------------------------------------------------------

class RXLaneDeskew(LiteXModule):
    """sinks: received Symbols of each lane (no back-pressure, SKP Ordered Sets already removed).
    With align set (Training Sequences on the lanes), the COM Symbols select the Symbol phase of each lane
    and the lanes are aligned on them: `locked` once they arrive together. source: the lanes side by side:
    Symbol j of Lane i on Symbol j*nlanes + i. depth: words in the FIFOs, max_skew: Symbols of skew compensated:
    the specification allows 20 ns at 2.5 GT/s and 8 ns at 5.0 GT/s, 2 words and 1 word. Enough margin with
    that, and below the 16 Symbols of a Training Sequence."""
    def __init__(self, nlanes, depth=16, max_skew=11):
        self.clear  = Signal() # i: partner's lanes not valid anymore (Electrical Idle): not locked.
        self.sinks  = [stream.Endpoint(lane_layout(4)) for _ in range(nlanes)]
        self.source = source = stream.Endpoint(lane_layout(4*nlanes))
        self.align  = Signal() # i
        self.locked = Signal() # o: lanes popped together.
        self.stable = Signal() # o: locked for 8 Training Sequences in a row.

        # # #

        fifos = []
        heads_com = []
        queued = [] # Symbols in the FIFO of each lane (a word needs the 4 - shift first Symbols of the next).
        for i, sink in enumerate(self.sinks):
            prev_data = Signal(32)
            prev_ctrl = Signal(4)
            shift     = Signal(2)
            self.comb += sink.ready.eq(1)
            self.sync += If(sink.valid,
                prev_data.eq(sink.data),
                prev_ctrl.eq(sink.ctrl),
            )
            # COM Symbol position in the word.
            coms = [prev_ctrl[j] & (prev_data[8*j:8*(j+1)] == COM.value) for j in range(4)]
            self.sync += If(self.align & sink.valid,
                If(coms[0],
                    shift.eq(0)
                ).Elif(coms[1],
                    shift.eq(1)
                ).Elif(coms[2],
                    shift.eq(2)
                ).Elif(coms[3],
                    shift.eq(3)
                )
            )
            fifo = stream.SyncFIFO(lane_layout(4), depth, buffered=True)
            self.submodules += fifo
            fifos.append(fifo)
            symbols = Signal(bits_for(4*depth + 3))
            self.comb += symbols.eq(4*fifo.level + 3 - shift)
            queued.append(symbols)
            data = Cat(prev_data, sink.data)
            ctrl = Cat(prev_ctrl, sink.ctrl)
            self.comb += [
                fifo.sink.valid.eq(sink.valid),
                Case(shift, {s: [
                    fifo.sink.data.eq(data[8*s:8*s + 32]),
                    fifo.sink.ctrl.eq(ctrl[s:s + 4]),
                ] for s in range(4)}),
            ]
            head = fifo.source
            heads_com.append(head.ctrl[0] & (head.data[0:8] == COM.value))

        valids  = Cat(*[fifo.source.valid for fifo in fifos])
        all_v   = valids == (2**nlanes - 1)
        coms    = Cat(*heads_com)
        all_com = coms == (2**nlanes - 1)
        locked  = self.locked
        # COMs of different Training Sequences: a lane more than max_skew Symbols ahead of another isn't
        # aligned with it, it goes to its next COM. Happens
        # when the receivers restart at different times, with old words in some of the FIFOs.
        drops = []
        for i, fifo in enumerate(fifos):
            drop = Signal()
            self.comb += drop.eq(Reduce("OR", [queued[i] >= queued[j] + max_skew + 1 for j in range(nlanes) if j != i]))
            drops.append(drop)
        any_drop = Signal()
        self.comb += any_drop.eq(Reduce("OR", drops))
        for i, fifo in enumerate(fifos):
            self.comb += If(locked | ~self.align,
                # Together.
                fifo.source.ready.eq(all_v),
            ).Else(
                # Up to the COM of each lane, then waiting for the others.
                fifo.source.ready.eq(fifo.source.valid & (~heads_com[i] | drops[i] | (all_v & all_com & ~any_drop))),
            )
        # Checked on every COM: a SKP Ordered Set being removed on some of the lanes can hide the difference
        # for one of them.
        good = Signal(4)
        self.comb += self.stable.eq(good == 8)
        self.sync += [
            If(self.clear,
                locked.eq(0),
                good.eq(0),
            ).Elif(~self.align,
                # Kept.
            ).Elif(all_v & all_com & ~any_drop,
                locked.eq(1),
                If(good != 8, good.eq(good + 1)),
            ).Elif(all_v & (coms != 0),
                # A lane's COM without the others, or too far from them: not aligned anymore.
                locked.eq(0),
                good.eq(0),
            ),
        ]
        self.comb += source.valid.eq(all_v & (locked | ~self.align))
        for i, fifo in enumerate(fifos):
            for j in range(4):
                self.comb += [
                    source.data[8*(j*nlanes + i):8*(j*nlanes + i + 1)].eq(fifo.source.data[8*j:8*(j+1)]),
                    source.ctrl[j*nlanes + i].eq(fifo.source.ctrl[j]),
                ]

# Multi-Lane Physical Layer ------------------------------------------------------------------------

class PCIeMultiLanePhysicalLayer(LiteXModule):
    """Same interface as PCIePhysicalLayer with sink/source of 4*nlanes Symbols. The LTSSM follows Lane
    0, the Lane Numbers go up from there on the other lanes, which have their own Training Sequences
    generators and checkers and polarity. lanes_ok: lanes receiving Training Sequences with their Lane
    Number (status, valid after Configuration)."""
    def __init__(self, serdes, clk_freq, upstream=True, with_timers=True, timer_scale=1,
        gen2_capable=False, ts1_min=1024, tx_depth=16, rx_depth=16):
        nlanes = serdes.nlanes
        assert nlanes >= 2
        lanes  = serdes.lanes
        self.nlanes = nlanes
        self.sink   = sink   = stream.Endpoint(lane_layout(4*nlanes)) # "pcie_link"
        self.source = source = stream.Endpoint(lane_layout(4*nlanes)) # "pcie_link"

        # Controls ("pcie_link").
        self.enable       = Signal(reset=1)
        self.retrain      = Signal()
        self.link_error   = Signal()
        self.link_number  = Signal(8)
        self.speed_change = Signal()
        self.lanes_ok     = Signal(nlanes) # o ("pcie_pipe")

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
                     "tx_data_enable", "rx_data_enable", "idle_hs", "rx_reset",
                     "scrambling_enable", "skp_enable"]:
            level = Signal(len(getattr(ltssm, name)), name="pipe_" + name)
            self.specials += MultiReg(getattr(ltssm, name), level, "pcie_pipe")
            levels[name] = level
        rate           = Signal()
        select_deemph  = Signal()
        polarity_check = Signal()
        self.specials += [
            MultiReg(ltssm.rate,           rate,           "pcie_pipe"),
            MultiReg(ltssm.select_deemph,  select_deemph,  "pcie_pipe"),
            MultiReg(ltssm.polarity_check, polarity_check, "pcie_pipe"),
        ]

        # Lane controls.
        tx_detect_rx = PulseSynchronizer("pcie_link", "pcie_pipe")
        self.submodules += tx_detect_rx
        self.comb += tx_detect_rx.i.eq(ltssm.tx_detect_rx)
        for lane in lanes:
            self.comb += [
                lane.tx_detect_rx.eq(tx_detect_rx.o),
                lane.rx_reset.eq(levels["rx_reset"]),
                lane.skp_enable.eq(levels["skp_enable"]),
                lane.scrambling_enable.eq(levels["scrambling_enable"]),
                lane.tx_deemph.eq(~rate | select_deemph),
            ]

        # Lane status to the LTSSM: from Lane 0.
        detect_done = PulseSynchronizer("pcie_pipe", "pcie_link")
        self.submodules += detect_done
        self.specials += [
            MultiReg(lanes[0].rx_elecidle, ltssm.rx_elecidle, "pcie_link"),
            MultiReg(lanes[0].rx_detected, ltssm.rx_detected, "pcie_link"),
        ]
        self.comb += [
            detect_done.i.eq(lanes[0].detect_done),
            ltssm.detect_done.eq(detect_done.o),
        ]

        # TX ("pcie_pipe") -------------------------------------------------------------------------
        self.ts_gens = []
        eieos_reset = PulseSynchronizer("pcie_link", "pcie_pipe")
        self.submodules += eieos_reset
        self.comb += eieos_reset.i.eq(ltssm.tx_eieos_reset)
        for i in range(nlanes):
            ts_gen = ClockDomainsRenamer("pcie_pipe")(TSGenerator())
            self.submodules += ts_gen
            self.ts_gens.append(ts_gen)
            self.comb += [
                ts_gen.eieos.eq(rate),
                ts_gen.eieos_reset.eq(eieos_reset.o),
                ts_gen.enable.eq(levels["tx_ts_enable"]),
                ts_gen.ts.ts2.eq(levels["tx_ts2"]),
                ts_gen.ts.link.eq(levels["tx_ts_link"]),
                ts_gen.ts.link_pad.eq(levels["tx_ts_link_pad"]),
                ts_gen.ts.lane.eq(levels["tx_ts_lane"] + i),
                ts_gen.ts.lane_pad.eq(levels["tx_ts_lane_pad"]),
                ts_gen.ts.n_fts.eq(0xff),
                ts_gen.ts.rate.eq(levels["tx_ts_rate"]),
                ts_gen.ts.ctrl.eq(levels["tx_ts_ctrl"]),
            ]
        tx_ts_done = PulseSynchronizer("pcie_pipe", "pcie_link")
        self.submodules += tx_ts_done
        self.comb += [
            tx_ts_done.i.eq(self.ts_gens[0].done),
            ltssm.tx_ts_done.eq(tx_ts_done.o),
        ]

        self.tx_fifo = tx_fifo = ClockDomainsRenamer({"write": "pcie_link", "read": "pcie_pipe"})(
            stream.AsyncFIFO(lane_layout(4*nlanes), tx_depth, buffered=True))
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

        # Multiplexing, the same on all the lanes: EIOS, Electrical Idle, Training Sequences, packets
        # (striped), Logical Idle. A word goes to the lanes when they are all ready.
        all_ready = Signal()
        self.comb += all_ready.eq(Reduce("AND", [lane.sink.ready for lane in lanes]))
        ts_mode = levels["tx_ts_enable"] | self.ts_gens[0].busy
        tx_idle = Signal()
        for i, lane in enumerate(lanes):
            ts_gen = self.ts_gens[i]
            striped_data = Cat(*[tx_fifo.source.data[8*(j*nlanes + i):8*(j*nlanes + i + 1)] for j in range(4)])
            striped_ctrl = Cat(*[tx_fifo.source.ctrl[j*nlanes + i] for j in range(4)])
            self.comb += [
                lane.tx_elecidle.eq(tx_elecidle & ~eios_pending),
                If(eios_pending,
                    lane.sink.valid.eq(all_ready),
                    lane.sink.first.eq(1),
                    lane.sink.last.eq(1),
                    lane.sink.data.eq(EIOS_WORD[0]),
                    lane.sink.ctrl.eq(EIOS_WORD[1]),
                ).Elif(tx_elecidle,
                    lane.sink.valid.eq(0),
                ).Elif(ts_mode,
                    lane.sink.valid.eq(ts_gen.source.valid & all_ready),
                    lane.sink.first.eq(ts_gen.source.first),
                    lane.sink.last.eq(ts_gen.source.last),
                    lane.sink.data.eq(ts_gen.source.data),
                    lane.sink.ctrl.eq(ts_gen.source.ctrl),
                    ts_gen.source.ready.eq(all_ready),
                ).Elif(levels["tx_data_enable"] & tx_fifo.source.valid,
                    lane.sink.valid.eq(all_ready),
                    lane.sink.first.eq(tx_fifo.source.first),
                    lane.sink.last.eq(tx_fifo.source.last),
                    lane.sink.data.eq(striped_data),
                    lane.sink.ctrl.eq(striped_ctrl),
                ).Else(
                    lane.sink.valid.eq(all_ready),
                ),
            ]
        self.comb += [
            eios_sent.eq(eios_pending & all_ready),
            If(~eios_pending & ~tx_elecidle & ~ts_mode,
                If(levels["tx_data_enable"] & tx_fifo.source.valid,
                    tx_fifo.source.ready.eq(all_ready)
                ).Else(
                    tx_idle.eq(all_ready)
                )
            ),
        ]

        # RX ("pcie_pipe") -------------------------------------------------------------------------
        self.ts_chks = []
        lanes_ok     = []
        for i, lane in enumerate(lanes):
            ts_chk = ClockDomainsRenamer("pcie_pipe")(TSChecker())
            self.submodules += ts_chk
            self.ts_chks.append(ts_chk)
            self.comb += lane.source.connect(ts_chk.sink, omit={"ready"})
            # Polarity of each lane: inverted identifiers received toggle it, held for the inversion to
            # take effect on the received stream.
            hold     = Signal(max=int(2e-6*clk_freq) + 1, reset=int(2e-6*clk_freq))
            polarity = Signal()
            invert   = polarity_check & ts_chk.detected & ts_chk.inverted & (hold == 0)
            self.comb += lane.rx_polarity.eq(polarity)
            self.sync.pcie_pipe += [
                If(invert,
                    polarity.eq(~polarity),
                    hold.eq(hold.reset),
                ).Elif(hold != 0,
                    hold.eq(hold - 1)
                )
            ]
            # Lane Number status.
            ok = Signal()
            self.sync.pcie_pipe += If(ts_chk.detected,
                ok.eq(~ts_chk.ts.lane_pad & (ts_chk.ts.lane == levels["tx_ts_lane"] + i))
            )
            lanes_ok.append(ok)
        self.comb += self.lanes_ok.eq(Cat(*lanes_ok))
        self.ts_chk   = ts_chk   = self.ts_chks[0]
        self.eios_det = eios_det = ClockDomainsRenamer("pcie_pipe")(OrderedSetDetector(EIOS))
        self.comb += lanes[0].source.connect(eios_det.sink, omit={"ready"})

        # Received Training Sequences of Lane 0 to the LTSSM.
        rx_ts_layout = [field for field in ts_layout if field[0] != "n_fts"]
        self.ts_fifo = ts_fifo = ClockDomainsRenamer({"write": "pcie_pipe", "read": "pcie_link"})(
            stream.AsyncFIFO(rx_ts_layout + [("inverted", 1)], 4, buffered=True))
        self.comb += [
            ts_fifo.sink.valid.eq(ts_chk.detected),
            ts_fifo.sink.inverted.eq(0), # Polarity handled above.
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

        # Lanes deskewed, then received Symbols to the Data Link Layer (L0, no back-pressure).
        self.deskew = deskew = ClockDomainsRenamer("pcie_pipe")(RXLaneDeskew(nlanes))
        self.specials += MultiReg(deskew.stable, ltssm.lanes_locked, "pcie_link")
        for i, lane in enumerate(lanes):
            self.comb += [
                deskew.sinks[i].valid.eq(lane.source.valid),
                deskew.sinks[i].data.eq(lane.source.data),
                deskew.sinks[i].ctrl.eq(lane.source.ctrl),
                lane.source.ready.eq(1),
            ]
        self.comb += [
            deskew.align.eq(~levels["rx_data_enable"]),
            deskew.clear.eq(tx_elecidle),
            deskew.source.ready.eq(1),
        ]
        self.rx_fifo = rx_fifo = ClockDomainsRenamer({"write": "pcie_pipe", "read": "pcie_link"})(
            stream.AsyncFIFO(lane_layout(4*nlanes), rx_depth, buffered=True))
        self.comb += [
            rx_fifo.sink.valid.eq(deskew.source.valid & levels["rx_data_enable"]),
            rx_fifo.sink.data.eq(deskew.source.data),
            rx_fifo.sink.ctrl.eq(deskew.source.ctrl),
            rx_fifo.source.connect(source),
        ]

        # Logical Idle handshake (all the lanes side by side): 8 Idle Symbols per lane, then 16 sent.
        idle_hs       = levels["idle_hs"]
        rx_idle_word  = Signal()
        rx_idle_words = Signal(2)
        rx_idle_seen  = Signal()
        tx_idle_after = Signal(3)
        idle_hs_done  = Signal()
        self.comb += rx_idle_word.eq(deskew.source.valid & (deskew.source.data == 0) & (deskew.source.ctrl == 0))
        self.sync.pcie_pipe += [
            If(deskew.source.valid,
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
