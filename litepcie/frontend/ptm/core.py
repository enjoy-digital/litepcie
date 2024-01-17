#
# This file is part of LitePCIe-PTM.
#
# Copyright (c) 2023 NetTimeLogic
# Copyright (c) 2023 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

from migen import *

from litex.gen import *
from litex.gen.genlib.misc import WaitTimer

from litex.soc.interconnect.csr    import *
from litex.soc.interconnect import stream

from litepcie.common import phy_layout

# PTM Constants ------------------------------------------------------------------------------------

PTM_REQUEST_MESSAGE_CODE   = 0b01010010 # PTM Request.
PTM_RESPONSE_MESSAGE_CODE  = 0b01010011 # PTM Response without timing information.
PTM_RESPONSED_MESSAGE_CODE = 0b01010011 # PTM Response with timing information.

# PTM Capabilities Constants -----------------------------------------------------------------------

PTM_STRUCTURE_REGS = 3

PTM_HEADER_REG      = 0x00
PTM_CAPABILITY_REG  = 0x04
PTM_CONTROL_REG     = 0x08

PTM_HEADER_ID_OFFSET      = 0
PTM_HEADER_VERSION_OFFSET = 16

PTM_CAPABILITY_REQUESTER_CAPABLE_OFFSET = 0
PTM_CAPABILITY_RESPONDER_CAPABLE_OFFSET = 1
PTM_CAPABILITY_ROOT_CAPABLE_OFFSET      = 2
PTM_CAPABILITY_CLOCK_GRANULARITY_OFFSET = 8

PTM_CONTROL_ENABLE_OFFSET                = 0
PTM_CONTROL_ROOT_SELECT_OFFSET           = 1
PTM_CONTROL_EFFECTIVE_GRANULARITY_OFFSET = 8

# PTM Capabilities ---------------------------------------------------------------------------------

