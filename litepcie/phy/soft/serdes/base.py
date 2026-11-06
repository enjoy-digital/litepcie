#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY lane transceiver contract.

A PCIeSerDes drives nlanes lanes. Each lane (PCIeLane) exchanges 4-Symbol words (lane_layout(4)) in
the "pcie_pipe" clock domain, the lane clock: 62.5 MHz at 2.5 GT/s and 125 MHz at 5.0 GT/s with 40-bit
transceiver interfaces. The serdes includes the lane datapaths: on TX, Logical Idle filling, SKP
Ordered Set insertion (between the packets/Ordered Sets delimited by first/last) and scrambling; on
RX, 8b/10b decoding with error substitution (ERR Symbol), descrambling, SKP Ordered Set removal and
the elastic buffer from the recovered clock to the lane clock. The upper layers see a logical lane:
Training Sequences, Ordered Sets and packets, at any Symbol position on RX.

Lane clock domains come from the serdes: "pcie_pipe" (lane clock, all lanes), "pcie_link" (fixed
125 MHz), per-lane recovered clocks (internal). Controls/status are in "pcie_pipe" unless noted.
"""

from migen import *
from migen.genlib.cdc import PulseSynchronizer

from litex.gen import *

from litex.soc.interconnect import stream

from litepcie.phy.soft.common   import lane_layout
from litepcie.phy.soft.datapath import TXLaneDatapath, RXLaneDatapath, RXIdleFilter

# PCIe Lane ----------------------------------------------------------------------------------------

class PCIeLane:
    """Lane interface (signals only, see the module docstring)."""
    def __init__(self):
        self.sink   = stream.Endpoint(lane_layout(4)) # Symbols to transmit (first/last: packets/OS).
        self.source = stream.Endpoint(lane_layout(4)) # Received Symbols (descrambled, no SKP OS).

        # TX controls.
        self.tx_elecidle  = Signal()        # i: TX Electrical Idle.
        self.tx_detect_rx = Signal()        # i (Pulse): receiver detection request (TX in Electrical Idle).
        self.tx_deemph    = Signal(reset=1) # i: TX de-emphasis (0: -6 dB, 1: -3.5 dB).
        self.tx_polarity  = Signal()        # i: TX polarity inversion.

        # RX controls.
        self.rx_polarity  = Signal()        # i: RX polarity inversion.
        self.rx_reset     = Signal()        # i (Level): re-initialize the RX (training failure).

        # Datapath controls.
        self.skp_enable        = Signal(reset=1) # i: SKP Ordered Sets scheduling.
        self.scrambling_enable = Signal(reset=1) # i: Disable Scrambling when cleared.

        # Status.
        self.ready        = Signal()   # o: TX/RX initialized.
        self.rx_detected  = Signal()   # o: receiver detected (valid with detect_done).
        self.detect_done  = Signal()   # o (Pulse): receiver detection done.
        self.rx_elecidle  = Signal()   # o: RX Electrical Idle (filtered).
        self.rx_errors    = Signal()   # o (Pulse): 8b/10b error received.
        self.rx_overflows = Signal(16) # o: elastic buffer overflows.

# PCIe SerDes --------------------------------------------------------------------------------------

class PCIeSerDes(LiteXModule):
    """Lane transceivers base: lanes, shared rate/loopback controls and the lane datapaths."""
    def __init__(self, nlanes):
        self.nlanes    = nlanes
        self.lanes     = [PCIeLane() for _ in range(nlanes)]
        self.rate      = Signal()  # i ("pcie_link"): 0: 2.5 GT/s, 1: 5.0 GT/s.
        self.rate_done = Signal()  # o ("pcie_link"): rate change applied.
        self.loopback  = Signal(3) # i: transceiver loopback mode.
        self.ready     = Signal()  # o: all lanes ready.

    def add_lane_datapaths(self, lane, xcvr_sink, xcvr_source, rx_cd, tx_cd="pcie_pipe", skp_interval=None):
        """Lane datapaths around a transceiver: lane.sink -> TX datapath (tx_cd) -> xcvr_sink;
        xcvr_source (rx_cd, 8b/10b errors already substituted) -> RX datapath -> lane.source."""
        kwargs = {} if skp_interval is None else {"skp_interval": skp_interval}
        tx = ClockDomainsRenamer(tx_cd)(TXLaneDatapath(**kwargs))
        rx = RXLaneDatapath(cd_from=rx_cd, cd_to=tx_cd)
        self.submodules += tx, rx
        self.comb += [
            tx.skp_enable.eq(lane.skp_enable),
            tx.scrambling_enable.eq(lane.scrambling_enable),
            rx.scrambling_enable.eq(lane.scrambling_enable),
            lane.sink.connect(tx.sink),
            tx.source.connect(xcvr_sink),
            xcvr_source.connect(rx.sink),
            rx.source.connect(lane.source),
            lane.rx_overflows.eq(rx.overflows),
        ]
        return tx, rx

    def add_rx_elecidle_filter(self, lane, rx_elecidle, cd="pcie_pipe"):
        """Filtered Electrical Idle status from a transceiver's asynchronous detection."""
        f = ClockDomainsRenamer(cd)(RXIdleFilter(rx_elecidle))
        self.submodules += f
        self.comb += lane.rx_elecidle.eq(f.idle)
        return f

    def add_rx_errors(self, lane, error, rx_cd, cd="pcie_pipe"):
        """Lane rx_errors pulses from the RX error pulses of the recovered clock domain."""
        ps = PulseSynchronizer(rx_cd, cd)
        self.submodules += ps
        self.comb += [
            ps.i.eq(error),
            lane.rx_errors.eq(ps.o),
        ]

    def add_receiver_detection_stub(self, lane, cd="pcie_pipe"):
        """Receiver always detected (add-in card bring-up: the host is there), one cycle after the
        request."""
        sync = getattr(self.sync, cd)
        sync += [
            lane.detect_done.eq(lane.tx_detect_rx),
            lane.rx_detected.eq(1),
        ]
