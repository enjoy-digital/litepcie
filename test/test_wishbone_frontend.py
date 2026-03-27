#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import unittest

from migen import *
from migen.sim import run_simulation, passive

from litex.gen import *

from litepcie.core.common import LitePCIeMasterInternalPort, LitePCIeMasterPort, LitePCIeSlaveInternalPort, LitePCIeSlavePort
from litepcie.frontend.wishbone import LitePCIeWishboneMaster, LitePCIeWishboneSlave


class _FakePHY:
    def __init__(self, data_width):
        self.data_width = data_width
        self.id = Signal(16, reset=0x1234)


class _FakeCrossbar:
    def __init__(self, data_width):
        self.slave_port = LitePCIeSlavePort(LitePCIeSlaveInternalPort(data_width))
        self.master_port = LitePCIeMasterPort(LitePCIeMasterInternalPort(data_width, channel=Signal()))

    def get_slave_port(self, address_decoder):
        return self.slave_port

    def get_master_port(self, write_only=False, read_only=False):
        return self.master_port


class _FakeEndpoint:
    def __init__(self, data_width):
        self.phy = _FakePHY(data_width)
        self.crossbar = _FakeCrossbar(data_width)


class _WishboneMasterDUT(LiteXModule):
    def __init__(self, data_width=64, **kwargs):
        self.endpoint = _FakeEndpoint(data_width)
        self.frontend = LitePCIeWishboneMaster(self.endpoint, **kwargs)
        self.port = self.endpoint.crossbar.slave_port


class _WishboneSlaveDUT(LiteXModule):
    def __init__(self, data_width=64, **kwargs):
        self.endpoint = _FakeEndpoint(data_width)
        self.frontend = LitePCIeWishboneSlave(self.endpoint, **kwargs)
        self.port = self.endpoint.crossbar.master_port


