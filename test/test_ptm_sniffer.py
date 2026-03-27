#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import unittest

from migen import *
from migen.sim import run_simulation, passive

from litex.gen import *

from litepcie.tlp.common import fmt_type_dict
from litepcie.frontend.ptm.sniffer import END, SHP, LinkStreamPacker, PTMPacketParser


def _pack_bytes(values):
    value = 0
    for i, byte in enumerate(values):
        value |= (byte & 0xff) << (8*i)
    return value


def _pack_bits(values):
    value = 0
    for i, bit in enumerate(values):
        value |= (bit & 0x1) << i
    return value


def _lane_words_from_link_beat(beat_bytes, beat_ctrl, nlanes):
    assert len(beat_bytes) == 4*nlanes
    assert len(beat_ctrl)  == 4*nlanes

    lane_words = []
    lane_ctrls = []
    for lane in range(nlanes):
        lane_bytes = [beat_bytes[symbol*nlanes + lane] for symbol in range(4)]
        lane_bits  = [beat_ctrl[symbol*nlanes + lane] for symbol in range(4)]
        lane_words.append(_pack_bytes(lane_bytes))
        lane_ctrls.append(_pack_bits(lane_bits))
    return lane_words, lane_ctrls


class _PackerParserDUT(LiteXModule):
    def __init__(self, nlanes, lane_reverse=False):
        self.submodules.packer = LinkStreamPacker(nlanes)
        self.submodules.parser = PTMPacketParser(self.packer.width)
        self.comb += [
            self.packer.lane_reverse.eq(int(lane_reverse)),
            self.packer.source.connect(self.parser.sink),
        ]


