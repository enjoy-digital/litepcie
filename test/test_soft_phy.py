#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import unittest

from migen import *

from litepcie.phy.soft              import SoftPCIEPHY
from litepcie.phy.soft.serdes.model import PCIeSerDesModel

def phy_csrs(**kwargs):
    phy = SoftPCIEPHY(None, None, data_width=64, serdes=PCIeSerDesModel(rx_symbol_shift=0))
    if kwargs.get("debug"):
        phy.add_debug()
    if kwargs.get("tracer"):
        phy.add_ltssm_tracer()
    return phy, [csr.name for csr in phy.get_csrs()]

class TestSoftPHY(unittest.TestCase):
    def test_debug_and_tracer_are_optional(self):
        phy, csrs = phy_csrs()
        self.assertEqual(sorted(csrs), sorted(["link_status", "msi_enable", "msix_enable",
            "bus_master_enable", "max_request_size", "max_payload_size"]))
        # The LTSSM starts on its own without the debug CSRs.
        self.assertEqual(phy.phy_layer.enable.reset.value, 1)

    def test_debug_only(self):
        phy, csrs = phy_csrs(debug=True)
        self.assertIn("debug_control", csrs)
        self.assertNotIn("debug_tracer_history", csrs)
        self.assertFalse(hasattr(phy, "ltssm_tracer"))

    def test_tracer_only(self):
        phy, csrs = phy_csrs(tracer=True)
        self.assertIn("ltssm_tracer_history", csrs)
        self.assertNotIn("debug_control", csrs)
