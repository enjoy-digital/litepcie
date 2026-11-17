#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2023 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

from migen import *

from litex.gen import *

from litepcie.common      import *
from litepcie.core.common import *
from litepcie.tlp.common  import *

# Helpers ------------------------------------------------------------------------------------------

def get_completion_buffer_depth(data_width, max_request_size_bytes=max_request_size, buffered=False):
    # Completion payloads are repacked independently at each TLP boundary. An unaligned request
    # can use one additional stream beat since partial first/last Completion TLPs cannot share one.
    beat_bytes    = data_width//8
    request_beats = (max_request_size_bytes + beat_bytes - 1)//beat_bytes
    # A buffered SyncFIFO already provides the additional beat in its output register.
    return request_beats + (0 if buffered else 1)

# LitePCIe TLP Controller --------------------------------------------------------------------------

class LitePCIeTLPController(LiteXModule):
    """LitePCIe TLP requests/completions controller.

    Arbitrate/throttle TLP requests and reorder/assemble/redirect completions.

    Every read request sent to the Host is terminated by exactly one last Completion beat on the
    user side (``last`` with ``end`` or ``err``), in request order, and its tag is only reused after
    that:
    - ``ctrl_rst`` flushes the controller: no new read request is sent and the requests still
      outstanding at the Host are terminated in order with an error beat (``err``, no data) once
      their Completions have been received (and discarded). The Host still owns these requests,
      so their tags can't be reused before.
    - When ``cmp_timeout`` cycles elapse with requests outstanding and nothing sent or received
      for them (lost Completions, link down), ``timeout`` pulses and the outstanding requests are
      terminated in order: the data already received is delivered, then an error beat for each
      request whose Completion is incomplete (``cmp_timeout=None`` disables it).

    A Completion received for a tag with no request outstanding (unexpected, or late after a
    timeout) is dropped, and a tag's buffer is emptied when the tag is sent again. After a timeout,
    no read request is sent until ``cmp_timeout`` cycles have elapsed without such a Completion:
    the tags of the lost requests are not reused while their Completions may still arrive (a
    Completion arriving later than that can't be told from the one of the request reusing its
    tag).
    """
    def __init__(self, data_width, address_width, max_pending_requests, cmp_bufs_buffered=True,
        with_configuration=False, cmp_buf_depth=None, cmp_timeout=2**27):
        self.ctrl_rst  = Signal() # Flush (level or pulse).
        self.timeout   = Signal() # Completion timeout (pulse).
        self.master_in  = LitePCIeMasterInternalPort(data_width, address_width, with_configuration=with_configuration)
        self.master_out = LitePCIeMasterInternalPort(data_width, address_width, with_configuration=with_configuration)

        # # #

        req_sink, req_source = self.master_in.sink,    self.master_out.sink
        cmp_sink, cmp_source = self.master_out.source, self.master_in.source

        # Parameters.
        tag_bits = log2_int(max_pending_requests)

        # Tag queue --------------------------------------------------------------------------------
        # The tag queue is filled initially with the tags that will be used to issue read requests
        # to the host. A tag is dequeued when a read requests is issued to the host and queued when
        # a readcomplementation is received from the host.
        self.tag_queue = tag_queue = ResetInserter()(SyncFIFO(
            layout   = [("tag", tag_bits)],
            depth    = max_pending_requests,
            buffered = True,
        ))

        # Requests queue ---------------------------------------------------------------------------
        # Store the read requests tags as emitted to the host, datas will be dequeued in this order
        self.req_queue = req_queue = ResetInserter()(SyncFIFO(
            layout   =  [("tag", tag_bits), ("channel", 8), ("user_id", 8)],
            depth    = max_pending_requests,
            buffered = True,
        ))

        # Flush / Abort ----------------------------------------------------------------------------
        # Flush: the outstanding requests are terminated as their Completions arrive.
        # Abort: the outstanding requests are terminated without waiting for more Completions.
        # Quarantine: after an Abort, no read request until the late Completions have stopped.
        flush      = Signal()
        abort      = Signal()
        quarantine = Signal()
        hold       = Signal()
        self.comb += hold.eq(self.ctrl_rst | flush | abort | quarantine)

        # Requests Management ----------------------------------------------------------------------

        # Connect Data-Path.
        self.comb += req_sink.connect(req_source, omit={"valid", "ready", "tag"})

        # FSM.
        self.req_fsm = req_fsm = FSM(reset_state="WAIT-REQ")
        req_fsm.act("WAIT-REQ",
            # Wait for a TLP Request...
            If(req_sink.valid & req_sink.first,
                # TLP Write: We can send the request directly.
                If(req_sink.we,
                   NextState("SEND-WRITE-REQ")
                # TLP Read:  We can send the request when one tag available and space in req_queue
                # (and no Flush/Abort ongoing).
                ).Elif(tag_queue.source.valid & req_queue.sink.ready & ~hold,
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
        self.comb += [
            req_queue.sink.tag.eq(tag_queue.source.tag),
            req_sink.connect(req_queue.sink, keep={"channel", "user_id"}),
        ]
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

        cmp_in      = stream.Endpoint(completion_layout(data_width))
        cmp_reorder = stream.Endpoint(completion_layout(data_width))
        cmp_out     = stream.Endpoint(completion_layout(data_width))
        cmp_bufs    = []

        # Create Buffers.
        if cmp_buf_depth is None:
            cmp_buf_depth = get_completion_buffer_depth(data_width, buffered=cmp_bufs_buffered)
        for i in range(max_pending_requests):
            cmp_buf       = ResetInserter()(SyncFIFO(completion_layout(data_width), cmp_buf_depth, buffered=cmp_bufs_buffered))
            cmp_bufs.append(cmp_buf)
        self.submodules += cmp_bufs

        # Tags owned by a request: from the request sent to its ordered retirement.
        tag_owned  = Signal(max_pending_requests)
        tag_issue  = Signal()
        tag_retire = Signal()
        self.comb += tag_issue.eq(tag_queue.source.valid & tag_queue.source.ready)
        self.sync += [
            If(tag_retire, tag_owned.eq(tag_owned & ~(1 << req_queue.source.tag))),
            If(tag_issue,  tag_owned.eq(tag_owned |  (1 << tag_queue.source.tag))),
            If(tag_retire & tag_issue,
                tag_owned.eq((tag_owned & ~(1 << req_queue.source.tag)) | (1 << tag_queue.source.tag))
            ),
        ]

        # A tag's buffer is emptied when the tag is sent: anything in it belongs to no request.
        self.comb += [
            cmp_buf.reset.eq(tag_issue & (tag_queue.source.tag == i))
            for i, cmp_buf in enumerate(cmp_bufs)
        ]

        # Connect Cmp Input to Buffers (based on incoming Tag), drop the Completions of tags not owned.
        cmp_drop = Signal()
        cases = {
            i: [
                If(tag_owned[i],
                    cmp_reorder.connect(cmp_bufs[i].sink, keep={"valid", "ready"})
                ).Else(
                    cmp_reorder.ready.eq(1),
                    cmp_drop.eq(cmp_reorder.valid),
                )
            ] for i in range(len(cmp_bufs))
        }
        cases["default"] = [cmp_reorder.ready.eq(1)]
        self.comb += Case(cmp_reorder.tag, cases)
        # The data goes to all the buffers, only valid/ready are steered (no data mux per buffer).
        self.comb += [cmp_reorder.connect(cmp_buf.sink, omit={"valid", "ready"}) for cmp_buf in cmp_bufs]

        # Connect Buffers to Cmp Output (based on Tag from req_queue).
        self.comb += Case(req_queue.source.tag,
            {i: cmp_bufs[i].source.connect(cmp_out) for i in range(len(cmp_bufs))})
        cmp_out_done = Signal()
        cmp_out_ctrl = {"valid", "ready", "first", "last", "end", "err", "be", "tag"}
        self.comb += [
            cmp_out_done.eq(cmp_out.valid & cmp_out.last & (cmp_out.end | cmp_out.err)),
            # Abort: deliver what has been received for the oldest request, then terminate it with an
            # error beat when its Completion is incomplete.
            If(abort & ~cmp_out.valid,
                cmp_source.valid.eq(req_queue.source.valid),
                cmp_source.first.eq(1),
                cmp_source.last.eq(1),
                cmp_source.err.eq(1),
                cmp_source.tag.eq(req_queue.source.tag),
            # Flush: discard the oldest request's data and terminate it with an error beat on its
            # last Completion beat.
            ).Elif(self.ctrl_rst | flush,
                cmp_source.valid.eq(cmp_out_done),
                cmp_source.first.eq(1),
                cmp_source.last.eq(1),
                cmp_source.err.eq(1),
                cmp_source.tag.eq(req_queue.source.tag),
                cmp_out.ready.eq(~cmp_out_done | cmp_source.ready),
            # Else deliver the oldest request's Completions.
            ).Else(
                cmp_out.connect(cmp_source, keep=cmp_out_ctrl),
            )
        ]
        # The data always comes from the oldest request's buffer (not valid on an error beat).
        self.comb += cmp_out.connect(cmp_source, omit=cmp_out_ctrl)
        self.comb += [
            # Pop Req from req_queue when Req is fully received.
            # Retire on a normal end-of-completion OR on an error completion (UR/CA):
            # an error Cpl is zero-length so "end" (length == byte_count) never asserts,
            # which would otherwise leave the request un-retired and leak its tag,
            # deadlocking the DMA reader.
            If(cmp_source.valid & cmp_source.last & (cmp_source.end | cmp_source.err),
                req_queue.source.ready.eq(cmp_source.ready),
            ),
            req_queue.source.connect(cmp_source, keep={"channel", "user_id"}),
        ]

        # Retire Tag once the buffered Completion has been consumed in request order.
        self.comb += tag_retire.eq(
            cmp_source.valid & cmp_source.ready & cmp_source.last &
            (cmp_source.end | cmp_source.err)
        )

        # Completions Management -------------------------------------------------------------------

        fill_tag = Signal(tag_bits)

        # Completions received during an Abort are dropped: they belong to requests being terminated.
        self.comb += [
            cmp_sink.connect(cmp_in, omit={"valid", "ready"}),
            If(abort,
                cmp_sink.ready.eq(1),
            ).Else(
                cmp_sink.connect(cmp_in, keep={"valid", "ready"}),
            )
        ]
        cmp_sink = cmp_in

        # Connect Data-Path.
        self.comb += cmp_sink.connect(cmp_reorder, omit={"valid", "ready"})

        # FSM
        self.cmp_fsm = cmp_fsm = FSM(reset_state="FILL-TAG-QUEUE")
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
            tag_queue.sink.valid.eq(tag_retire),
            tag_queue.sink.tag.eq(req_queue.source.tag),
            # Wait for a TLP Completion, its first beat forwarded in the same cycle (no cycle lost
            # between Completion TLPs)...
            If(cmp_sink.first,
                cmp_sink.connect(cmp_reorder, keep={"valid", "ready"}),
                If(cmp_sink.valid & cmp_sink.ready & ~cmp_sink.last,
                    NextState("RUN")
                )
            # ...and drop beats outside a TLP.
            ).Else(
                cmp_sink.ready.eq(1)
            )
        )
        cmp_fsm.act("RUN",
            tag_queue.sink.valid.eq(tag_retire),
            tag_queue.sink.tag.eq(req_queue.source.tag),
            # Connect Control-Path.
            cmp_sink.connect(cmp_reorder, keep={"valid", "ready"}),
            If(cmp_sink.valid & cmp_sink.ready & cmp_sink.last,
                NextState("WAIT")
            )
        )

        # Flush / Abort Control --------------------------------------------------------------------
        cmp_phy  = self.master_out.source
        idle     = Signal()
        activity = Signal()
        self.comb += [
            # No read request outstanding and none being sent.
            idle.eq(~req_queue.source.valid & ~req_fsm.ongoing("SEND-READ-REQ")),
            # A request sent, a Completion beat received or data available for the user.
            activity.eq(
                (req_queue.sink.valid & req_queue.sink.ready) |
                (cmp_phy.valid & cmp_phy.ready) |
                cmp_out.valid
            ),
        ]
        self.sync += [
            If(self.ctrl_rst,
                flush.eq(1)
            ).Elif(idle,
                flush.eq(0)
            )
        ]
        if cmp_timeout is not None:
            timer = Signal(max=cmp_timeout + 1)
            self.sync += [
                self.timeout.eq(0),
                If(abort,
                    timer.eq(0),
                    If(idle,
                        abort.eq(0),
                        quarantine.eq(1),
                    ),
                ).Elif(quarantine,
                    # Completions dropped during the Abort or for a tag not owned restart it.
                    If(cmp_drop | (cmp_phy.valid & cmp_phy.ready),
                        timer.eq(0),
                    ).Elif(timer == cmp_timeout,
                        timer.eq(0),
                        quarantine.eq(0),
                    ).Else(
                        timer.eq(timer + 1),
                    )
                ).Elif(~req_queue.source.valid | activity,
                    timer.eq(0),
                ).Elif(timer == cmp_timeout,
                    # A read request being sent is not aborted (the Host would still complete it):
                    # wait for it, it restarts the timer.
                    If(~req_fsm.ongoing("SEND-READ-REQ"),
                        abort.eq(1),
                        self.timeout.eq(1),
                    )
                ).Else(
                    timer.eq(timer + 1),
                )
            ]
