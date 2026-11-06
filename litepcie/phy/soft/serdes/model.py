#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY lane transceivers simulation model.

PCIeSerDesModel implements the PCIeSerDes contract with the fabric 8b/10b encoders/decoders and the
lane datapaths, exchanging 40-bit raw words (tx/rx per lane) with a partner model: polarity
inversion, RX Symbol shift (the word phase of a real link is arbitrary) and Electrical Idle are
emulated, receiver detection reports the partner's presence. The RX side runs in the partner's lane
clock domain (rx_cd: the recovered clock), as a real transceiver.
"""

from migen import *
from migen.genlib.cdc import MultiReg

from litex.gen import *

from litex.soc.interconnect import stream
from litex.soc.cores.code_8b10b import Encoder, Decoder

from litepcie.phy.soft.datapath   import RXErrorSubstitution
from litepcie.phy.soft.serdes.base import PCIeSerDes

# PCIe SerDes Model --------------------------------------------------------------------------------

class PCIeSerDesModel(PCIeSerDes):
    def __init__(self, nlanes=1, tx_cd="pcie_pipe", rx_cd="pcie_pipe_partner", rx_symbol_shift=0,
        skp_interval=None, rate_delay=64):
        PCIeSerDes.__init__(self, nlanes)
        self.tx = [stream.Endpoint([("data", 40)]) for _ in range(nlanes)] # o (tx_cd): raw words.
        self.rx = [stream.Endpoint([("data", 40)]) for _ in range(nlanes)] # i (rx_cd): raw words.
        self.tx_idle = Signal(nlanes) # o: TX in Electrical Idle (to the partner).
        self.rx_idle = Signal(nlanes) # i: partner in Electrical Idle.
        self.present = Signal(reset=1) # i: partner receiver present.
        self.partner_rate = Signal()   # i: partner's rate, nothing received when it differs from ours.
        self.fail_5g = Signal()        # i: nothing received at 5.0 GT/s.
        self.applied_rate = Signal()   # o: rate applied.

        # # #

        assert 0 <= rx_symbol_shift <= 3
        # Rate change, after a delay as with real transceivers.
        rate_count = Signal(max=rate_delay + 1)
        sync_rate  = getattr(self.sync, tx_cd)
        sync_rate += [
            If(self.applied_rate == self.rate,
                rate_count.eq(0)
            ).Elif(rate_count == rate_delay,
                self.applied_rate.eq(self.rate)
            ).Else(
                rate_count.eq(rate_count + 1)
            )
        ]
        self.comb += self.rate_done.eq(self.applied_rate == self.rate)
        rx_bad = (self.partner_rate != self.applied_rate) | (self.fail_5g & self.applied_rate)

        # Ready: cleared by the RX re-initialization, as with a real transceiver.
        self.comb += self.ready.eq(Reduce("AND", [lane.ready for lane in self.lanes]))
        for i, lane in enumerate(self.lanes):
            encoder  = ClockDomainsRenamer(tx_cd)(Encoder(4, True))
            decoders = [ClockDomainsRenamer(rx_cd)(Decoder(True)) for _ in range(4)]
            self.submodules += encoder, decoders
            # Decode errors only (no disparity code table: simulation speed).
            err = ClockDomainsRenamer(rx_cd)(RXErrorSubstitution(decoders, clock_domain=rx_cd, with_disparity=False))
            self.submodules += err

            # Transceiver-like stream endpoints: TX always ready, RX always valid.
            xcvr_sink   = stream.Endpoint([("data", 32), ("ctrl", 4)])
            xcvr_source = stream.Endpoint([("data", 32), ("ctrl", 4)])
            self.comb += [xcvr_sink.ready.eq(1), xcvr_source.valid.eq(1)]
            for j in range(4):
                self.comb += [
                    encoder.k[j].eq(xcvr_sink.ctrl[j]),
                    encoder.d[j].eq(xcvr_sink.data[8*j:8*(j+1)]),
                    xcvr_source.ctrl[j].eq(decoders[j].k),
                    xcvr_source.data[8*j:8*(j+1)].eq(decoders[j].d),
                ]
            self.comb += xcvr_source.connect(err.sink)
            self.add_lane_datapaths(lane, xcvr_sink, err.source, rx_cd=rx_cd, tx_cd=tx_cd,
                skp_interval=skp_interval)
            self.add_rx_errors(lane, err.error, rx_cd, cd=tx_cd)

            # TX: polarity, Electrical Idle (all zeros on the line).
            tx_data     = Cat(*[encoder.output[j] for j in range(4)])
            tx_polarity = Signal()
            self.specials += MultiReg(lane.tx_polarity, tx_polarity, tx_cd)
            self.comb += [
                self.tx[i].valid.eq(1),
                If(lane.tx_elecidle,
                    self.tx[i].data.eq(0)
                ).Elif(tx_polarity,
                    self.tx[i].data.eq(~tx_data)
                ).Else(
                    self.tx[i].data.eq(tx_data)
                ),
                self.tx_idle[i].eq(lane.tx_elecidle),
            ]

            # RX: polarity, Symbol shift (previous word in the LSBs of the shift register).
            rx_polarity = Signal()
            rx_data     = Signal(40)
            rx_data_sr  = Signal(80)
            self.specials += MultiReg(lane.rx_polarity, rx_polarity, rx_cd)
            self.comb += If(rx_bad,
                rx_data.eq(0) # Not decodable.
            ).Else(
                rx_data.eq(Mux(rx_polarity, ~self.rx[i].data, self.rx[i].data))
            )
            getattr(self.sync, rx_cd).__iadd__(rx_data_sr.eq(Cat(rx_data_sr[40:], rx_data)))
            for j in range(4):
                self.comb += decoders[j].input.eq(rx_data_sr[10*(rx_symbol_shift + j):10*(rx_symbol_shift + j + 1)])

            # Status.
            idle = Signal()
            self.specials += MultiReg(self.rx_idle[i], idle, tx_cd)
            self.add_rx_elecidle_filter(lane, idle, cd=tx_cd)
            sync_tx = getattr(self.sync, tx_cd)
            sync_tx += [
                lane.ready.eq(~lane.rx_reset),
                lane.detect_done.eq(lane.tx_detect_rx),
                lane.rx_detected.eq(self.present),
            ]

    def connect(self, partner):
        """Link two models: this TX to the partner RX and the reverse."""
        for i in range(self.nlanes):
            self.comb += [
                self.tx[i].connect(partner.rx[i]),
                partner.tx[i].connect(self.rx[i]),
                partner.rx_idle[i].eq(self.tx_idle[i]),
                self.rx_idle[i].eq(partner.tx_idle[i]),
            ]
        self.comb += [
            partner.partner_rate.eq(self.applied_rate),
            self.partner_rate.eq(partner.applied_rate),
        ]
