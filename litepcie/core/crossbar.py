#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2022 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

from migen import *

from litepcie.common import *
from litepcie.core.common import *
from litepcie.tlp.controller import LitePCIeTLPController

# LitePCIe Crossbar --------------------------------------------------------------------------------

class LitePCIeCrossbar(Module):
    def __init__(self, data_width, address_width, max_pending_requests, cmp_bufs_buffered=True):
        self.data_width           = data_width
        self.address_width        = address_width
        self.max_pending_requests = max_pending_requests
        self.cmp_bufs_buffered    = cmp_bufs_buffered

        self.master     = LitePCIeMasterInternalPort(data_width, address_width)
        self.slave      = LitePCIeSlaveInternalPort(data_width)
        self.phy_master = LitePCIeMasterPort(self.master)
        self.phy_slave  = LitePCIeSlavePort(self.slave)

        self.user_masters         = []
        self.user_masters_channel = 0
        self.user_slaves          = []

    def get_slave_port(self, address_decoder):
        s = LitePCIeSlaveInternalPort(
            data_width      = self.data_width,
            address_decoder = address_decoder)
        self.user_slaves.append(s)
        return LitePCIeSlavePort(s)

    def get_master_port(self, write_only=False, read_only=False):
        m = LitePCIeMasterInternalPort(
            data_width    = self.data_width,
            address_width = self.address_width,
            channel       = self.user_masters_channel,
            write_only    = write_only,
            read_only     = read_only
        )
        self.user_masters_channel += 1
        self.user_masters.append(m)
        return LitePCIeMasterPort(m)

    def filter_masters(self, write_only, read_only):
        masters = []
        for m in self.user_masters:
            if m.write_only == write_only and m.read_only == read_only:
                masters.append(m)
        return masters

    def slave_dispatch_arbitrate(self, slaves, slave):
        # Dispatch ---------------------------------------------------------------------------------
        s_sources    = [s.source for s in slaves]
        s_dispatcher = Dispatcher(slave.source, s_sources, one_hot=True)
        self.submodules += s_dispatcher
        for i, s in enumerate(slaves):
                self.comb += s_dispatcher.sel[i].eq(s.address_decoder(slave.source.adr))

        # Arbitrate --------------------------------------------------------------------------------
        s_sinks   = [s.sink for s in slaves]
        s_arbiter = Arbiter(s_sinks, slave.sink)
        self.submodules += s_arbiter

    def master_arbitrate_dispatch(self, masters, master, dispatch=True):
        # Arbitrate --------------------------------------------------------------------------------
        m_sinks   = [m.sink for m in masters]
        m_arbiter = Arbiter(m_sinks, master.sink)
        self.submodules += m_arbiter

        # Dispatch ---------------------------------------------------------------------------------
        if dispatch:
            m_sources    = [m.source for m in masters]
            m_dispatcher = Dispatcher(master.source, m_sources, one_hot=True)
            self.submodules += m_dispatcher
            for i, m in enumerate(masters):
                if m.channel is not None:
                    self.comb += m_dispatcher.sel[i].eq(master.source.channel == m.channel)
        else:
            # Connect to first master
            self.comb += master.source.connect(masters[0].source)

    def do_finalize(self):
        # Slave path -------------------------------------------------------------------------------
        # Dispatch request to user sources (according to address decoder)
        # Arbitrate completion from user sinks
        if self.user_slaves != []:
            self.slave_dispatch_arbitrate(self.user_slaves, self.slave)

        # Master path ------------------------------------------------------------------------------
        # Abritrate requests from user sinks
        # Dispatch completion to user sources (according to channel)

        #           +-------+
        #  reqs---> |  RD   |
        #  cmps<--- | PORTS |---------+
        #           +-------+     +---+----+   +----------+
        #                         |Arb/Disp|-->|Controller|--+
        #           +-------+     +---+----+   +----------+  |
        #  reqs---> |  RW   |         |                      |
        #  cmps<--- | PORTS |---------+                      |
        #           +-------+                            +---+----+
        #                                                |Arb/Disp|<--> to/from  Packetizer/
        #           +-------+                            +---+----+              Depacketizer
        #  reqs---> |  WR   |     +--------+                 |
        #  cmps<--- | PORTS |-----|Arb/Disp|-----------------+
        #           +-------+     +--------+
        #
        # The controller blocks RD requests when the max number of pending
        # requests have been sent (max_pending_requests parameters).
        # To avoid blocking write_only ports when RD requests are blocked,
        # a separate arbitration stage is used.

        if self.user_masters != []:
            masters = []

            # Arbitrate / dispatch read_only / read_write ports ------------------------------------
            # and insert controller
            rd_rw_masters = self.filter_masters(False, True)
            rd_rw_masters += self.filter_masters(False, False)
            if rd_rw_masters != []:
                rd_rw_master = LitePCIeMasterInternalPort(self.data_width, self.address_width)
                controller   = LitePCIeTLPController(
                    data_width           = self.data_width,
                    address_width        = self.address_width,
                    max_pending_requests = self.max_pending_requests,
                    cmp_bufs_buffered    = self.cmp_bufs_buffered)
                self.submodules.controller = controller
                self.master_arbitrate_dispatch(rd_rw_masters, controller.master_in)
                masters.append(controller.master_out)

            # Arbitrate / dispatch write_only ports ------------------------------------------------
            wr_masters = self.filter_masters(True, False)
            if wr_masters != []:
                wr_master = LitePCIeMasterInternalPort(self.data_width, self.address_width)
                self.master_arbitrate_dispatch(wr_masters, wr_master)
                masters.append(wr_master)

            # Final Arbitrate / dispatch stage -----------------------------------------------------
            self.master_arbitrate_dispatch(masters, self.master, False)
