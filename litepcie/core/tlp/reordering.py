from litex.gen import *

from litepcie.common import *
from litepcie.core.common import *
from litepcie.core.tlp.common import *


class Reordering(Module):
    def __init__(self, data_width, max_pending_requests):
        self.sink = Sink(completion_layout(data_width))
        self.source = Source(completion_layout(data_width))

        self.req_we = Signal()
        self.req_tag = Signal(log2_int(max_pending_requests))

        # # #

        tag_buffer = SyncFIFO([("data", log2_int(max_pending_requests))],
                              2*max_pending_requests)
        self.submodules += tag_buffer
        self.comb += [
            tag_buffer.sink.stb.eq(self.req_we),
            tag_buffer.sink.data.eq(self.req_tag)
        ]

        reorder_buffers = []
        for i in range(max_pending_requests):
            reorder_buffer = SyncFIFO(completion_layout(data_width),
                                      2*max_request_size//(data_width//8),
                                      buffered=True)
            reorder_buffers.append(reorder_buffer)
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
            Case(tag_buffer.source.data, cases),
            If(self.source.stb & self.source.eop & self.source.last,
                tag_buffer.source.ack.eq(self.source.ack)
            )
        ]
