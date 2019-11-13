# This file is Copyright (c) 2015-2019 Florent Kermarrec <florent@enjoy-digital.fr>
# License: BSD

from migen import *
from migen.genlib.misc import chooser, displacer
from migen.genlib.fifo import SyncFIFOBuffered

from litex.soc.interconnect.stream import *
from litex.soc.interconnect.csr import *

from litepcie.common import *
from litepcie.tlp.common import *

# Constants/Layouts --------------------------------------------------------------------------------

DMA_ADDRESS_OFFSET = 0
DMA_LENGTH_OFFSET  = 32
DMA_CONTROL_OFFSET = 56

DMA_IRQ_DISABLE    = 0
DMA_LAST_DISABLE   = 1

def descriptor_layout(with_user_id=False):
    layout = [
        ("address", 32),
        ("length",  24),
        ("control", 8)
    ]
    if with_user_id:
        layout += [("user_id", 8)]
    return EndpointDescription(layout)


# LitePCIeDMARequestTable --------------------------------------------------------------------------

class LitePCIeDMARequestTable(Module, AutoCSR):
    def __init__(self, depth):
        self.source = source = stream.Endpoint(descriptor_layout())

        self.value       = CSRStorage(64)
        self.we          = CSR()
        self.loop_prog_n = CSRStorage()
        self.loop_status = CSRStatus(fields=[
            CSRField("index", size=16, offset= 0),
            CSRField("count", size=16, offset=16),
        ])
        self.level       = CSRStatus(log2_int(depth))
        self.flush       = CSR()

        # # #

        # CSRs -------------------------------------------------------------------------------------
        value       = self.value.storage
        we          = self.we.r & self.we.re
        loop_prog_n = self.loop_prog_n.storage
        loop_status = self.loop_status
        level       = self.level.status
        flush       = self.flush.r & self.flush.re

        # Table FIFO -------------------------------------------------------------------------------
        fifo = SyncFIFO([("address", 32), ("length",  24), ("control", 8)], depth)
        fifo = ResetInserter()(fifo)
        self.submodules += fifo
        self.comb += [
            fifo.reset.eq(flush),
            level.eq(fifo.level),
        ]

        # Write logic ------------------------------------------------------------------------------
        self.sync += [
            # In "loop" mode, each data output of the fifo is written back
            If(loop_prog_n,
                fifo.sink.address.eq(fifo.source.address),
                fifo.sink.length.eq(fifo.source.length),
                fifo.sink.control.eq(fifo.source.control),
                fifo.sink.first.eq(fifo.source.first),
                fifo.sink.valid.eq(fifo.source.ready)
            # In "program" mode, fifo input is connected to registers
            ).Else(
                fifo.sink.address.eq(value[DMA_ADDRESS_OFFSET:DMA_ADDRESS_OFFSET + 32]),
                fifo.sink.length.eq( value[ DMA_LENGTH_OFFSET:DMA_LENGTH_OFFSET  + 24]),
                fifo.sink.control.eq(value[DMA_CONTROL_OFFSET:DMA_CONTROL_OFFSET +  8]),
                fifo.sink.first.eq(~fifo.source.valid),
                fifo.sink.valid.eq(we)
            )
        ]

        # Read logic -------------------------------------------------------------------------------
        self.comb += [
            source.valid.eq(fifo.source.valid),
            source.first.eq(fifo.source.first),
            fifo.source.ready.eq(source.valid & source.ready),
            source.address.eq(fifo.source.address),
            source.length.eq(fifo.source.length),
            source.control.eq(fifo.source.control),
        ]

        # Loops monitoring -------------------------------------------------------------------------
        # Used by the software for synchronization in "loop" mode
        loop_first = Signal(reset=1)
        loop_index = Signal(log2_int(depth))
        loop_count = Signal(16)
        self.sync += [
            If(flush,
                loop_first.eq(1),
                loop_index.eq(0),
                loop_count.eq(0),
                loop_status.fields.index.eq(0),
                loop_status.fields.count.eq(0),
            ).Elif(source.valid & source.ready,
                loop_status.fields.index.eq(loop_index),
                loop_status.fields.count.eq(loop_count),
                If(source.first,
                    loop_first.eq(0),
                    loop_index.eq(0),
                    If(~loop_first,
                        loop_count.eq(loop_count + 1)
                    )
                ).Else(
                    loop_index.eq(loop_index + 1)
                )
            )
        ]

