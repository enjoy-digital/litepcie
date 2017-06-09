from litex.gen import *
from litex.gen.genlib.misc import chooser, displacer

from litex.soc.interconnect.stream import *
from litex.soc.interconnect.csr import *

from litepcie.common import *
from litepcie.core.tlp.common import *

from litex.gen.genlib.fifo import SyncFIFOBuffered


def descriptor_layout(with_user_id=False):
    layout = [
        ("address", 32),
        ("length",  16)
    ]
    if with_user_id:
        layout += [("user_id", 8)]
    return EndpointDescription(layout)


class LitePCIeDMARequestTable(Module, AutoCSR):
    def __init__(self, depth):
        self.source = source = stream.Endpoint(descriptor_layout())

        address_bits = len(source.address)
        length_bits = len(source.length)

        self.value = CSRStorage(address_bits + length_bits)
        self.we = CSR()
        self.loop_prog_n = CSRStorage()
        self.loop_status = CSRStatus(32)
        self.level = CSRStatus(log2_int(depth))
        self.flush = CSR()

        # # #

        # CSR signals
        value = self.value.storage
        we = self.we.r & self.we.re
        loop_prog_n = self.loop_prog_n.storage
        loop_status = self.loop_status.status
        level = self.level.status
        flush = self.flush.r & self.flush.re

        # FIFO

        # instance
        fifo_layout = [("address", address_bits),
                       ("length", length_bits),
                       ("start", 1)]
        fifo = ResetInserter()(SyncFIFO(fifo_layout, depth))
        self.submodules += fifo
        self.comb += [
            fifo.reset.eq(flush),
            level.eq(fifo.level)
        ]

        # write part
        self.sync += [
            # in "loop" mode, each data output of the fifo is
            # written back
            If(loop_prog_n,
                fifo.sink.address.eq(fifo.source.address),
                fifo.sink.length.eq(fifo.source.length),
                fifo.sink.start.eq(fifo.source.start),
                fifo.sink.valid.eq(fifo.source.ready)
            # in "program" mode, fifo input is connected
            # to registers
            ).Else(
                fifo.sink.address.eq(value[:address_bits]),
                fifo.sink.length.eq(value[address_bits:address_bits + length_bits]),
                fifo.sink.start.eq(~fifo.source.valid),
                fifo.sink.valid.eq(we)
            )
        ]

        # read part
        self.comb += [
            source.valid.eq(fifo.source.valid),
            fifo.source.ready.eq(source.valid & source.ready),
            source.address.eq(fifo.source.address),
            source.length.eq(fifo.source.length)
        ]

        # loop_index, loop_count
        # used by the software for synchronization in
        # "loop" mode

        loop_index = Signal(log2_int(depth))
        loop_count = Signal(16)

        self.sync += \
            If(flush,
                loop_index.eq(0),
                loop_count.eq(0),
                loop_status.eq(0),
            ).Elif(source.valid & source.ready,
			    loop_status[0:16].eq(loop_index),
                loop_status[16:].eq(loop_count),
                If(fifo.source.start,
                    loop_index.eq(0),
                    loop_count.eq(loop_count + 1)
                ).Else(
                    loop_index.eq(loop_index + 1)
                )
            )


class LitePCIeDMARequestSplitter(Module, AutoCSR):
    def __init__(self, max_size):
        self.sink = sink = stream.Endpoint(descriptor_layout())
        self.source = source = stream.Endpoint(descriptor_layout(True))

        # # #

        offset = Signal(32)
        offset_reset = Signal()
        offset_ce = Signal()
        self.sync += \
            If(offset_reset,
                offset.eq(0)
            ).Elif(offset_ce,
                offset.eq(offset + max_size)
            )

        user_id = Signal(32)
        user_id_ce = Signal()
        self.sync += If(user_id_ce, user_id.eq(user_id + 1))
        self.comb += user_id_ce.eq(sink.valid & sink.ready)

        length = Signal(16)
        length_update = Signal()
        self.sync += If(length_update, length.eq(sink.length))

        self.submodules.fsm = fsm = FSM(reset_state="IDLE")
        fsm.act("IDLE",
            offset_reset.eq(1),
            If(sink.valid,
                length_update.eq(1),
                NextState("RUN")
            ).Else(
                sink.ready.eq(1)
            )
        )
        self.comb += [
            source.address.eq(sink.address + offset),
            source.user_id.eq(user_id),
        ]
        fsm.act("RUN",
            source.valid.eq(1),
            source.first.eq(offset == 0),
            If((length - offset) > max_size,
                source.length.eq(max_size),
                offset_ce.eq(source.ready)
            ).Else(
                source.last.eq(1),
                source.length.eq(length - offset),
                If(source.ready,
                    NextState("ACK")
                )
            )
        )
        fsm.act("ACK",
            sink.ready.eq(1),
            NextState("IDLE")
        )


