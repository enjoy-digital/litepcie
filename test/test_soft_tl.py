#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import unittest

from migen import *

from litepcie.phy.soft.tl.adapter      import TXAdapter, RXAdapter
from litepcie.phy.soft.tl.config_space import PCIeConfigSpace

def swap(dw):
    return int.from_bytes(dw.to_bytes(4, "little"), "big")

class TestSoftTL(unittest.TestCase):
    def test_tx_adapter(self):
        # Beats to DWs: be=0 DWs dropped, last on the last valid DW, byte swap.
        for data_width, beats in [
            (64,  [(0x0000000200000001, 0xff, 0), (0x0000000000000003, 0x0f, 1)]),
            (64,  [(0x0000000200000001, 0xff, 0), (0x0000000400000003, 0xff, 1)]),
            (128, [(0x00000000000000030000000200000001, 0x0fff, 1)]),
            (128, [(0x00000004000000030000000200000001, 0xffff, 0), (0x5, 0x000f, 1)]),
        ]:
            dut = TXAdapter(data_width)
            out = []
            def generator():
                yield dut.source.ready.eq(1)
                for dat, be, last in beats:
                    yield dut.sink.dat.eq(dat)
                    yield dut.sink.be.eq(be)
                    yield dut.sink.last.eq(last)
                    yield dut.sink.valid.eq(1)
                    yield
                    while True:
                        if (yield dut.source.valid):
                            out.append(((yield dut.source.data), (yield dut.source.first), (yield dut.source.last)))
                        if (yield dut.sink.ready):
                            break
                        yield
                yield dut.sink.valid.eq(0)
                yield
            run_simulation(dut, generator())
            n = sum(bin(be).count("1")//4 for dat, be, last in beats)
            self.assertEqual([d for d, f, l in out], [swap(i + 1) for i in range(n)])
            self.assertEqual([f for d, f, l in out], [1] + [0]*(n - 1))
            self.assertEqual([l for d, f, l in out], [0]*(n - 1) + [1])

    def test_rx_adapter(self):
        # DWs to beats: be=0 past the end, a TLP starts on DW 0.
        for data_width, lengths in [(64, [3, 4, 5]), (128, [3, 4, 5, 8])]:
            dut = RXAdapter(data_width)
            ratio = data_width//32
            beats = []
            def generator():
                yield dut.source.ready.eq(1)
                for length in lengths:
                    for i in range(length):
                        yield dut.sink.data.eq(swap(i + 1))
                        yield dut.sink.first.eq(i == 0)
                        yield dut.sink.last.eq(i == length - 1)
                        yield dut.sink.valid.eq(1)
                        yield
                        if (yield dut.source.valid):
                            beats.append(((yield dut.source.dat), (yield dut.source.be), (yield dut.source.last)))
                yield dut.sink.valid.eq(0)
                yield
                if (yield dut.source.valid):
                    beats.append(((yield dut.source.dat), (yield dut.source.be), (yield dut.source.last)))
                yield
            run_simulation(dut, generator())
            expected = []
            for length in lengths:
                for b in range(0, length, ratio):
                    count = min(ratio, length - b)
                    dat = sum((b + j + 1) << 32*j for j in range(count))
                    be  = (1 << 4*count) - 1
                    expected.append((dat, be, int(b + ratio >= length)))
            self.assertEqual(beats, expected)

    def test_config_space(self):
        dut = PCIeConfigSpace(bar0_mask=0xfff00000)
        def read(adr):
            yield dut.adr.eq(adr//4)
            yield
            return (yield dut.dat_r)
        def write(adr, value, be=0xf):
            yield dut.adr.eq(adr//4)
            yield dut.dat_w.eq(value)
            yield dut.be.eq(be)
            yield dut.we.eq(1)
            yield
            yield dut.we.eq(0)
            yield
        def generator():
            self.assertEqual((yield from read(0x00)), 0x702110ee)
            self.assertEqual((yield from read(0x100)), 0) # No extended capabilities.
            # Capability list ends.
            ptr = (yield from read(0x34)) & 0xff
            caps = []
            while ptr:
                dw = yield from read(ptr)
                caps.append(dw & 0xff)
                ptr = (dw >> 8) & 0xff
            self.assertEqual(caps, [0x01, 0x05, 0x10])
            # BAR sizing.
            yield from write(0x10, 0xffffffff)
            self.assertEqual((yield from read(0x10)), 0xfff00000)
            # Command with byte enables, read-only bits kept.
            yield from write(0x04, 0xffffffff, be=0x1)
            self.assertEqual((yield from read(0x04)), 0x00100046)
            self.assertEqual((yield dut.mse), 1)
            self.assertEqual((yield dut.bme), 1)
            # Device Control: MPS/MRRS reset and write.
            self.assertEqual((yield dut.mps), 0)
            self.assertEqual((yield dut.mrrs), 2)
            yield from write(0x68, 0x00001030)
            self.assertEqual((yield dut.mps), 1)
            self.assertEqual((yield dut.mrrs), 1)
            # Unsupported Request Detected: set, write 1 to clear.
            yield dut.ur_detected.eq(1)
            yield
            yield dut.ur_detected.eq(0)
            yield
            self.assertEqual(((yield from read(0x68)) >> 19) & 1, 1)
            yield from write(0x68, 0x00080000, be=0x4)
            self.assertEqual(((yield from read(0x68)) >> 19) & 1, 0)
            # MSI.
            yield from write(0x4c, 0xfee00003)
            yield from write(0x50, 0x00000001)
            yield from write(0x54, 0xffff1234)
            yield from write(0x48, 0x00010000)
            self.assertEqual((yield dut.msi_enable), 1)
            self.assertEqual((yield dut.msi_address), 0x1fee00000)
            self.assertEqual((yield dut.msi_data), 0x1234)
        run_simulation(dut, generator())