# LitePCIeDMARequestSplitter -----------------------------------------------------------------------

class LitePCIeDMARequestSplitter(Module, AutoCSR):
    def __init__(self, max_size):
        self.sink   =   sink = stream.Endpoint(descriptor_layout())
        self.source = source = stream.Endpoint(descriptor_layout(True))
        self.end    = Signal()

        # # #

        offset  = Signal(32)
        user_id = Signal(32)

        # FSM --------------------------------------------------------------------------------------
        self.submodules.fsm = fsm = FSM(reset_state="IDLE")
        fsm.act("IDLE",
            NextValue(offset, 0),
            If(sink.valid,
                NextState("RUN")
            ).Else(
                sink.ready.eq(1)
            )
        )
        self.comb += [
            source.address.eq(sink.address + offset),
            source.control.eq(sink.control),
            source.user_id.eq(user_id),
        ]
        fsm.act("RUN",
            source.valid.eq(1),
            source.first.eq(offset == 0),
            If((sink.length - offset) > max_size,
                source.last.eq(self.end),
                source.length.eq(max_size),
                If(source.ready,
                    NextValue(offset, offset + max_size),
                    If(self.end,
                        NextState("ACK")
                    )
                )
            ).Else(
                source.last.eq(1),
                source.length.eq(sink.length - offset),
                If(source.ready,
                    NextState("ACK")
                )
            )
        )
        fsm.act("ACK",
            sink.ready.eq(1),
            NextValue(user_id, user_id + 1),
            NextState("IDLE")
        )

# LitePCIeDMAReader --------------------------------------------------------------------------------

class LitePCIeDMAReader(Module, AutoCSR):
    def __init__(self, endpoint, port, table_depth=256):
        self.source = stream.Endpoint(dma_layout(endpoint.phy.data_width))
        self.irq    = Signal()
        self.enable = CSRStorage()

        # # #

        # CSR/Parameters ---------------------------------------------------------------------------
        enable = self.enable.storage

        max_words_per_request = max_request_size//(endpoint.phy.data_width//8)
        max_pending_words     = endpoint.max_pending_requests*max_words_per_request
        fifo_depth            = 4*max_pending_words

        # Table / Splitter -----------------------------------------------------------------
        # Requests from Table are splitted in requests of max_request_size. (negociated at link-up)
        table    = LitePCIeDMARequestTable(table_depth)
        splitter = LitePCIeDMARequestSplitter(max_size=endpoint.phy.max_request_size)
        splitter = ResetInserter()(splitter)
        splitter = BufferizeEndpoints({"source": DIR_SOURCE})(splitter)
        self.submodules.table    = table
        self.submodules.splitter = splitter
        self.comb += [
            splitter.reset.eq(~enable),
            table.source.connect(splitter.sink)
        ]

        # Data FIFO --------------------------------------------------------------------------------
        fifo = SyncFIFO(dma_layout(endpoint.phy.data_width), fifo_depth, buffered=True)
        fifo = ResetInserter()(fifo)
        self.submodules.fifo = fifo
        self.comb += fifo.reset.eq(~enable)
        self.comb += fifo.source.connect(self.source)

        last_user_id = Signal(8, reset=255)
        self.comb += [
            fifo.sink.valid.eq(port.sink.valid),
            fifo.sink.first.eq(port.sink.first & (port.sink.user_id != last_user_id)),
            fifo.sink.data.eq(port.sink.dat),
            port.sink.ready.eq(fifo.sink.ready | ~enable),
        ]
        self.sync += [
            If(port.sink.valid & port.sink.first & port.sink.ready,
                last_user_id.eq(port.sink.user_id)
            )
        ]

        # FSM --------------------------------------------------------------------------------------
        self.submodules.fsm = fsm = FSM(reset_state="IDLE")
        fsm.act("IDLE",
            If(splitter.source.valid,
                If(fifo.level < (fifo_depth - max_words_per_request),
                    NextState("REQUEST"),
                )
            )
        )
        self.comb += [
            port.source.channel.eq(port.channel),
            port.source.user_id.eq(splitter.source.user_id),
            port.source.first.eq(1),
            port.source.last.eq(1),
            port.source.we.eq(0),
            port.source.adr.eq(splitter.source.address),
            port.source.len.eq(splitter.source.length[2:]),
            port.source.req_id.eq(endpoint.phy.id),
            port.source.dat.eq(0),
        ]
        fsm.act("REQUEST",
            port.source.valid.eq(1),
            If(port.source.ready,
                splitter.source.ready.eq(1),
                NextState("IDLE"),
            )
        )

        # IRQ --------------------------------------------------------------------------------------
        self.comb += self.irq.eq(
            splitter.source.valid &
            splitter.source.ready &
            splitter.source.last  &
            ~splitter.source.control[DMA_IRQ_DISABLE]
        )

