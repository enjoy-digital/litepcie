# This file is Copyright (c) 2015-2019 Florent Kermarrec <florent@enjoy-digital.fr>
# License: BSD

from migen import *

from litepcie.common import *
from litepcie.core.common import *
from litepcie.tlp.common import *


class LitePCIeTLPController(Module):
    """LitePCIe TLP requests/completions controller.

    Arbitrate/throttle TLP requests and reorder/assemble/redirect completions.
    """
    def __init__(self, data_width, max_pending_requests):
        self.master_in = LitePCIeMasterInternalPort(data_width)
        self.master_out = LitePCIeMasterInternalPort(data_width)

        # # #

        req_sink, req_source = self.master_in.sink, self.master_out.sink
        cmp_sink, cmp_source = self.master_out.source, self.master_in.source

        tags_bits = log2_int(max_pending_requests)

        # Tags queue -------------------------------------------------------------------------------
        # The tags queue is filled initially with the tags that will be used to issue read requests
        # to the host.A tag is dequeued when a read requests is issued to the host and queued when
        # a readcomplementation is received from the host.
        tags_queue = SyncFIFO([("tag", tags_bits)], max_pending_requests, buffered=True)
        self.submodules.tags_queue = tags_queue

        # Requests queue ---------------------------------------------------------------------------
        # Store the read requests tags as emitted to the host, datas will be dequeued in this order
        requests_queue_layout = [("tag", tags_bits), ("channel", 8), ("user_id", 8)]
        requests_queue = SyncFIFO(requests_queue_layout, max_pending_requests, buffered=True)
        self.submodules.requests_queue = requests_queue

        # Requests Managment -----------------------------------------------------------------------
        self.comb += req_sink.connect(req_source, omit=set(["valid", "ready", "tag"]))
        self.submodules.req_fsm = req_fsm = FSM(reset_state="IDLE")
        req_fsm.act("IDLE",
            If(req_sink.valid & req_sink.first,
                If(req_sink.we,
                   NextState("WRITE-REQUEST")
                ).Elif(tags_queue.source.valid & requests_queue.sink.ready,
                   NextState("READ-REQUEST")
                )
            )
        )
        req_fsm.act("WRITE-REQUEST",
            req_source.valid.eq(req_sink.valid),
            req_sink.ready.eq(req_source.ready),
            req_source.tag.eq(32),
            If(req_source.valid & req_source.ready & req_source.last,
                NextState("IDLE")
            )
        )
        self.comb += [
            requests_queue.sink.tag.eq(tags_queue.source.tag),
            requests_queue.sink.channel.eq(req_sink.channel),
            requests_queue.sink.user_id.eq(req_sink.user_id)
        ]
        req_fsm.act("READ-REQUEST",
            req_source.valid.eq(req_sink.valid),
            req_source.tag.eq(tags_queue.source.tag),
            req_sink.ready.eq(req_source.ready),
            If(req_source.valid & req_source.ready & req_source.last,
                tags_queue.source.ready.eq(1),
                requests_queue.sink.valid.eq(1),
                NextState("IDLE")
            )
        )

        # Completions data buffers (Reordering) ----------------------------------------------------
        cmp_reorder = stream.Endpoint(completion_layout(data_width))
        cmp_write_cases = {}
        cmp_read_cases = {}
        for i in range(max_pending_requests):
            cmp_buf_depth = int(4*max_request_size/(data_width/8))
            cmp_buf = SyncFIFO(completion_layout(data_width), cmp_buf_depth, buffered=True)
            self.submodules += cmp_buf
            cmp_write_cases[i] = [cmp_reorder.connect(cmp_buf.sink)]
            cmp_read_cases[i] = [cmp_buf.source.connect(cmp_source)]

        # Completions are written to the buffer indicated by the incoming tag.
        cmp_write_cases["default"] = [cmp_reorder.ready.eq(1)]
        self.comb += Case(cmp_reorder.tag, cmp_write_cases)

        # Completions are read in the order the tags were emitted to the host.
        self.comb += [
            Case(requests_queue.source.tag, cmp_read_cases),
            If(cmp_source.valid & cmp_source.last & cmp_source.end,
                requests_queue.source.ready.eq(cmp_source.ready)
            ),
            cmp_source.channel.eq(requests_queue.source.channel),
            cmp_source.user_id.eq(requests_queue.source.user_id)
        ]

        # Completions Managment --------------------------------------------------------------------
        self.comb += cmp_sink.connect(cmp_reorder, omit=set(["valid", "ready"]))
        self.submodules.cmp_fsm = cmp_fsm = FSM(reset_state="FILL-TAGS-QUEUE")
        fill_tag = Signal(tags_bits)
        cmp_fsm.act("FILL-TAGS-QUEUE",
            tags_queue.sink.valid.eq(1),
            tags_queue.sink.tag.eq(fill_tag),
            NextValue(fill_tag, fill_tag + 1),
            If(fill_tag == (max_pending_requests - 1),
                NextState("WAIT")
            )
        )
        cmp_fsm.act("WAIT",
            If(cmp_sink.valid & cmp_sink.first,
                NextState("RUN")
            ).Else(
                cmp_sink.ready.eq(1)
            )
        )
        cmp_fsm.act("RUN",
            cmp_reorder.valid.eq(cmp_sink.valid),
            cmp_sink.ready.eq(cmp_reorder.ready),
            If(cmp_sink.valid & cmp_sink.ready & cmp_sink.last,
                If(cmp_sink.end,
                    tags_queue.sink.valid.eq(1),
                    tags_queue.sink.tag.eq(cmp_sink.tag)
                ),
                NextState("WAIT")
            )
        )
