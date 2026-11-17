#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import math
import unittest

from migen.sim import passive, run_simulation

from litepcie.tlp.packetizer import LitePCIeTLPPacketizer


class TestRequestPacketizer(unittest.TestCase):
    def packetize_write(self, data_width, length):
        dut = LitePCIeTLPPacketizer(
            data_width    = data_width,
            endianness    = "big",
            address_width = 64,
            capabilities  = ["REQUEST"],
        )
        beats = []

        @passive
        def monitor():
            while True:
                yield dut.source.ready.eq(1)
                if (yield dut.source.valid) and (yield dut.source.ready):
                    beats.append({
                        "be"    : (yield dut.source.be),
                        "first" : (yield dut.source.first),
                        "last"  : (yield dut.source.last),
                    })
                yield

        def stimulus():
            sink = dut.req_sink
            dwords_per_beat = data_width//32
            nbeats = math.ceil(length/dwords_per_beat)

            yield sink.valid.eq(0)
            yield sink.we.eq(1)
            yield sink.adr.eq(0x1_0000_1000)
            yield sink.len.eq(length)
            yield sink.req_id.eq(0x1234)
            yield sink.tag.eq(0x5a)
            yield

            for beat in range(nbeats):
                yield sink.dat.eq(0x12345678 << (32*(beat % dwords_per_beat)))
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

    def test_write_keep_matches_length(self):
        for data_width in [128, 256, 512]:
            dwords_per_beat = data_width//32
            lengths = sorted(set([
                1,
                dwords_per_beat//2,
                dwords_per_beat,
                dwords_per_beat + dwords_per_beat//2,
            ]))
            for length in lengths:
                with self.subTest(data_width=data_width, length=length):
                    beats = self.packetize_write(data_width, length)
                    valid_dwords = sum(
                        1
                        for beat in beats
                        for lane in range(data_width//32)
                        if ((beat["be"] >> (4*lane)) & 0xf) == 0xf
                    )

                    self.assertEqual(valid_dwords, 4 + length)
                    self.assertEqual([beat["last"] for beat in beats].count(1), 1)

    def test_3dw_write_tail_drains_before_4dw_read(self):
        dut = LitePCIeTLPPacketizer(
            data_width    = 128,
            endianness    = "little",
            address_width = 64,
            capabilities  = ["REQUEST"],
        )
        beats = []

        def stimulus():
            sink = dut.req_sink
            # A 32-bit address Write (3-DW header, 4 DWs) directly followed by a 64-bit address
            # Read (4-DW header).
            for we, adr, length in [
                (1,        0x1000,   4),
                (0, 0x1_0000_2000, 128),
            ]:
                yield sink.we.eq(we)
                yield sink.adr.eq(adr)
                yield sink.len.eq(length)
                yield sink.dat.eq(0x44444444333333332222222211111111)
                yield sink.first.eq(1)
                yield sink.last.eq(1)
                yield sink.valid.eq(1)
                yield
                while not (yield sink.ready):
                    yield
            yield sink.valid.eq(0)
            for _ in range(32):
                yield

        @passive
        def monitor():
            yield dut.source.ready.eq(1)
            while True:
                if (yield dut.source.valid) and (yield dut.source.ready):
                    beats.append({
                        "first" : (yield dut.source.first),
                        "last"  : (yield dut.source.last),
                        "dat"   : (yield dut.source.dat),
                        "be"    : (yield dut.source.be),
                    })
                yield

        run_simulation(dut, [stimulus(), monitor()])

        # Write: header + first DW, then the 3-DW tail. Read: header only.
        self.assertEqual(
            [(beat["first"], beat["last"]) for beat in beats],
            [(1, 0), (0, 1), (1, 1)])
        self.assertEqual(beats[1]["dat"], 0x444444443333333322222222)
        self.assertEqual(beats[1]["be"],  0x0fff)
        self.assertEqual(beats[2]["dat"] & 0xffffffff, 0x20000080)

    def test_512b_32byte_tail_fits_one_rq_beat(self):
        beats = self.packetize_write(data_width=512, length=8)

        self.assertEqual(len(beats), 1)
        self.assertEqual(beats[0]["first"], 1)
        self.assertEqual(beats[0]["last"], 1)
        self.assertEqual(beats[0]["be"], (1 << (16 + 32)) - 1)


if __name__ == "__main__":
    unittest.main()
