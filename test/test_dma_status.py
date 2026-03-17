#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Enjoy-Digital <enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import unittest
from types import SimpleNamespace

from litex.gen import *

from litepcie.core import LitePCIeEndpoint
from litepcie.frontend.dma import LitePCIeDMAStatus

from test.model.host import Host


root_id     = 0x100
endpoint_id = 0x400


class LoggingHost(Host):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.writes = []

    def callback(self, msg):
        super().callback(msg)
        if msg.name in ["WR32", "WR64"]:
            self.writes.append(msg)


class _DMAStub(LiteXModule):
    def __init__(self):
        self.enable = Signal(reset=1)
        self.irq    = Signal()
        self.table  = SimpleNamespace(
            loop_status=SimpleNamespace(status=Signal(32))
        )


class TestDMAStatus(unittest.TestCase):
    @staticmethod
    def _swap32(value):
        return (
            ((value >> 24) & 0x000000FF) |
            ((value >>  8) & 0x0000FF00) |
            ((value <<  8) & 0x00FF0000) |
            ((value << 24) & 0xFF000000)
        )

    def _run_status_update(self, data_width, trigger_mode):
        status_base = 0x40
        external_words = [0x100 + i for i in range(8)]
        captured = {}

        class DUT(LiteXModule):
            def __init__(self, data_width):
                self.host = LoggingHost(
                    data_width         = data_width,
                    root_id            = root_id,
                    endpoint_id        = endpoint_id,
                    phy_debug          = False,
                    chipset_debug      = False,
                    chipset_split      = True,
                    chipset_reordering = True,
                    host_debug         = False,
                )
                self.endpoint = LitePCIeEndpoint(
                    self.host.phy,
                    address_width        = 32,
                    max_pending_requests = 8,
                )
                self.writer = _DMAStub()
                self.reader = _DMAStub()
                self.status = LitePCIeDMAStatus(
                    endpoint      = self.endpoint,
                    writer        = self.writer,
                    reader        = self.reader,
                    address_width = 32,
                    status_width  = 64,
                )

        def main_generator(dut):
            dut.host.malloc(0x00000000, 0x200)
            dut.host.chipset.enable()

            yield dut.writer.table.loop_status.status.eq(0x12345678)
            yield dut.reader.table.loop_status.status.eq(0x9ABCDEF0)
            for index, value in enumerate(external_words):
                yield dut.status.external_status[index].eq(value)

            yield from dut.status.address_lsb.write(status_base)
            yield from dut.status.address_msb.write(0)
            yield from dut.status.control.write(1 | (trigger_mode << 4))

            if trigger_mode == 0b00:
                yield dut.status.external_update.eq(1)
                yield
                yield dut.status.external_update.eq(0)
            elif trigger_mode == 0b01:
                yield dut.writer.irq.eq(1)
                yield
                yield dut.writer.irq.eq(0)
            elif trigger_mode == 0b10:
                yield dut.reader.irq.eq(1)
                yield
                yield dut.reader.irq.eq(0)
            else:
                raise ValueError("Unsupported trigger mode")

            for _ in range(128):
                yield

            captured["writes"] = list(dut.host.writes)
            captured["memory"] = dut.host.read_mem(status_base, 16*4)

        dut = DUT(data_width)
        generators = {
            "sys": [
                main_generator(dut),
                dut.host.generator(),
                dut.host.chipset.generator(),
                dut.host.phy.phy_sink.generator(),
                dut.host.phy.phy_source.generator(),
            ]
        }
        clocks = {"sys": 10}
        run_simulation(dut, generators, clocks, vcd_name=None)
        return captured

    def _assert_status_words(self, memory):
        self.assertEqual(memory[0], self._swap32(0x5AA55AA5))
        self.assertEqual(memory[1], self._swap32(0x12345678))
        self.assertEqual(memory[2], self._swap32(0x9ABCDEF0))
        self.assertEqual(memory[3], 0)
        self.assertEqual(memory[4], 0)
        self.assertEqual(memory[5:8], [0, 0, 0])
        self.assertEqual(memory[8:16], [self._swap32(0x100 + i) for i in range(8)])

    def test_status_256bit_emits_two_writes(self):
        result = self._run_status_update(data_width=256, trigger_mode=0b00)
        writes = result["writes"]

        self.assertEqual(len(writes), 2)
        self.assertEqual([write.length for write in writes], [8, 8])
        self.assertEqual([write.address for write in writes], [0x40, 0x60])
        self._assert_status_words(result["memory"])

    def test_status_512bit_emits_single_write(self):
        result = self._run_status_update(data_width=512, trigger_mode=0b00)
        writes = result["writes"]

        self.assertEqual(len(writes), 1)
        self.assertEqual(writes[0].length, 16)
        self.assertEqual(writes[0].address, 0x40)
        self._assert_status_words(result["memory"])

    def test_status_writer_irq_trigger_256bit(self):
        result = self._run_status_update(data_width=256, trigger_mode=0b01)
        writes = result["writes"]

        self.assertEqual(len(writes), 2)
        self.assertEqual([write.length for write in writes], [8, 8])
        self._assert_status_words(result["memory"])

    def test_status_reader_irq_trigger_512bit(self):
        result = self._run_status_update(data_width=512, trigger_mode=0b10)
        writes = result["writes"]

        self.assertEqual(len(writes), 1)
        self.assertEqual(writes[0].length, 16)
        self._assert_status_words(result["memory"])
