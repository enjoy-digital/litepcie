#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2024 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import os
import unittest

import pytest

from litex.gen import *

from litex.soc.interconnect import wishbone

from litepcie.core import LitePCIeEndpoint
from litepcie.frontend.wishbone import LitePCIeWishboneMaster, LitePCIeWishboneSlave

from test.common import seed_to_data
from test.model.host import *

# Parameters ---------------------------------------------------------------------------------------

root_id     = 0x100
endpoint_id = 0x400

def _vcd_name(filename):
    return filename if os.environ.get("LITEPCIE_TEST_VCD") else None

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

@pytest.mark.sim
@pytest.mark.slow
class TestWishboneMaster(unittest.TestCase):
    def wishbone_test(self, data_width, nwords=16):
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

    def test_wishbone_32b(self):
        self.wishbone_test(data_width=32)

    def test_wishbone_64b(self):
        self.wishbone_test(data_width=64)

    def test_wishbone_128b(self):
        self.wishbone_test(data_width=128)

    def test_wishbone_256b(self):
        self.wishbone_test(data_width=256)

    def test_wishbone_512b(self):
        self.wishbone_test(data_width=512)

    def test_read_completion_preserves_traffic_class(self):
        observed_tc = []

        def main_generator(dut):
            yield from dut.host.chipset.rd32(0, tc=0b101)
            observed_tc.append(dut.host.chipset.rd_completion.tc)

        class DUT(LiteXModule):
            def __init__(self):
                self.host     = Host(64, root_id, endpoint_id)
                self.endpoint = LitePCIeEndpoint(self.host.phy)
                self.master   = LitePCIeWishboneMaster(self.endpoint)
                self.sram     = wishbone.SRAM(8, bus=self.master.wishbone)

        dut = DUT()
        generators = {"sys": [
            main_generator(dut),
            dut.host.chipset.phy.phy_sink.generator(),
            dut.host.chipset.phy.phy_source.generator(),
        ]}
        run_simulation(dut, generators, {"sys": 10})

        self.assertEqual(observed_tc, [0b101])

    def test_read_completion_preserves_attributes(self):
        observed_attr = []

        def main_generator(dut):
            for attr in [0b01, 0b10, 0b11]:
                yield from dut.host.chipset.rd32(0, attr=attr)
                observed_attr.append(dut.host.chipset.rd_completion.attr)

        class DUT(LiteXModule):
            def __init__(self):
                self.host     = Host(64, root_id, endpoint_id)
                self.endpoint = LitePCIeEndpoint(self.host.phy)
                self.master   = LitePCIeWishboneMaster(self.endpoint)
                self.sram     = wishbone.SRAM(8, bus=self.master.wishbone)

        dut = DUT()
        generators = {"sys": [
            main_generator(dut),
            dut.host.chipset.phy.phy_sink.generator(),
            dut.host.chipset.phy.phy_source.generator(),
        ]}
        run_simulation(dut, generators, {"sys": 10})

        self.assertEqual(observed_attr, [0b01, 0b10, 0b11])

    def test_split_read_completion_metadata(self):
        full_metadata    = []
        partial_metadata = []
        zero_metadata    = []

        def completion_metadata(completions):
            return [(c.length, c.byte_count, c.lower_address) for c in completions]

        def main_generator(dut):
            for address, data in enumerate([0x11111111, 0x22222222, 0x33333333]):
                yield from dut.host.chipset.wr32(address, [data])

            yield from dut.host.chipset.rd32(0, length=3)
            full_metadata.extend(completion_metadata(dut.host.chipset.rd_completions))

            yield from dut.host.chipset.rd32(0, length=2, first_be=0b1100, last_be=0b0011)
            partial_metadata.extend(completion_metadata(dut.host.chipset.rd_completions))

            yield from dut.host.chipset.rd32(0, length=1, first_be=0)
            zero_metadata.extend(completion_metadata(dut.host.chipset.rd_completions))

        class DUT(LiteXModule):
            def __init__(self):
                self.host     = Host(64, root_id, endpoint_id)
                self.endpoint = LitePCIeEndpoint(self.host.phy)
                self.master   = LitePCIeWishboneMaster(self.endpoint)
                self.sram     = wishbone.SRAM(16, bus=self.master.wishbone)

        dut = DUT()
        generators = {"sys": [
            main_generator(dut),
            dut.host.chipset.phy.phy_sink.generator(),
            dut.host.chipset.phy.phy_source.generator(),
        ]}
        run_simulation(dut, generators, {"sys": 10})

        self.assertEqual(full_metadata, [
            (1, 12, 0x00),
            (1,  8, 0x04),
            (1,  4, 0x08),
        ])
        self.assertEqual(partial_metadata, [
            (1, 4, 0x02),
            (1, 2, 0x04),
        ])
        self.assertEqual(zero_metadata, [
            (1, 1, 0x00),
        ])


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

@pytest.mark.sim
@pytest.mark.slow
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
                self.host     = Host(data_width, root_id, endpoint_id)
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
        run_simulation(dut, generators, clocks, vcd_name=_vcd_name("sim.vcd"))
        # Verify Write/Read datas match.
        self.assertEqual(wr_datas, rd_datas)

    def test_wishbone_32b(self):
        self.wishbone_test(32)

    def test_wishbone_64b(self):
        self.wishbone_test(64)
