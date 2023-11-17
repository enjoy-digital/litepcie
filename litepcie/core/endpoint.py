#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2023 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

from migen import *

from litex.gen import *

from litex.soc.interconnect.csr import *

from litepcie.tlp.depacketizer import LitePCIeTLPDepacketizer
from litepcie.tlp.packetizer   import LitePCIeTLPPacketizer
from litepcie.core.crossbar    import LitePCIeCrossbar

# LitePCIe Endpoint --------------------------------------------------------------------------------

class LitePCIeEndpoint(LiteXModule):
    def __init__(self, phy, max_pending_requests=4, address_width=32, endianness="big",
        cmp_bufs_buffered = True,
        with_ptm          = False,
    ):
        self.phy                  = phy
        self.max_pending_requests = max_pending_requests

        # # #

        # Parameters.
        optional_packetizer_capabilities   = []
        optional_depacketizer_capabilities = []
        if with_ptm:
            optional_packetizer_capabilities   = ["PTM"]
            optional_depacketizer_capabilities = ["PTM", "CONFIGURATION"]

        # TLP Packetizer / Depacketizer ------------------------------------------------------------

        if hasattr(phy, "sink") and hasattr(phy, "source"):
            # Shared Request/Completion channels
            self.depacketizer = depacketizer = LitePCIeTLPDepacketizer(
                data_width   = phy.data_width,
                endianness   = endianness,
                address_mask = phy.bar0_mask,
                capabilities = ["REQUEST", "COMPLETION"] + optional_depacketizer_capabilities,
            )
            self.packetizer = packetizer = LitePCIeTLPPacketizer(
                data_width    = phy.data_width,
                endianness    = endianness,
                address_width = address_width,
                capabilities  = ["REQUEST", "COMPLETION"] + optional_packetizer_capabilities,
            )
            self.comb += [
                phy.source.connect(depacketizer.sink),
                packetizer.source.connect(phy.sink)
            ]
            req_source = depacketizer.req_source
            cmp_sink   = packetizer.cmp_sink
            req_sink   = packetizer.req_sink
            cmp_source = depacketizer.cmp_source
        else:
            if with_ptm:
                raise NotImplementedError
            # Separate Request/Completion channels
            self.cmp_depacketizer = cmp_depacketizer = LitePCIeTLPDepacketizer(
                data_width   = phy.data_width,
                endianness   = endianness,
                address_mask = phy.bar0_mask,
                capabilities = ["COMPLETION"],
            )
            self.req_depacketizer = req_depacketizer = LitePCIeTLPDepacketizer(
                data_width   = phy.data_width,
                endianness   = endianness,
                address_mask = phy.bar0_mask,
                capabilities = ["REQUEST"],
            )
            self.cmp_packetizer = cmp_packetizer = LitePCIeTLPPacketizer(
                data_width    = phy.data_width,
                endianness    = endianness,
                address_width = address_width,
                capabilities  = ["COMPLETION"],
            )
            self.req_packetizer = req_packetizer = LitePCIeTLPPacketizer(
                data_width    = phy.data_width,
                endianness    = endianness,
                address_width = address_width,
                capabilities  = ["REQUEST"],
            )
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

        self.crossbar = crossbar = LitePCIeCrossbar(
            data_width           = phy.data_width,
            address_width        = address_width,
            max_pending_requests = max_pending_requests,
            cmp_bufs_buffered    = cmp_bufs_buffered,
        )

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
