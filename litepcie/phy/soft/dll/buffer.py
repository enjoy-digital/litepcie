#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY Data Link Layer packet buffer: store-and-forward ring buffer of DW packets with
commit (last word written) or abort (packet being written dropped), per-packet parameters sampled
with the last word written and presented with every word read."""

from migen import *

from litex.gen import *

from litex.soc.interconnect import stream

# Packet Buffer ------------------------------------------------------------------------------------

class PacketBuffer(LiteXModule):
    """depth: DWs (power of 2), packets: committed packets descriptors. sink.ready drops when the
    memory is full (words of an uncommitted packet are kept) or the descriptors are full."""
    def __init__(self, param_layout=[], depth=2048, packets=32):
        self.sink   = sink   = stream.Endpoint([("data", 32)] + param_layout)
        self.source = source = stream.Endpoint([("data", 32)] + param_layout)
        self.abort  = Signal()              # i (Pulse): drop the packet being written.
        self.free   = Signal(max=depth + 1) # o: free DWs.
        self.level  = Signal(max=depth + 1) # o: committed DWs not read yet.

        # # #

        assert depth & (depth - 1) == 0
        adr_width = log2_int(depth)

        mem = Memory(32, depth)
        wr_port = mem.get_port(write_capable=True)
        rd_port = mem.get_port(async_read=False)
        self.specials += mem, wr_port, rd_port

        # Descriptors of the committed packets.
        self.descs = descs = stream.SyncFIFO([("length", adr_width + 1)] + param_layout, packets, buffered=True)

        # Write ------------------------------------------------------------------------------------
        wr_ptr     = Signal(adr_width)
        commit_ptr = Signal(adr_width)
        pending    = Signal(adr_width + 1) # DWs written, not committed.
        used       = Signal(adr_width + 1) # DWs committed, not consumed.
        commit     = Signal()
        self.comb += [
            self.level.eq(used),
            self.free.eq(depth - used - pending),
            sink.ready.eq((self.free != 0) & descs.sink.ready),
            wr_port.adr.eq(wr_ptr),
            wr_port.dat_w.eq(sink.data),
            wr_port.we.eq(sink.valid & sink.ready & ~self.abort),
            commit.eq(sink.valid & sink.ready & sink.last & ~self.abort),
            descs.sink.valid.eq(commit),
            descs.sink.length.eq(pending + 1),
        ]
        for name, width in param_layout:
            self.comb += getattr(descs.sink, name).eq(getattr(sink, name))
        self.sync += [
            If(self.abort,
                wr_ptr.eq(commit_ptr),
                pending.eq(0),
            ).Elif(sink.valid & sink.ready,
                wr_ptr.eq(wr_ptr + 1),
                If(sink.last,
                    commit_ptr.eq(wr_ptr + 1),
                    pending.eq(0),
                ).Else(
                    pending.eq(pending + 1)
                )
            )
        ]

        # Read -------------------------------------------------------------------------------------
        # One packet at a time (descriptor popped with its last word consumed), one word per cycle:
        # source.data is the memory output, the next address is presented when a word is consumed.
        rd_ptr    = Signal(adr_width)
        remaining = Signal(adr_width + 1) # Words left in the current packet, current one included.
        out_valid = Signal()
        consumed  = source.valid & source.ready
        self.comb += [
            source.valid.eq(out_valid),
            source.data.eq(rd_port.dat_r),
            source.last.eq(remaining == 1),
            rd_port.adr.eq(rd_ptr),
            If(consumed & ~source.last,
                rd_port.adr.eq(rd_ptr + 1)
            ),
            descs.source.ready.eq(consumed & source.last),
        ]
        for name, width in param_layout:
            self.comb += getattr(source, name).eq(getattr(descs.source, name))
        self.sync += [
            If(~out_valid,
                If(descs.source.valid,
                    out_valid.eq(1),
                    source.first.eq(1),
                    remaining.eq(descs.source.length),
                )
            ).Elif(consumed,
                source.first.eq(0),
                rd_ptr.eq(rd_ptr + 1),
                remaining.eq(remaining - 1),
                If(source.last,
                    out_valid.eq(0),
                )
            )
        ]

        # Committed/unconsumed DWs.
        self.sync += [
            If(commit & consumed,
                used.eq(used + pending)
            ).Elif(commit,
                used.eq(used + pending + 1)
            ).Elif(consumed,
                used.eq(used - 1)
            )
        ]
