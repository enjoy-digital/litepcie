#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2024 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import unittest

from litex.gen import *

from litex.soc.interconnect import wishbone

from litepcie.core import LitePCIeEndpoint
from litepcie.frontend.wishbone import LitePCIeWishboneMaster, LitePCIeWishboneSlave

from test.common import seed_to_data
from test.model.host import *

# Parameters ---------------------------------------------------------------------------------------

root_id     = 0x100
endpoint_id = 0x400

# Test Wishbone Master -----------------------------------------------------------------------------

# In this high level test, LitePCIeEndpoint is connected to LitePCIeWishboneMaster frontend, itself
# connected to a Wishbone SRAM and the Host software model is used to generate Write/Read TLPs:
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
#                              │ LitePCIeWishboneMaster │
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

class TestWishboneMaster(unittest.TestCase):
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

        class DUT(LiteXModule):
            def __init__(self, data_width):
                self.host     = Host(data_width, root_id, endpoint_id)
                self.endpoint = LitePCIeEndpoint(self.host.phy)
                self.master   = LitePCIeWishboneMaster(self.endpoint)
                self.sram     = wishbone.SRAM(nwords*4, bus=self.master.wishbone)

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
        self.wishbone_test(data_width=64)

    def test_wishbone_128b(self):
        self.wishbone_test(data_width=128)

    def test_wishbone_256b(self):
        self.wishbone_test(data_width=256)

    def test_wishbone_512b(self):
        self.wishbone_test(data_width=512)


# Test Wishbone Slave ------------------------------------------------------------------------------

# In this high level test, LitePCIeEndpoint is connected to LitePCIeWishboneSlave frontend. Wishbone
# accesses are done to Host Memory through LitePCIeWishbone and the Host software model is used to 
# handle Write/Read TLPs:
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
#                              │ LitePCIeWishboneSlave  │
#                              │                        │
#                              │                        │
#                              └────────┬──────▲────────┘
#                                       │      │
#                                   ┌───▼──────┴───┐
#                                   │   Wishbone   │
#                                   │   Accesses   │
#                                   └──────────────┘
#
# The test verifies that the LitePCIeWishboneSlave is able to access Host Memory.

class TestWishboneSlave(unittest.TestCase):
    def wishbone_test(self, data_width, nwords=8):
        wr_datas = [seed_to_data(i, True) for i in range(nwords)]
        rd_datas = []

        #@passive
        def main_generator(dut):
            # Allocate Host's Memory.
            dut.host.malloc(0x00000000, 1024)

            # Enable Chipset
            dut.host.chipset.enable()

            # Write ndatas to Host Memory.
            for i in range(nwords):
                yield from dut.slave.wishbone.write(i, wr_datas[i])

           # Read ndatas from Host Memory.
            for i in range(nwords):
                rd_datas.append((yield from dut.slave.wishbone.read(i)))

        def fake_generator(dut):
            for i in range(1024):
                yield

        class DUT(LiteXModule):
            def __init__(self, data_width):
                self.host     = Host(data_width, root_id, endpoint_id, phy_debug=True, host_debug=True)
                self.endpoint = LitePCIeEndpoint(self.host.phy)
                self.slave    = LitePCIeWishboneSlave(self.endpoint)

        dut = DUT(data_width)
        generators = {
            "sys" : [
                main_generator(dut),
                #fake_generator(dut),
                dut.host.generator(),
                dut.host.chipset.generator(),
                dut.host.chipset.phy.phy_sink.generator(),
                dut.host.chipset.phy.phy_source.generator(),
            ]
        }
        clocks = {"sys": 10}
        run_simulation(dut, generators, clocks, vcd_name="sim.vcd")

    def test_wishbone_64b(self):
        self.wishbone_test(64)
