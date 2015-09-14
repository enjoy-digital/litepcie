from migen.fhdl.std import *
from migen.bank.description import *
from migen.genlib.fifo import SyncFIFOBuffered as SyncFIFO
from migen.genlib.fsm import FSM, NextState
from migen.genlib.misc import chooser, displacer
from migen.flow.plumbing import Buffer

from litepcie.common import *


def descriptor_layout(with_user_id=False):
    layout = [
        ("address",        32),
        ("length",        16)
    ]
    if with_user_id:
        layout += [("user_id",    8)]
    return EndpointDescription(layout, packetized=True)


class DMARequestTable(Module, AutoCSR):
    def __init__(self, depth):
        self.source = source = Source(descriptor_layout())

        aw = flen(source.address)
        lw = flen(source.length)

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
        loop_index = self._loop_status.status[:log2_int(depth)]
        loop_count = self._loop_status.status[16:]
        level = self._level.status
        flush = self._flush.r & self._flush.re

        # FIFO

        # instance
        fifo_layout = [("address", aw), ("length", lw), ("start", 1)]
        fifo = InsertReset(SyncFIFO(fifo_layout, depth))
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
                fifo.din.address.eq(fifo.dout.address),
                fifo.din.length.eq(fifo.dout.length),
                fifo.din.start.eq(fifo.dout.start),
                fifo.we.eq(fifo.re)
            # in "program" mode, fifo input is connected
            # to registers
            ).Else(
                fifo.din.address.eq(value[:aw]),
                fifo.din.length.eq(value[aw:aw+lw]),
                fifo.din.start.eq(~fifo.readable),
                fifo.we.eq(we)
            )
        ]

        # read part
        self.comb += [
            source.stb.eq(fifo.readable),
            fifo.re.eq(source.stb & source.ack),
            source.address.eq(fifo.dout.address),
            source.length.eq(fifo.dout.length)
        ]

        # loop_index, loop_count
        # used by the software for synchronization in
        # "loop" mode
        self.sync += \
            If(flush,
                loop_index.eq(0),
                loop_count.eq(0),
            ).Elif(source.stb & source.ack,
                If(fifo.dout.start,
                    loop_index.eq(0),
                    loop_count.eq(loop_count+1)
                ).Else(
                    loop_index.eq(loop_index+1)
                )
            )

        # IRQ
        self.comb += self.irq.eq(source.stb & source.ack)


class DMARequestSplitter(Module, AutoCSR):
    def __init__(self, max_size):
        self.sink = sink = Sink(descriptor_layout())
        self.source = source = Source(descriptor_layout(True))

        # # #

        self.submodules.offset = offset = Counter(32, increment=max_size)
        self.submodules.user_id = user_id = Counter(8)
        self.comb += user_id.ce.eq(sink.stb & sink.ack)

        self.submodules.length = length = FlipFlop(16)
        self.comb += self.length.d.eq(sink.length)

        self.submodules.fsm = fsm = FSM(reset_state="IDLE")
        fsm.act("IDLE",
            offset.reset.eq(1),
            If(sink.stb,
                length.ce.eq(1),
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
            If((length.q - offset.value) > max_size,
                source.length.eq(max_size),
                offset.ce.eq(source.ack)
            ).Else(
                source.length.eq(length.q - offset.value),
                If(source.ack,
                    NextState("ACK")
                )
            )
        )
        fsm.act("ACK",
            sink.ack.eq(1),
            NextState("IDLE")
        )
