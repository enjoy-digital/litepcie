#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Enjoy-Digital <enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

# LitePCIeDMAReader alone, with a Host model answering its requests in order when the test says so:
# disable/enable with requests in flight, requests terminated with an error, Completions taking
# more beats than the request's words.

import unittest

from migen import *

from litex.gen import *

from litepcie.core.common  import LitePCIeMasterInternalPort, LitePCIeMasterPort
from litepcie.frontend.dma import LitePCIeDMAReader

# DUT ----------------------------------------------------------------------------------------------

class PHY:
    def __init__(self, data_width):
        self.data_width       = data_width
        self.max_request_size = Signal(16, reset=512)
        self.id               = Signal(16)

class Endpoint:
    def __init__(self, data_width, max_pending_requests):
        self.phy                  = PHY(data_width)
        self.max_pending_requests = max_pending_requests

class DUT(LiteXModule):
    def __init__(self, data_width=64, max_pending_requests=4):
        self.endpoint = Endpoint(data_width, max_pending_requests)
        self.internal = LitePCIeMasterInternalPort(data_width, channel=0, read_only=True)
        self.reader   = LitePCIeDMAReader(self.endpoint, LitePCIeMasterPort(self.internal),
            with_table=False)

        self.requests  = []    # (address, bytes) sent by the Reader, in order.
        self.answers   = []    # Per request: "data", "error" or "extra" (one more beat than words).
        self.delivered = []    # Data words on the Reader's source.
        self.allowed   = 0     # Requests the Host may answer.

    @passive
    def host_requests(self):
        sink = self.internal.sink
        yield sink.ready.eq(1)
        while True:
            yield
            if (yield sink.valid) and (yield sink.ready):
                self.requests.append(((yield sink.adr), (yield sink.len)*4))

    @passive
    def host_completions(self):
        source     = self.internal.source
        beat_bytes = self.endpoint.phy.data_width//8
        answered   = 0
        while True:
            yield source.valid.eq(0)
            if answered >= min(self.allowed, len(self.requests)):
                yield
                continue
            address, length = self.requests[answered]
            answer = self.answers[answered] if answered < len(self.answers) else "data"
            beats  = 1 if answer == "error" else length//beat_bytes + (answer == "extra")
            for beat in range(beats):
                yield source.valid.eq(1)
                yield source.first.eq(beat == 0)
                yield source.last.eq(beat == beats - 1)
                yield source.end.eq(answer != "error")
                yield source.err.eq(answer == "error")
                yield source.dat.eq(address + beat*beat_bytes)
                yield source.be.eq(2**beat_bytes - 1)
                yield
                while not (yield source.ready):
                    yield
            answered += 1

    @passive
    def user(self):
        source = self.reader.source
        yield source.ready.eq(1)
        while True:
            yield
            if (yield source.valid) and (yield source.ready):
                self.delivered.append((yield source.data))

    def descriptor(self, address, length):
        sink = self.reader.desc_sink
        yield sink.address.eq(address)
        yield sink.length.eq(length)
        yield sink.valid.eq(1)
        yield
        cycles = 0
        while not (yield sink.ready):
            yield
            cycles += 1
            if cycles > 20000:
                raise TimeoutError
        yield sink.valid.eq(0)

    def wait(self, condition, timeout=5000):
        cycles = 0
        while not condition():
            yield
            cycles += 1
            if cycles > timeout:
                raise TimeoutError

    def run(self, generator):
        run_simulation(self, [generator, self.host_requests(), self.host_completions(), self.user()])

# Tests --------------------------------------------------------------------------------------------

class TestDMAReaderRestart(unittest.TestCase):
    def test_disable_enable_with_requests_in_flight(self):
        dut = DUT()

        def generator():
            # First run: 4 requests in flight, not answered by the Host yet.
            yield from dut.reader._enable.write(1)
            yield from dut.descriptor(0x1000_0000, 4*512)
            yield from dut.wait(lambda: len(dut.requests) == 4)

            # Disable and re-enable right away. The Host now answers everything, the first run's
            # requests first, while a new descriptor is given.
            yield from dut.reader._enable.write(0)
            yield from dut.reader._enable.write(1)
            dut.allowed = 100
            yield from dut.descriptor(0x2000_0000, 2*512)
            yield from dut.wait(lambda: len(dut.delivered) >= 2*512//8)
            for _ in range(200):
                yield

        dut.run(generator())
        # Only the second run's data, complete and in order.
        self.assertEqual(dut.delivered, [0x2000_0000 + 8*i for i in range(2*512//8)])

    def test_requests_terminated_with_an_error(self):
        # More error terminations than the Data FIFO could hold as requests, then data.
        dut = DUT()
        errors = 40
        dut.answers = ["error"]*errors
        dut.allowed = 1000

        def generator():
            yield from dut.reader._enable.write(1)
            yield from dut.descriptor(0x1000_0000, errors*512)
            yield from dut.descriptor(0x2000_0000, 4*512)
            yield from dut.wait(lambda: len(dut.requests) == errors + 4, timeout=20000)
            yield from dut.wait(lambda: len(dut.delivered) >= errors + 4*512//8)

        dut.run(generator())
        self.assertEqual(dut.delivered[errors:], [0x2000_0000 + 8*i for i in range(4*512//8)])

    def test_completions_with_more_beats_than_words(self):
        # Completions not packed as the request's words were counted (one more beat per request).
        dut = DUT()
        requests = 40
        dut.answers = ["extra"]*requests
        dut.allowed = 1000

        def generator():
            yield from dut.reader._enable.write(1)
            yield from dut.descriptor(0x1000_0000, requests*512)
            yield from dut.wait(lambda: len(dut.requests) == requests, timeout=20000)
            yield from dut.wait(lambda: len(dut.delivered) >= requests*(512//8 + 1))

        dut.run(generator())

if __name__ == "__main__":
    unittest.main()
