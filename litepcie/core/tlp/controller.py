from migen import *

from litepcie.common import *
from litepcie.core.common import *
from litepcie.core.tlp.common import *
from litepcie.core.tlp.reordering import LitePCIeTLPReordering


class LitePCIeTLPController(Module):
    def __init__(self, data_width, max_pending_requests, with_reordering=False):
        self.master_in = LitePCIeMasterInternalPort(data_width)
        self.master_out = LitePCIeMasterInternalPort(data_width)

        # # #

        req_sink, req_source = self.master_in.sink, self.master_out.sink
        cmp_sink, cmp_source = self.master_out.source, self.master_in.source

        tags = SyncFIFO([("data", log2_int(max_pending_requests))], max_pending_requests, buffered=True)
        self.submodules += tags

        info_mem = Memory(16, max_pending_requests)
        info_mem_wr_port = info_mem.get_port(write_capable=True)
        info_mem_rd_port = info_mem.get_port(async_read=False)
        self.specials += info_mem, info_mem_wr_port, info_mem_rd_port

        # Requests mgt
        self.submodules.req_fsm = req_fsm = FSM(reset_state="IDLE")
        req_fsm.act("IDLE",
            If(req_sink.valid & req_sink.first,
                If(req_sink.we,
                   NextState("SEND_WRITE")
                ).Elif(tags.source.valid,
                   NextState("SEND_READ")
                )
            )
        )
        self.comb += req_sink.connect(req_source, omit=set(["valid", "ready"]))
        req_fsm.act("SEND_READ",
            req_source.valid.eq(req_sink.valid),
            req_source.tag.eq(tags.source.data),
            If(req_source.valid & req_source.last & req_source.ready,
                NextState("UPDATE_INFO_MEM")
            ).Else(
                req_sink.ready.eq(req_source.ready)
            )
        )
        req_fsm.act("SEND_WRITE",
            req_source.valid.eq(req_sink.valid),
            req_sink.ready.eq(req_source.ready),
            req_source.tag.eq(32),
            If(req_source.valid & req_source.last & req_source.ready,
                NextState("IDLE")
            )
        )
        self.comb += [
            info_mem_wr_port.adr.eq(tags.source.data),
            info_mem_wr_port.dat_w[:8].eq(req_sink.channel),
            info_mem_wr_port.dat_w[8:].eq(req_sink.user_id)
        ]
        req_fsm.act("UPDATE_INFO_MEM",
            info_mem_wr_port.we.eq(1),
            req_sink.ready.eq(1),
            tags.source.ready.eq(1),
            NextState("IDLE")
        )

        # Completions mgt
        if with_reordering:
            reordering = LitePCIeTLPReordering(data_width, max_pending_requests)
            self.submodules += reordering
            self.comb += [
                reordering.tag.valid.eq(info_mem_wr_port.we),
                reordering.tag.data.eq(info_mem_wr_port.adr),
                reordering.source.connect(cmp_source)
            ]
            cmp_source = reordering.sink

        tag_init = Signal(log2_int(max_pending_requests))

        self.submodules.cmp_fsm = cmp_fsm = FSM(reset_state="INIT")
        cmp_fsm.act("INIT",
            tags.sink.valid.eq(1),
            tags.sink.data.eq(tag_init),
            NextValue(tag_init, tag_init + 1),
            If(tag_init == (max_pending_requests-1),
                NextState("IDLE")
            )
        )
        self.comb += [
            info_mem_rd_port.adr.eq(cmp_sink.tag),
            cmp_sink.connect(cmp_source, omit=set(["valid", "ready"])),
            cmp_source.channel.eq(info_mem_rd_port.dat_r[:8]),
            cmp_source.user_id.eq(info_mem_rd_port.dat_r[8:])
        ]
        cmp_fsm.act("IDLE",
            If(cmp_sink.valid & cmp_sink.first,
                NextState("COPY"),
            ).Else(
                cmp_sink.ready.eq(1)
            )
        )
        cmp_fsm.act("COPY",
            cmp_source.valid.eq(cmp_sink.valid),
            cmp_sink.ready.eq(cmp_source.ready),
            If(cmp_sink.valid & cmp_sink.last & cmp_sink.ready,
                If(cmp_sink.end,
                    tags.sink.valid.eq(1),
                    tags.sink.data.eq(cmp_sink.tag)
                ),
                NextState("IDLE")
            )
        )
