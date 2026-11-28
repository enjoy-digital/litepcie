#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2023 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

from migen import *

from litex.gen import *

from litex.soc.interconnect.csr import *

from litepcie.tlp.depacketizer   import LitePCIeTLPDepacketizer
from litepcie.tlp.packetizer     import LitePCIeTLPPacketizer
from litepcie.core.crossbar      import LitePCIeCrossbar
from litepcie.core.expansion_rom import LitePCIeExpansionROM

# LitePCIe Endpoint --------------------------------------------------------------------------------

class LitePCIeEndpoint(LiteXModule):
    def __init__(self, phy, max_pending_requests=4, address_width=32, endianness="big",
        cmp_bufs_buffered  = True,
        cmp_bufs_shared    = False,
        with_ptm           = False,
        with_configuration = False,
        address_mask       = None,
    ):
        self.phy                  = phy
        self.max_pending_requests = max_pending_requests

        # The PHY is a module of the SoC with its own CSRs: do not collect them a second time here.
        self.autocsr_exclude = {"phy"}

        # # #

        # Parameters.
        optional_packetizer_capabilities   = []
        optional_depacketizer_capabilities = []
        if with_ptm:
            optional_packetizer_capabilities   = ["PTM"]
            optional_depacketizer_capabilities = ["PTM", "CONFIGURATION"]
        if with_configuration:
            optional_packetizer_capabilities += ["CONFIGURATION"]
            if "CONFIGURATION" not in optional_depacketizer_capabilities:
                optional_depacketizer_capabilities += ["CONFIGURATION"]
        # Default to PHY BAR0 aperture mask for memory requests.
        if address_mask is None:
            address_mask = getattr(phy, "bar0_mask", 0)

        # TLP Packetizer / Depacketizer ------------------------------------------------------------

        if hasattr(phy, "sink") and hasattr(phy, "source"):
            # Shared Request/Completion channels
            self.depacketizer = depacketizer = LitePCIeTLPDepacketizer(
                data_width   = phy.data_width,
                endianness   = endianness,
                address_mask = address_mask,
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
            if with_ptm and not getattr(phy, "with_ptm", False):
                raise ValueError("PTM requires a PHY with with_ptm=True")
            # Separate Request/Completion channels
            self.cmp_depacketizer = cmp_depacketizer = LitePCIeTLPDepacketizer(
                data_width   = phy.data_width,
                endianness   = endianness,
                address_mask = address_mask,
                capabilities = ["COMPLETION"] + (["CONFIGURATION"] if with_configuration else []),
            )
            self.req_depacketizer = req_depacketizer = LitePCIeTLPDepacketizer(
                data_width   = phy.data_width,
                endianness   = endianness,
                address_mask = address_mask,
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
                capabilities  = ["REQUEST"] + optional_packetizer_capabilities,
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
            cmp_bufs_shared      = cmp_bufs_shared,
            with_configuration   = with_configuration,
        )
        self.tlp_ctrl_rst = crossbar.tlp_ctrl_rst

        # Slave: HOST initiates the transactions ---------------------------------------------------

        # Connected in do_finalize() (depends on add_expansion_rom()).
        self.expansion_rom = None
        self._req_source   = req_source
        self._cmp_sink     = cmp_sink

        # Master: FPGA initiates the transactions --------------------------------------------------

        self.comb += [
            crossbar.phy_master.source.connect(req_sink),
            cmp_source.connect(crossbar.phy_master.sink),
        ]

    def add_expansion_rom(self, size, init=None, bar_hit_bit=6):
        """Add a read-only Expansion ROM responder.

        size        : ROM size in bytes (must match the PHY's Expansion ROM BAR size).
        init        : ROM content (list of 32-bit words).
        bar_hit_bit : bar_hit bit of the Expansion ROM BAR (6 on 7-Series).
        """
        assert self.expansion_rom is None, "add_expansion_rom() can only be called once."
        self.expansion_rom = LitePCIeExpansionROM(
            data_width = self.phy.data_width,
            size       = size,
            init       = init,
        )
        self.comb += self.expansion_rom.id.eq(self.phy.id)
        self._expansion_rom_bar_hit_bit = bar_hit_bit

    def do_finalize(self):
        req_source = self._req_source
        cmp_sink   = self._cmp_sink
        crossbar   = self.crossbar

        if self.expansion_rom is None:
            # Default: everything goes to the Crossbar.
            self.comb += [
                req_source.connect(crossbar.phy_slave.sink),
                crossbar.phy_slave.source.connect(cmp_sink),
            ]
        else:
            # Requests: Expansion ROM BAR hits go to the ROM, others to the Crossbar.
            self.comb += [
                If(req_source.bar_hit[self._expansion_rom_bar_hit_bit],
                    req_source.connect(self.expansion_rom.sink),
                ).Else(
                    req_source.connect(crossbar.phy_slave.sink),
                ),
            ]

            # Completions: Mux, a Request only goes to one of the branches (no arbitration needed).
            self.comb += [
                If(self.expansion_rom.source.valid,
                    self.expansion_rom.source.connect(cmp_sink),
                ).Else(
                    crossbar.phy_slave.source.connect(cmp_sink),
                ),
            ]
