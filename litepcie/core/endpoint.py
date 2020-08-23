#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2020 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

from migen import *

from litex.soc.interconnect.csr import *

from litepcie.tlp.depacketizer import LitePCIeTLPDepacketizer
from litepcie.tlp.packetizer import LitePCIeTLPPacketizer
from litepcie.core.crossbar import LitePCIeCrossbar

# --------------------------------------------------------------------------------------------------

class LitePCIeEndpoint(Module):
    def __init__(self, phy, max_pending_requests=4, endianness="big", cmp_bufs_buffered=True):
        self.phy                  = phy
        self.max_pending_requests = max_pending_requests

        # # #

        # TLP Packetizer / Depacketizer ------------------------------------------------------------
        if hasattr(phy, "sink") and hasattr(phy, "source"):
            # Shared Request/Completion channels
            depacketizer = LitePCIeTLPDepacketizer(phy.data_width, endianness, phy.bar0_mask)
            packetizer   = LitePCIeTLPPacketizer(phy.data_width, endianness)
            self.submodules.depacketizer = depacketizer
            self.submodules.packetizer   = packetizer
            self.comb += [
                phy.source.connect(depacketizer.sink),
                packetizer.source.connect(phy.sink)
            ]
            req_source = depacketizer.req_source
            cmp_sink   = packetizer.cmp_sink
            req_sink   = packetizer.req_sink
            cmp_source = depacketizer.cmp_source
        else:
            # Separate Request/Completion channels
            cmp_depacketizer = LitePCIeTLPDepacketizer(phy.data_width, endianness, phy.bar0_mask)
            req_depacketizer = LitePCIeTLPDepacketizer(phy.data_width, endianness, phy.bar0_mask)
            cmp_packetizer   = LitePCIeTLPPacketizer(phy.data_width, endianness)
            req_packetizer   = LitePCIeTLPPacketizer(phy.data_width, endianness)
            self.submodules.cmp_depacketizer = cmp_depacketizer
            self.submodules.req_depacketizer = req_depacketizer
            self.submodules.cmp_packetizer   = cmp_packetizer
            self.submodules.req_packetizer   = req_packetizer
            self.comb += [
                phy.cmp_source.connect(cmp_depacketizer.sink),
                phy.req_source.connect(req_depacketizer.sink),
                cmp_packetizer.source.connect(phy.cmp_sink),
                req_packetizer.source.connect(phy.req_sink),
            ]
            req_source = req_depacketizer.req_source
            cmp_sink   = cmp_packetizer.cmp_sink
            req_sink   = req_packetizer.req_sink
            cmp_source = cmp_depacketizer.cmp_source

        # Crossbar ---------------------------------------------------------------------------------
        crossbar = LitePCIeCrossbar(phy.data_width, max_pending_requests, cmp_bufs_buffered)
        self.submodules.crossbar = crossbar

        # Slave: HOST initiates the transactions ---------------------------------------------------
        self.comb += [
            req_source.connect(crossbar.phy_slave.sink),
            crossbar.phy_slave.source.connect(cmp_sink),
        ]

        # Master: FPGA initiates the transactions --------------------------------------------------
        self.comb += [
            crossbar.phy_master.source.connect(req_sink),
            cmp_source.connect(crossbar.phy_master.sink),
        ]
