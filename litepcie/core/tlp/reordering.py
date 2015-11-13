from litex.gen import *

from litepcie.common import *
from litepcie.core.common import *
from litepcie.core.tlp.common import *

from litex.soc.interconnect.stream import SyncFIFO as SyncFlowFIFO

from litex.gen.genlib.fifo import SyncFIFO


class Reordering(Module):
    def __init__(self, dw, max_pending_requests):
        self.sink = Sink(completion_layout(dw))
        self.source = Source(completion_layout(dw))

        self.req_we = Signal()
        self.req_tag = Signal(log2_int(max_pending_requests))

        # # #

        tag_buffer = SyncFIFO(log2_int(max_pending_requests), 2*max_pending_requests)
        self.submodules += tag_buffer
        self.comb += [
            tag_buffer.we.eq(self.req_we),
            tag_buffer.din.eq(self.req_tag)
        ]

        reorder_buffers = [SyncFlowFIFO(completion_layout(dw), 2*max_request_size//(dw//8), buffered=True)
            for i in range(max_pending_requests)]
        self.submodules += iter(reorder_buffers)

        # store incoming completion in "sink.tag" buffer
        cases = {}
        for i in range(max_pending_requests):
            cases[i] = [Record.connect(self.sink, reorder_buffers[i].sink)]
        cases["default"] = [self.sink.ack.eq(1)]
        self.comb += Case(self.sink.tag, cases)

        # read buffer according to tag_buffer order
        cases = {}
        for i in range(max_pending_requests):
            cases[i] = [Record.connect(reorder_buffers[i].source, self.source)]
        cases["default"] = []
        self.comb += [
            Case(tag_buffer.dout, cases),
            If(self.source.stb & self.source.eop & self.source.last,
                tag_buffer.re.eq(self.source.ack)
            )
        ]
