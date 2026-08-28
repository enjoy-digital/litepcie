#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Enjoy-Digital <enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#
# Regression test for the DMA Reader descriptor-retirement semantics:
# loop_status (and the per-descriptor IRQ) must only advance once all the
# descriptor's read data has been delivered, not when the last read request
# is issued. Software that polls loop_status to recycle host TX buffers
# must not be able to race the device's own outstanding reads.
#
# The test programs descriptors in PROG mode, monitors the pending-words
# counter at each descriptor pop, and rewrites the host buffer the cycle
# loop_status reports done. With correct retirement semantics, no delivered
# data can carry the rewrite marker.

import unittest

import pytest

from litex.gen import *

from litepcie.common     import *
from litepcie.core       import LitePCIeEndpoint
from litepcie.core.msi   import LitePCIeMSI
from litepcie.frontend.dma import LitePCIeDMAReader

from test.common import seed_to_data
from test.model.host import *

root_id     = 0x100
endpoint_id = 0x400


@pytest.mark.slow
class TestDMAReaderRetire(unittest.TestCase):
    def test_descriptor_retired_only_when_data_delivered(self):
        data_width     = 64
        address_width  = 32
        desc_count     = 4
        desc_length    = 1024
        total_length   = desc_count * desc_length

        original  = [seed_to_data(i, True) for i in range(total_length // 4)]
        rewritten = [0xdeadbeef] * (total_length // 4)
        delivered = []

        pops   = []   # pending_words sampled at each descriptor pop
        beats  = 0
        beats_expected = total_length // (data_width // 8)

        def main_generator(dut):
            dut.host.malloc(0x00000000, total_length * 2)
            dut.host.chipset.enable()
            dut.host.write_mem(0x00000000, original)

            # Program descriptors in PROG mode.
            yield from dut.dma_reader.table.loop_prog_n.write(0)
            yield from dut.dma_reader.table.reset.write(1)
            for i in range(desc_count):
                value = (i * desc_length) & 0xffffffff
                value |= (desc_length << 32)
                yield from dut.dma_reader.table.value.write(value)
                yield from dut.dma_reader.table.we.write(0)

            yield from dut.dma_reader._enable.write(1)

            # Software model: poll loop_status; the cycle it reports all
            # descriptors executed, rewrite the host buffer.
            timeout = 0
            while True:
                index = (yield dut.dma_reader.table.loop_status.fields.index)
                if index >= desc_count:
                    break
                timeout += 1
                if timeout > 20000:
                    self.fail("loop_status never reached expected index")
                yield
            yield
            dut.host.write_mem(0x00000000, rewritten)

            # Drain until all beats delivered.
            t2 = 0
            while beats < beats_expected and t2 < 100000:
                t2 += 1
                yield

        @passive
        def pop_monitor(dut):
            while True:
                valid = (yield dut.dma_reader.table.source.valid)
                ready = (yield dut.dma_reader.table.source.ready)
                if valid and ready:
                    pops.append((yield dut.dma_reader.pending_words))
                yield

        @passive
        def drain(dut):
            nonlocal beats
            while True:
                yield dut.dma_reader.source.ready.eq(1)
                if (yield dut.dma_reader.source.valid):
                    beats += 1
                    delivered.append((yield dut.dma_reader.source.data))
                yield

        class DUT(LiteXModule):
            def __init__(self):
                self.host = Host(data_width, root_id, endpoint_id,
                    phy_debug=False, chipset_debug=False,
                    chipset_split=True, chipset_reordering=True,
                    host_debug=False)
                self.endpoint = LitePCIeEndpoint(self.host.phy,
                    address_width=address_width, max_pending_requests=8)
                port = self.endpoint.crossbar.get_master_port(read_only=True)
                self.dma_reader = LitePCIeDMAReader(self.endpoint, port,
                    address_width=address_width)
                self.msi = LitePCIeMSI(1)
                self.comb += self.msi.irqs[0].eq(self.dma_reader.irq)

        dut = DUT()
        generators = {
            "sys": [
                main_generator(dut),
                drain(dut),
                pop_monitor(dut),
                dut.host.generator(),
                dut.host.chipset.generator(),
                dut.host.phy.phy_sink.generator(),
                dut.host.phy.phy_source.generator(),
            ]
        }
        from migen.sim import run_simulation
        run_simulation(dut, generators, {"sys": 10})

        self.assertEqual(beats, beats_expected, "DMA did not deliver all data")

        # A descriptor must only be retired (popped -> loop_status/IRQ) once
        # no read data is pending for it.
        for n, pending in enumerate(pops):
            self.assertEqual(pending, 0,
                f"descriptor {n} retired with {pending} read words still pending")

        # No delivered word may carry the post-done rewrite marker.
        got = []
        for d in delivered:
            got.append(d & 0xffffffff)
            got.append((d >> 32) & 0xffffffff)
        torn = [w for w in got if w == 0xDEADBEEF]
        self.assertEqual(torn, [],
            f"{len(torn)} delivered words fetched after loop_status reported done")
