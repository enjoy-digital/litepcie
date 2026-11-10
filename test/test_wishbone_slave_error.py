#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

# LitePCIeWishboneSlave error Completions: a Host read answered with an error Completion (UR/CA
# status, no data) must end the Wishbone access with err and all-ones data (as an unanswered read,
# and as LiteX's Wishbone Timeout), not with a normal ack.

import unittest

import pytest

from litex.gen import *

from litepcie.core import LitePCIeEndpoint
from litepcie.frontend.wishbone import LitePCIeWishboneSlave

from test.common import seed_to_data
from test.model.host import *

# Parameters ---------------------------------------------------------------------------------------

root_id     = 0x100
endpoint_id = 0x400

CPL_STATUS_UR = 0b001 # Unsupported Request.
CPL_STATUS_CA = 0b100 # Completer Abort.

def bswap(dw):
    # The Host model DWs are in TLP byte order, byte-swapped on the Wishbone bus.
    return int.from_bytes(dw.to_bytes(4, "little"), "big")

# Host answering reads above ``error_base`` with an error Completion -------------------------------

class ErrorHost(Host):
    def __init__(self, *args, error_base, error_status, **kwargs):
        Host.__init__(self, *args, **kwargs)
        self.error_base   = error_base
        self.error_status = error_status

    @passive
    def generator(self):
        while True:
            if len(self.rd_queue):
                msg = self.rd_queue.pop(0)
                if msg.address >= self.error_base:
                    self.chipset.cmp(msg.requester_id, [],
                        byte_count    = 4*msg.length,
                        lower_address = msg.address & 0x7f,
                        tag           = msg.tag,
                        status        = self.error_status,
                    )
                else:
                    self.chipset.cmp(msg.requester_id, self.read_mem(msg.address, 4*msg.length),
                        byte_count    = 4*msg.length,
                        lower_address = msg.address & 0x7f,
                        tag           = msg.tag,
                    )
            yield

# Test ---------------------------------------------------------------------------------------------

@pytest.mark.sim
class TestWishboneSlaveError(unittest.TestCase):
    def error_test(self, data_width, error_status):
        nwords     = 4
        error_base = 4*nwords
        host_data  = [seed_to_data(i, True) for i in range(nwords)]
        results    = []

        def wishbone_read(bus, adr):
            yield bus.adr.eq(adr)
            yield bus.we.eq(0)
            yield bus.cyc.eq(1)
            yield bus.stb.eq(1)
            yield
            while not (yield bus.ack):
                yield
            results.append(((yield bus.dat_r), (yield bus.err)))
            yield bus.cyc.eq(0)
            yield bus.stb.eq(0)
            yield

        def main_generator(dut):
            dut.host.malloc(0x00000000, 1024)
            dut.host.chipset.enable()
            dut.host.write_mem(0x00000000, host_data)
            # Reads answered normally, then with an error Completion, then normally again.
            yield from wishbone_read(dut.slave.bus, 0)
            yield from wishbone_read(dut.slave.bus, error_base//4)
            yield from wishbone_read(dut.slave.bus, error_base//4 + 1)
            yield from wishbone_read(dut.slave.bus, 1)

        class DUT(LiteXModule):
            def __init__(self):
                self.host = ErrorHost(data_width, root_id, endpoint_id,
                    error_base   = error_base,
                    error_status = error_status)
                self.endpoint = LitePCIeEndpoint(self.host.phy)
                self.slave    = LitePCIeWishboneSlave(self.endpoint)

        dut = DUT()
        generators = {"sys": [
            main_generator(dut),
            dut.host.generator(),
            dut.host.chipset.generator(),
            dut.host.chipset.phy.phy_sink.generator(),
            dut.host.chipset.phy.phy_source.generator(),
        ]}
        run_simulation(dut, generators, {"sys": 10})

        self.assertEqual(results, [
            (bswap(host_data[0]), 0),
            (0xffffffff,          1),
            (0xffffffff,          1),
            (bswap(host_data[1]), 0),
        ])

    def test_unsupported_request(self):
        for data_width in [64, 128]:
            with self.subTest(data_width=data_width):
                self.error_test(data_width, CPL_STATUS_UR)

    def test_completer_abort(self):
        self.error_test(64, CPL_STATUS_CA)
