# This file is Copyright (c) 2020 Florent Kermarrec <florent@enjoy-digital.fr>
# License: BSD

import os

from migen import *

from litex.soc.interconnect.csr import *

from litepcie.common import *

# USPCIEPHY ----------------------------------------------------------------------------------------

class USPCIEPHY(Module, AutoCSR):
    def __init__(self, platform, pads, data_width=64, bar0_size=1*MB, cd="sys", pcie_data_width=64):
        # Streams ----------------------------------------------------------------------------------
        self.req_sink   = stream.Endpoint(phy_layout(data_width))
        self.cmp_sink   = stream.Endpoint(phy_layout(data_width))
        self.req_source = stream.Endpoint(phy_layout(data_width))
        self.cmp_source = stream.Endpoint(phy_layout(data_width))
        self.msi    = stream.Endpoint(msi_layout())

        # Registers --------------------------------------------------------------------------------
        self._link_up           = CSRStatus(description="Link Up Status. ``1``: Link is Up.")
        self._msi_enable        = CSRStatus(description="MSI Enable Status. ``1``: MSI is enabled.")
        self._bus_master_enable = CSRStatus(description="Bus Mastering Status. ``1``: Bus Mastering enabled.")
        self._max_request_size  = CSRStatus(16, description="Negiotiated Max Request Size (in bytes).")
        self._max_payload_size  = CSRStatus(16, description="Negiotiated Max Payload Size (in bytes).")

        # Parameters/Locals ------------------------------------------------------------------------
        self.platform         = platform
        self.data_width       = data_width
        self.pcie_data_width  = pcie_data_width

        self.id               = Signal(16)
        self.bar0_size        = bar0_size
        self.bar0_mask        = get_bar_mask(bar0_size)
        self.max_request_size = Signal(16)
        self.max_payload_size = Signal(16)

        self.external_hard_ip = False

        # # #

        self.nlanes = nlanes = len(pads.tx_p)

        assert nlanes          in [1, 2, 4]
        assert data_width      in [64, 128]
        assert pcie_data_width in [64, 128]

        # TODO

    # Hard IP sources ------------------------------------------------------------------------------
    def add_sources(self, platform, phy_path, phy_filename):
        # TODO
        pass

    # External Hard IP -----------------------------------------------------------------------------
    def use_external_hard_ip(self, hard_ip_path, hard_ip_filename):
        # TODO
        pass

    # Finalize -------------------------------------------------------------------------------------
    def do_finalize(self):
        # TODO
        pass
