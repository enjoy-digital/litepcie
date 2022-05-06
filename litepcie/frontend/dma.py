#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2022 Florent Kermarrec <florent@enjoy-digital.fr>
# Copyright (c) 2020 Antmicro <www.antmicro.com>
# SPDX-License-Identifier: BSD-2-Clause

from migen import *

from litex.soc.interconnect import stream
from litex.soc.interconnect.csr import *

from litepcie.common import *
from litepcie.tlp.common import *

# Constants/Layouts --------------------------------------------------------------------------------

def descriptor_layout(address_width=32, with_user_id=False):
    layout = [("address", address_width), ("length",  24), ("irq_disable", 1), ("last_disable", 1)]
    if with_user_id:
        layout += [("user_id", 8)]
    return EndpointDescription(layout)


# LitePCIeDMAScatterGather --------------------------------------------------------------------------

class LitePCIeDMAScatterGather(Module, AutoCSR):
    """LitePCIe DMA Scatter-Gather

    Software programmable table storing a list of DMA descriptors.

                               Mode
                                │
                              ┌─▼─┐  ┌───────────────────┐
       Descriptor to program  │   │  │                   │
             (Prog Mode) ─────►   │  │                   │
                              │   │  │    ScatterGather  │
                              │   ├──►     Table(FIFO)   ├──┬───► Descriptor (To DMA).
                          ┌───►   │  │                   │  │
                          │   │   │  │                   │  │
                          │   └───┘  └───────────────────┘  │
                          │                                 │
                          └─────────────────────────────────┘
                                    Refill (Loop Mode)


    A DMA descriptor is composed of:
    - a 32/64-bit address: The base address of the Host where the data stream should be written/read.
    - a 24-bit length : The length of the data stream (bytes).
    - a 8-bit control : Dynamic controls (ex: Disable IRQ generation, disable Last handling).

    The table is implemented as a FIFO initially filled by software. Once enabled, the DMA gets the
    descriptors from this table and executes them.

    This module has two modes:
    - Prog mode: Used to program the table by software and for cases where automatic refill of the
    table is not needed: A descriptor is only executed once and when all the descriptors have been
    executed (ie the table is empty), the DMA just stops until the next software refill.
    - Loop mode: Used once the table has been filled by software in PROG mode and allow continuous
    Scatter-Gather DMA: Each descriptor sent to the DMA is refilled to the table.

    In Loop mode, a loop status is maintained by the hardware for the software synchronization of the
    DMA buffers. (Even if a MSI IRQ is generated after a descriptor has been executed, since IRQ can
    potentially be lost, it's safer for the software to just use the hardware loop status than to
    maintain a software loop status based MSI IRQ reception).
    """
    def __init__(self, depth, address_width=32):
        assert address_width in [32, 64]
        # Stream Endpoint.
        self.source = source = stream.Endpoint(descriptor_layout(address_width=address_width))

        # Control/Status.
        self.value = CSRStorage(address_width + 32, reset_less=True, fields=[
            CSRField("address",      size=address_width, description="32/64-bit Address of the descriptor (bytes-aligned)."),
            CSRField("length",       size=24,            description="24-bit Length  of the descriptor (in bytes)."),
            CSRField("irq_disable",  size=1,             description="IRQ Disable Control of the descriptor."),
            CSRField("last_disable", size=1,             description="Last Disable Control of the descriptor.")
            ], description="64/96-bit DMA descriptor to be written to the table.")
        self.we = CSRStorage(description="A write to this register adds the descriptor to table.")
        self.loop_prog_n = CSRStorage(description="""Mode Selection.\n
            ``0``: **Prog** mode / ``1``: **Loop** mode.\n
            **Prog** mode should be used to program the table by software and for cases where automatic
            refill of the table is not needed: A descriptor is only executed once and when all the
            descriptors have been executed (ie the table is empty), the DMA just stops until the next
            software refill.\n
            **Loop** mode should be used once the table has been filled by software in **Prog** mode
            and allow continuous Scatter-Gather DMA: Each descriptor sent to the DMA is refilled to the table.
            """)
        self.loop_status = CSRStatus(fields=[
            CSRField("index", size=16, description= "Index of the last descriptor executed in the DMA descriptor table."),
            CSRField("count", size=16, description= "Loops of the DMA descriptor table since started."),
            ], description="Loop monitoring for software synchronization.")
        self.level = CSRStatus(bits_for(depth), description="Number descriptors in the table.")
        self.reset = CSRStorage(description="A write to this register resets the table.")

        # # #

        # Table (FIFO) -----------------------------------------------------------------------------
        table = stream.SyncFIFO(descriptor_layout(address_width=address_width), depth)
        table = ResetInserter()(table)
        self.submodules += table
        self.comb += table.reset.eq(self.reset.storage & self.reset.re)
        self.comb += self.level.status.eq(table.level)

        # Table Write logic ------------------------------------------------------------------------
        prog_mode = (self.loop_prog_n.storage == 0)
        self.sync += [
            # In Prog mode, the Table is filled through the CSRs.
            If(prog_mode,
                table.sink.address.eq(self.value.fields.address),
                table.sink.length.eq(self.value.fields.length),
                table.sink.irq_disable.eq(self.value.fields.irq_disable),
                table.sink.last_disable.eq(self.value.fields.last_disable),
                table.sink.first.eq(table.level == 0),
                table.sink.valid.eq(self.we.storage & self.we.re),
            # In Loop mode, the Table is automatically refilled.
            ).Else(
                table.source.connect(table.sink, omit={"valid", "ready"}),
                table.sink.valid.eq(table.source.valid & table.source.ready),
            )
        ]

        # Table Read logic -------------------------------------------------------------------------
        self.comb += table.source.connect(source)

        # Loop Status (For Software Sychronization in Loop mode) -----------------------------------
        loop_index = self.loop_status.fields.index
        loop_count = self.loop_status.fields.count
        self.sync += [
            # Reset Loop Index/Count on Table reset.
            If(table.reset,
                # Init count to 2**n-1 to have (index, count) == (0, 0) for the first Descriptor.
                loop_index.eq(0),
                loop_count.eq(2**len(loop_count) - 1),
            # When a Descriptor is consumned...
            ).Elif(table.source.valid & table.source.ready,
                # Update Loop Status with current Loop Index/Count.
                # Update Loop Index/Count.
                If(table.source.first,
                    loop_index.eq(0),
                    loop_count.eq(loop_count + 1),
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

    Descriptors from LitePCIeDMAScatterGather have a maximum length of 16Mb (24-bits). It is not
    possible to do such long Writes/Reads on the PCIe bus. At the PCIe enumeration, Maximum Payload
    and Request Sizes are negotiated between the Host and the Device. Writes are limited to Maximum
    Payload Size, Reads are limited to Maximum Request Size. Each descriptor is then split in
    several shorter descriptors.
    """
    def __init__(self, max_size, address_width):
        # Stream Endpoints.
        self.sink   =   sink = stream.Endpoint(descriptor_layout(address_width=address_width))
        self.source = source = stream.Endpoint(descriptor_layout(address_width=address_width, with_user_id=True))

        # # #

        desc_length  = Signal(32)
        desc_offset  = Signal(32)
        desc_id      = Signal(32)

        # FSM --------------------------------------------------------------------------------------
        self.submodules.fsm = fsm = FSM(reset_state="IDLE")
        fsm.act("IDLE",
            # Set Descriptor Offset/Length.
            NextValue(desc_offset, 0),
            NextValue(desc_length, sink.length),
            # Wait for a Descriptor and go to Run.
            If(sink.valid,
                NextState("SPLIT")
            )
        )
        # Split Data-Path.
        self.comb += [
            source.address.eq(sink.address + desc_offset),
            source.irq_disable.eq(sink.irq_disable),
            source.last_disable.eq(sink.last_disable),
            source.user_id.eq(desc_id),
        ]
        fsm.act("SPLIT",
            # Split Control-Path.
            source.valid.eq(1),
            source.first.eq(desc_offset == 0),
            # Full Descriptor when Length > max_size.
            If(desc_length > max_size,
                source.last.eq(0),
                source.length.eq(max_size),
            # Partial Descriptor when Length <= max_size.
            ).Else(
                source.last.eq(1),
                source.length.eq(desc_length),
            ),
            # When Descriptor is accepted...
            If(source.ready,
                # Increment Offset.
                NextValue(desc_offset, desc_offset + max_size),
                # Decrement Length.
                NextValue(desc_length, desc_length - max_size),
                # When Last....
                If(source.last,
                    # Accept Descriptor.
                    sink.ready.eq(1),
                    # Increment ID.
                    NextValue(desc_id, desc_id + 1),
                    # Go to Idle.
                    NextState("IDLE")
                )
            )
        )

# LitePCIeDMAReader --------------------------------------------------------------------------------

class LitePCIeDMAReader(Module, AutoCSR):
    """LitePCIe DMA Reader

    Generates a data stream from Host's memory.

    This module allows Scatter-Gather DMAs from Host's memory to data stream in the FPGA. The DMA
    descriptors, stored in a software programmable table, are split and executed as Read Requests
    on the PCIe bus.

    A Read Request is only sent to the Host when enough space is available in the Data FIFO to store
    the requested data.

    A MSI IRQ can be generated when a descriptor has been executed.
    """
    def __init__(self, endpoint, port, with_table=True, table_depth=256, address_width=32):
        self.port = port
        # Stream Endpoint.
        self.source = stream.Endpoint(dma_layout(endpoint.phy.data_width))

        # Control.
        self._enable = CSRStorage(description="DMA Reader Control. Write ``1`` to enable DMA Reader.", reset=0 if with_table else 1)

        # IRQ.
        self.irq = Signal()

        # # #

        # CSR/Parameters ---------------------------------------------------------------------------
        self.enable = enable = self._enable.storage

        length_shift          = log2_int(endpoint.phy.data_width//8)
        max_words_per_request = max_request_size//(endpoint.phy.data_width//8)
        max_pending_words     = endpoint.max_pending_requests*max_words_per_request

        # Table ------------------------------------------------------------------------------------
        if with_table:
            self.submodules.table = LitePCIeDMAScatterGather(table_depth, address_width=address_width)
        else:
            self.desc_sink = stream.Endpoint(descriptor_layout(address_width=address_width)) # Expose a Descriptor sink.

        # Splitter ---------------------------------------------------------------------------------
        # DMA descriptors need to be splitted in descriptors of max_request_size (negotiated at link-up)
        splitter = LitePCIeDMADescriptorSplitter(
            max_size      = endpoint.phy.max_request_size,
            address_width = address_width
        )
        splitter = ResetInserter()(splitter)
        splitter = BufferizeEndpoints({"source": DIR_SOURCE})(splitter) # For timings.
        self.submodules.splitter = splitter
        if with_table:
            self.comb += self.table.source.connect(splitter.sink)
        else:
            self.comb += self.desc_sink.connect(splitter.sink)

        # User ID ----------------------------------------------------------------------------------
        last_user_id = Signal(8, reset=255)
        self.sync += If(port.sink.valid & port.sink.first & port.sink.ready,
            last_user_id.eq(port.sink.user_id)
        )

        # Data FIFO --------------------------------------------------------------------------------
        data_fifo_depth = 4*max_pending_words
        data_fifo = SyncFIFO(dma_layout(endpoint.phy.data_width), data_fifo_depth, buffered=True)
        self.submodules += ResetInserter()(data_fifo)
        self.comb += [
            # Connect Data FIFO to Source.
            data_fifo.source.connect(self.source),
            # When Enabled, connect Sink to Data FIFO.
            If(enable,
                port.sink.connect(data_fifo.sink, keep={"valid", "ready"}),
                data_fifo.sink.data.eq(port.sink.dat),
                data_fifo.sink.first.eq(port.sink.first & (port.sink.user_id != last_user_id)),
            # Else accept incoming Port Data.
            ).Else(
                port.sink.ready.eq(1)
            )
        ]

        # Pending words ----------------------------------------------------------------------------
        pending_words         = Signal(max=data_fifo_depth + 1)
        pending_words_queue   = Signal.like(pending_words)
        pending_words_dequeue = Signal.like(pending_words)
        self.comb += [
            # Queue Pending words as Read Requests are emitted.
            If(splitter.source.valid & splitter.source.ready,
                pending_words_queue.eq(splitter.source.length[length_shift:])
            ),
            # Dequeue Pending words as Read Responses are received.
            If(data_fifo.source.valid & data_fifo.source.ready,
                pending_words_dequeue.eq(1)
            ),
        ]
        # Update Pending words.
        self.sync += pending_words.eq(pending_words + pending_words_queue - pending_words_dequeue)
        self.sync += If(~enable, pending_words.eq(0))

        # FSM --------------------------------------------------------------------------------------
        self.submodules.fsm = fsm = FSM(reset_state="IDLE")
        fsm.act("IDLE",
            # Reset Splitter/FIFO when Disabled.
            # Reset Splitter/FIFO when disabled.
            If(~enable,
                splitter.reset.eq(1),
                data_fifo.reset.eq(1),
            ),
            # Wait for a Descriptor and to have enough Space to generate the Request.
            If(splitter.source.valid & (pending_words < (data_fifo_depth - max_words_per_request)),
                NextState("REQUEST"),
            )
        )
        # Request Data-Path.
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
            # Request Control-Path.
            port.source.valid.eq(1),
            # When Request is accepted...
            If(port.source.ready,
                # Accept Descriptor.
                splitter.source.ready.eq(1),
                # Return to Idle.
                NextState("IDLE"),
            )
        )

        # IRQ --------------------------------------------------------------------------------------
        self.comb += If(splitter.source.valid & splitter.source.ready & splitter.source.last,
            self.irq.eq(~splitter.source.irq_disable)
        )

# LitePCIeDMAWriter --------------------------------------------------------------------------------

class LitePCIeDMAWriter(Module, AutoCSR):
    """LitePCIe DMA Writer

    Stores a data stream to Host's memory.

    This module allows Scatter-Gather DMAs from a data stream in the FPGA to Host's memory. The DMA
    descriptors, stored in a software programmable table, are split and executed as Write Requests
    on the PCIe bus.

    A Write Request is only sent to the Host when enough data are available for the current split
    descriptor.

    A MSI IRQ can be generated when a descriptor has been executed.
    """
    def __init__(self, endpoint, port, with_table=True, table_depth=256, address_width=32):
        self.port = port
        # Stream Endpoint.
        self.sink = sink = stream.Endpoint(dma_layout(endpoint.phy.data_width))

        # Control.
        self._enable = CSRStorage(description="DMA Writer Control. Write ``1`` to enable DMA Writer.", reset=0 if with_table else 1)

        # IRQ.
        self.irq = Signal()

        # # #

        # CSR/Parameters ---------------------------------------------------------------------------
        self.enable = enable = self._enable.storage

        length_shift          = log2_int(endpoint.phy.data_width//8)
        max_words_per_request = max_payload_size//(endpoint.phy.data_width//8)

        # Table ------------------------------------------------------------------------------------
        if with_table:
            self.submodules.table = LitePCIeDMAScatterGather(table_depth, address_width)
        else:
            self.desc_sink = stream.Endpoint(descriptor_layout(address_width=address_width)) # Expose a Descriptor sink.

        # Splitter ---------------------------------------------------------------------------------
        # DMA descriptors need to be splitted in descriptors of max_request_size (negotiated at link-up)
        splitter = LitePCIeDMADescriptorSplitter(
            max_size      = endpoint.phy.max_payload_size,
            address_width = address_width
        )
        splitter = ResetInserter()(splitter)
        splitter = BufferizeEndpoints({"source": DIR_SOURCE})(splitter) # For timings.
        self.submodules.splitter = splitter
        if with_table:
            self.comb += self.table.source.connect(splitter.sink)
        else:
            self.comb += self.desc_sink.connect(splitter.sink)

        # Data FIFO --------------------------------------------------------------------------------
        data_fifo_depth = 4*max_words_per_request
        data_fifo = stream.SyncFIFO([("data", endpoint.phy.data_width)], data_fifo_depth, buffered=True)
        self.submodules += ResetInserter()(data_fifo)
         # By default, accept incoming stream when disabled.
        self.comb += sink.ready.eq(1)
        # When Enabled, connect Sink to Data FIFO.
        self.comb += If(enable, sink.connect(data_fifo.sink))

        # FSM --------------------------------------------------------------------------------------
        req_done  = Signal()
        req_count = Signal.like(splitter.source.length)
        self.submodules.fsm = fsm = FSM(reset_state="IDLE")
        fsm.act("IDLE",
            # Reset Splitter/FIFO when disabled.
            If(~enable,
                splitter.reset.eq(1),
                data_fifo.reset.eq(1),
            ),
            # Reset Request Count/Done.
            NextValue(req_count, 0),
            NextValue(req_done,  0),
            # Wait for a Descriptor and to have enough Data to generate the Request.
            If(splitter.source.valid & (data_fifo.level >= splitter.source.length[length_shift:]),
                NextState("REQUEST"),
            )
        )
        # Request Data-Path.
        self.comb += [
            port.source.channel.eq(port.channel),
            port.source.user_id.eq(splitter.source.user_id),
            port.source.first.eq(req_count == 0),
            port.source.last.eq( req_count == (splitter.source.length[length_shift:] - 1)),
            port.source.we.eq(1),
            port.source.adr.eq(splitter.source.address),
            port.source.req_id.eq(endpoint.phy.id),
            port.source.tag.eq(0),
            port.source.len.eq(splitter.source.length[2:]),
            port.source.dat.eq(data_fifo.source.data)
        ]
        fsm.act("REQUEST",
            # Request Control-Path.
            port.source.valid.eq(1),
            # When Request is accepted...
            If(port.source.ready,
                # Increment Request Count.
                NextValue(req_count, req_count + 1),
                # Accept Data (Only when not terminated).
                data_fifo.source.ready.eq(~req_done),
                # When last...
                If(port.source.last,
                    # Accept Descriptor.
                    splitter.source.ready.eq(1),
                    # Terminate early on last (Optional, can be disabled).
                    If(data_fifo.source.last & ~splitter.source.last_disable,
                        NextValue(req_done, 1)
                    ),
                    # Return to Idle.
                    NextState("IDLE"),
                )
            )
        )

        # IRQ --------------------------------------------------------------------------------------
        self.comb += If(splitter.source.valid & splitter.source.ready & splitter.source.last,
            self.irq.eq(~splitter.source.irq_disable)
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
        self.enable      = CSRStorage(description="""DMA Loopback Enable Control.\n
         Write ``1`` to enable DMA internal loopback (DMA Reader to DMA Writer).""")

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

        self.synced = synced = Signal()

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
    """LitePCIe DMA Buffering

    Optional DMA buffering with dynamically configurable depth.

    For some applications (Software Defined Radio, Video, ...), the user module consuming the data
    from the DMA Reader works at fixed rate and does not handle backpressure. (The same also applies
    to the user module generating the data to the DMA Writer). Since the PCIe bus is shared, gaps
    appears in the streams and our Writes/Reads can't be absorbed/produced at a fixed rate. A minimum
    of buffering is needed to make sure the gaps are smoothed and not propagated to user modules.
    """
    def __init__(self, data_width, writer_depth, reader_depth, dynamic_depth=True):
        self.sink        = stream.Endpoint(dma_layout(data_width))
        self.source      = stream.Endpoint(dma_layout(data_width))

        self.next_source = stream.Endpoint(dma_layout(data_width))
        self.next_sink   = stream.Endpoint(dma_layout(data_width))

        # Reader FIFO Control/Status.
        assert bits_for(reader_depth) < 24
        self.reader_fifo_control = CSRStorage(fields=[
            CSRField("depth", offset=0, size=24, reset=reader_depth,
                description="DMA Reader FIFO depth (in {}-bit words).".format(data_width)),
            CSRField("scratch",    offset=24, size=4, description="Software Scratchpad."),
            CSRField("level_mode", offset=31, values=[
                ("``0b0``", "Report Instantaneous level."),
                ("``0b1``", "Report `Minimal` level since last clear.")
            ])
        ])
        self.reader_fifo_status = CSRStatus(fields=[
            CSRField("level", offset=0, size=24,
                description="DMA Reader FIFO level (in {}-bit words).".format(data_width))
            ])

        # Writer FIFO Control/Status.
        assert bits_for(writer_depth) < 24
        self.writer_fifo_control = CSRStorage(fields=[
            CSRField("depth", offset=0, size=24, reset=writer_depth,
                description="DMA Writer FIFO depth (in {}-bit words).".format(data_width)),
            CSRField("scratch",    offset=24, size=4, description="Software Scratchpad."),
            CSRField("level_mode", offset=31, values=[
                ("``0b0``", "Report Instantaneous level."),
                ("``0b1``", "Report `Maximal` level since last clear.")
            ])
        ])
        self.writer_fifo_status = CSRStatus(fields=[
            CSRField("level", offset=0, size=24,
                description="DMA Writer FIFO level (in {}-bit words).".format(data_width))
            ])

        # # #

        depth_shift = log2_int(data_width//8)

        # Reader FIFO.
        reader_fifo = SyncFIFO(dma_layout(data_width), reader_depth//(data_width//8), buffered=True)
        self.submodules += reader_fifo
        self.comb += [
            # Connect Reader Sink to Reader FIFO when Level < Configured Depth.
            self.sink.connect(reader_fifo.sink, omit={"valid", "ready"}),
            If((reader_fifo.level < self.reader_fifo_control.fields.depth[depth_shift:]) | (not dynamic_depth),
                self.sink.connect(reader_fifo.sink, keep={"valid", "ready"})
            ),
            # Connect Reader FIFO to Reader Source.
            reader_fifo.source.connect(self.next_source),
        ]

        # Store Min.
        reader_fifo_level_min = Signal.like(reader_fifo.level)
        self.sync += If(reader_fifo.level < reader_fifo_level_min, reader_fifo_level_min.eq(reader_fifo.level))
        # Clear on Status write or when in Instantaneous mode.
        reader_fifo_level_clr = (self.reader_fifo_status.re | (self.reader_fifo_control.fields.level_mode == 0))
        self.sync += If(reader_fifo_level_clr, reader_fifo_level_min.eq(2**len(reader_fifo_level_min)-1))
        # Return Reader FIFO level.
        self.comb += [
            # Instantaneous.
            If(self.reader_fifo_control.fields.level_mode == 0,
                self.reader_fifo_status.fields.level[depth_shift:].eq(reader_fifo.level)
            # Min.
            ).Else(
                self.reader_fifo_status.fields.level[depth_shift:].eq(reader_fifo_level_min)
            )
        ]

        # Writer FIFO.
        writer_fifo = SyncFIFO(dma_layout(data_width), writer_depth//(data_width//8), buffered=True)
        self.submodules += writer_fifo
        self.comb += [
            # Connect Writer Sink to Writer FIFO when Level < Configured Depth.
            self.next_sink.connect(writer_fifo.sink, omit={"valid", "ready"}),
            If((writer_fifo.level < self.writer_fifo_control.fields.depth[depth_shift:]) | (not dynamic_depth),
                self.next_sink.connect(writer_fifo.sink, keep={"valid", "ready"})
            ),
            # Connect Writer FIFO to Writer Source.
            writer_fifo.source.connect(self.source),
        ]
        # Store Max.
        writer_fifo_level_max = Signal.like(writer_fifo.level)
        self.sync += If(writer_fifo.level > writer_fifo_level_max, writer_fifo_level_max.eq(writer_fifo.level))
        # Clear on Status write or when in Instantaneous mode.
        writer_fifo_level_clr = (self.writer_fifo_status.re | (self.writer_fifo_control.fields.level_mode == 0))
        self.sync += If(writer_fifo_level_clr, writer_fifo_level_max.eq(0))
        # Return Writer FIFO level.
        self.comb += [
            # Instantaneous.
            If(self.writer_fifo_control.fields.level_mode == 0,
                self.writer_fifo_status.fields.level[depth_shift:].eq(writer_fifo.level)
            # Min.
            ).Else(
                self.writer_fifo_status.fields.level[depth_shift:].eq(writer_fifo_level_max)
            )
        ]

# LitePCIeDMAStatus --------------------------------------------------------------------------------

class LitePCIeDMAStatus(Module, AutoCSR):
    """LitePCIe DMA Status

    Optional DMA Status writer to Host Memory.

    LitePCIeDMAStatus writes 16 x 32-bit words to the Host memory. The first 8 words are reserved for
    the internal DMA status and the last 8 words for optional external status. The mapping as follows:

    0:    Sync Word (0x5aa55aa5).
    1:    DMA Writer Loop Status.
    2:    DMA Reader Loop Status.
    3-7:  Reserved
    8-15: External (Optional, from user logic/design).

    The Update to the Host Memory can be triggered from the following events:
    - External (From user logic/design).
    - DMA Writer IRQ.
    - DMA Reader IRQ.
    Allowing a Synchronous or Asynchrounous update with the DMAs.
    """
    def __init__(self, endpoint, writer, reader):
        self.control = CSRStorage(fields=[
            CSRField("enable", offset=0, size=1, description="Status Enable"),
            CSRField("update", offset=4, size=2, description="Status Update Event", values=[
                ("``0b00``", "External."),
                ("``0b01``", "DMA Writer IRQ."),
                ("``0b10``", "DMA Reader IRQ."),
                ("``0b11``", "Software."),
            ]),
        ])
        self.address = CSRStorage(32, description="Status Base Address on Host.")

        self.external_update = Signal()
        self.external_status = Array([Signal(32) for _ in range(8)])

        # # #


        # Create Status Array.
        # --------------------
        status = Array([Signal(32) for _ in range(16)])
        # 0-7:  Internal.
        sync_word = 0x5aa55aa5
        self.comb += [
            status[0].eq(0x5aa55aa5),
            status[1].eq(writer.table.loop_status.status),
            status[2].eq(reader.table.loop_status.status),
        ]

        # 7-15: External.
        for i in range(8):
            self.comb += status[8 + i].eq(self.external_status[i])

        # Update Event.
        # -------------
        update = Signal()
        update_cases = {
            0b00: update.eq(self.external_update),
            0b01: update.eq(writer.irq),
            0b10: update.eq(reader.irq),
            0b11: update.eq(self.control.re),
        }
        self.comb += Case(self.control.fields.update, update_cases)

        # Update Logic.
        # -------------
        port   = endpoint.crossbar.get_master_port(write_only=True)
        offset = Signal(4)

        self.submodules.fsm = fsm = FSM(reset_state="IDLE")
        fsm.act("IDLE",
            If(self.control.fields.enable,
                If(update,
                    NextValue(offset, 0),
                    NextState("WORD-WRITE")
                )
            )
        )
        fsm.act("WORD-UPDATE",
            NextValue(offset, offset + 1),
            If(offset == (16 - 1),
                NextState("IDLE")
            ).Else(
                NextState("WORD-WRITE")
            )
        )
        self.comb += [
            port.source.channel.eq(port.channel),
            port.source.first.eq(1),
            port.source.last.eq(1),
            port.source.adr.eq(self.address.storage + 4*offset),
            port.source.req_id.eq(endpoint.phy.id),
            port.source.tag.eq(0),
            port.source.len.eq(1),
            port.source.dat.eq(status[offset]),
        ]

        fsm.act("WORD-WRITE",
            port.source.valid.eq(1),
            port.source.we.eq(1),
            If(port.source.ready,
                NextState("WORD-UPDATE")
            )
        )

# LitePCIeDMA --------------------------------------------------------------------------------------

class LitePCIeDMA(Module, AutoCSR):
    """LitePCIe DMA

    Scatter-Gather bi-directional DMA:
    - Generates a data stream from Host's memory.
    - Stores a data stream to Host's memory.

    Optional buffering, loopback, synchronization and monitoring.
    """
    def __init__(self, phy, endpoint, table_depth=256, address_width=32,
        with_loopback      = False,
        with_synchronizer  = False,
        with_buffering     = False, buffering_depth=256*8, writer_buffering_depth=None, reader_buffering_depth=None,
        with_monitor       = False,
        with_status        = False):

        # Writer/Reader ----------------------------------------------------------------------------
        writer = LitePCIeDMAWriter(
            endpoint      = endpoint,
            port          = endpoint.crossbar.get_master_port(write_only=True),
            table_depth   = table_depth,
            address_width = address_width,
        )
        reader = LitePCIeDMAReader(
            endpoint      = endpoint,
            port          = endpoint.crossbar.get_master_port(read_only=True),
            table_depth   = table_depth,
            address_width = address_width,
        )
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
            writer_depth = writer_buffering_depth if writer_buffering_depth is not None else buffering_depth
            reader_depth = reader_buffering_depth if reader_buffering_depth is not None else buffering_depth
            self.submodules.buffering = LitePCIeDMABuffering(
                data_width   = phy.data_width,
                writer_depth = writer_depth,
                reader_depth = reader_depth)
            self.add_plugin_module(self.buffering)

        # Monitor ----------------------------------------------------------------------------------
        if with_monitor:
            self.submodules.writer_monitor = stream.Monitor(self.sink,   count_width=16, with_overflows  = True)
            self.submodules.reader_monitor = stream.Monitor(self.source, count_width=16, with_underflows = True)

        # Status -----------------------------------------------------------------------------------
        if with_status:
            self.submodules.status = LitePCIeDMAStatus(
                endpoint = endpoint,
                writer   = writer,
                reader   = reader
            )

    def add_plugin_module(self, m):
        self.comb += [
            self.source.connect(m.sink),
            m.source.connect(self.sink)
        ]
        self.sink, self.source = m.next_sink, m.next_source