class LitePCIeDMAReader(Module, AutoCSR):
    def __init__(self, endpoint, port, table_depth=256):
        self.source = stream.Endpoint(dma_layout(endpoint.phy.data_width))
        self.irq = Signal()
        self.enable = CSRStorage()

        # # #

        enable = self.enable.storage

        max_words_per_request = max_request_size//(endpoint.phy.data_width//8)
        max_pending_words = endpoint.max_pending_requests*max_words_per_request

        fifo_depth = 2*max_pending_words

        # Request generation

        # requests from table are splitted in chunks of "max_size"
        self.table = table = LitePCIeDMARequestTable(table_depth)
        splitter = LitePCIeDMARequestSplitter(endpoint.phy.max_request_size)
        self.submodules += table, BufferizeEndpoints({"source": DIR_SOURCE})(ResetInserter()(splitter))
        self.comb += [
            splitter.reset.eq(~enable),
            table.source.connect(splitter.sink)
        ]

        # Request FSM
        self.submodules.fsm = fsm = FSM(reset_state="IDLE")

        request_ready = Signal()
        fsm.act("IDLE",
            If(request_ready,
                NextState("REQUEST"),
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

        # Data FIFO

        # issue read requests when enough space available in fifo
        fifo = SyncFIFO(dma_layout(endpoint.phy.data_width), fifo_depth, buffered=True)
        self.submodules += ResetInserter()(fifo)
        self.comb += fifo.reset.eq(~enable)

        last_user_id = Signal(8, reset=255)
        self.sync += \
            If(port.sink.valid & port.sink.first & port.sink.ready,
                last_user_id.eq(port.sink.user_id)
            )
        self.comb += [
            fifo.sink.valid.eq(port.sink.valid),
            fifo.sink.first.eq(port.sink.first & (port.sink.user_id != last_user_id)),
            fifo.sink.data.eq(port.sink.dat),
            port.sink.ready.eq(fifo.sink.ready | ~enable),
        ]
        self.comb += fifo.source.connect(self.source)

        fifo_ready = fifo.level < (fifo_depth//2)
        self.comb += request_ready.eq(splitter.source.valid & fifo_ready)

        # IRQ
        self.comb += self.irq.eq(splitter.source.valid &
                                 splitter.source.ready &
                                 splitter.source.first)


class LitePCIeDMAWriter(Module, AutoCSR):
    def __init__(self, endpoint, port, table_depth=256):
        self.sink = sink = stream.Endpoint(dma_layout(endpoint.phy.data_width))
        self.irq = Signal()
        self.enable = CSRStorage()

        # # #

        enable = self.enable.storage

        max_words_per_request = max_request_size//(endpoint.phy.data_width//8)
        fifo_depth = 4*max_words_per_request

        # Data FIFO

        # store data until we have enough data to issue a
        # write request
        fifo = SyncFIFOBuffered(endpoint.phy.data_width, fifo_depth)
        self.submodules += ResetInserter()(fifo)
        self.comb += [
            fifo.we.eq(sink.valid & enable),
            sink.ready.eq(fifo.writable & sink.valid & enable),
            fifo.din.eq(sink.data),
            fifo.reset.eq(~enable)
        ]

        # Request generation
        request_ready = Signal()
        counter = Signal(max=(2**len(endpoint.phy.max_payload_size))//8)
        counter_reset = Signal()
        counter_ce = Signal()
        self.sync += \
            If(counter_reset,
                counter.eq(0)
            ).Elif(counter_ce,
                counter.eq(counter + 1)
            )

        # requests from table are splitted in chunks of "max_size"
        self.table = table = LitePCIeDMARequestTable(table_depth)
        splitter = LitePCIeDMARequestSplitter(endpoint.phy.max_payload_size)
        self.submodules += table, BufferizeEndpoints({"source": DIR_SOURCE})(ResetInserter()(splitter))
        self.comb += [
            splitter.reset.eq(~enable),
            table.source.connect(splitter.sink)
        ]

        # Request FSM
        self.submodules.fsm = fsm = FSM(reset_state="IDLE")
        fsm.act("IDLE",
            counter_reset.eq(1),
            If(request_ready,
                NextState("REQUEST"),
            )
        )
        self.comb += [
            port.source.channel.eq(port.channel),
            port.source.user_id.eq(splitter.source.user_id),
            port.source.first.eq(counter == 0),
            port.source.last.eq(counter == splitter.source.length[3:] - 1),
            port.source.we.eq(1),
            port.source.adr.eq(splitter.source.address),
            port.source.req_id.eq(endpoint.phy.id),
            port.source.tag.eq(0),
            port.source.len.eq(splitter.source.length[2:]),
            port.source.dat.eq(fifo.dout)
        ]
        fsm.act("REQUEST",
            counter_ce.eq(port.source.valid & port.source.ready),
            port.source.valid.eq(1),
            If(port.source.ready,
                fifo.re.eq(1),
                If(port.source.last,
                    splitter.source.ready.eq(1),
                    NextState("IDLE"),
                )
            )
        )

        fifo_ready = fifo.level >= splitter.source.length[3:]
        self.sync += request_ready.eq(splitter.source.valid & fifo_ready)

        # IRQ
        self.comb += self.irq.eq(splitter.source.valid &
                                 splitter.source.ready &
                                 splitter.source.first)


class LitePCIeDMALoopback(Module, AutoCSR):
    def __init__(self, data_width):
        self.enable = CSRStorage()

        self.sink = stream.Endpoint(dma_layout(data_width))
        self.source = stream.Endpoint(dma_layout(data_width))

        self.next_source = stream.Endpoint(dma_layout(data_width))
        self.next_sink = stream.Endpoint(dma_layout(data_width))

        # # #

        enable = self.enable.storage
        self.comb += \
                If(enable,
                    self.sink.connect(self.source)
                ).Else(
                    self.sink.connect(self.next_source),
                    self.next_sink.connect(self.source)
                )


class LitePCIeDMASynchronizer(Module, AutoCSR):
    def __init__(self, data_width):
        self.bypass = CSRStorage()
        self.enable = CSRStorage()
        self.ready = Signal(reset=1)
        self.pps = Signal()

        self.sink = stream.Endpoint(dma_layout(data_width))
        self.source = stream.Endpoint(dma_layout(data_width))

        self.next_source = stream.Endpoint(dma_layout(data_width))
        self.next_sink = stream.Endpoint(dma_layout(data_width))

        # # #

        bypass = self.bypass.storage
        enable = self.enable.storage
        synced = Signal()

        self.sync += \
            If(~enable,
                synced.eq(0)
            ).Else(
                If(self.ready & self.sink.valid & (self.pps | bypass),
                    synced.eq(1)
                )
            )

        self.comb += \
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


class LitePCIeDMABuffering(Module, AutoCSR):
    def __init__(self, data_width, depth):
        tx_fifo = SyncFIFO(dma_layout(data_width), depth//(data_width//8), buffered=True)
        rx_fifo = SyncFIFO(dma_layout(data_width), depth//(data_width//8), buffered=True)
        self.submodules += tx_fifo, rx_fifo

        self.sink = tx_fifo.sink
        self.source = rx_fifo.source

        self.next_source = tx_fifo.source
        self.next_sink = rx_fifo.sink


class LitePCIeDMA(Module, AutoCSR):
    def __init__(self, phy, endpoint,
        with_buffering=False, buffering_depth=256*8,
        with_loopback=False,
        with_synchronizer=False):

        # Writer, Reader
        self.submodules.writer = LitePCIeDMAWriter(endpoint, endpoint.crossbar.get_master_port(write_only=True))
        self.submodules.reader = LitePCIeDMAReader(endpoint, endpoint.crossbar.get_master_port(read_only=True))
        self.sink, self.source = self.writer.sink, self.reader.source

        # Loopback
        if with_loopback:
            self.submodules.loopback = LitePCIeDMALoopback(phy.data_width)
            self.insert_optional_module(self.loopback)

        # Synchronizer
        if with_synchronizer:
            self.submodules.synchronizer = LitePCIeDMASynchronizer(phy.data_width)
            self.insert_optional_module(self.synchronizer)

        # Buffering
        if with_buffering:
            self.submodules.buffering = LitePCIeDMABuffering(phy.data_width, buffering_depth)
            self.insert_optional_module(self.buffering)


    def insert_optional_module(self, m):
        self.comb += [
            self.source.connect(m.sink),
            m.source.connect(self.sink)
        ]
        self.sink, self.source = m.next_sink, m.next_source
