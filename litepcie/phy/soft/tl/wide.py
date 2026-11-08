#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY Transaction Layer glue for wide links (ndw DWs per cycle).

The memory requests and the Completions go to and from LitePCIe at full width. The rest (configuration
accesses, Unsupported Requests, MSI) is what SoftTransactionLayer handles DW by DW: short and rare TLPs,
which are converted, and which keep their priority over LitePCIe's.
"""

from migen import *

from litex.gen import *

from litex.soc.interconnect import stream

from litepcie.common import phy_layout, msi_layout
from litepcie.phy.soft.tl.adapter import swap_dw
from litepcie.phy.soft.tl.core    import SoftTransactionLayer

def beat_layout(ndw):
    return [("data", 32*ndw), ("dws", bits_for(ndw))]

# Converters ---------------------------------------------------------------------------------------

class BeatsToDWs(LiteXModule):
    """TLP beats to DWs."""
    def __init__(self, ndw):
        self.sink   = sink   = stream.Endpoint(beat_layout(ndw))
        self.source = source = stream.Endpoint([("data", 32)])

        # # #

        index = Signal(max=max(ndw, 2))
        dws   = Array(sink.data[32*i:32*(i+1)] for i in range(ndw))
        end   = index == (sink.dws - 1)
        self.comb += [
            source.valid.eq(sink.valid),
            source.data.eq(dws[index]),
            source.first.eq(sink.first & (index == 0)),
            source.last.eq(sink.last & end),
            sink.ready.eq(source.ready & end),
        ]
        self.sync += If(source.valid & source.ready,
            If(end, index.eq(0)).Else(index.eq(index + 1))
        )

class DWsToBeats(LiteXModule):
    """DWs to TLP beats, a beat with what is available at the end of the TLP."""
    def __init__(self, ndw):
        self.sink   = sink   = stream.Endpoint([("data", 32)])
        self.source = source = stream.Endpoint(beat_layout(ndw))

        # # #

        index = Signal(max=max(ndw, 2))
        out   = Signal()
        self.comb += [
            source.valid.eq(out),
            sink.ready.eq(~out | source.ready),
        ]
        self.sync += [
            If(source.valid & source.ready,
                out.eq(0)
            ),
            If(sink.valid & sink.ready,
                Case(index, {i: source.data[32*i:32*(i+1)].eq(sink.data) for i in range(ndw)}),
                If(index == 0,
                    source.first.eq(sink.first)
                ),
                source.last.eq(sink.last),
                source.dws.eq(index + 1),
                If((index == ndw - 1) | sink.last,
                    out.eq(1),
                    index.eq(0),
                ).Else(
                    index.eq(index + 1)
                )
            )
        ]

# Adapters -----------------------------------------------------------------------------------------

class WideTXAdapter(LiteXModule):
    """LitePCIe TLP beats to beats: DWs in byte order, dws from be (the DWs past the end have be=0)."""
    def __init__(self, data_width):
        ndw = data_width//32
        self.sink   = sink   = stream.Endpoint(phy_layout(data_width))
        self.source = source = stream.Endpoint(beat_layout(ndw))

        # # #

        count = If(sink.be[0:4] != 0, source.dws.eq(1)).Else(source.dws.eq(0))
        for i in range(1, ndw):
            count = If(sink.be[4*i:4*(i+1)] != 0, source.dws.eq(i + 1)).Else(count)
        self.comb += [
            count,
            source.valid.eq(sink.valid),
            source.first.eq(sink.first),
            source.last.eq(sink.last),
            sink.ready.eq(source.ready),
            source.data.eq(Cat(*[swap_dw(sink.dat[32*i:32*(i+1)]) for i in range(ndw)])),
        ]

class WideRXAdapter(LiteXModule):
    """Beats to LitePCIe TLP beats: be=0 past the end."""
    def __init__(self, data_width):
        ndw = data_width//32
        self.sink   = sink   = stream.Endpoint(beat_layout(ndw))
        self.source = source = stream.Endpoint(phy_layout(data_width))

        # # #

        self.comb += [
            source.valid.eq(sink.valid),
            source.first.eq(sink.first),
            source.last.eq(sink.last),
            sink.ready.eq(source.ready),
            source.dat.eq(Cat(*[swap_dw(sink.data[32*i:32*(i+1)]) for i in range(ndw)])),
            Case(sink.dws, dict(
                [(n, source.be.eq((1 << 4*n) - 1)) for n in range(ndw + 1)] +
                [("default", source.be.eq(0))])),
        ]

# Transaction Layer --------------------------------------------------------------------------------

class WideTransactionLayer(LiteXModule):
    def __init__(self, ndw, bar0_mask, nlanes=1, vendor_id=0x10ee, device_id=0x7021, msi_vectors=1, gen2_capable=False, gen3_capable=False):
        self.sink      = sink      = stream.Endpoint(beat_layout(ndw)) # i: from the Data Link Layer.
        self.source    = source    = stream.Endpoint(beat_layout(ndw)) # o: to the Data Link Layer.
        self.ep_source = ep_source = stream.Endpoint(beat_layout(ndw)) # o: to LitePCIe.
        self.ep_sink   = ep_sink   = stream.Endpoint(beat_layout(ndw)) # i: from LitePCIe.
        self.msi       = msi       = stream.Endpoint(msi_layout())     # i

        # # #

        self.tl = tl = SoftTransactionLayer(bar0_mask,
            nlanes       = nlanes,
            vendor_id    = vendor_id,
            device_id    = device_id,
            msi_vectors  = msi_vectors,
            gen2_capable = gen2_capable,
            gen3_capable = gen3_capable,
        )
        self.cfg      = tl.cfg
        self.id       = tl.id
        self.ur_count = tl.ur_count
        self.link_width = tl.link_width
        self.comb += [
            msi.connect(tl.msi),
            tl.ep_source.ready.eq(1), # Not used: memory TLPs don't go through it.
        ]

        # Received TLPs: same selection as SoftTransactionLayer on the first DW.
        fmt  = sink.data[5:8]
        type = sink.data[0:5]
        to_ep = ((fmt[0] == 0) & (type == 0)) | ((fmt[0] == 0) & (type == 0b01010))
        self.rx_dws = rx_dws = BeatsToDWs(ndw)
        self.rx_fsm = rx_fsm = FSM(reset_state="IDLE")
        rx_fsm.act("IDLE",
            If(sink.valid,
                If(to_ep,
                    NextState("TO-EP")
                ).Else(
                    NextState("TO-TL")
                )
            )
        )
        rx_fsm.act("TO-EP",
            sink.connect(ep_source),
            If(sink.valid & sink.ready & sink.last,
                NextState("IDLE")
            )
        )
        rx_fsm.act("TO-TL",
            sink.connect(rx_dws.sink),
            If(sink.valid & sink.ready & sink.last,
                NextState("IDLE")
            )
        )
        self.comb += rx_dws.source.connect(tl.sink)

        # Transmitted TLPs: the TL's first, the grant held until the last beat.
        self.tx_beats = tx_beats = DWsToBeats(ndw)
        self.comb += tl.source.connect(tx_beats.sink)
        self.tx_fsm = tx_fsm = FSM(reset_state="IDLE")
        tx_fsm.act("IDLE",
            If(tx_beats.source.valid,
                tx_beats.source.connect(source),
                If(source.ready & ~tx_beats.source.last,
                    NextState("TL")
                )
            ).Elif(ep_sink.valid,
                ep_sink.connect(source),
                If(source.ready & ~ep_sink.last,
                    NextState("EP")
                )
            )
        )
        tx_fsm.act("TL",
            tx_beats.source.connect(source),
            If(source.valid & source.ready & source.last,
                NextState("IDLE")
            )
        )
        tx_fsm.act("EP",
            ep_sink.connect(source),
            If(source.valid & source.ready & source.last,
                NextState("IDLE")
            )
        )
