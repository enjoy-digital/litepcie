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

DMA_IRQ_DISABLE    = 0
DMA_LAST_DISABLE   = 1

def descriptor_layout(with_user_id=False):
    layout = [("address", 32), ("length",  24), ("control", 8)]
    if with_user_id:
        layout += [("user_id", 8)]
    return EndpointDescription(layout)


# LitePCIeDMAScatterGather --------------------------------------------------------------------------

class LitePCIeDMAScatterGather(Module, AutoCSR):
    """LitePCIe DMA Scatter-Gather

    Software programmable table that stores a list of DMA descriptors to be executed.

    A DMA descriptor is composed of:
    - a 32-bit address: the base address where the data stream should be written/read.
    - a 24-bit length : the length of the data stream (bytes).
    - 8 control bits  : control to allow dynamic specific behavior (for example: disable MSI IRQ).

    The table is implemented as a FIFO initially filled by software. Once enabled, the DMA gets the
    descriptors from this table and executes them.

    This module has two modes:
    - PROG mode: Used to program the table by software and for cases where automatic refill of the
    table is not needed: A descriptor is only executed once and when all the descriptors have been
    executed (ie the table is empty), the DMA just stops until the next software refill.
    - LOOP mode: Used once the table has been filled by software in PROG mode and allow continuous
    Scatter-Gather DMA: Each descriptor sent to the DMA is refilled to the table.

    In LOOP mode, a loop status is maintained by the hardware for the software synchronization of the
    DMA buffers. (Even if a MSI IRQ is generated after a descriptor has been executed, since IRQ can
    potentially be lost, it's safer for the software to just use the hardware loop status than to
    maintain a software loop status based MSI IRQ reception).
    """
    def __init__(self, depth):
        self.source = source = stream.Endpoint(descriptor_layout())

        self.value = CSRStorage(64, fields=[
            CSRField("address", size=32),
            CSRField("length",  size=24),
            CSRField("control", size=8)
            ], description="64-bit DMA descriptor to be writter to the table")
        self.we = CSRStorage(description="A write to this register writes descriptor to table")
        self.loop_prog_n = CSRStorage(description="PROG(0) / LOOP(1) mode")
        self.loop_status = CSRStatus(fields=[
            CSRField("index", size=16, offset= 0),
            CSRField("count", size=16, offset=16),
            ], description="Loop monitoring for software synchronization")
        self.level = CSRStatus(log2_int(depth), description="Table FIFO level")
        self.flush = CSRStorage(description="A write to this register flushes the table")

        # # #

        # CSRs -------------------------------------------------------------------------------------
        address     = self.value.fields.address
        length      = self.value.fields.length
        control     = self.value.fields.control
        we          = self.we.storage & self.we.re
        loop_prog_n = self.loop_prog_n.storage
        loop_status = self.loop_status
        level       = self.level.status
        flush       = self.flush.storage & self.flush.re

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
            # In LOOP mode, the FIFO is automatically refilled with the descriptors.
            If(loop_prog_n,
                fifo.sink.address.eq(fifo.source.address),
                fifo.sink.length.eq(fifo.source.length),
                fifo.sink.control.eq(fifo.source.control),
                fifo.sink.first.eq(fifo.source.first),
                fifo.sink.valid.eq(fifo.source.ready)
            # In PROG mode, the FIFO is filled through the CSRs and not automatically refilled.
            ).Else(
                fifo.sink.address.eq(address),
                fifo.sink.length.eq(length),
                fifo.sink.control.eq(control),
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
        # Used for software synchronization in LOOP mode.
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

# LitePCIeDMADescriptorSplitter --------------------------------------------------------------------

class LitePCIeDMADescriptorSplitter(Module, AutoCSR):
    """LitePCIe DMA Descriptor Splitter

    Splits descriptors from LitePCIeDMAScatterGather in shorter descriptors of:
    - Maximum Payload Size for Writes.
    - Maximum Request Size for Reads.

    Descriptors from LitePCIeDMAScatterGather have a maximum length of 16mB (24-bits). It is not
    possible to do such long Writes/Reads on the PCIe bus. At the PCIe enumeration, Maximum Payload
    and Request Sizes are negociated between the Host and the Device. Writes are limited to Maximum
    Payload Size, Reads are limited to Maximum Rquest Size. Each descriptor is then splitted in
    several shorter descriptors.
    """
    def __init__(self, max_size):
        self.sink   =   sink = stream.Endpoint(descriptor_layout())
        self.source = source = stream.Endpoint(descriptor_layout(with_user_id=True))
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
    """LitePCIe DMA Reader

    Generates a data stream from Host's memory.

    This module allows Scatter-Gather DMAs from Host's memory to data stream in the FPGA. The DMA
    descriptors, stored in a software programmable table, are splitted and executed as Read Requests
    on the PCIe bus.

    A Read Request is only sent to the Host when enough space is available in the Data FIFO to store
    the requested datas.

    A MSI IRQ can be generated when a descriptor has been executed.
    """
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
        # Descriptors from Table are splitted in descriptors of max_request_size. (negociated at link-up)
        table    = LitePCIeDMAScatterGather(table_depth)
        splitter = LitePCIeDMADescriptorSplitter(max_size=endpoint.phy.max_request_size)
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
    """LitePCIe DMA Writer

    Stores a data stream to Host's memory.

    This module allows Scatter-Gather DMAs from a data stream in the FPGA to Host's memory. The DMA
    descriptors, stored in a software programmable table, are splitted and executed as Write Requests
    on the PCIe bus.

    A Write Request is only sent to the Host when enough datas are available for the current splitted
    descriptor.

    A MSI IRQ can be generated when a descriptor has been executed.
    """
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
        # Descriptors from table are splitted in descriptors of max_payload_size. (negociated at link-up)
        table    = LitePCIeDMAScatterGather(table_depth)
        splitter = LitePCIeDMADescriptorSplitter(max_size=endpoint.phy.max_payload_size)
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
    """LitePCIe DMA Loopback

    Optional DMA Reader to DMA Writer loopback.

    For software development or system bring-up/check, being able to do a DMA loopback in the FPGA
    is very useful. This module allows doing a DMA Reader to DMA Writer loopback that can be enabled
    by a CSR. When enabled, user data stream from the DMA Reader is no longer generated, the same
    goes for user data stream to the DMA Writer that is no longer consumed.
    """
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
    """LitePCIe DMA Synchronizer

    Optional DMA synchronization.

    For some applications (Software Defined Radio, Video, ...), DMA start needs to be precisely
    synchronized to an internal signal of the FPGA (PPS for example for an SDR applications). This
    module allows releasing precisely the DMA Writer/Reader data streams.
    """
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
    """LitePCIe DMA Synchronizer

    Optional DMA buffering.

    For some applications (Software Defined Radio, Video, ...), the user module consuming the datas
    from the DMA Reader works at fixed rate and does not handle backpressure. (The same also applies
    to the user module generating the datas to the DMA Writer). Since the PCIe bus is shared, gaps
    appears in the streams and our Writes/Reads can't be absorbed/produced at a fixed rate. A minimum
    of buffering is needed to make sure the gaps are smoothed and not propagated to user modules.
    """
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
    """LitePCIe DMA

    Scatter-Gather bi-directional DMA:
    - Generates a data stream from Host's memory.
    - Stores a data stream to Host's memory.

    Optional buffering, loopback, synchronization and monitoring.
    """
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
