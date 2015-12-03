from litex.gen import *

from litepcie.common import *
from litepcie.core.common import *
from litepcie.core.tlp.common import *
from litepcie.core.tlp.reordering import LitePCIeTLPReordering

from litex.soc.interconnect.stream import SyncFIFO as SyncFlowFIFO

from litex.gen.genlib.fifo import SyncFIFO

class LitePCIeTLPController(Module):
    def __init__(self, data_width, max_pending_requests, with_reordering=False):
        self.master_in = LitePCIeMasterInternalPort(data_width)
        self.master_out = LitePCIeMasterInternalPort(data_width)

        # # #

        req_sink, req_source = self.master_in.sink, self.master_out.sink
        cmp_sink, cmp_source = self.master_out.source, self.master_in.source

        tag_fifo = SyncFIFO(log2_int(max_pending_requests), max_pending_requests)
        self.submodules += tag_fifo

        info_mem = Memory(16, max_pending_requests)
        info_mem_wr_port = info_mem.get_port(write_capable=True)
        info_mem_rd_port = info_mem.get_port(async_read=False)
        self.specials += info_mem, info_mem_wr_port, info_mem_rd_port

        req_tag = Signal(max=max_pending_requests)
        self.sync += \
            If(tag_fifo.re,
                req_tag.eq(tag_fifo.dout)
            )

        # Requests mgt
        self.submodules.req_fsm = req_fsm = FSM(reset_state="IDLE")
        req_fsm.act("IDLE",
            If(req_sink.stb & req_sink.sop & ~req_sink.we & tag_fifo.readable,
                tag_fifo.re.eq(1),
                NextState("SEND_READ")
            ).Elif(req_sink.stb & req_sink.sop & req_sink.we,
                NextState("SEND_WRITE")
            )
        )
        self.comb += Record.connect(req_sink, req_source, leave_out=set(["stb", "ack"]))
        req_fsm.act("SEND_READ",
            req_source.stb.eq(req_sink.stb),
            req_source.tag.eq(req_tag),
            If(req_source.stb & req_source.eop & req_source.ack,
                NextState("UPDATE_INFO_MEM")
            ).Else(
                req_sink.ack.eq(req_source.ack)
            )
        )
        req_fsm.act("SEND_WRITE",
            req_source.stb.eq(req_sink.stb),
            req_sink.ack.eq(req_source.ack),
            req_source.tag.eq(32),
            If(req_source.stb & req_source.eop & req_source.ack,
                NextState("IDLE")
            )
        )
        self.comb += [
            info_mem_wr_port.adr.eq(req_tag),
            info_mem_wr_port.dat_w[:8].eq(req_sink.channel),
            info_mem_wr_port.dat_w[8:].eq(req_sink.user_id)
        ]
        req_fsm.act("UPDATE_INFO_MEM",
            info_mem_wr_port.we.eq(1),
            req_sink.ack.eq(1),
            NextState("IDLE")
        )


        # Completions mgt
        if with_reordering:
            self.submodules.reordering = LitePCIeTLPReordering(data_width, max_pending_requests)
            self.comb += [
                self.reordering.req_we.eq(info_mem_wr_port.we),
                self.reordering.req_tag.eq(info_mem_wr_port.adr),
                Record.connect(self.reordering.source, cmp_source)
            ]
            cmp_source = self.reordering.sink

        self.submodules.cmp_fsm = cmp_fsm = FSM(reset_state="INIT")
        tag_cnt = Signal(max=max_pending_requests)
        inc_tag_cnt = Signal()
        self.sync += \
            If(inc_tag_cnt,
                tag_cnt.eq(tag_cnt + 1)
            )

        cmp_fsm.act("INIT",
            inc_tag_cnt.eq(1),
            tag_fifo.we.eq(1),
            tag_fifo.din.eq(tag_cnt),
            If(tag_cnt == (max_pending_requests-1),
                NextState("IDLE")
            )
        )
        self.comb += [
            info_mem_rd_port.adr.eq(cmp_sink.tag),
            Record.connect(cmp_sink, cmp_source, leave_out=set(["stb", "ack"])),
            cmp_source.channel.eq(info_mem_rd_port.dat_r[:8]),
            cmp_source.user_id.eq(info_mem_rd_port.dat_r[8:])
        ]
        cmp_fsm.act("IDLE",
            If(cmp_sink.stb & cmp_sink.sop,
                NextState("COPY"),
            ).Else(
                cmp_sink.ack.eq(1)
            )
        )
        cmp_fsm.act("COPY",
            If(cmp_sink.stb & cmp_sink.eop & cmp_sink.last,
                NextState("UPDATE_TAG_FIFO"),
            ).Else(
                cmp_source.stb.eq(cmp_sink.stb),
                cmp_sink.ack.eq(cmp_source.ack),
                If(cmp_sink.stb & cmp_sink.eop & cmp_sink.ack,
                    NextState("IDLE")
                )
            )
        )
        cmp_fsm.act("UPDATE_TAG_FIFO",
            tag_fifo.we.eq(1),
            tag_fifo.din.eq(cmp_sink.tag),
            cmp_source.stb.eq(cmp_sink.stb),
            cmp_sink.ack.eq(cmp_source.ack),
            If(cmp_sink.stb & cmp_sink.ack,
                NextState("IDLE")
            )
        )
