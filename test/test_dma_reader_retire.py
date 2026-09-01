#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Enjoy-Digital <enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#

import unittest

import pytest

from litex.gen import *

from litepcie.core         import LitePCIeEndpoint
from litepcie.frontend.dma import LitePCIeDMAReader, LitePCIeDMAScatterGather

from test.common     import seed_to_data
from test.model.host import Host


root_id     = 0x100
endpoint_id = 0x400


@pytest.mark.slow
class TestDMAReaderRetire(unittest.TestCase):
    def test_external_retire_preserves_loop_markers(self):
        table = LitePCIeDMAScatterGather(depth=4, with_external_retire=True)

        def generator():
            yield from table.loop_prog_n.write(0)
            yield from table.reset.write(1)
            for i in range(2):
                yield from table.value.write((64 << 32) | (i * 64))
                yield from table.we.write(0)
            yield from table.loop_prog_n.write(1)

            # Consume into the next loop before retiring anything. This verifies that table
            # lookahead/refill is independent from ordered software-visible retirement.
            descriptor_first = []
            for _ in range(3):
                while not (yield table.source.valid):
                    yield
                descriptor_first.append((yield table.source.first))
                yield table.source.ready.eq(1)
                yield
                yield table.source.ready.eq(0)
                yield
            self.assertEqual(descriptor_first, [1, 0, 1])

            statuses = []
            for first in descriptor_first:
                yield table.retire_first.eq(first)
                yield table.retire_loop.eq(1)
                yield table.retire.eq(1)
                yield
                yield table.retire.eq(0)
                yield
                statuses.append((
                    (yield table.loop_status.fields.index),
                    (yield table.loop_status.fields.count),
                ))
            self.assertEqual(statuses, [(0, 0), (1, 0), (0, 1)])

        run_simulation(table, generator())

    def test_descriptor_retires_on_final_completion(self):
        data_width    = 64
        address_width = 32
        desc_count    = 4
        desc_length   = 1024
        total_length  = desc_count * desc_length
        host_data     = [seed_to_data(i, True) for i in range(total_length // 4)]
        expected      = [int.from_bytes(data.to_bytes(4, "little"), "big") for data in host_data]
        rewritten     = [0xdeadbeef] * (total_length // 4)
        delivered     = []

        beats_expected = total_length // (data_width // 8)
        retire_irqs    = []
        release_output = False

        class DUT(LiteXModule):
            def __init__(self):
                self.host = Host(data_width, root_id, endpoint_id,
                    phy_debug          = False,
                    chipset_debug      = False,
                    chipset_split      = True,
                    chipset_reordering = True,
                    host_debug         = False,
                )
                self.endpoint = LitePCIeEndpoint(self.host.phy,
                    address_width        = address_width,
                    max_pending_requests = 8,
                )
                port = self.endpoint.crossbar.get_master_port(read_only=True)
                self.reader = LitePCIeDMAReader(self.endpoint, port,
                    address_width=address_width)

        dut = DUT()

        def main_generator():
            nonlocal release_output

            dut.host.malloc(0x00000000, total_length * 2)
            dut.host.chipset.enable()
            dut.host.write_mem(0x00000000, host_data)

            yield from dut.reader.table.loop_prog_n.write(0)
            yield from dut.reader.table.reset.write(1)
            for i in range(desc_count):
                value  = (i * desc_length) & 0xffffffff
                value |= desc_length << 32
                value |= (i == 1) << 56  # Disable IRQ on the second descriptor.
                yield from dut.reader.table.value.write(value)
                yield from dut.reader.table.we.write(0)

            yield from dut.reader._enable.write(1)

            # Keep the user stream stalled. Retirement must wait for the final PCIe Completion,
            # but must not wait for already-fetched data to leave the Reader's internal FIFO.
            timeout = 0
            while (yield dut.reader.table.loop_status.fields.index) < desc_count:
                timeout += 1
                if timeout > 20000:
                    self.fail("loop_status did not retire all descriptors")
                yield

            self.assertEqual((yield dut.reader.request_metadata.level), 0)
            self.assertGreater((yield dut.reader.data_fifo.level), 0)

            # Recycling the Host buffers at the documented software-visible completion point must
            # not affect data which has already been fetched into the Reader.
            dut.host.write_mem(0x00000000, rewritten)
            release_output = True

            timeout = 0
            while len(delivered) < beats_expected:
                timeout += 1
                if timeout > 20000:
                    self.fail("Reader output did not drain")
                yield

        @passive
        def output_generator():
            while True:
                yield dut.reader.source.ready.eq(release_output)
                if (yield dut.reader.source.valid) and (yield dut.reader.source.ready):
                    delivered.append((yield dut.reader.source.data))
                yield

        @passive
        def retire_monitor():
            while True:
                if (yield dut.reader.table.retire):
                    retire_irqs.append((yield dut.reader.irq))
                if (yield dut.reader.irq):
                    self.assertEqual((yield dut.reader.table.retire), 1)
                yield

        generators = {"sys": [
            main_generator(),
            output_generator(),
            retire_monitor(),
            dut.host.generator(),
            dut.host.chipset.generator(),
            dut.host.phy.phy_sink.generator(),
            dut.host.phy.phy_source.generator(),
        ]}
        run_simulation(dut, generators, {"sys": 10})

        self.assertEqual(retire_irqs, [1, 0, 1, 1])
        self.assertEqual(len(delivered), beats_expected)
        received = []
        for data in delivered:
            received.append(data & 0xffffffff)
            received.append((data >> 32) & 0xffffffff)
        self.assertEqual(received, expected)
