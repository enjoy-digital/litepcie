from migen import *

from litepcie.common import *
from litepcie.core.common import *
from litepcie.core.tlp.common import *


class LitePCIeTLPReordering(Module):
    def __init__(self, data_width, max_pending_requests):
        self.sink = sink = stream.Endpoint(completion_layout(data_width))
        self.source = source = stream.Endpoint(completion_layout(data_width))

        self.tag = tag = stream.Endpoint([("data", log2_int(max_pending_requests))])

        # # #

        # Store tags in the order read requests were emitted to the Host.
        tags = SyncFIFO(
            [("data", log2_int(max_pending_requests))],
            8*max_pending_requests,
            buffered=True)
        self.submodules += tags
        self.comb += tag.connect(tags.sink)

        # Completions data buffers
        completion_write_cases = {}
        completion_read_cases = {}
        for i in range(max_pending_requests):
            completion = SyncFIFO(
                completion_layout(data_width),
                8*max_request_size//(data_width//8),
                buffered=True)
            self.submodules += completion
            completion_write_cases[i] = [sink.connect(completion.sink)]
            completion_read_cases[i] = [completion.source.connect(source)]

        # Completions are written to the buffer indicated by the incoming tag.
        completion_write_cases["default"] = [sink.ready.eq(1)]
        self.comb += Case(sink.tag, completion_write_cases)

        # Completions are read in the order the tags were emitted to the Host.
        self.comb += [
            Case(tags.source.data, completion_read_cases),
            If(source.valid & source.last & source.end,
                tags.source.ready.eq(source.ready)
            )
        ]
