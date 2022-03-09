#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2021 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

from migen import *

from litepcie.common import *
from litepcie.core.common import *
from litepcie.tlp.common import *


class LitePCIeTLPController(Module):
    """LitePCIe TLP requests/completions controller.

    Arbitrate/throttle TLP requests and reorder/assemble/redirect completions.
    """
    def __init__(self, data_width, address_width, max_pending_requests, cmp_bufs_buffered=True):
        self.master_in  = LitePCIeMasterInternalPort(data_width, address_width)
        self.master_out = LitePCIeMasterInternalPort(data_width, address_width)

        # # #

        req_sink, req_source = self.master_in.sink,    self.master_out.sink
        cmp_sink, cmp_source = self.master_out.source, self.master_in.source

        # Parameters.
        tag_bits = log2_int(max_pending_requests)

        # Tag queue --------------------------------------------------------------------------------
        # The tag queue is filled initially with the tags that will be used to issue read requests
        # to the host. A tag is dequeued when a read requests is issued to the host and queued when
        # a readcomplementation is received from the host.
        tag_queue = SyncFIFO([("tag", tag_bits)], max_pending_requests, buffered=True)
        self.submodules.tag_queue = tag_queue

        # Requests queue ---------------------------------------------------------------------------
        # Store the read requests tags as emitted to the host, datas will be dequeued in this order
        req_queue_layout = [("tag", tag_bits), ("channel", 8), ("user_id", 8)]
        req_queue        = SyncFIFO(req_queue_layout, max_pending_requests, buffered=True)
        self.submodules.req_queue = req_queue

        # Requests Management ----------------------------------------------------------------------

        # Connect Data-Path.
        self.comb += req_sink.connect(req_source, omit={"valid", "ready", "tag"})
        self.submodules.req_fsm = req_fsm = FSM(reset_state="WAIT-REQ")

        # FSM.
        req_fsm.act("WAIT-REQ",
            # Wait for a TLP Request...
            If(req_sink.valid & req_sink.first,
                # TLP Write: We can send the request directly.
                If(req_sink.we,
                   NextState("SEND-WRITE-REQ")
                # TLP Read:  We can send the request when one tag available and space in req_queue.
                ).Elif(tag_queue.source.valid & req_queue.sink.ready,
                   NextState("SEND-READ-REQ")
                )
            )
        )
        req_fsm.act("SEND-WRITE-REQ",
            # Connect Control-Path.
            req_sink.connect(req_source, keep={"valid", "ready"}),
            req_source.tag.eq(32),
            # End Request and return to Wait on last valid cycle.
            If(req_source.valid & req_source.ready & req_source.last,
                NextState("WAIT-REQ")
            )
        )
        req_fsm.act("SEND-READ-REQ",
            # Connect Control-Path.
            req_sink.connect(req_source, keep={"valid", "ready"}),
            req_source.tag.eq(tag_queue.source.tag),
            # End Request and return to Wait on last valid cycle.
            If(req_source.valid & req_source.ready & req_source.last,
                # Pop Tag from tag_queue.
                tag_queue.source.ready.eq(1),
                # Push Req to req_queue.
                req_queue.sink.valid.eq(1),
                req_queue.sink.tag.eq(tag_queue.source.tag),
                req_sink.connect(req_queue.sink, keep={"channel", "user_id"}),
                NextState("WAIT-REQ")
            )
        )

        # Completions Data Buffers (Reordering) ----------------------------------------------------
        #                          ┌───────────────┐
        #   Read Requests'Tags ────►   Req Queue   ├───┐
        #                          └───────────────┘   │
        #                                              │
        #                                              ▼
        #                 ┌─► Demux                   Mux
        #             Tag │   ┌──┐    ┌──────────┐   ┌───┐
        #                 │   │  ├────► Buffer 0 ├───►   │
        #                 │   │  │    └──────────┘   │   │
        #                 │   │  │                   │   │
        #                 │   │  │    ┌──────────┐   │   │
        #        Cmp In ──┴───►  ├────► Buffer . ├───►   ├─────► Cmp Out
        #                     │  │    └──────────┘   │   │
        #                     │  │                   │   │
        #                     │  │    ┌──────────┐   │   │
        #                     │  ├────► Buffer N ├───►   │
        #                     └──┘    └──────────┘   └───┘
        #
        #

        cmp_reorder = stream.Endpoint(completion_layout(data_width))
        cmp_bufs    = []

        # Create Buffers.
        for i in range(max_pending_requests):
            cmp_buf_depth = 4*max_request_size//(data_width//8)
            cmp_buf       = SyncFIFO(completion_layout(data_width), cmp_buf_depth, buffered=cmp_bufs_buffered)
            cmp_bufs.append(cmp_buf)
        self.submodules += cmp_bufs

        # Connect Cmp Input to Buffers (based on incoming Tag).
        self.comb += Case(cmp_reorder.tag,
            {i: cmp_reorder.connect(cmp_bufs[i].sink) for i in range(len(cmp_bufs))})

        # Connect Buffers to Cmp Output (based on Tag from req_ueue).
        self.comb += Case(req_queue.source.tag,
            {i: cmp_bufs[i].source.connect(cmp_source) for i in range(len(cmp_bufs))})
        self.comb += [
            # Pop Req from req_queue when Req is fully received.
            If(cmp_source.valid & cmp_source.last & cmp_source.end,
                req_queue.source.ready.eq(cmp_source.ready)
            ),
            req_queue.source.connect(cmp_source, keep={"channel", "user_id"}),
        ]

        # Completions Management -------------------------------------------------------------------

        fill_tag = Signal(tag_bits)

        # Connect Data-Path.
        self.comb += cmp_sink.connect(cmp_reorder, omit={"valid", "ready"})

        # FSM
        self.submodules.cmp_fsm = cmp_fsm = FSM(reset_state="FILL-TAG-QUEUE")
        cmp_fsm.act("FILL-TAG-QUEUE",
            # Pre-fill Tags.
            tag_queue.sink.valid.eq(1),
            tag_queue.sink.tag.eq(fill_tag),
            NextValue(fill_tag, fill_tag + 1),
            If(fill_tag == (max_pending_requests - 1),
                NextState("WAIT")
            )
        )
        cmp_fsm.act("WAIT",
            # Wait for a TLP Completion...
            If(cmp_sink.valid & cmp_sink.first,
                NextState("RUN")
            ).Else(
                cmp_sink.ready.eq(1)
            )
        )
        cmp_fsm.act("RUN",
            # Connect Control-Path.
            cmp_sink.connect(cmp_reorder, keep={"valid", "ready"}),
            # Push incoming Tag to tag_queue when Cmp is fully received.
            If(cmp_sink.valid & cmp_sink.ready & cmp_sink.last,
                If(cmp_sink.end,
                    tag_queue.sink.valid.eq(1),
                    tag_queue.sink.tag.eq(cmp_sink.tag)
                ),
                NextState("WAIT")
            )
        )
