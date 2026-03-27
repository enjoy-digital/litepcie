#
# This file is part of LitePCIe.
#
# Copyright (c) 2020 Antmicro <www.antmicro.com>
# SPDX-License-Identifier: BSD-2-Clause

from migen import *

from litex.gen import *

from litex.soc.interconnect import axi, stream

from litepcie.common       import *
from litepcie.frontend.dma import descriptor_layout, LitePCIeDMAWriter, LitePCIeDMAReader

# LitePCIeAXISlave ---------------------------------------------------------------------------------

class LitePCIeAXISlave(LiteXModule):
    def __init__(self, endpoint, data_width=32, id_width=1):
        self.axi = axi.AXIInterface(data_width=data_width, id_width=id_width)

        # # #

        ax_burst_incr = axi.BURST_INCR
        ax_resp_okay  = axi.RESP_OKAY
        ax_resp_slverr = axi.RESP_SLVERR
        beat_bytes    = data_width//8
        beat_size     = log2_int(beat_bytes)
        full_strb     = (1 << beat_bytes) - 1

        aw_id = Signal(id_width)
        ar_id = Signal(id_width)
        r_len = Signal(8)
        w_len = Signal(9)
        read_error  = Signal()
        write_error = Signal()
        aw_unsupported = Signal()
        ar_unsupported = Signal()
        write_last_expected = Signal()
        write_strobe_error  = Signal()

        desc_rd = stream.Endpoint(descriptor_layout())
        desc_wr = stream.Endpoint(descriptor_layout())

        self.comb += [
            aw_unsupported.eq((self.axi.aw.burst != ax_burst_incr) | (self.axi.aw.size != beat_size)),
            ar_unsupported.eq((self.axi.ar.burst != ax_burst_incr) | (self.axi.ar.size != beat_size)),
            write_last_expected.eq(w_len == 1),
            write_strobe_error.eq(self.axi.w.strb != full_strb),
        ]

        port_rd = endpoint.crossbar.get_master_port(read_only=True)
        port_wr = endpoint.crossbar.get_master_port(write_only=True)

        # AXI Write Path ---------------------------------------------------------------------------

        # DMA / FIFO / Converter
        self.dma_wr = dma_wr = LitePCIeDMAWriter(
            endpoint = endpoint,
            port     = port_wr,
            with_table = False)
        self.fifo_wr = fifo_wr = stream.SyncFIFO(descriptor_layout(), 16)
        self.conv_wr = conv_wr = stream.Converter(nbits_from=data_width, nbits_to=endpoint.phy.data_width)

        # Flow
        self.comb += [
            desc_wr.connect(fifo_wr.sink),
            fifo_wr.source.connect(dma_wr.desc_sink),
            conv_wr.source.connect(dma_wr.sink),
        ]

        # FSM (Convert AXI Write Requests to LitePCIe's DMA Descriptors).
        self.comb += desc_wr.address.eq(self.axi.aw.addr)                        # Start address (byte addressed)
        self.comb += desc_wr.length.eq((self.axi.aw.len + 1) * beat_bytes)      # Transfer length (in bytes)

        self.fsm_wr = fsm_wr = FSM(reset_state="WRITE-IDLE")
        fsm_wr.act("WRITE-IDLE",
            self.axi.aw.ready.eq(desc_wr.ready | aw_unsupported),
            desc_wr.valid.eq(self.axi.aw.valid & ~aw_unsupported),
            If(self.axi.aw.valid & self.axi.aw.ready,
                NextValue(aw_id, self.axi.aw.id),
                NextValue(w_len, self.axi.aw.len + 1),
                NextValue(write_error, aw_unsupported),
                If(aw_unsupported,
                    NextState("WRITE-DROP")
                ).Else(
                    NextState("WRITE-MONITOR")
                )
            )
        )

        self.comb += [
            conv_wr.sink.data.eq(self.axi.w.data),
            # Preserve descriptor-sized framing even when AXI WLAST is malformed.
            conv_wr.sink.last.eq(write_last_expected),
        ]
        fsm_wr.act("WRITE-MONITOR",
            conv_wr.sink.valid.eq(self.axi.w.valid),
            self.axi.w.ready.eq(conv_wr.sink.ready),
            If(self.axi.w.valid & self.axi.w.ready,
                NextValue(write_error, write_error | write_strobe_error | (self.axi.w.last != write_last_expected)),
                NextValue(w_len, w_len - 1),
                If(write_last_expected,
                    NextState("WRITE-RESP")
                )
            )
        )
        fsm_wr.act("WRITE-DROP",
            self.axi.w.ready.eq(1),
            If(self.axi.w.valid,
                NextValue(w_len, w_len - 1),
                If(write_last_expected,
                    NextState("WRITE-RESP")
                )
            )
        )

        self.comb += [
            self.axi.b.id.eq(aw_id),
            self.axi.b.resp.eq(Mux(write_error, ax_resp_slverr, ax_resp_okay)),
        ]
        fsm_wr.act("WRITE-RESP",
            self.axi.b.valid.eq(1),
            If(self.axi.b.ready,
                NextState("WRITE-IDLE"),
            )
        )

        # AXI Read Path ----------------------------------------------------------------------------

        # DMA / FIFO / Converter
        self.dma_rd = dma_rd = LitePCIeDMAReader(
            endpoint = endpoint,
            port     = port_rd,
            with_table = False)
        self.fifo_rd = fifo_rd = stream.SyncFIFO(descriptor_layout(), 16)
        self.conv_rd = conv_rd = stream.Converter(nbits_from=endpoint.phy.data_width, nbits_to=data_width)

        # Flow
        self.comb += [
            desc_rd.connect(fifo_rd.sink),
            fifo_rd.source.connect(dma_rd.desc_sink),
            dma_rd.source.connect(conv_rd.sink),
        ]

        # FSM (Convert AXI Read Requests to LitePCIe's DMA Descriptors).
        self.comb += desc_rd.address.eq(self.axi.ar.addr)                       # Starting address (byte addressed)
        self.comb += desc_rd.length.eq((self.axi.ar.len + 1) * beat_bytes)      # Transfer length (in bytes)

        self.fsm_rd = fsm_rd = FSM(reset_state="READ-IDLE")
        fsm_rd.act("READ-IDLE",
            self.axi.ar.ready.eq(desc_rd.ready | ar_unsupported),
            desc_rd.valid.eq(self.axi.ar.valid & ~ar_unsupported),
            If(self.axi.ar.valid & self.axi.ar.ready,
                NextValue(ar_id, self.axi.ar.id),
                NextValue(r_len, self.axi.ar.len),
                NextValue(read_error, ar_unsupported),
                If(ar_unsupported,
                    NextState("READ-ERROR")
                ).Else(
                    NextState("READ-MONITOR")
                )
            )
        )

        self.comb += [
            self.axi.r.data.eq(Mux(read_error, 0, conv_rd.source.data)),
            self.axi.r.last.eq(r_len == 0),
            # We need to provide the same id that was provided on ar channel for the duration of the transfer.
            self.axi.r.id.eq(ar_id),
            self.axi.r.resp.eq(Mux(read_error, ax_resp_slverr, ax_resp_okay)),
        ]
        fsm_rd.act("READ-MONITOR",
            self.axi.r.valid.eq(conv_rd.source.valid),
            conv_rd.source.ready.eq(self.axi.r.ready),
            If(self.axi.r.ready & self.axi.r.valid,
                NextValue(r_len, r_len - 1),
                If(self.axi.r.last,
                    NextState("READ-IDLE"),
                )
            )
        )
        fsm_rd.act("READ-ERROR",
            self.axi.r.valid.eq(1),
            If(self.axi.r.ready,
                NextValue(r_len, r_len - 1),
                If(self.axi.r.last,
                    NextState("READ-IDLE")
                )
            )
        )

