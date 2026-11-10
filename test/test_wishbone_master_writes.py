#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

# LitePCIeWishboneMaster Host writes: multi-DW Memory Writes must write every DW to consecutive
# Wishbone words (across beats of the PHY data path), and the TLP First/Last Byte Enables must be
# honoured on the Wishbone sel (bytes not enabled are left unchanged).

import unittest

import pytest

from litex.gen import *

from litex.soc.interconnect import wishbone

from litepcie.core import LitePCIeEndpoint
from litepcie.frontend.wishbone import LitePCIeWishboneMaster

from test.common import seed_to_data
from test.model.host import *

# Parameters ---------------------------------------------------------------------------------------

root_id     = 0x100
endpoint_id = 0x400
nwords      = 16

# Helpers ------------------------------------------------------------------------------------------

def be_mask(be):
    # The Host model DWs are in TLP byte order: byte n (Byte Enable n) is bits [31-8n:24-8n].
    return sum(0xff << (8*(3 - n)) for n in range(4) if (be >> n) & 0b1)

def apply_write(mem, adr, data, first_be=0xf, last_be=None):
    if last_be is None:
        last_be = 0xf if len(data) > 1 else 0x0
    for i, dw in enumerate(data):
        be   = first_be if i == 0 else (last_be if i == len(data) - 1 else 0xf)
        mask = be_mask(be)
        mem[adr + i] = (mem[adr + i] & ~mask) | (dw & mask)

# Test ---------------------------------------------------------------------------------------------

@pytest.mark.sim
class TestWishboneMasterWrites(unittest.TestCase):
    def writes_test(self, data_width, writes):
        """Do ``writes`` (adr, data, first_be, last_be) after filling the SRAM, read it back."""
        init     = [seed_to_data(i, True) for i in range(nwords)]
        expected = list(init)
        for adr, data, first_be, last_be in writes:
            apply_write(expected, adr, data, first_be, last_be)
        rd_datas = []

        def main_generator(dut):
            for i in range(nwords):
                yield from dut.host.chipset.wr32(i, [init[i]])
            for adr, data, first_be, last_be in writes:
                yield from dut.host.chipset.wr32(adr, data, first_be=first_be, last_be=last_be)
            yield from dut.host.chipset.rd32(0, length=nwords)
            rd_datas.extend(dut.host.chipset.rd_data)

        class DUT(LiteXModule):
            def __init__(self):
                self.host     = Host(data_width, root_id, endpoint_id)
                self.endpoint = LitePCIeEndpoint(self.host.phy)
                self.master   = LitePCIeWishboneMaster(self.endpoint)
                self.sram     = wishbone.SRAM(nwords*4, bus=self.master.wishbone)

        dut = DUT()
        generators = {"sys": [
            main_generator(dut),
            dut.host.chipset.phy.phy_sink.generator(),
            dut.host.chipset.phy.phy_source.generator(),
        ]}
        run_simulation(dut, generators, {"sys": 10})
        self.assertEqual([hex(d) for d in rd_datas], [hex(d) for d in expected])

    def multi_dw_writes(self):
        data = [seed_to_data(0x100 + i, True) for i in range(7)]
        return [
            (1, data[:2], 0xf, 0xf), # 2 DWs.
            (4, data[:7], 0xf, 0xf), # 7 DWs, across beats.
            (13, data[:3], 0xf, 0xf),
        ]

    def byte_enable_writes(self):
        data = [seed_to_data(0x200 + i, True) for i in range(4)]
        return [
            (0,  data[:1], 0b0011, 0b0000), # 1 DW, partial.
            (2,  data[:1], 0b0000, 0b0000), # Zero-length write: nothing written.
            (5,  data[:4], 0b1100, 0b0001), # 4 DWs, partial first/last.
            (11, data[:2], 0b1000, 0b0111), # 2 DWs, partial first/last.
        ]

    def test_multi_dw_writes(self):
        for data_width in [32, 64, 128, 256]:
            with self.subTest(data_width=data_width):
                self.writes_test(data_width, self.multi_dw_writes())

    def test_byte_enables(self):
        for data_width in [64, 128]:
            with self.subTest(data_width=data_width):
                self.writes_test(data_width, self.byte_enable_writes())