class TestWishboneFrontendHelpers(unittest.TestCase):
    def test_master_read_completion_propagates_bus_error(self):
        dut = _WishboneMasterDUT()
        observed = []

        @passive
        def monitor():
            while True:
                yield dut.port.source.ready.eq(1)
                if (yield dut.port.source.valid):
                    observed.append({
                        "err": (yield dut.port.source.err),
                        "end": (yield dut.port.source.end),
                        "tag": (yield dut.port.source.tag),
                        "adr": (yield dut.port.source.adr),
                    })
                yield

        def stim():
            yield dut.frontend.bus.err.eq(0)
            yield dut.port.sink.valid.eq(1)
            yield dut.port.sink.first.eq(1)
            yield dut.port.sink.last.eq(1)
            yield dut.port.sink.we.eq(0)
            yield dut.port.sink.tag.eq(0x5a)
            yield dut.port.sink.adr.eq(0x20)
            yield

            while not ((yield dut.frontend.bus.cyc) and (yield dut.frontend.bus.stb)):
                yield

            yield dut.frontend.bus.err.eq(1)
            yield
            yield dut.frontend.bus.err.eq(0)

            while not (yield dut.port.sink.ready):
                yield
            yield dut.port.sink.valid.eq(0)
            for _ in range(3):
                yield

        run_simulation(dut, [stim(), monitor()], vcd_name=None)
        self.assertEqual(observed, [{"err": 1, "end": 1, "tag": 0x5a, "adr": 0x20}])

    def test_master_write_completes_on_bus_error(self):
        dut = _WishboneMasterDUT()
        observed = {"completions": 0}

        @passive
        def monitor():
            while True:
                yield dut.port.source.ready.eq(1)
                if (yield dut.port.source.valid):
                    observed["completions"] += 1
                yield

        def stim():
            yield dut.frontend.bus.err.eq(0)
            yield dut.port.sink.valid.eq(1)
            yield dut.port.sink.first.eq(1)
            yield dut.port.sink.last.eq(1)
            yield dut.port.sink.we.eq(1)
            yield dut.port.sink.adr.eq(0x24)
            yield dut.port.sink.dat.eq(0xcafef00d)
            yield

            while not ((yield dut.frontend.bus.cyc) and (yield dut.frontend.bus.stb) and (yield dut.frontend.bus.we)):
                yield

            yield dut.frontend.bus.err.eq(1)
            yield
            observed["ready"] = (yield dut.port.sink.ready)
            yield dut.frontend.bus.err.eq(0)
            yield dut.port.sink.valid.eq(0)
            yield
            observed["cyc"] = (yield dut.frontend.bus.cyc)
            observed["stb"] = (yield dut.frontend.bus.stb)
            for _ in range(2):
                yield

        run_simulation(dut, [stim(), monitor()], vcd_name=None)
        self.assertEqual(observed, {"completions": 0, "ready": 1, "cyc": 0, "stb": 0})

    def test_slave_qword_aligned_read_selects_upper_dword(self):
        dut = _WishboneSlaveDUT(qword_aligned=True)
        observed = {}

        def stim():
            yield dut.frontend.bus.cyc.eq(1)
            yield dut.frontend.bus.stb.eq(1)
            yield dut.frontend.bus.we.eq(0)
            yield dut.frontend.bus.adr.eq(0)
            yield

            while not (yield dut.port.source.valid):
                yield
            yield dut.port.source.ready.eq(1)
            yield
            yield dut.port.source.ready.eq(0)

            yield dut.port.sink.valid.eq(1)
            yield dut.port.sink.first.eq(1)
            yield dut.port.sink.last.eq(1)
            yield dut.port.sink.err.eq(0)
            yield dut.port.sink.adr.eq(0x0)
            yield dut.port.sink.dat.eq(0x1122334455667788)
            yield

            while not (yield dut.frontend.bus.ack):
                yield
            observed["dat"] = (yield dut.frontend.bus.dat_r)
            observed["err"] = (yield dut.frontend.bus.err)
            yield dut.port.sink.valid.eq(0)
            yield dut.frontend.bus.cyc.eq(0)
            yield dut.frontend.bus.stb.eq(0)
            yield

        run_simulation(dut, stim(), vcd_name=None)
        self.assertEqual(observed, {"dat": 0x11223344, "err": 0})

    def test_slave_qword_aligned_read_selects_lower_dword(self):
        dut = _WishboneSlaveDUT(qword_aligned=True)
        observed = {}

        def stim():
            yield dut.frontend.bus.cyc.eq(1)
            yield dut.frontend.bus.stb.eq(1)
            yield dut.frontend.bus.we.eq(0)
            yield dut.frontend.bus.adr.eq(1)
            yield

            while not (yield dut.port.source.valid):
                yield
            yield dut.port.source.ready.eq(1)
            yield
            yield dut.port.source.ready.eq(0)

            yield dut.port.sink.valid.eq(1)
            yield dut.port.sink.first.eq(1)
            yield dut.port.sink.last.eq(1)
            yield dut.port.sink.err.eq(0)
            yield dut.port.sink.adr.eq(0x4)
            yield dut.port.sink.dat.eq(0x1122334455667788)
            yield

            while not (yield dut.frontend.bus.ack):
                yield
            observed["dat"] = (yield dut.frontend.bus.dat_r)
            observed["err"] = (yield dut.frontend.bus.err)
            yield dut.port.sink.valid.eq(0)
            yield dut.frontend.bus.cyc.eq(0)
            yield dut.frontend.bus.stb.eq(0)
            yield

        run_simulation(dut, stim(), vcd_name=None)
        self.assertEqual(observed, {"dat": 0x55667788, "err": 0})

    def test_slave_read_completion_propagates_completion_error(self):
        dut = _WishboneSlaveDUT()
        observed = {}

        def stim():
            yield dut.frontend.bus.cyc.eq(1)
            yield dut.frontend.bus.stb.eq(1)
            yield dut.frontend.bus.we.eq(0)
            yield dut.frontend.bus.adr.eq(0)
            yield

            while not (yield dut.port.source.valid):
                yield
            yield dut.port.source.ready.eq(1)
            yield
            yield dut.port.source.ready.eq(0)

            yield dut.port.sink.valid.eq(1)
            yield dut.port.sink.first.eq(1)
            yield dut.port.sink.last.eq(1)
            yield dut.port.sink.err.eq(1)
            yield dut.port.sink.adr.eq(0x0)
            yield dut.port.sink.dat.eq(0xdeadbeef)
            yield

            while not (yield dut.frontend.bus.ack):
                yield
            observed["ack"] = (yield dut.frontend.bus.ack)
            observed["err"] = (yield dut.frontend.bus.err)
            yield dut.port.sink.valid.eq(0)
            yield dut.frontend.bus.cyc.eq(0)
            yield dut.frontend.bus.stb.eq(0)
            yield

        run_simulation(dut, stim(), vcd_name=None)
        self.assertEqual(observed, {"ack": 1, "err": 1})


if __name__ == "__main__":
    unittest.main()
