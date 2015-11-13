from litex.gen import *
from litex.gen.genlib.misc import chooser, displacer

from litex.soc.interconnect.csr import *

from litepcie.common import *

def descriptor_layout(with_user_id=False):
    layout = [
        ("address", 32),
        ("length",  16)
    ]
    if with_user_id:
        layout += [("user_id", 8)]
    return EndpointDescription(layout, packetized=True)


class DMARequestTable(Module, AutoCSR):
    def __init__(self, depth):
        self.source = source = Source(descriptor_layout())

        aw = len(source.address)
        lw = len(source.length)

        self._value = CSRStorage(aw+lw)
        self._we = CSR()
        self._loop_prog_n = CSRStorage()
        self._loop_status = CSRStatus(32)
        self._level = CSRStatus(log2_int(depth))
        self._flush = CSR()
        self.irq = Signal()

        # # #

        # CSR signals
        value = self._value.storage
        we = self._we.r & self._we.re
        loop_prog_n = self._loop_prog_n.storage
        loop_status = self._loop_status.status
        level = self._level.status
        flush = self._flush.r & self._flush.re

        # FIFO

        # instance
        fifo_layout = [("address", aw), ("length", lw), ("start", 1)]
        fifo = ResetInserter()(SyncFIFO(fifo_layout, depth))
        self.submodules += fifo
        self.comb += [
            fifo.reset.eq(flush),
            level.eq(fifo.fifo.level)
        ]

        # write part
        self.sync += [
            # in "loop" mode, each data output of the fifo is
            # written back
            If(loop_prog_n,
                fifo.sink.address.eq(fifo.source.address),
                fifo.sink.length.eq(fifo.source.length),
                fifo.sink.start.eq(fifo.source.start),
                fifo.sink.stb.eq(fifo.source.ack)
            # in "program" mode, fifo input is connected
            # to registers
            ).Else(
                fifo.sink.address.eq(value[:aw]),
                fifo.sink.length.eq(value[aw:aw+lw]),
                fifo.sink.start.eq(~fifo.source.stb),
                fifo.sink.stb.eq(we)
            )
        ]

        # read part
        self.comb += [
            source.stb.eq(fifo.source.stb),
            fifo.source.ack.eq(source.stb & source.ack),
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
            ).Elif(source.stb & source.ack,
			    loop_status[0:16].eq(loop_index),
                loop_status[16:].eq(loop_count),
                If(fifo.source.start,
                    loop_index.eq(0),
                    loop_count.eq(loop_count+1)
                ).Else(
                    loop_index.eq(loop_index+1)
                )
            )


class DMARequestSplitter(Module, AutoCSR):
    def __init__(self, max_size):
        self.sink = sink = Sink(descriptor_layout())
        self.source = source = Source(descriptor_layout(True))

        # # #

        self.submodules.offset = offset = Counter(32, increment=max_size)
        self.submodules.user_id = user_id = Counter(8)
        self.comb += user_id.ce.eq(sink.stb & sink.ack)

        length = Signal(16)
        length_update = Signal()
        self.sync += If(length_update, length.eq(sink.length))

        self.submodules.fsm = fsm = FSM(reset_state="IDLE")
        fsm.act("IDLE",
            offset.reset.eq(1),
            If(sink.stb,
                length_update.eq(1),
                NextState("RUN")
            ).Else(
                sink.ack.eq(1)
            )
        )
        self.comb += [
            source.address.eq(sink.address + offset.value),
            source.user_id.eq(user_id.value),
        ]
        fsm.act("RUN",
            source.stb.eq(1),
            source.sop.eq(offset.value == 0),
            If((length - offset.value) > max_size,
                source.length.eq(max_size),
                offset.ce.eq(source.ack)
            ).Else(
                source.eop.eq(1),
                source.length.eq(length - offset.value),
                If(source.ack,
                    NextState("ACK")
                )
            )
        )
        fsm.act("ACK",
            sink.ack.eq(1),
            NextState("IDLE")
        )