class TestPTMSnifferHelpers(unittest.TestCase):
    def test_link_stream_packer_x1_keeps_byte_order(self):
        dut = LinkStreamPacker(1)
        observed = []

        @passive
        def monitor():
            while True:
                yield dut.source.ready.eq(1)
                if (yield dut.source.valid) and (yield dut.source.ready):
                    observed.append((yield dut.source.data))
                yield

        def stim():
            yield dut.sinks[0].valid.eq(1)
            yield dut.sinks[0].ctrl.eq(0)
            yield dut.sinks[0].data.eq(_pack_bytes([0x00, 0x01, 0x02, 0x03]))
            yield
            yield dut.sinks[0].data.eq(_pack_bytes([0x04, 0x05, 0x06, 0x07]))
            yield
            yield dut.sinks[0].valid.eq(0)
            for _ in range(3):
                yield

        run_simulation(dut, [stim(), monitor()], vcd_name=None)
        self.assertEqual(observed, [_pack_bytes([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])])

    def test_link_stream_packer_lane_reversal_reorders_lanes(self):
        dut = LinkStreamPacker(4)
        observed = []

        @passive
        def monitor():
            while True:
                yield dut.source.ready.eq(1)
                if (yield dut.source.valid) and (yield dut.source.ready):
                    observed.append((yield dut.source.data))
                yield

        def stim():
            yield dut.lane_reverse.eq(1)
            for lane in range(4):
                yield dut.sinks[lane].valid.eq(1)
                yield dut.sinks[lane].ctrl.eq(0)
                yield dut.sinks[lane].data.eq(_pack_bytes([
                    lane + 0x00,
                    lane + 0x10,
                    lane + 0x20,
                    lane + 0x30,
                ]))
            yield
            for lane in range(4):
                yield dut.sinks[lane].valid.eq(0)
            for _ in range(2):
                yield

        run_simulation(dut, [stim(), monitor()], vcd_name=None)
        self.assertEqual(observed, [_pack_bytes([
            0x03, 0x02, 0x01, 0x00,
            0x13, 0x12, 0x11, 0x10,
            0x23, 0x22, 0x21, 0x20,
            0x33, 0x32, 0x31, 0x30,
        ])])

    def test_x4_path_reconstructs_and_decodes_ptm_response(self):
        dut = _PackerParserDUT(4)
        observed = []

        packet = [
            fmt_type_dict["ptm_res"],
            0x00, 0x00, 0x01,
            0xaa, 0xbb, 0xcc, 0x53,
            0x01, 0x02, 0x03, 0x04,
            0x05, 0x06, 0x07, 0x08,
            0x11, 0x22, 0x33, 0x44,
        ]
        beat0_bytes = [SHP.value] + packet[:15]
        beat0_ctrl  = [1] + [0]*15
        beat1_bytes = packet[15:] + [END.value] + [0x00]*(16 - 6)
        beat1_ctrl  = [0]*5 + [1] + [0]*(16 - 6)
        beat_words  = [
            _lane_words_from_link_beat(beat0_bytes, beat0_ctrl, nlanes=4),
            _lane_words_from_link_beat(beat1_bytes, beat1_ctrl, nlanes=4),
        ]

        @passive
        def monitor():
            while True:
                yield dut.parser.source.ready.eq(1)
                if (yield dut.parser.source.valid) and (yield dut.parser.source.ready):
                    observed.append({
                        "message_code": (yield dut.parser.source.message_code),
                        "master_time":  (yield dut.parser.source.master_time),
                        "link_delay":   (yield dut.parser.source.link_delay),
                    })
                yield

        def stim():
            for lane in range(4):
                yield dut.packer.sinks[lane].valid.eq(0)
                yield dut.packer.sinks[lane].ctrl.eq(0)
                yield dut.packer.sinks[lane].data.eq(0)
            yield

            for words, ctrls in beat_words:
                for lane in range(4):
                    yield dut.packer.sinks[lane].valid.eq(1)
                    yield dut.packer.sinks[lane].data.eq(words[lane])
                    yield dut.packer.sinks[lane].ctrl.eq(ctrls[lane])
                yield

            for lane in range(4):
                yield dut.packer.sinks[lane].valid.eq(0)
                yield dut.packer.sinks[lane].ctrl.eq(0)
                yield dut.packer.sinks[lane].data.eq(0)
            for _ in range(4):
                yield

        run_simulation(dut, [stim(), monitor()], vcd_name=None)
        self.assertEqual(observed, [{
            "message_code": 0x53,
            "master_time":  0x0102030405060708,
            "link_delay":   0x11223344,
        }])

    def test_x4_path_reversed_lanes_reconstructs_and_decodes_ptm_response(self):
        dut = _PackerParserDUT(4, lane_reverse=True)
        observed = []

        packet = [
            fmt_type_dict["ptm_res"],
            0x00, 0x00, 0x01,
            0xaa, 0xbb, 0xcc, 0x53,
            0x01, 0x02, 0x03, 0x04,
            0x05, 0x06, 0x07, 0x08,
            0x11, 0x22, 0x33, 0x44,
        ]
        beat0_bytes = [SHP.value] + packet[:15]
        beat0_ctrl  = [1] + [0]*15
        beat1_bytes = packet[15:] + [END.value] + [0x00]*(16 - 6)
        beat1_ctrl  = [0]*5 + [1] + [0]*(16 - 6)
        beat_words  = [
            _lane_words_from_link_beat(beat0_bytes, beat0_ctrl, nlanes=4),
            _lane_words_from_link_beat(beat1_bytes, beat1_ctrl, nlanes=4),
        ]

        @passive
        def monitor():
            while True:
                yield dut.parser.source.ready.eq(1)
                if (yield dut.parser.source.valid) and (yield dut.parser.source.ready):
                    observed.append({
                        "message_code": (yield dut.parser.source.message_code),
                        "master_time":  (yield dut.parser.source.master_time),
                        "link_delay":   (yield dut.parser.source.link_delay),
                    })
                yield

        def stim():
            for lane in range(4):
                yield dut.packer.sinks[lane].valid.eq(0)
                yield dut.packer.sinks[lane].ctrl.eq(0)
                yield dut.packer.sinks[lane].data.eq(0)
            yield

            for words, ctrls in beat_words:
                for lane in range(4):
                    physical_lane = 3 - lane
                    yield dut.packer.sinks[physical_lane].valid.eq(1)
                    yield dut.packer.sinks[physical_lane].data.eq(words[lane])
                    yield dut.packer.sinks[physical_lane].ctrl.eq(ctrls[lane])
                yield

            for lane in range(4):
                yield dut.packer.sinks[lane].valid.eq(0)
                yield dut.packer.sinks[lane].ctrl.eq(0)
                yield dut.packer.sinks[lane].data.eq(0)
            for _ in range(4):
                yield

        run_simulation(dut, [stim(), monitor()], vcd_name=None)
        self.assertEqual(observed, [{
            "message_code": 0x53,
            "master_time":  0x0102030405060708,
            "link_delay":   0x11223344,
        }])


if __name__ == "__main__":
    unittest.main()
