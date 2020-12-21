#
# This file is part of LitePCIe.
#
# Copyright (c) 2020 Antmicro <www.antmicro.com>
# SPDX-License-Identifier: BSD-2-Clause

from migen import *

from litex.soc.interconnect import axi, stream

from litepcie.common import *

from litepcie.frontend.dma import descriptor_layout, LitePCIeDMAWriter, LitePCIeDMAReader

# LitePCIeAXI4Slave --------------------------------------------------------------------------------

class LitePCIeAXI4Slave(Module):
    def __init__(self, endpoint, data_width=32, id_width=1):
        self.axi = axi.AXIInterface(data_width=data_width, id_width=id_width)

        # # #

        aw_id = Signal(id_width)
        ar_id = Signal(id_width)
        r_len = Signal(8)

        desc_rd = stream.Endpoint(descriptor_layout())
        desc_wr = stream.Endpoint(descriptor_layout())

        port_rd = endpoint.crossbar.get_master_port(read_only=True)
        port_wr = endpoint.crossbar.get_master_port(write_only=True)

        self.submodules.fsm_rd = fsm_rd = FSM(reset_state="READ-IDLE")
        self.submodules.fsm_wr = fsm_wr = FSM(reset_state="WRITE-IDLE")

        self.submodules.writer = writer = LitePCIeDMAWriter(
            endpoint = endpoint,
            port     = port_wr,
            with_table = False)

        self.submodules.reader = reader = LitePCIeDMAReader(
            endpoint = endpoint,
            port     = port_rd,
            with_table = False)

        self.submodules.wr_fifo = wr_fifo = stream.SyncFIFO(descriptor_layout(), 16)
        self.submodules.rd_fifo = rd_fifo = stream.SyncFIFO(descriptor_layout(), 16)

        self.submodules.writer_conv = writer_conv = stream.Converter(nbits_from=data_width, nbits_to=endpoint.phy.data_width)
        self.submodules.reader_conv = reader_conv = stream.Converter(nbits_from=endpoint.phy.data_width, nbits_to=data_width)

        self.comb += [
            desc_wr.connect(wr_fifo.sink),
            wr_fifo.source.connect(writer.desc_sink),
            writer_conv.source.connect(writer.sink),
        ]
        self.comb += [
            desc_rd.connect(rd_fifo.sink),
            rd_fifo.source.connect(reader.desc_sink),
            reader.source.connect(reader_conv.sink),
        ]

        # convert AXI read request to a format used by LitePCIe DMA (defined in descriptor_layout)
        self.comb += [
            desc_rd.address.eq(self.axi.ar.addr), # starting address (byte addressed)
            desc_rd.length.eq((self.axi.ar.len + 1) * (data_width // 8)), # transfer length (in bytes)
        ]

        fsm_rd.act("READ-IDLE",
            self.axi.ar.ready.eq(desc_rd.ready),
            desc_rd.valid.eq(self.axi.ar.valid),
            If(self.axi.ar.valid & self.axi.ar.ready,
                NextValue(ar_id, self.axi.ar.id), # save id to use it on r bus
                NextValue(r_len, self.axi.ar.len),
                NextState("READ-MONITOR"),
            )
        )

        self.comb += [
            self.axi.r.data.eq(reader_conv.source.data),
            self.axi.r.last.eq(r_len == 0),
            # we need to provide the same id that was provided on aw bus for the duration of the transfer
            self.axi.r.id.eq(ar_id),
            self.axi.r.resp.eq(0),
        ]
        fsm_rd.act("READ-MONITOR",
            self.axi.r.valid.eq(reader_conv.source.valid),
            reader_conv.source.ready.eq(self.axi.r.ready),
            If(self.axi.r.ready & self.axi.r.valid,
                NextValue(r_len, r_len - 1),
                If(self.axi.r.last, # check if we finished the whole AXI transaction
                    NextState("READ-IDLE"),
                )
            )
        )

        # convert AXI write request to a format used by LitePCIe DMA (defined in descriptor_layout)
        self.comb += [
            desc_wr.address.eq(self.axi.aw.addr), # starting address (byte addressed)
            desc_wr.length.eq((self.axi.aw.len + 1) * (data_width // 8)), # transfer length (in bytes)
        ]

        fsm_wr.act("WRITE-IDLE",
            self.axi.aw.ready.eq(desc_wr.ready),
            desc_wr.valid.eq(self.axi.aw.valid),
            If(self.axi.aw.valid & self.axi.aw.ready,
                NextValue(aw_id, self.axi.aw.id), # save id to use it on b bus
                NextState("WRITE-MONITOR"),
            )
        )

        self.comb += [
            writer_conv.sink.data.eq(self.axi.w.data),
            writer_conv.sink.last.eq(self.axi.w.last),
        ]
        fsm_wr.act("WRITE-MONITOR",
            writer_conv.sink.valid.eq(self.axi.w.valid),
            self.axi.w.ready.eq(writer_conv.sink.ready),
            If(self.axi.w.valid & self.axi.w.ready & self.axi.w.last,
                NextState("WRITE-RESP"),
            )
        )

        self.comb += [
            self.axi.b.id.eq(aw_id),
            self.axi.b.resp.eq(0),
        ]
        fsm_wr.act("WRITE-RESP",
            self.axi.b.valid.eq(1),
            If(self.axi.b.ready,
                NextState("WRITE-IDLE"), # write done
            )
        )
