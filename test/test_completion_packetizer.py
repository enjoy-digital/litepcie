#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import math
import unittest

from migen import *
from migen.sim import run_simulation, passive

from litex.gen import LiteXModule

from litepcie.phy.axis_adapters import SAxisCCAdapter
from litepcie.tlp.common     import cpl_dict, fmt_type_dict
from litepcie.tlp.packetizer import LitePCIeTLPPacketizer


class TestCompletionPacketizer(unittest.TestCase):
    @staticmethod
    def field(value, msb, lsb):
        return (value >> lsb) & ((1 << (msb - lsb + 1)) - 1)

    def packetize(self, data_width, length, error=False):
        dut = LitePCIeTLPPacketizer(
            data_width   = data_width,
            endianness   = "big",
            capabilities = ["COMPLETION"],
        )
        beats = []

        @passive
        def monitor():
            while True:
                yield dut.source.ready.eq(1)
                if (yield dut.source.valid) and (yield dut.source.ready):
                    beats.append({
                        "dat"   : (yield dut.source.dat),
                        "be"    : (yield dut.source.be),
                        "first" : (yield dut.source.first),
                        "last"  : (yield dut.source.last),
                    })
                yield

        def stimulus():
            sink = dut.cmp_sink
            dwords_per_beat = data_width//32
            nbeats = math.ceil(length/dwords_per_beat)

            yield sink.valid.eq(0)
            yield sink.len.eq(length)
            yield sink.byte_count.eq(4*length)
            yield sink.adr.eq(0x24)
            yield sink.req_id.eq(0x1234)
            yield sink.cmp_id.eq(0x0100)
            yield sink.tc.eq(0b101)
            yield sink.tag.eq(0xa5)
            yield sink.err.eq(error)
            yield

            for beat in range(nbeats):
                payload = 0
                for lane in range(dwords_per_beat):
                    payload |= (0x1000 + beat*dwords_per_beat + lane) << (32*lane)
                yield sink.dat.eq(payload)
                yield sink.first.eq(beat == 0)
                yield sink.last.eq(beat == (nbeats - 1))
                yield sink.valid.eq(1)
                yield
                while not (yield sink.ready):
                    yield

            yield sink.valid.eq(0)
            for _ in range(30):
                yield

        run_simulation(dut, [stimulus(), monitor()])
        return beats

    @staticmethod
    def valid_dwords(data_width, beats):
        dwords = []
        for beat in beats:
            for lane in range(data_width//32):
                nibble = (beat["be"] >> (4*lane)) & 0xf
                if nibble == 0xf:
                    dwords.append((beat["dat"] >> (32*lane)) & 0xffffffff)
                else:
                    assert nibble == 0
        return dwords

    def test_successful_completion_keep_matches_length(self):
        for data_width in [32, 64, 128, 256, 512]:
            dwords_per_beat = data_width//32
            lengths = sorted(set([1, dwords_per_beat, dwords_per_beat + 1]))
            for length in lengths:
                with self.subTest(data_width=data_width, length=length):
                    beats = self.packetize(data_width, length)
                    dwords = self.valid_dwords(data_width, beats)

                    self.assertEqual(len(dwords), 3 + length)
                    self.assertEqual((dwords[0] >> 24) & 0x7f, fmt_type_dict["cpld"])
                    self.assertEqual(dwords[0] & 0x3ff, length)
                    self.assertEqual(dwords[1] & 0xfff, 4*length)
                    self.assertEqual([beat["last"] for beat in beats].count(1), 1)

    def test_error_completion_has_no_data(self):
        for data_width in [64, 128]:
            with self.subTest(data_width=data_width):
                beats = self.packetize(data_width, length=1, error=True)
                dwords = self.valid_dwords(data_width, beats)

                self.assertEqual(len(dwords), 3)
                self.assertEqual((dwords[0] >> 24) & 0x7f, fmt_type_dict["cpl"])
                self.assertEqual(dwords[0] & 0x3ff, 0)
                self.assertEqual((dwords[1] >> 13) & 0x7, cpl_dict["ur"])
                self.assertEqual(dwords[1] & 0xfff, 0)
                self.assertEqual(dwords[2] & 0x7f, 0)

    def packetize_to_xilinx_cc(self, data_width, error=False):
        class DUT(LiteXModule):
            def __init__(self):
                self.packetizer = LitePCIeTLPPacketizer(
                    data_width   = data_width,
                    endianness   = "big",
                    capabilities = ["COMPLETION"],
                )
                self.cc_adapter = SAxisCCAdapter(data_width)
                self.comb += [
                    self.cc_adapter.s_axis_tdata.eq(self.packetizer.source.dat),
                    self.cc_adapter.s_axis_tkeep.eq(self.packetizer.source.be),
                    self.cc_adapter.s_axis_tlast.eq(self.packetizer.source.last),
                    self.cc_adapter.s_axis_tuser.eq(0),
                    self.cc_adapter.s_axis_tvalid.eq(self.packetizer.source.valid),
                    self.packetizer.source.ready.eq(self.cc_adapter.s_axis_tready),
                ]

        dut = DUT()
        beats = []

        @passive
        def monitor():
            while True:
                yield dut.cc_adapter.m_axis_tready.eq(1)
                if (yield dut.cc_adapter.m_axis_tvalid):
                    beats.append({
                        "dat"  : (yield dut.cc_adapter.m_axis_tdata),
                        "keep" : (yield dut.cc_adapter.m_axis_tkeep),
                        "last" : (yield dut.cc_adapter.m_axis_tlast),
                    })
                yield

        def stimulus():
            sink = dut.packetizer.cmp_sink
            yield sink.valid.eq(0)
            yield sink.first.eq(1)
            yield sink.last.eq(1)
            yield sink.len.eq(1)
            yield sink.byte_count.eq(4)
            yield sink.adr.eq(0x24)
            yield sink.req_id.eq(0x1234)
            yield sink.cmp_id.eq(0x0100)
            yield sink.tc.eq(0b101)
            yield sink.tag.eq(0xa5)
            yield sink.err.eq(error)
            yield sink.dat.eq(0x89abcdef)
            yield sink.valid.eq(1)
            yield
            while not (yield sink.ready):
                yield
            yield sink.valid.eq(0)
            for _ in range(30):
                yield

        run_simulation(dut, [stimulus(), monitor()])
        return beats

    def test_xilinx_cc_path_preserves_completion_metadata(self):
        for data_width in [128, 256, 512]:
            with self.subTest(data_width=data_width):
                beats = self.packetize_to_xilinx_cc(data_width)
                self.assertEqual(len(beats), 1)
                descriptor = beats[0]["dat"]

                self.assertEqual(self.field(descriptor,  6,  0), 0x24)
                self.assertEqual(self.field(descriptor, 28, 16), 4)
                self.assertEqual(self.field(descriptor, 42, 32), 1)
                self.assertEqual(self.field(descriptor, 45, 43), cpl_dict["sc"])
                self.assertEqual(self.field(descriptor, 63, 48), 0x1234)
                self.assertEqual(self.field(descriptor, 71, 64), 0xa5)
                self.assertEqual(self.field(descriptor, 87, 72), 0x0100)
                self.assertEqual(self.field(descriptor, 91, 89), 0b101)
                self.assertEqual(beats[0]["keep"], 0xf)
                self.assertEqual(beats[0]["last"], 1)

    def test_xilinx_cc_path_formats_error_completion(self):
        for data_width in [128, 256, 512]:
            with self.subTest(data_width=data_width):
                beats = self.packetize_to_xilinx_cc(data_width, error=True)
                self.assertEqual(len(beats), 1)
                descriptor = beats[0]["dat"]

                self.assertEqual(self.field(descriptor,  6,  0), 0)
                self.assertEqual(self.field(descriptor, 28, 16), 0)
                self.assertEqual(self.field(descriptor, 42, 32), 0)
                self.assertEqual(self.field(descriptor, 45, 43), cpl_dict["ur"])
                self.assertEqual(beats[0]["keep"], 0x7)


if __name__ == "__main__":
    unittest.main()
