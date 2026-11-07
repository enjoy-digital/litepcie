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

The link width is negotiated in Configuration (4.2.6.3): each lane answers with the Link and Lane Numbers it
receives, the width is the largest of x1, x2, x4, x8 with these lanes from Lane 0. Lanes above it go to Electrical
Idle. The Data Link Layer keeps the width of the design: beats are split into words for the lanes in use, and
words from them make beats, a word being aligned on a DW first at x1 and x2. Lane reversal isn't handled.

With gen3_capable (ndw: 2 DWs per lane), 8.0 GT/s replaces this datapath by the 128b/130b one of gen3.py on the
transceivers' raw words: Blocks of the lanes (Gen3LaneTX/RX), the Data Stream and the Ordered Sets of the Link
(Gen3LinkTX/RX, the lanes aligned on EIEOS), and the equalization of each lane (Gen3LaneEQ), at the full width
only.
"""

from migen import *
from migen.genlib.cdc import MultiReg, PulseSynchronizer
from migen.genlib.misc import WaitTimer

from litex.gen import *

from litex.soc.interconnect import stream

from litepcie.phy.soft.common       import COM, EIOS, lane_layout
from litepcie.phy.soft.dll.wide     import RXPhaseAligner, RXPhaseAlignerX1
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
        self.mask   = Signal(nlanes, reset=2**nlanes - 1) # i: lanes to deskew, the others are ignored.
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
        all_v   = (valids & self.mask) == self.mask
        coms    = Cat(*heads_com) & self.mask
        all_com = coms == self.mask
        locked  = self.locked
        # COMs of different Training Sequences: a lane more than max_skew Symbols ahead of another isn't
        # aligned with it, it goes to its next COM. Happens
        # when the receivers restart at different times, with old words in some of the FIFOs.
        drops = []
        for i, fifo in enumerate(fifos):
            drop = Signal()
            self.comb += drop.eq(self.mask[i] & Reduce("OR", [self.mask[j] & (queued[i] >= queued[j] + max_skew + 1) for j in range(nlanes) if j != i]))
            drops.append(drop)
        any_drop = Signal()
        self.comb += any_drop.eq(Reduce("OR", drops))
        for i, fifo in enumerate(fifos):
            self.comb += If(~self.mask[i],
                # Not in the Link.
                fifo.source.ready.eq(1),
            ).Elif(locked | ~self.align,
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
    """Same interface as PCIePhysicalLayer with sink/source of 4*ndw Symbols (ndw: a multiple of the lanes, 2 DWs
    per lane for 8.0 GT/s, default 1). The LTSSM follows Lane
    0, the other lanes have their own Training Sequences generators and checkers and polarity, and follow the
    numbers they receive. width: negotiated link width. lanes_ok: lanes numbered by the partner (status).
    lane_disable: lanes kept out of the link, in Electrical Idle and with their receiver ignored (bring-up).
    early_idle: lanes out of the Link in Electrical Idle during Configuration, as a root port can do.
    gen3_capable: 8.0 GT/s (see the module docstring), eq_request_preset: preset requested in the requesting
    phase of the equalization (bit 4: request it, else no change)."""
    def __init__(self, serdes, clk_freq, upstream=True, with_timers=True, timer_scale=1,
        gen2_capable=False, gen3_capable=False, ts1_min=1024, tx_depth=16, rx_depth=16, early_idle=False, ndw=None,
        gen3_skp_interval=370, **ltssm_kwargs):
        nlanes = serdes.nlanes
        assert nlanes >= 2
        lanes  = serdes.lanes
        self.nlanes = nlanes
        ndw = nlanes if ndw is None else ndw
        assert ndw % nlanes == 0
        assert not gen3_capable or ndw == 2*nlanes
        self.ndw    = ndw
        self.sink   = sink   = stream.Endpoint(lane_layout(4*ndw)) # "pcie_link"
        self.source = source = stream.Endpoint(lane_layout(4*ndw)) # "pcie_link"

        # Controls ("pcie_link").
        self.enable       = Signal(reset=1)
        self.retrain      = Signal()
        self.link_error   = Signal()
        self.link_number  = Signal(8)
        self.speed_change = Signal()
        self.lanes_ok     = Signal(nlanes) # o ("pcie_pipe")
        self.width        = Signal(max=nlanes + 1, reset=nlanes) # o ("pcie_pipe")
        self.lane_disable = Signal(nlanes) # i
        self.eq_request_preset = Signal(5) # i
        self.force_g3     = Signal()       # i: debug (gen3_capable, LTSSM disabled): 8.0 GT/s, transmitters on.

        # # #

        # LTSSM ------------------------------------------------------------------------------------
        self.ltssm = ltssm = ClockDomainsRenamer("pcie_link")(PCIeLTSSM(clk_freq,
            upstream     = upstream,
            with_timers  = with_timers,
            timer_scale  = timer_scale,
            gen2_capable = gen2_capable,
            gen3_capable = gen3_capable,
            ts1_min      = ts1_min,
            **ltssm_kwargs,
        ))
        serdes_ready = Signal()
        self.specials += MultiReg(serdes.ready, serdes_ready, "pcie_link")
        self.comb += [
            ltssm.enable.eq(self.enable & serdes_ready),
            ltssm.retrain.eq(self.retrain),
            ltssm.link_error.eq(self.link_error),
            ltssm.link_number.eq(self.link_number),
            ltssm.speed_change.eq(self.speed_change),
            serdes.rate.eq(Mux(self.force_g3, 2, ltssm.rate)),
            ltssm.rate_done.eq(serdes.rate_done),
        ]

        # LTSSM levels in the lane clock domain.
        levels = {}
        for name in ["tx_elecidle", "tx_ts_enable", "tx_ts2", "tx_ts_link", "tx_ts_link_pad",
                     "tx_ts_lane", "tx_ts_lane_pad", "tx_ts_rate", "tx_ts_ctrl", "tx_ts_eq_info",
                     "tx_data_enable", "rx_data_enable", "idle_hs", "rx_reset",
                     "scrambling_enable", "skp_enable"]:
            level = Signal(len(getattr(ltssm, name)), name="pipe_" + name)
            self.specials += MultiReg(getattr(ltssm, name), level, "pcie_pipe")
            levels[name] = level
        rate           = Signal(2)
        select_deemph  = Signal()
        polarity_check = Signal()
        in_training    = Signal(reset=1)
        in_config      = Signal()
        lane_disable   = Signal(nlanes)
        self.specials += [
            MultiReg(ltssm.in_training,    in_training,    "pcie_pipe"),
            MultiReg(ltssm.in_config,      in_config,      "pcie_pipe"),
            MultiReg(self.lane_disable,    lane_disable,   "pcie_pipe"),
            MultiReg(serdes.rate,          rate,           "pcie_pipe"),
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
                lane.tx_deemph.eq((rate == 0) | select_deemph),
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

        # Width negotiation ("pcie_pipe") ----------------------------------------------------------
        # A lane is in the Link once it receives the Link Number (downstream: the partner answers on it)
        # and its Lane Number (upstream). Width: the largest with all the lanes from Lane 0.
        link_ok  = [Signal() for _ in range(nlanes)]
        lane_num = [Signal() for _ in range(nlanes)]
        lane_pad = [Signal() for _ in range(nlanes)]
        widths   = [w for w in [1, 2, 4, 8, 16] if w <= nlanes]
        cand     = Signal(max=nlanes + 1, reset=1)
        numbered = link_ok if not upstream else lane_num
        selection = cand.eq(1)
        for w in widths[1:]:
            selection = If(Reduce("AND", numbered[:w]), cand.eq(w)).Else(selection)
        self.comb += selection
        self.sync.pcie_pipe += If(in_training,
            self.width.eq(nlanes)
        ).Elif(in_config,
            self.width.eq(cand)
        )
        frozen = ~in_training & ~in_config
        self.comb += self.lanes_ok.eq(Cat(*lane_num))
        for i in range(nlanes):
            self.comb += lane_pad[i].eq(~lane_num[i] if upstream else (i >= cand))

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
                ts_gen.eieos.eq(rate != 0),
                ts_gen.eieos_reset.eq(eieos_reset.o),
                ts_gen.enable.eq(levels["tx_ts_enable"]),
                ts_gen.ts.ts2.eq(levels["tx_ts2"]),
                ts_gen.ts.link.eq(levels["tx_ts_link"]),
                ts_gen.ts.link_pad.eq(levels["tx_ts_link_pad"] | (upstream & ~link_ok[i])),
                ts_gen.ts.lane.eq(i),
                ts_gen.ts.lane_pad.eq(levels["tx_ts_lane_pad"] | lane_pad[i]),
                ts_gen.ts.n_fts.eq(0xff),
                ts_gen.ts.rate.eq(levels["tx_ts_rate"]),
                ts_gen.ts.ctrl.eq(levels["tx_ts_ctrl"]),
                ts_gen.ts.eq_info.eq(levels["tx_ts_eq_info"]),
            ]
        tx_ts_done = PulseSynchronizer("pcie_pipe", "pcie_link")
        self.submodules += tx_ts_done
        self.comb += [
            tx_ts_done.i.eq(self.ts_gens[0].done),
            ltssm.tx_ts_done.eq(tx_ts_done.o),
        ]

        self.tx_fifo = tx_fifo = ClockDomainsRenamer({"write": "pcie_link", "read": "pcie_pipe"})(
            stream.AsyncFIFO(lane_layout(4*ndw), tx_depth, buffered=True))
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

        # Beats split into a word per Symbol times for the lanes in use.
        tx_data  = levels["tx_data_enable"] & tx_fifo.source.valid
        tx_part  = Signal(max=max(ndw, 2))
        tx_end   = Signal() # Last word of the beat.
        tx_ok    = all_ready & tx_data & ~eios_pending & ~tx_elecidle & ~ts_mode
        self.comb += tx_fifo.source.ready.eq(tx_ok & tx_end)
        self.comb += Case(self.width, {w: tx_end.eq(tx_part == ndw//w - 1) for w in widths})
        self.sync.pcie_pipe += If(~levels["tx_data_enable"],
            tx_part.eq(0)
        ).Elif(tx_ok,
            If(tx_end, tx_part.eq(0)).Else(tx_part.eq(tx_part + 1))
        )
        for i, lane in enumerate(lanes):
            ts_gen = self.ts_gens[i]
            striped_data = Signal(32)
            striped_ctrl = Signal(4)
            cases = {}
            for w in widths:
                if i >= w:
                    continue
                parts = {}
                for part in range(ndw//w):
                    symbols = [part*4*w + j*w + i for j in range(4)]
                    parts[part] = [
                        striped_data.eq(Cat(*[tx_fifo.source.data[8*k:8*(k+1)] for k in symbols])),
                        striped_ctrl.eq(Cat(*[tx_fifo.source.ctrl[k] for k in symbols])),
                    ]
                cases[w] = Case(tx_part, parts)
            self.comb += [
                Case(self.width, cases),
                # Lanes out of the Link in Electrical Idle.
                lane.tx_elecidle.eq((tx_elecidle & ~eios_pending) | lane_disable[i] | (frozen & (i >= self.width)) |
                    (early_idle & in_config & link_ok[0] & (i >= cand))),
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
                ).Elif(tx_data,
                    lane.sink.valid.eq(all_ready),
                    lane.sink.first.eq(tx_fifo.source.first & (tx_part == 0)),
                    lane.sink.last.eq(tx_fifo.source.last & tx_end),
                    lane.sink.data.eq(striped_data),
                    lane.sink.ctrl.eq(striped_ctrl),
                ).Else(
                    lane.sink.valid.eq(all_ready),
                ),
            ]
        self.comb += [
            eios_sent.eq(eios_pending & all_ready),
            If(~eios_pending & ~tx_elecidle & ~ts_mode & ~tx_data,
                tx_idle.eq(all_ready)
            ),
        ]

        # RX ("pcie_pipe") -------------------------------------------------------------------------
        self.ts_chks = []
        recent       = []
        for i, lane in enumerate(lanes):
            ts_chk = ClockDomainsRenamer("pcie_pipe")(TSChecker())
            self.submodules += ts_chk
            self.ts_chks.append(ts_chk)
            self.comb += [
                lane.source.connect(ts_chk.sink, omit={"ready", "valid"}),
                ts_chk.sink.valid.eq(lane.source.valid & ~lane_disable[i]),
            ]
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
            # Numbers received on this lane, and is it receiving Training Sequences.
            received = Signal(13)
            recent.append(received != 0)
            self.sync.pcie_pipe += [
                If(in_training | lane_disable[i],
                    link_ok[i].eq(0),
                    lane_num[i].eq(0),
                ).Elif(ts_chk.detected,
                    link_ok[i].eq(~ts_chk.ts.link_pad & (ts_chk.ts.link == levels["tx_ts_link"])),
                    lane_num[i].eq(~ts_chk.ts.lane_pad & (ts_chk.ts.lane == i)),
                ),
                If(lane_disable[i],
                    received.eq(0)
                ).Elif(ts_chk.detected,
                    received.eq(2**13 - 1)
                ).Elif(received != 0,
                    received.eq(received - 1)
                )
            ]
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
        lanes_locked = Signal()
        self.specials += MultiReg(deskew.stable, lanes_locked, "pcie_link")
        self.comb += ltssm.lanes_locked.eq(lanes_locked)
        for i, lane in enumerate(lanes):
            self.comb += [
                deskew.sinks[i].valid.eq(lane.source.valid),
                deskew.sinks[i].data.eq(lane.source.data),
                deskew.sinks[i].ctrl.eq(lane.source.ctrl),
                lane.source.ready.eq(1),
            ]
        # Lanes to deskew: the ones receiving Training Sequences until the lanes are numbered, then the ones
        # of the Link: the partner can stop on the others during Configuration. Lane 0 always.
        in_link = Signal(nlanes)
        for i in range(nlanes):
            self.comb += If(frozen | (in_config & numbered[0]),
                in_link[i].eq(i < self.width)
            ).Elif(i == 0,
                in_link[i].eq(1)
            ).Else(
                in_link[i].eq(recent[i])
            )
        self.comb += [
            deskew.mask.eq(in_link),
            deskew.align.eq(~levels["rx_data_enable"]),
            deskew.clear.eq(tx_elecidle),
            deskew.source.ready.eq(1),
        ]

        # Words of the lanes in use: Symbol j*width + i.
        word_data = Signal(32*nlanes)
        word_ctrl = Signal(4*nlanes)
        cases = {}
        for w in widths:
            statements = []
            for i in range(w):
                for j in range(4):
                    statements += [
                        word_data[8*(j*w + i):8*(j*w + i + 1)].eq(deskew.source.data[8*(j*nlanes + i):8*(j*nlanes + i + 1)]),
                        word_ctrl[j*w + i].eq(deskew.source.ctrl[j*nlanes + i]),
                    ]
            cases[w] = statements
        self.comb += Case(self.width, cases)

        # x1 and x2: packets aligned on the DWs.
        self.aligner_x1 = aligner_x1 = ClockDomainsRenamer("pcie_pipe")(RXPhaseAlignerX1())
        self.aligner_x2 = aligner_x2 = ClockDomainsRenamer("pcie_pipe")(RXPhaseAligner())
        aligned_valid = Signal()
        aligned_data  = Signal(32*nlanes)
        aligned_ctrl  = Signal(4*nlanes)
        self.comb += [
            aligner_x1.sink.valid.eq(deskew.source.valid & (self.width == 1)),
            aligner_x1.sink.data.eq(word_data[:32]),
            aligner_x1.sink.ctrl.eq(word_ctrl[:4]),
            aligner_x2.sink.valid.eq(deskew.source.valid & (self.width == 2)),
            aligner_x2.sink.data.eq(word_data[:64]),
            aligner_x2.sink.ctrl.eq(word_ctrl[:8]),
            aligner_x1.source.ready.eq(1),
            aligner_x2.source.ready.eq(1),
            If(self.width == 1,
                aligned_valid.eq(aligner_x1.source.valid),
                aligned_data.eq(aligner_x1.source.data),
                aligned_ctrl.eq(aligner_x1.source.ctrl),
            ).Elif(self.width == 2,
                aligned_valid.eq(aligner_x2.source.valid),
                aligned_data.eq(aligner_x2.source.data),
                aligned_ctrl.eq(aligner_x2.source.ctrl),
            ).Else(
                aligned_valid.eq(deskew.source.valid),
                aligned_data.eq(word_data),
                aligned_ctrl.eq(word_ctrl),
            )
        ]

        # Words to beats.
        rx_part  = Signal(max=max(ndw, 2))
        rx_end   = Signal()
        beat_ok  = Signal()
        beat_data = Signal(32*ndw)
        beat_ctrl = Signal(4*ndw)
        self.comb += Case(self.width, {w: rx_end.eq(rx_part == ndw//w - 1) for w in widths})
        store = {}
        for w in widths:
            store[w] = Case(rx_part, {part: [
                beat_data[32*w*part:32*w*(part + 1)].eq(aligned_data[:32*w]),
                beat_ctrl[4*w*part:4*w*(part + 1)].eq(aligned_ctrl[:4*w]),
            ] for part in range(ndw//w)})
        self.sync.pcie_pipe += [
            beat_ok.eq(aligned_valid & rx_end),
            If(aligned_valid,
                Case(self.width, store),
                If(rx_end, rx_part.eq(0)).Else(rx_part.eq(rx_part + 1)),
            )
        ]
        self.rx_fifo = rx_fifo = ClockDomainsRenamer({"write": "pcie_pipe", "read": "pcie_link"})(
            stream.AsyncFIFO(lane_layout(4*ndw), rx_depth, buffered=True))
        self.comb += [
            rx_fifo.sink.valid.eq(beat_ok & levels["rx_data_enable"]),
            rx_fifo.sink.data.eq(beat_data),
            rx_fifo.sink.ctrl.eq(beat_ctrl),
            rx_fifo.source.connect(source),
        ]

        # Logical Idle handshake (all the lanes side by side): 8 Idle Symbols per lane, then 16 sent.
        idle_hs       = levels["idle_hs"]
        rx_idle_word  = Signal()
        rx_idle_words = Signal(2)
        rx_idle_seen  = Signal()
        tx_idle_after = Signal(3)
        idle_hs_done  = Signal()
        lanes_idle = [(~in_link[i] | ((word == 0) & (ctrl == 0))) for i, (word, ctrl) in enumerate(
            (Cat(*[deskew.source.data[8*(j*nlanes + i):8*(j*nlanes + i + 1)] for j in range(4)]),
             Cat(*[deskew.source.ctrl[j*nlanes + i] for j in range(4)])) for i in range(nlanes))]
        self.comb += rx_idle_word.eq(deskew.source.valid & Reduce("AND", lanes_idle))
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
        idle_hs_done_link = Signal()
        self.specials += MultiReg(idle_hs_done, idle_hs_done_link, "pcie_link")
        self.comb += ltssm.idle_hs_done.eq(idle_hs_done_link)

        # 8.0 GT/s ---------------------------------------------------------------------------------
        if not gen3_capable:
            self.comb += ltssm.eq_eval_done.eq(1)
            return
        # Datapath in "pcie_g3" (the transmit clock of the transceivers at 8.0 GT/s), selected on the
        # "pcie_link" side with the rate.
        g3_link = Signal()
        self.comb += g3_link.eq(serdes.rate == 2)
        eq_ts2 = []
        for i in range(nlanes):
            # EQ TS2 received on each lane at the lower rates.
            value = Signal(8)
            self.sync.pcie_pipe += If(in_training,
                value.eq(0)
            ).Elif((rate != 2) & self.ts_chks[i].detected & self.ts_chks[i].ts.ts2 & self.ts_chks[i].ts.eq_info[7],
                value.eq(self.ts_chks[i].ts.eq_info)
            )
            eq_ts2.append(value)
        self.g3 = g3 = Gen3Lanes(ltssm, lanes, upstream, skp_interval=gen3_skp_interval, rate=serdes.rate)
        # Lanes in Electrical Idle once the EIOS Block is out (seen busy then done).
        g3_eios_busy = Signal()
        g3_eios_wait = Signal()
        g3_eios_seen = Signal()
        self.specials += MultiReg(g3.eios_busy, g3_eios_busy, "pcie_pipe")
        self.sync.pcie_pipe += If(tx_elecidle & ~tx_elecidle_r,
            g3_eios_wait.eq(rate == 2),
            g3_eios_seen.eq(0),
        ).Elif(g3_eios_wait & g3_eios_busy,
            g3_eios_seen.eq(1),
        ).Elif(g3_eios_wait & g3_eios_seen,
            g3_eios_wait.eq(0),
        )
        for i, lane in enumerate(lanes):
            self.comb += If((rate == 2) & tx_elecidle & ~lane_disable[i],
                lane.tx_elecidle.eq(~(g3_eios_wait | (tx_elecidle & ~tx_elecidle_r)))
            )
        force_g3 = Signal()
        self.specials += MultiReg(self.force_g3, force_g3, "pcie_pipe")
        for i, lane in enumerate(lanes):
            self.comb += If(force_g3, lane.tx_elecidle.eq(lane_disable[i]))
        self.comb += [
            g3.eq_request_preset.eq(self.eq_request_preset),
            g3.lane_pad.eq(Cat(*lane_pad)),
            g3.link_pad.eq(upstream & ~link_ok[0]),
            *[g3.eq_ts2[i].eq(eq_ts2[i]) for i in range(nlanes)],
            ltssm.eq_eval_done.eq(g3.eq_eval_done),
            # Data Link Layer beats to the datapath of the rate.
            tx_fifo.sink.valid.eq(sink.valid & ~g3_link),
            g3.sink.valid.eq(sink.valid & g3_link),
            g3.sink.first.eq(sink.first),
            g3.sink.last.eq(sink.last),
            g3.sink.data.eq(sink.data),
            If(g3_link,
                sink.ready.eq(g3.sink.ready),
                rx_fifo.source.ready.eq(1), # Flushed.
                g3.source.connect(source),
                ltssm.rx_ts.eq(g3.rx_ts),
                *[getattr(ltssm, "rx_ts_" + name).eq(getattr(g3.rx_ts_fields, name)) for name, _ in rx_ts_layout],
                ltssm.rx_ts_inverted.eq(0),
                ltssm.rx_ts_error.eq(g3.rx_ts_error),
                ltssm.rx_eios.eq(g3.rx_eios),
                ltssm.tx_ts_done.eq(g3.tx_ts_done),
                ltssm.lanes_locked.eq(g3.lanes_locked),
                ltssm.idle_hs_done.eq(g3.idle_hs_done),
            ).Else(
                g3.source.ready.eq(1), # Flushed.
            )
        ]

# 8.0 GT/s Lanes -----------------------------------------------------------------------------------

class Gen3Lanes(LiteXModule):
    """8.0 GT/s datapath of PCIeMultiLanePhysicalLayer, in "pcie_g3" (the transmit clock of the transceivers
    at 8.0 GT/s) with its clock domain crossings to "pcie_link": Training Sequences with the equalization
    fields of each lane (Gen3LaneEQ), EIOS before Electrical Idle, Data Stream (SDS first) for the Data Link
    Layer and the Logical Idle handshake (IDL Tokens), the Blocks of the lanes (Gen3LaneTX/RX), the lanes
    aligned on EIEOS (Gen3LinkRX). Inputs from "pcie_pipe" (lane_pad, link_pad, eq_ts2) are levels."""
    def __init__(self, ltssm, lanes, upstream, skp_interval=370, tx_depth=16, rx_depth=16, rate=None):
        from litepcie.phy.soft.gen3 import Gen3LaneTX, Gen3LaneRX, Gen3LinkTX, Gen3LinkRX, Gen3LaneEQ
        from litepcie.phy.soft.gen3 import LFSR_SEEDS, BLOCK_TS, BLOCK_EIOS, ts3_layout, ts3_fields
        nlanes = len(lanes)
        ndw    = 2*nlanes
        rx_ts_layout = [field for field in ts_layout if field[0] != "n_fts"]
        # "pcie_link".
        self.sink         = sink   = stream.Endpoint(lane_layout(4*ndw))
        self.source       = source = stream.Endpoint(lane_layout(4*ndw))
        self.rx_ts        = Signal()                 # o (Pulse)
        self.rx_ts_fields = Record(rx_ts_layout)     # o
        self.rx_ts_error  = Signal()                 # o (Pulse)
        self.rx_eios      = Signal()                 # o (Pulse)
        self.tx_ts_done   = Signal()                 # o (Pulse)
        self.lanes_locked = Signal()                 # o
        self.idle_hs_done = Signal()                 # o
        self.eq_eval_done = Signal()                 # o
        self.eq_request_preset = Signal(5)           # i
        # "pcie_g3".
        self.eios_busy    = Signal()                 # o: EIOS to send or in the transceivers' words.
        # "pcie_pipe".
        self.lane_pad     = Signal(nlanes)           # i
        self.link_pad     = Signal()                 # i
        self.eq_ts2       = [Signal(8) for _ in range(nlanes)] # i

        # # #

        # LTSSM levels and inputs from "pcie_pipe" (rate: "pcie_link", the LTSSM's by default).
        rate_link = rate
        levels = {}
        for name in ["tx_elecidle", "tx_ts2", "tx_ts_link", "tx_ts_link_pad", "tx_ts_lane_pad", "tx_ts_rate",
                     "tx_ts_ctrl", "tx_ts_eq_info", "tx_data_enable", "rx_data_enable", "idle_hs", "rx_reset"]:
            level = Signal(len(getattr(ltssm, name)), name="g3_" + name)
            self.specials += MultiReg(getattr(ltssm, name), level, "pcie_g3")
            levels[name] = level
        rate     = Signal(2)
        lane_pad = Signal(nlanes)
        link_pad = Signal()
        eq_request_preset = Signal(5)
        eq_ts2   = [Signal(8) for _ in range(nlanes)]
        self.specials += [
            MultiReg(ltssm.rate if rate_link is None else rate_link, rate, "pcie_g3"),
            MultiReg(self.lane_pad, lane_pad, "pcie_g3"),
            MultiReg(self.link_pad, link_pad, "pcie_g3"),
            MultiReg(self.eq_request_preset, eq_request_preset, "pcie_g3"),
            *[MultiReg(self.eq_ts2[i], eq_ts2[i], "pcie_g3") for i in range(nlanes)],
        ]
        g3 = Signal()
        self.comb += g3.eq(rate == 2)
        # Reset of the datapath out of 8.0 GT/s, a registered copy per block (fanout).
        g3_reset = Signal(reset=1)
        self.sync.pcie_g3 += g3_reset.eq(~g3 | levels["rx_reset"])
        cd = lambda m: ClockDomainsRenamer("pcie_g3")(ResetInserter()(m))
        self.ltx = ltx = cd(Gen3LinkTX(nlanes, skp_interval=skp_interval))
        self.lrx = lrx = cd(Gen3LinkRX(nlanes))
        self.lanes_tx = lanes_tx = [cd(Gen3LaneTX(LFSR_SEEDS[i % 8])) for i in range(nlanes)]
        self.lanes_rx = lanes_rx = [cd(Gen3LaneRX(LFSR_SEEDS[i % 8])) for i in range(nlanes)]
        self.eqs      = eqs      = [cd(Gen3LaneEQ(upstream)) for i in range(nlanes)]
        self.submodules += lanes_tx + lanes_rx + eqs
        resets = {}
        for m in [ltx, lrx] + lanes_tx + lanes_rx + eqs:
            reset = Signal(reset=1)
            self.sync.pcie_g3 += reset.eq(g3_reset)
            self.comb += m.reset.eq(reset)
            resets[m] = reset

        # Clock domain crossings to "pcie_link".
        self.tx_fifo = tx_fifo = ClockDomainsRenamer({"write": "pcie_link", "read": "pcie_g3"})(
            stream.AsyncFIFO(lane_layout(4*ndw), tx_depth, buffered=True))
        self.rx_fifo = rx_fifo = ClockDomainsRenamer({"write": "pcie_g3", "read": "pcie_link"})(
            stream.AsyncFIFO(lane_layout(4*ndw), rx_depth, buffered=True))
        self.ts_fifo = ts_fifo = ClockDomainsRenamer({"write": "pcie_g3", "read": "pcie_link"})(
            stream.AsyncFIFO(rx_ts_layout, 4, buffered=True))
        # Registered both ways (timing, the ready of the FIFO to the Data Link Layer's replay buffer).
        self.tx_buffer = tx_buffer = ClockDomainsRenamer("pcie_link")(
            stream.Buffer(lane_layout(4*ndw), pipe_valid=True, pipe_ready=True))
        self.comb += [
            sink.connect(tx_buffer.sink),
            tx_buffer.source.connect(tx_fifo.sink),
            rx_fifo.source.connect(source),
            ts_fifo.source.ready.eq(1),
            self.rx_ts.eq(ts_fifo.source.valid),
            *[getattr(self.rx_ts_fields, name).eq(getattr(ts_fifo.source, name)) for name, _ in rx_ts_layout],
        ]
        pulses = {}
        for name in ["rx_ts_error", "rx_eios", "tx_ts_done"]:
            ps = PulseSynchronizer("pcie_g3", "pcie_link")
            self.submodules += ps
            self.comb += getattr(self, name).eq(ps.o)
            pulses[name] = ps.i

        # TX: Training Sequences with the equalization fields of each lane, EIOS before Electrical Idle,
        # Data Stream (SDS first) in L0 and for the Logical Idle handshake (IDL Tokens).
        tx_elecidle   = levels["tx_elecidle"]
        tx_elecidle_r = Signal()
        eios_pending  = Signal()
        data_enable   = levels["tx_data_enable"]
        in_packet     = Signal() # Beats already taken: in a packet (EDS not allowed before the next one).
        take0         = ltx.blocks[0].valid & ltx.blocks[0].ready
        eios_drain    = Signal(3)
        self.sync.pcie_g3 += [
            tx_elecidle_r.eq(tx_elecidle),
            If(tx_elecidle & ~tx_elecidle_r,
                eios_pending.eq(1)
            ).Elif(take0 & (ltx.blocks[0].kind == BLOCK_EIOS),
                eios_pending.eq(0),
                eios_drain.eq(7),
            ).Elif(eios_drain != 0,
                eios_drain.eq(eios_drain - 1)
            ),
            If(~data_enable,
                in_packet.eq(0)
            ).Elif(tx_fifo.source.valid & ltx.sink.ready,
                If(tx_fifo.source.first & ~tx_fifo.source.last,
                    in_packet.eq(1)
                ).Elif(tx_fifo.source.last,
                    in_packet.eq(0)
                )
            )
        ]
        self.comb += [
            self.eios_busy.eq(eios_pending | (eios_drain != 0)),
            ltx.data_enable.eq(data_enable | levels["idle_hs"]),
            ltx.eios.eq(eios_pending),
            ltx.lane_eq_enable.eq(1),
            ltx.ts.ts2.eq(levels["tx_ts2"]),
            ltx.ts.link.eq(levels["tx_ts_link"]),
            ltx.ts.link_pad.eq(levels["tx_ts_link_pad"] | link_pad),
            ltx.ts.lane_pad.eq(levels["tx_ts_lane_pad"]),
            ltx.ts.n_fts.eq(0xff),
            ltx.ts.rate.eq(levels["tx_ts_rate"]),
            ltx.ts.ctrl.eq(levels["tx_ts_ctrl"]),
            ltx.lane_pad.eq(lane_pad),
            ltx.idle.eq(~in_packet),
            If(data_enable,
                ltx.sink.valid.eq(tx_fifo.source.valid),
                ltx.sink.data.eq(tx_fifo.source.data),
                tx_fifo.source.ready.eq(ltx.sink.ready),
            ).Else(
                ltx.sink.valid.eq(1),
                ltx.sink.data.eq(0),
                tx_fifo.source.ready.eq(1), # Flushed.
            ),
            pulses["tx_ts_done"].eq(take0 & (ltx.blocks[0].kind == BLOCK_TS)),
        ]
        for i, lane in enumerate(lanes):
            self.comb += [
                ltx.blocks[i].connect(lanes_tx[i].sink),
                lane.raw_tx.eq(lanes_tx[i].data),
                lanes_tx[i].reset_balance.eq(tx_elecidle),
                ltx.lane_eq[i].eq(eqs[i].tx),
                lane.tx_eq_pre.eq(eqs[i].c_pre),
                lane.tx_eq_post.eq(eqs[i].c_post),
            ]

        # RX: Blocks of the lanes aligned, Data Stream to the Data Link Layer, Training Sequences of Lane 0
        # to the LTSSM.
        for i, lane in enumerate(lanes):
            self.comb += [
                lanes_rx[i].data.eq(lane.raw_rx),
                lanes_rx[i].gearbox.ce.eq(lane.raw_rx_valid),
                lanes_rx[i].locked.eq(lrx.locked),
                lanes_rx[i].source.connect(lrx.blocks[i]),
            ]
        rx_ts3 = Record(ts3_layout())
        self.comb += ts3_fields(lrx.ts_data[0:128], rx_ts3)
        self.comb += [
            lrx.source.ready.eq(1),
            rx_fifo.sink.valid.eq(lrx.source.valid & levels["rx_data_enable"]),
            rx_fifo.sink.data.eq(lrx.source.data),
            ts_fifo.sink.valid.eq(lrx.ts_valid),
            *[getattr(ts_fifo.sink, name).eq(getattr(rx_ts3, name)) for name in
                ["ts2", "link", "link_pad", "lane", "lane_pad", "rate", "ctrl"]],
            ts_fifo.sink.eq_info.eq(rx_ts3.eq_ctrl),
            pulses["rx_ts_error"].eq(lrx.error),
            pulses["rx_eios"].eq(lrx.eios),
        ]
        self.specials += MultiReg(lrx.locked, self.lanes_locked, "pcie_link")

        # Logical Idle handshake: a beat of IDL Tokens received (8 Symbols per lane), then 4 sent.
        idle_hs       = levels["idle_hs"]
        rx_idle_seen  = Signal()
        tx_idle_after = Signal(3)
        idle_hs_done  = Signal()
        self.sync.pcie_g3 += If(~idle_hs,
            rx_idle_seen.eq(0),
            tx_idle_after.eq(0),
        ).Else(
            If(lrx.source.valid & (lrx.source.data == 0), rx_idle_seen.eq(1)),
            If(~data_enable & ltx.sink.ready & rx_idle_seen & (tx_idle_after != 7), tx_idle_after.eq(tx_idle_after + 1)),
        )
        self.comb += idle_hs_done.eq(idle_hs & rx_idle_seen & (tx_idle_after >= 4))
        self.specials += MultiReg(idle_hs_done, self.idle_hs_done, "pcie_link")

        # Equalization of each lane: preset of the EQ TS2 received at the lower rate, loaded at the change to
        # 8.0 GT/s, phase from the LTSSM, Training Sequences of the lane.
        eval_done = Signal()
        self.comb += eval_done.eq(Reduce("AND", [eq.eval_done for eq in eqs]))
        self.specials += MultiReg(eval_done, self.eq_eval_done, "pcie_link")
        # Preset loaded on the first cycle out of reset (the change to 8.0 GT/s).
        eq_load = []
        for eq in eqs:
            reset_r = Signal(reset=1)
            load    = Signal()
            self.sync.pcie_g3 += reset_r.eq(resets[eq])
            self.comb += load.eq(reset_r & ~resets[eq])
            eq_load.append(load)
        for i in range(nlanes):
            rx_ts = Record(ts3_layout())
            self.comb += ts3_fields(lrx.ts_data[128*i:128*(i + 1)], rx_ts)
            self.comb += [
                eqs[i].ec.eq(levels["tx_ts_eq_info"][0:2]),
                eqs[i].load.eq(eq_load[i]),
                eqs[i].eq_ts2.eq(eq_ts2[i]),
                eqs[i].rx_valid.eq(lrx.ts_valid),
                eqs[i].rx.eq(rx_ts),
                eqs[i].request_preset.eq(eq_request_preset),
            ]


