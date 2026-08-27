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

    def test_512b_32byte_tail_fits_one_rq_beat(self):
        beats = self.packetize_write(data_width=512, length=8)

        self.assertEqual(len(beats), 1)
        self.assertEqual(beats[0]["first"], 1)
        self.assertEqual(beats[0]["last"], 1)
        self.assertEqual(beats[0]["be"], (1 << (16 + 32)) - 1)


if __name__ == "__main__":
    unittest.main()
