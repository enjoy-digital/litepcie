#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

from migen import *

from litex.gen import *

from litex.soc.interconnect.csr import *

from litepcie.core.endpoint import LitePCIeEndpoint

# LitePCIe RootPort --------------------------------------------------------------------------------

class LitePCIeRootPort(LitePCIeEndpoint):
    def __init__(self, phy, **kwargs):
        # FIXME: Endpoint is now role-agnostic; consider a shared base class for Endpoint/RootPort.
        kwargs.setdefault("address_mask", 0)
        LitePCIeEndpoint.__init__(self, phy, **kwargs)