class PTMCapabilities(LiteXModule):
    def __init__(self, pcie_endpoint,
        requester_capable = True,
        responder_capable = False,
        root_capable      = False,
        clock_granularity = 8e-9,
    ):
        # Outputs.
        self.ptm_enable                = Signal()
        self.ptm_root_select           = Signal()
        self.ptm_effective_granularity = Signal(8)

        # # #

        # Signals.
        reg  = Signal(10)
        dat  = Signal(32)

        # PTM Capability Structure Initial Content.
        ptm_capability_init = {
           PTM_HEADER_REG      : ((1 << PTM_HEADER_VERSION_OFFSET) * 0x01 |
                                  (1 << PTM_HEADER_ID_OFFSET)      * 0x1f),
           PTM_CAPABILITY_REG  : ((1 << PTM_CAPABILITY_REQUESTER_CAPABLE_OFFSET) * requester_capable |
                                  (1 << PTM_CAPABILITY_RESPONDER_CAPABLE_OFFSET) * responder_capable |
                                  (1 << PTM_CAPABILITY_ROOT_CAPABLE_OFFSET)      * root_capable      |
                                  (1 << PTM_CAPABILITY_CLOCK_GRANULARITY_OFFSET) * int(clock_granularity*1e9)),
           PTM_CONTROL_REG     : ((1 << PTM_CONTROL_ENABLE_OFFSET)                * 0 |
                                  (1 << PTM_CONTROL_ROOT_SELECT_OFFSET)           * 0 |
                                  (1 << PTM_CONTROL_EFFECTIVE_GRANULARITY_OFFSET) * 0),
        }

        # PTM Capability Structure Memory.
        mem = Memory(32, PTM_STRUCTURE_REGS, init=[ptm_capability_init[4*i] for i in range(PTM_STRUCTURE_REGS)])
        mem_wr_port   = mem.get_port(write_capable=True)
        mem_rd_port   = mem.get_port(async_read=True)
        mem_ctrl_port = mem.get_port(async_read=True)
        self.specials += mem, mem_wr_port, mem_rd_port, mem_ctrl_port

        # PTM Capability Configuration/Completion Endpoints
        self.conf_ep = conf_ep = pcie_endpoint.depacketizer.conf_source
        self.comp_ep = comp_ep = pcie_endpoint.crossbar.get_slave_port(address_decoder=lambda a: 0).source

        # PTM Capability FSM.
        self.fsm = fsm = FSM(reset_state="IDLE")
        fsm.act("IDLE",
            If(conf_ep.valid,
                If(conf_ep.we,
                    NextState("WRITE-MEM")
                ).Else(
                    NextState("READ-MEM")
                )
            )
        )
        self.comb += reg.eq((Cat(conf_ep.register_no, conf_ep.ext_reg) - 0x6B)) # FIXME: Expose.
        fsm.act("WRITE-MEM",
            conf_ep.ready.eq(1),
            mem_wr_port.adr.eq(reg),
            mem_wr_port.we.eq(1),
            mem_wr_port.dat_w.eq(conf_ep.dat),
            NextState("IDLE")
        )
        fsm.act("READ-MEM",
            mem_rd_port.adr.eq(reg),
            NextValue(dat, mem_rd_port.dat_r),
            NextState("SEND-COMPLETION")
        )

        fsm.act("SEND-COMPLETION",
            comp_ep.valid.eq(1),
            comp_ep.first.eq(1),
            comp_ep.last.eq(1),
            comp_ep.len.eq(1),
            comp_ep.err.eq(0),
            comp_ep.tag.eq(conf_ep.tag),
            comp_ep.adr.eq(0),
            comp_ep.cmp_id.eq(pcie_endpoint.phy.id),
            comp_ep.req_id.eq(conf_ep.req_id),
            comp_ep.dat.eq(dat),
            If(comp_ep.valid & comp_ep.ready,
                conf_ep.ready.eq(1),
                NextState("IDLE")
            )
        )

        # PTM Control Outputs.
        self.comb += [
            mem_ctrl_port.adr.eq(PTM_CONTROL_REG//4),
            self.ptm_enable.eq(               (mem_ctrl_port.dat_r >> PTM_CONTROL_ENABLE_OFFSET)                & 0b1),
            self.ptm_root_select.eq(          (mem_ctrl_port.dat_r >> PTM_CONTROL_ROOT_SELECT_OFFSET)           & 0b1),
            self.ptm_effective_granularity.eq((mem_ctrl_port.dat_r >> PTM_CONTROL_EFFECTIVE_GRANULARITY_OFFSET) & 0b1111_1111),
        ]

# PTM Requester ------------------------------------------------------------------------------------

class PTMRequester(LiteXModule):
    def __init__(self, pcie_endpoint, pcie_ptm_sniffer, sys_clk_freq, with_csr=True):
        # Inputs.
        self.enable     = Signal()
        self.trigger    = Signal()
        self.invalidate = Signal()

        # Outputs.
        self.valid       = Signal()
        self.busy        = Signal()
        self.update      = Signal()
        self.master_time = Signal(64)
        self.link_delay  = Signal(32)
        self.t1          = Signal(64)
        self.t4          = Signal(64)

        # Time.
        self.time_clk = Signal()
        self.time_rst = Signal()
        self.time     = Signal(64)

        # CSRs.
        if with_csr:
            self.add_csr(sys_clk_freq)

        # # #

        # Time Clock Domain Crossing.
        self.cd_time = ClockDomain()
        self.comb += [
            self.cd_time.clk.eq(self.time_clk),
            self.cd_time.rst.eq(self.time_rst),
        ]
        time_cdc = stream.ClockDomainCrossing([("time", 64)],
            cd_from  = "time",
            cd_to    = "sys",
        )
        self.submodules += time_cdc
        self.comb += [
            time_cdc.sink.valid.eq(1),
            time_cdc.sink.time.eq(self.time),
            time_cdc.source.ready.eq(1),
        ]
        time = Signal(64)
        self.sync += If(time_cdc.source.valid,
            time.eq(time_cdc.source.time)
        )

        # PTM Request Endpoint.
        self.req_ep = req_ep = pcie_endpoint.packetizer.ptm_sink

        # PTM Response Endpoint.
        self.res_ep = res_ep = pcie_ptm_sniffer.source

        # PTM Request Timer.
        self.req_timer = req_timer = WaitTimer(1e-6*sys_clk_freq)

        # PTM Requester FSM.
        self.fsm = fsm = ResetInserter()(FSM(reset_state="START"))
        self.comb += fsm.reset.eq(~self.enable)
        fsm.act("START",
            If(self.enable,
                NextState("INVALID-PTM-CONTEXT")
            )
        )
        fsm.act("INVALID-PTM-CONTEXT",
            If(self.trigger,
                NextState("ISSUE-PTM-REQUEST")
            )
        )
        fsm.act("ISSUE-PTM-REQUEST",
            self.busy.eq(1),
            req_ep.valid.eq(1),
            req_ep.request.eq(1),
            req_ep.response.eq(0),
            req_ep.first.eq(1),
            req_ep.last.eq(1),
            req_ep.length.eq(0),
            req_ep.requester_id.eq(pcie_endpoint.phy.id),
            req_ep.message_code.eq(PTM_REQUEST_MESSAGE_CODE),
            If(req_ep.ready,
                NextValue(self.t1, time),
                NextState("WAIT-PTM-RESPONSE")
            )
        )
        self.comb += pcie_ptm_sniffer.source.ready.eq(1)
        fsm.act("WAIT-PTM-RESPONSE",
            self.busy.eq(1),
            If(pcie_ptm_sniffer.source.valid,
                If(pcie_ptm_sniffer.source.message_code == PTM_RESPONSE_MESSAGE_CODE,
                    If(pcie_ptm_sniffer.source.master_time == 0, # FIXME: Add Response/ResponseD indication.
                        NextState("WAIT-1-US")
                    ).Else(
                        NextValue(self.update, 1),
                        NextValue(self.master_time, pcie_ptm_sniffer.source.master_time),
                        NextValue(self.link_delay,  pcie_ptm_sniffer.source.link_delay),
                        NextValue(self.t4, time),
                        NextState("VALID-PTM-CONTEXT")
                    )
                )
            )
        )
        fsm.act("WAIT-1-US",
            self.req_timer.wait.eq(1),
            If(self.req_timer.done,
                NextState("ISSUE-PTM-REQUEST")
            )
        )
        fsm.act("VALID-PTM-CONTEXT",
            self.valid.eq(1),
            NextValue(self.update, 0),
            If(self.trigger,
                NextState("ISSUE-PTM-REQUEST")
            ),
            If(self.invalidate,
                NextState("INVALID-PTM-CONTEXT")
            )
        )

    def add_csr(self, sys_clk_freq, default_enable=0, phy_tx_delay=40e-9, phy_rx_delay=100e-9):
        self._control = CSRStorage(fields=[
            CSRField("enable", size=1, offset=0, values=[
                ("``0b0``", "PTM Requester Disabled."),
                ("``0b1``", "PTM Requester Enabled."),
            ], reset=default_enable),
            CSRField("trigger", size=1, offset=1, pulse=True),
        ])
        self._status = CSRStatus(fields=[
            CSRField("valid", size=1, offset=0, values=[
                ("``0b0``", "PTM Context Invalid."),
                ("``0b1``", "PTM Context Valid."),
            ]),
            CSRField("busy", size=1, offset=1, values=[
                ("``0b0``", "PTM Request Done."),
                ("``0b1``", "PTM Request Ongoing."),
            ]),

        ])
        self._phy_tx_delay = CSRStatus(32, reset=int(phy_tx_delay*1e9), description="PHY TX logic delay (in ns).")
        self._phy_rx_delay = CSRStatus(32, reset=int(phy_rx_delay*1e9), description="PHY RX logic delay (in ns).")
        self._master_time  = CSRStatus(64, description="Last PTM Master Time (in ns).")
        self._link_delay   = CSRStatus(32, description="Last PTM Link Delay (in ns).")
        self._t1_time      = CSRStatus(64, description="Last PTM T1 Time (in ns).")
        self._t4_time      = CSRStatus(64, description="Last PTM T4 Time (in ns).")

        # # #

        self.comb += [
            # Control.
            self.enable.eq(self._control.fields.enable),
            self.trigger.eq(self._control.fields.trigger),
            # Status.
            self._status.fields.valid.eq(self.valid),
            self._status.fields.busy.eq(self.busy),
            # Time.
            self._master_time.status.eq(self.master_time),
            self._link_delay.status.eq(self.link_delay),
            self._t1_time.status.eq(self.t1),
            self._t4_time.status.eq(self.t4),
        ]
