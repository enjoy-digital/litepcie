# This file is Copyright (c) 2015-2018 Florent Kermarrec <florent@enjoy-digital.fr>
# License: BSD

import unittest
import random

from migen import *

from litex.gen.sim import *

from litex.soc.interconnect import stream
from litex.soc.interconnect.stream_sim import seed_to_data

from litepcie.common import *
from litepcie.core import LitePCIeEndpoint
from litepcie.core.msi import LitePCIeMSI
from litepcie.frontend.dma import (LitePCIeDMAWriter,
                                   LitePCIeDMAReader)

from test.model.host import *

DMA_READER_IRQ = 1
DMA_WRITER_IRQ = 2

root_id = 0x100
endpoint_id = 0x400
max_length = Signal(8, reset=128)
dma_size = 1024


class DMADriver:
    def __init__(self, dma, dut):
        self.dma = getattr(dut, dma)
        self.dut = dut

    def set_prog_mode(self):
        yield from self.dma.table.loop_prog_n.write(0)

    def set_loop_mode(self):
        yield from self.dma.table.loop_prog_n.write(1)

    def flush(self):
        yield from self.dma.table.flush.write(1)

    def program_descriptor(self, address, length):
        value = address
        value |= (length << 32)
        yield from self.dma.table.value.write(value)
        yield from self.dma.table.we.write(1)

    def enable(self):
        yield from self.dma.enable.write(1)

    def disable(self):
        yield from self.dma.enable.write(0)


class MSIHandler(Module):
    def __init__(self, debug=False):
        self.debug = debug
        self.sink = stream.Endpoint(msi_layout())

        self.dma_reader_irq_count = 0
        self.dma_writer_irq_count = 0

    def clear_dma_reader_irq_count(self):
        self.dma_writer_irq_count = 0

    def clear_dma_writer_irq_count(self):
        self.dma_writer_irq_count = 0

    @passive
    def generator(self, dut):
        last_valid = 0
        while True:
            yield from dut.msi.clear.write(0)
            yield self.sink.ready.eq(1)
            if (yield self.sink.valid):
                # get vector
                irq_vector = (yield dut.msi.vector.status)

                # handle irq
                if irq_vector & DMA_READER_IRQ:
                    self.dma_reader_irq_count += 1
                    if self.debug:
                        print("[MSI] dma_reader_irq (n: {:d})".format(self.dma_reader_irq_count))
                    # clear msi
                    yield from dut.msi.clear.write((yield from dut.msi.clear.read()) |
                                                   DMA_READER_IRQ)

                if irq_vector & DMA_WRITER_IRQ:
                    self.dma_writer_irq_count += 1
                    if self.debug:
                        print("[MSI] dma_writer_irq (n: {:d})".format(self.dma_writer_irq_count))
                    # clear msi
                    yield from dut.msi.clear.write((yield from dut.msi.clear.read()) |
                                                   DMA_WRITER_IRQ)
            yield


test_size = 1024


class DUT(Module):
    def __init__(self, data_width):
        self.submodules.host = Host(data_width, root_id, endpoint_id,
            phy_debug=False,
            chipset_debug=False, chipset_split=True, chipset_reordering=True,
            host_debug=True)
        self.submodules.endpoint = LitePCIeEndpoint(self.host.phy, max_pending_requests=8)
        self.submodules.dma_reader = LitePCIeDMAReader(self.endpoint, self.endpoint.crossbar.get_master_port(read_only=True))
        self.submodules.dma_writer = LitePCIeDMAWriter(self.endpoint, self.endpoint.crossbar.get_master_port(write_only=True))
        self.comb += self.dma_reader.source.connect(self.dma_writer.sink)

        self.submodules.msi = LitePCIeMSI(2)
        self.comb += [
            self.msi.irqs[log2_int(DMA_READER_IRQ)].eq(self.dma_reader.irq),
            self.msi.irqs[log2_int(DMA_WRITER_IRQ)].eq(self.dma_writer.irq)
        ]
        self.submodules.msi_handler = MSIHandler(debug=False)
        self.comb += self.msi.source.connect(self.msi_handler.sink)


host_datas = [seed_to_data(i, True) for i in range(test_size//4)]
loopback_datas = []

def main_generator(dut, nreads=8, nwrites=8):
    dut.host.malloc(0x00000000, test_size*2)
    dut.host.chipset.enable()

    dut.host.write_mem(0x00000000, host_datas)

    dma_reader_driver = DMADriver("dma_reader", dut)
    dma_writer_driver = DMADriver("dma_writer", dut)

    yield from dma_reader_driver.set_prog_mode()
    yield from dma_reader_driver.flush()
    for i in range(nreads):
        yield from dma_reader_driver.program_descriptor((test_size//8)*i, test_size//8)

    yield from dma_writer_driver.set_prog_mode()
    yield from dma_writer_driver.flush()
    for i in range(nwrites):
        yield from dma_writer_driver.program_descriptor(test_size + (test_size//8)*i, test_size//8)

    yield dut.msi.enable.storage.eq(DMA_READER_IRQ | DMA_WRITER_IRQ)

    yield from dma_reader_driver.enable()
    yield from dma_writer_driver.enable()

    while dut.msi_handler.dma_writer_irq_count != nwrites:
        yield

    for i in range(1024):
        yield

    for data in dut.host.read_mem(test_size, test_size):
        loopback_datas.append(data)


class TestDMA(unittest.TestCase):
    def dma_test(self, data_width):
        dut = DUT(data_width)
        generators = {
            "sys" : [
                main_generator(dut),
                dut.msi_handler.generator(dut),
                dut.host.generator(),
                dut.host.chipset.generator(),
                dut.host.phy.phy_sink.generator(),
                dut.host.phy.phy_source.generator()
            ]
        }
        clocks = {"sys": 10}
        run_simulation(dut, generators, clocks, vcd_name="test_dma.vcd")
        self.assertEqual(host_datas, loopback_datas)

    def test_dma_64b(self):
        self.dma_test(64)

    def test_dma_128b(self):
        self.dma_test(128)

