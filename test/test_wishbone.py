#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2022 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

# In this high level test, LitePCIeEndpoint is connected to LitePCIeWishboneBridge frontend, itself
# connected to a Wishbone SRAM and our Host software model is used to generate Write/Read TLPs:
#
#                                    ┌───────────┐
#                                    │           │
#                                    │   HOST    │
#                                    │  (Model)  │
#                                    │           │
#                                    └─┬───────▲─┘
#                                      │  TLPs │
#                                ┌─────▼───────┴─────┐
#                                │                   │
#                                │                   │
#                                │  LitePCIeEndpoint │
#                                │                   │
#                                │                   │
#                                └──┬──────────────▲─┘
#                                   │   Req/Cmp    │
#                              ┌────▼──────────────┴────┐
#                              │                        │
#                              │                        │
#                              │ LitePCIeWishboneBridge │
#                              │                        │
#                              │                        │
#                              └────────┬──────▲────────┘
#                                       │      │
#                                   ┌───▼──────┴───┐
#                                   │   Wishbone   │
#                                   │     SRAM     │
#                                   └──────────────┘
#
# The test verifies that the Host model is able to access the wishbone SRAM correctly through the
# LitePCIeEndpoint.

import unittest

from migen import *

from litex.soc.interconnect import wishbone

from litepcie.core import LitePCIeEndpoint
from litepcie.frontend.wishbone import LitePCIeWishboneBridge

from test.common import seed_to_data
from test.model.host import *

# Parameters ---------------------------------------------------------------------------------------

root_id     = 0x100
endpoint_id = 0x400

# Test Wishbone ------------------------------------------------------------------------------------

class TestWishbone(unittest.TestCase):
    def wishbone_test(self, data_width, nwords=64):
        wr_datas = [seed_to_data(i, True) for i in range(nwords)]
        rd_datas = []

        def main_generator(dut):
            # Write ndatas to the Wishbone SRAM.
            for i in range(nwords):
                yield from dut.host.chipset.wr32(i, [wr_datas[i]])
            # Read ndatas from the Wishbone SRAM.
            for i in range(nwords):
                yield from dut.host.chipset.rd32(i)
                rd_datas.append(dut.host.chipset.rd_data[0])

        class DUT(Module):
            def __init__(self, data_width):
                self.submodules.host            = Host(data_width, root_id, endpoint_id)
                self.submodules.endpoint        = LitePCIeEndpoint(self.host.phy)
                self.submodules.wishbone_bridge = LitePCIeWishboneBridge(self.endpoint)
                self.submodules.sram            = wishbone.SRAM(nwords*4, bus=self.wishbone_bridge.wishbone)

        dut = DUT(data_width)
        generators = {
            "sys" : [
                main_generator(dut),
                dut.host.chipset.phy.phy_sink.generator(),
                dut.host.chipset.phy.phy_source.generator(),
            ]
        }
        clocks = {"sys": 10}
        run_simulation(dut, generators, clocks)
        # Verify Write/Read datas match.
        self.assertEqual(wr_datas, rd_datas)

    def test_wishbone_64b(self):
        self.wishbone_test(64)

    def test_wishbone_128b(self):
        self.wishbone_test(128)

    def test_wishbone_256b(self):
        self.wishbone_test(256)

    def test_wishbone_512b(self):
        self.wishbone_test(512)
