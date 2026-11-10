#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

# LitePCIeDMAWriter early termination: user stream packets (delimited by last) shorter than the
# DMA descriptors they are written to. Each packet terminates its descriptor early: the descriptor
# must retire (loop status), its data must reach the Host and an IRQ must be raised, as for a
# descriptor executed to its end.

import unittest

import pytest

from litex.gen import *

from litepcie.common import *
from litepcie.core import LitePCIeEndpoint
from litepcie.core.msi import LitePCIeMSI
from litepcie.frontend.dma import LitePCIeDMAWriter

from test.common import seed_to_data
from test.model.host import *
from test.test_dma import DMADriver, MSIHandler, DMA_WRITER_IRQ, root_id, endpoint_id

# Parameters ---------------------------------------------------------------------------------------

data_width        = 64
descriptor_length = 512 # 4 split requests of 128 bytes (max payload size).
buffer_base       = 0x1000

# DUT ----------------------------------------------------------------------------------------------

class DUT(LiteXModule):
    def __init__(self):
        self.host     = Host(data_width, root_id, endpoint_id)
        self.endpoint = LitePCIeEndpoint(self.host.phy, address_width=32)

        dma_writer_port = self.endpoint.crossbar.get_master_port(write_only=True)
        self.dma_writer = LitePCIeDMAWriter(self.endpoint, dma_writer_port, address_width=32)

        self.msi = LitePCIeMSI(2)
        self.comb += self.msi.irqs[log2_int(DMA_WRITER_IRQ)].eq(self.dma_writer.irq)
        self.msi_handler = MSIHandler()
        self.comb += self.msi.source.connect(self.msi_handler.sink)

# Test ---------------------------------------------------------------------------------------------

@pytest.mark.sim
class TestDMAWriterEarlyLast(unittest.TestCase):
    def early_last_test(self, packet_lengths, timeout_cycles=4000):
        """Stream packets of ``packet_lengths`` bytes to descriptors of ``descriptor_length``."""
        dut      = DUT()
        n        = len(packet_lengths)
        packets  = []
        seed     = 0
        for length in packet_lengths:
            dws = [seed_to_data(seed + i) for i in range(length//4)]
            packets.append(dws)
            seed += len(dws)
        status = {"done": False}

        def stream_generator():
            # Wait for the DMA to be enabled.
            while not (yield dut.dma_writer.enable):
                yield
            for dws in packets:
                # DWs are byte-swapped between the DMA stream and the Host's memory.
                sdws  = [int.from_bytes(dw.to_bytes(4, "little"), "big") for dw in dws]
                words = [sdws[i] | (sdws[i + 1] << 32) for i in range(0, len(sdws), 2)]
                for i, word in enumerate(words):
                    yield dut.dma_writer.sink.valid.eq(1)
                    yield dut.dma_writer.sink.data.eq(word)
                    yield dut.dma_writer.sink.last.eq(i == len(words) - 1)
                    yield
                    while not (yield dut.dma_writer.sink.ready):
                        yield
            # Stream stops after the last packet.
            yield dut.dma_writer.sink.valid.eq(0)
            yield dut.dma_writer.sink.last.eq(0)

        def main_generator():
            dut.host.malloc(0, buffer_base + n*descriptor_length)
            dut.host.chipset.enable()

            driver = DMADriver("dma_writer", dut)
            yield from driver.set_prog_mode()
            yield from driver.flush()
            for i in range(n):
                yield from driver.program_descriptor(buffer_base + i*descriptor_length, descriptor_length)
            yield dut.msi.enable.storage.eq(DMA_WRITER_IRQ)
            yield from driver.enable()

            for _ in range(timeout_cycles):
                yield
            status["done"] = True

        generators = {
            "sys" : [
                main_generator(),
                stream_generator(),
                dut.msi_handler.generator(dut),
                dut.host.generator(),
                dut.host.chipset.generator(),
                dut.host.phy.phy_sink.generator(),
                dut.host.phy.phy_source.generator(),
            ]
        }
        run_simulation(dut, generators, {"sys": 10})
        self.assertTrue(status["done"])

        # Every packet must have been written at the start of its descriptor's buffer.
        for i, dws in enumerate(packets):
            written = dut.host.read_mem(buffer_base + i*descriptor_length, len(dws)*4)
            self.assertEqual(written, dws, f"packet {i}")
        # Every early terminated descriptor must raise an IRQ.
        self.assertEqual(dut.msi_handler.dma_writer_irq_count, n)

    def test_early_last_on_request_boundary(self):
        # Packets of one full request (128 bytes): last ends the first split of each descriptor.
        self.early_last_test([128]*4)

    def test_early_last_within_request(self):
        # Packets shorter than a request, with the stream stopping after the last one: each
        # packet has to be written without waiting for the data of the next one.
        self.early_last_test([64, 32, 96])
