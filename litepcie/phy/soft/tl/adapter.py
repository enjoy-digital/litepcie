#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY: Data Link Layer DW stream <-> LitePCIe TLP stream (phy_layout).

Data Link Layer DWs are in wire order with byte 0 on bits 7:0. LitePCIe DWs (endianness="big") have
byte 0 on bits 31:24, TLPs start on DW 0 of a beat and DWs past the end of a TLP have be=0.
"""

from migen import *

from litex.gen import *

from litex.soc.interconnect import stream

from litepcie.common import phy_layout

def swap_dw(dw):
    return Cat(dw[24:32], dw[16:24], dw[8:16], dw[0:8])

# TX Adapter ---------------------------------------------------------------------------------------

class TXAdapter(LiteXModule):
    """LitePCIe TLP beats to DWs: the DWs with be=0 are dropped, last is on the last valid DW."""
    def __init__(self, data_width):
        self.sink   = sink   = stream.Endpoint(phy_layout(data_width))
        self.source = source = stream.Endpoint([("data", 32)])

        # # #

        ratio = data_width//32
        index = Signal(max=max(ratio, 2))
        first = Signal(reset=1)
        dw_be = Signal(4)
        rest  = Signal() # Valid DWs after the current one in the beat.
        dat   = Array(sink.dat[32*i:32*(i+1)] for i in range(ratio))
        be    = Array(sink.be[4*i:4*(i+1)]    for i in range(ratio))
        rests = Array(Reduce("OR", [sink.be[4*j:4*(j+1)] != 0 for j in range(i + 1, ratio)]) if i + 1 < ratio else Constant(0, 1)
            for i in range(ratio))
        cur   = Signal(32)
        self.comb += [
            dw_be.eq(be[index]),
            cur.eq(dat[index]),
            rest.eq(rests[index]),
            source.valid.eq(sink.valid & (dw_be != 0)),
            source.data.eq(swap_dw(cur)),
            source.first.eq(first),
            source.last.eq(sink.last & ~rest),
            # Beat consumed with its last valid DW (or when empty).
            sink.ready.eq(~rest & ((dw_be == 0) | source.ready)),
        ]
        advance = sink.valid & ((dw_be == 0) | source.ready)
        self.sync += [
            If(advance,
                If(rest,
                    index.eq(index + 1)
                ).Else(
                    index.eq(0)
                )
            ),
            If(source.valid & source.ready,
                first.eq(source.last)
            )
        ]

# RX Adapter ---------------------------------------------------------------------------------------

class RXAdapter(LiteXModule):
    """DWs to LitePCIe TLP beats: first DW of a TLP on DW 0, be=0 past the end."""
    def __init__(self, data_width):
        self.sink   = sink   = stream.Endpoint([("data", 32)])
        self.source = source = stream.Endpoint(phy_layout(data_width))

        # # #

        ratio = data_width//32
        index = Signal(max=max(ratio, 2))
        dat   = Signal(data_width)
        be    = Signal(data_width//8)
        out   = Signal()
        swapped = swap_dw(sink.data)
        load  = sink.valid & sink.ready
        beat_end = (index == ratio - 1) | sink.last
        self.comb += [
            sink.ready.eq(~out | source.ready),
            source.valid.eq(out),
            source.dat.eq(dat),
            source.be.eq(be),
        ]
        cases = {i: [dat[32*i:32*(i+1)].eq(swapped), be[4*i:4*(i+1)].eq(0xf)] for i in range(ratio)}
        self.sync += [
            If(source.valid & source.ready,
                out.eq(0)
            ),
            If(load,
                If(index == 0,
                    # New beat: previous contents cleared.
                    dat.eq(swapped),
                    be.eq(0xf),
                    source.first.eq(sink.first),
                ).Else(
                    Case(index, cases)
                ),
                source.last.eq(sink.last),
                If(beat_end,
                    out.eq(1),
                    index.eq(0),
                ).Else(
                    index.eq(index + 1)
                )
            )
        ]