# LitePCIeDMAWriter --------------------------------------------------------------------------------

class LitePCIeDMAWriter(Module, AutoCSR):
    def __init__(self, endpoint, port, table_depth=256):
        self.sink   = sink = stream.Endpoint(dma_layout(endpoint.phy.data_width))
        self.irq    = Signal()
        self.enable = CSRStorage()

        # # #

        counter = Signal(max=(2**len(endpoint.phy.max_payload_size))//8)

        # CSR/Parameters ---------------------------------------------------------------------------
        enable = self.enable.storage

        max_words_per_request = max_payload_size//(endpoint.phy.data_width//8)
        fifo_depth            = 4*max_words_per_request

        # Table/Splitter ---------------------------------------------------------------------------
        # Requests from Table are splitted in requests of max_payload_size. (negociated at link-up)
        table    = LitePCIeDMARequestTable(table_depth)
        splitter = LitePCIeDMARequestSplitter(max_size=endpoint.phy.max_payload_size)
        splitter = ResetInserter()(splitter)
        splitter = BufferizeEndpoints({"source": DIR_SOURCE})(splitter)
        self.submodules.table    = table
        self.submodules.splitter = splitter
        self.comb += [
            splitter.reset.eq(~enable),
            table.source.connect(splitter.sink)
        ]

        # Data FIFO --------------------------------------------------------------------------------
        fifo = SyncFIFOBuffered(endpoint.phy.data_width + 1, fifo_depth)
        self.submodules += ResetInserter()(fifo)
        self.comb += [
            fifo.we.eq(sink.valid & enable),
            sink.ready.eq(fifo.writable | ~enable),
            fifo.din.eq(Cat(sink.data, sink.last)),
            fifo.reset.eq(~enable)
        ]

        # FSM --------------------------------------------------------------------------------------
        self.submodules.fsm = fsm = FSM(reset_state="IDLE")
        fsm.act("IDLE",
            NextValue(counter, 0),
            If(splitter.source.valid,
                If(fifo.level >= splitter.source.length[log2_int(endpoint.phy.data_width//8):],
                    NextState("REQUEST"),
                )
            )
        )
        length_shift = log2_int(endpoint.phy.data_width//8)
        self.comb += [
            port.source.channel.eq(port.channel),
            port.source.user_id.eq(splitter.source.user_id),
            port.source.first.eq(counter == 0),
            port.source.last.eq(~enable | (counter == splitter.source.length[length_shift:] - 1)),
            port.source.we.eq(1),
            port.source.adr.eq(splitter.source.address),
            port.source.req_id.eq(endpoint.phy.id),
            port.source.tag.eq(0),
            port.source.len.eq(splitter.source.length[2:]),
            port.source.dat.eq(fifo.dout[:-1])
        ]
        fsm.act("REQUEST",
            port.source.valid.eq(1),
            If(port.source.ready,
                NextValue(counter, counter + 1),
                # read only if not last
                fifo.re.eq(~(fifo.dout[-1] & ~splitter.source.control[DMA_LAST_DISABLE])),
                If(port.source.last,
                    # always read
                    fifo.re.eq(1),
                    splitter.end.eq(fifo.dout[-1] & ~splitter.source.control[DMA_LAST_DISABLE]),
                    splitter.source.ready.eq(1),
                    NextState("IDLE"),
                )
            )
        )

        # IRQ --------------------------------------------------------------------------------------
        self.comb += self.irq.eq(
            splitter.source.valid &
            splitter.source.ready &
            splitter.source.last  &
            ~splitter.source.control[DMA_IRQ_DISABLE]
        )

# LitePCIeDMALoopback ------------------------------------------------------------------------------

class LitePCIeDMALoopback(Module, AutoCSR):
    def __init__(self, data_width):
        self.enable      = CSRStorage()

        self.sink        = stream.Endpoint(dma_layout(data_width))
        self.source      = stream.Endpoint(dma_layout(data_width))

        self.next_source = stream.Endpoint(dma_layout(data_width))
        self.next_sink   = stream.Endpoint(dma_layout(data_width))

        # # #

        self.comb += [
            If(self.enable.storage,
                self.sink.connect(self.source)
            ).Else(
                self.sink.connect(self.next_source),
                self.next_sink.connect(self.source)
            )
        ]

# LitePCIeDMASynchronizer --------------------------------------------------------------------------

class LitePCIeDMASynchronizer(Module, AutoCSR):
    def __init__(self, data_width):
        self.bypass      = CSRStorage()
        self.enable      = CSRStorage()
        self.ready       = Signal(reset=1)
        self.pps         = Signal()

        self.sink        = stream.Endpoint(dma_layout(data_width))
        self.source      = stream.Endpoint(dma_layout(data_width))

        self.next_source = stream.Endpoint(dma_layout(data_width))
        self.next_sink   = stream.Endpoint(dma_layout(data_width))

        # # #

        synced = Signal()

        self.sync += [
            If(~self.enable.storage,
                synced.eq(0)
            ).Else(
                If(self.ready & self.sink.valid & (self.pps | self.bypass.storage),
                    synced.eq(1)
                )
            )
        ]
        self.comb += [
            If(synced,
                self.sink.connect(self.next_source),
                self.next_sink.connect(self.source),
            ).Else(
                # Block sink
                self.next_source.valid.eq(0),
                self.sink.ready.eq(0),

                # Ack next_sink
                self.source.valid.eq(0),
                self.next_sink.ready.eq(1),
            )
        ]

# LitePCIeDMABuffering -----------------------------------------------------------------------------

class LitePCIeDMABuffering(Module, AutoCSR):
    def __init__(self, data_width, depth):
        self.reader_fifo_level = CSRStatus(bits_for(depth))
        self.writer_fifo_level = CSRStatus(bits_for(depth))

        # # #

        reader_fifo = SyncFIFO(dma_layout(data_width), depth//(data_width//8), buffered=True)
        writer_fifo = SyncFIFO(dma_layout(data_width), depth//(data_width//8), buffered=True)
        self.submodules += reader_fifo, writer_fifo
        self.comb += [
            self.reader_fifo_level.status.eq(reader_fifo.level),
            self.writer_fifo_level.status.eq(writer_fifo.level),
        ]

        self.sink        = reader_fifo.sink
        self.source      = writer_fifo.source

        self.next_source = reader_fifo.source
        self.next_sink   = writer_fifo.sink

# LitePCIeDMA --------------------------------------------------------------------------------------

class LitePCIeDMA(Module, AutoCSR):
    def __init__(self, phy, endpoint,
        with_buffering    = False, buffering_depth = 256*8,
        with_loopback     = False,
        with_synchronizer = False,
        with_monitor      = False):

        # Writer/Reader ----------------------------------------------------------------------------
        writer = LitePCIeDMAWriter(endpoint, endpoint.crossbar.get_master_port(write_only=True))
        reader = LitePCIeDMAReader(endpoint, endpoint.crossbar.get_master_port(read_only=True))
        self.submodules.writer = writer
        self.submodules.reader = reader
        self.sink, self.source = writer.sink, reader.source

        # Loopback ---------------------------------------------------------------------------------
        if with_loopback:
            self.submodules.loopback = LitePCIeDMALoopback(phy.data_width)
            self.add_plugin_module(self.loopback)

        # Synchronizer -----------------------------------------------------------------------------
        if with_synchronizer:
            self.submodules.synchronizer = LitePCIeDMASynchronizer(phy.data_width)
            self.add_plugin_module(self.synchronizer)

        # Buffering --------------------------------------------------------------------------------
        if with_buffering:
            self.submodules.buffering = LitePCIeDMABuffering(phy.data_width, buffering_depth)
            self.add_plugin_module(self.buffering)

        # Monitor ----------------------------------------------------------------------------------
        if with_monitor:
            self.submodules.writer_monitor = stream.Monitor(self.sink, with_overflows=True)
            self.submodules.reader_monitor = stream.Monitor(self.source, with_underflows=True)

    def add_plugin_module(self, m):
        self.comb += [
            self.source.connect(m.sink),
            m.source.connect(self.sink)
        ]
        self.sink, self.source = m.next_sink, m.next_source
