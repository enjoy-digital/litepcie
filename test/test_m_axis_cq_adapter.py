#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Enjoy-Digital <enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import unittest

from litex.gen import *

from litepcie.phy.xilinx.axis_adapters import MAxisCQAdapter


def _field(value, msb, lsb):
    return (value >> lsb) & ((1 << (msb - lsb + 1)) - 1)


def _cq_fmt_type(reqtype):
    mapping = {
        0b0000: (0b000, 0b00000),
        0b0111: (0b000, 0b00001),
        0b0001: (0b010, 0b00000),
        0b0010: (0b000, 0b00010),
        0b0011: (0b010, 0b00010),
        0b1000: (0b000, 0b00100),
        0b1010: (0b010, 0b00100),
        0b1001: (0b000, 0b00101),
        0b1011: (0b010, 0b00101),
    }
    return mapping.get(reqtype, (0, 0))


def _cq_header(data0, be):
    hdr = _field(data0, 127, 64)
    dwlen = _field(hdr, 9, 0)
    attr = _field(hdr, 61, 60)
    tc = _field(hdr, 59, 57)
    reqtype = _field(hdr, 14, 11)
    tag = _field(hdr, 39, 32)
    requesterid = _field(hdr, 31, 16)
    fmt, typ = _cq_fmt_type(reqtype)

    out = 0
    out |= dwlen
    out |= attr << 12
    out |= tc << 20
    out |= typ << 24
    out |= fmt << 29
    out |= be << 32
    out |= tag << 40
    out |= requesterid << 48
    return out


class TestMAxisCQAdapter(unittest.TestCase):
    def _run_case(self, data_width):
        keep_width = data_width // 8
        dut = MAxisCQAdapter(data_width)

        data0 = int("1122334455667788aabbccddeeff0011" * (data_width // 128), 16)
        data1 = int("0102030405060708f0e0d0c0b0a09080" * (data_width // 128), 16)

        # reqtype=0001 (write), bar=0b101.
        hdr = 0
        dwlen = {128: 1, 256: 5, 512: 13}[data_width]
        hdr |= dwlen
        hdr |= 0b10 << 60
        hdr |= 0b011 << 57
        hdr |= 0x34 << 32
        hdr |= 0x5678 << 16
        hdr |= 0b0001 << 11
        hdr |= 0b101 << 48
        data0 &= ~(((1 << 64) - 1) << 64)
        data0 |= hdr << 64

        user0 = 0
        user1 = 0
        user0 |= 1 << 41
        user1 |= 1 << 41
        if data_width == 512:
            user0 |= 1 << 96
            user1 |= 1 << 96
            be = ((user0 >> 8) & 0xF) << 4 | (user0 & 0xF)
        else:
            be = user0 & 0xFF

        expected_header = _cq_header(data0, be)

        beats = []

        @passive
        def monitor():
            while len(beats) < 1:
                if (yield dut.m_axis_tvalid):
                    beats.append({
                        "data": (yield dut.m_axis_tdata),
                        "keep": (yield dut.m_axis_tkeep),
                        "last": (yield dut.m_axis_tlast),
                        "user": (yield dut.m_axis_tuser),
                        "ready": (yield dut.s_axis_tready),
                    })
                yield

        def stim():
            yield dut.m_axis_tready.eq(1)
            yield

            yield dut.s_axis_tvalid.eq(1)
            yield dut.s_axis_tlast.eq(0)
            yield dut.s_axis_tdata.eq(data0)
            yield dut.s_axis_tuser.eq(user0)
            yield dut.s_axis_tkeep.eq(0)
            yield

            yield dut.s_axis_tlast.eq(1)
            yield dut.s_axis_tdata.eq(data1)
            yield dut.s_axis_tuser.eq(user1)
            yield

            yield dut.s_axis_tvalid.eq(0)
            yield dut.s_axis_tlast.eq(0)
            yield

        run_simulation(dut, [stim(), monitor()], vcd_name=None)

        self.assertEqual(len(beats), 1)
        out = beats[0]
        self.assertEqual(out["ready"], 0b1111)
        self.assertEqual(out["last"], 1)

        if data_width == 128:
            expected_data = (data1 & 0xFFFF_FFFF) << 96
            expected_data |= (data0 & 0xFFFF_FFFF) << 64
            expected_data |= expected_header
        elif data_width == 256:
            expected_data = (data1 & 0xFFFF_FFFF) << 224
            expected_data |= ((data0 >> 128) & ((1 << 128) - 1)) << 96
            expected_data |= (data0 & 0xFFFF_FFFF) << 64
            expected_data |= expected_header
        else:
            expected_data = (data1 & 0xFFFF_FFFF) << (data_width - 32)
            expected_data |= ((data0 >> 128) & ((1 << (data_width - 128)) - 1)) << 96
            expected_data |= (data0 & 0xFFFF_FFFF) << 64
            expected_data |= expected_header

        self.assertEqual(out["data"], expected_data)
        self.assertEqual(out["keep"], (1 << keep_width) - 1)

        barhit = (0 << 7) | (0b101 << 4) | 0b0001
        ecrc_bit = 96 if data_width == 512 else 41
        expected_user = ((user1 >> ecrc_bit) & 0x1) | (barhit << 2)
        self.assertEqual(out["user"] & ((1 << 22) - 1), expected_user)

    def test_m_axis_cq_adapter_128(self):
        self._run_case(data_width=128)

    def test_m_axis_cq_adapter_256(self):
        self._run_case(data_width=256)

    def test_m_axis_cq_adapter_512(self):
        self._run_case(data_width=512)

    def test_m_axis_cq_adapter_256_delayed_last(self):
        dut = MAxisCQAdapter(256)

        # Force SOP with tlast_a=1 so the adapter must emit a delayed extra beat.
        data0 = int("00112233445566778899aabbccddeeff" * 2, 16)
        hdr = 0
        hdr |= 1            # dwlen != 5
        hdr |= 0b0001 << 11 # write reqtype
        data0 &= ~(((1 << 64) - 1) << 64)
        data0 |= hdr << 64
        user0 = 0
        user0 |= 1 << 41
        user0 |= 0xA5A5_5A5A << 8  # last-be source

        beats = []

        @passive
        def monitor():
            for _ in range(8):
                if (yield dut.m_axis_tvalid):
                    beats.append({
                        "last": (yield dut.m_axis_tlast),
                        "keep": (yield dut.m_axis_tkeep),
                    })
                yield

        def stim():
            yield dut.m_axis_tready.eq(1)
            yield
            yield dut.s_axis_tvalid.eq(1)
            yield dut.s_axis_tlast.eq(1)
            yield dut.s_axis_tdata.eq(data0)
            yield dut.s_axis_tuser.eq(user0)
            yield
            yield dut.s_axis_tvalid.eq(0)
            yield
            yield

        run_simulation(dut, [stim(), monitor()], vcd_name=None)
        self.assertEqual(len(beats), 1)
        self.assertEqual(beats[0]["last"], 1)
        expected_keep = ((user0 >> 24) & 0xFFFF) << 12 | 0xFFF
        self.assertEqual(beats[0]["keep"], expected_keep)

    def test_m_axis_cq_adapter_128_read_keep(self):
        dut = MAxisCQAdapter(128)

        data0 = int("89abcdef012345670011223344556677", 16)
        hdr = 0
        hdr |= 1              # dwlen
        hdr |= 0b0000 << 11   # read reqtype
        data0 &= ~(((1 << 64) - 1) << 64)
        data0 |= hdr << 64

        beats = []

        @passive
        def monitor():
            for _ in range(6):
                if (yield dut.m_axis_tvalid):
                    beats.append({
                        "keep": (yield dut.m_axis_tkeep),
                        "last": (yield dut.m_axis_tlast),
                    })
                yield

        def stim():
            yield dut.m_axis_tready.eq(1)
            yield
            yield dut.s_axis_tvalid.eq(1)
            yield dut.s_axis_tlast.eq(0)
            yield dut.s_axis_tdata.eq(data0)
            yield dut.s_axis_tuser.eq(0)
            yield
            yield dut.s_axis_tvalid.eq(1)
            yield dut.s_axis_tlast.eq(1)
            yield dut.s_axis_tdata.eq(0)
            yield dut.s_axis_tuser.eq(0)
            yield
            yield dut.s_axis_tvalid.eq(0)
            yield

        run_simulation(dut, [stim(), monitor()], vcd_name=None)
        self.assertGreaterEqual(len(beats), 1)
        self.assertEqual(beats[0]["keep"], 0x0FFF)

    def test_m_axis_cq_adapter_256_backpressure(self):
        data0 = int("1122334455667788aabbccddeeff0011" * 2, 16)
        data1 = int("0102030405060708f0e0d0c0b0a09080" * 2, 16)
        hdr = 0
        hdr |= 5
        hdr |= 0b0001 << 11
        data0 &= ~(((1 << 64) - 1) << 64)
        data0 |= hdr << 64
        user0 = 1 << 41
        user1 = 1 << 41

        in_beats = [
            dict(data=data0, user=user0, last=0),
            dict(data=data1, user=user1, last=1),
        ]

        def run(ready_pattern):
            dut = MAxisCQAdapter(256)
            out_beats = []

            @passive
            def monitor():
                while len(out_beats) < 1:
                    if (yield dut.m_axis_tvalid) and (yield dut.m_axis_tready):
                        out_beats.append((
                            (yield dut.m_axis_tdata),
                            (yield dut.m_axis_tkeep),
                            (yield dut.m_axis_tlast),
                            (yield dut.m_axis_tuser),
                        ))
                    yield

            def stim():
                yield dut.s_axis_tvalid.eq(0)
                yield
                cyc = 0
                i = 0
                while i < len(in_beats):
                    yield dut.m_axis_tready.eq(1 if ready_pattern[cyc % len(ready_pattern)] else 0)
                    beat = in_beats[i]
                    yield dut.s_axis_tvalid.eq(1)
                    yield dut.s_axis_tdata.eq(beat["data"])
                    yield dut.s_axis_tuser.eq(beat["user"])
                    yield dut.s_axis_tlast.eq(beat["last"])
                    if (yield dut.s_axis_tready[0]):
                        i += 1
                    cyc += 1
                    yield
                yield dut.s_axis_tvalid.eq(0)
                for _ in range(32):
                    yield dut.m_axis_tready.eq(1 if ready_pattern[cyc % len(ready_pattern)] else 0)
                    cyc += 1
                    yield

            run_simulation(dut, [stim(), monitor()], vcd_name=None)
            return out_beats

        ready_all_ones = [1] * 128
        ready_bursty = [1 if ((i * 13 + 1) % 9) not in [0, 1, 2] else 0 for i in range(128)]
        self.assertEqual(run(ready_bursty), run(ready_all_ones))

    def test_m_axis_cq_adapter_256_multi_packet_continuity_dwlen(self):
        dut = MAxisCQAdapter(256)

        def make_sop(dwlen):
            d = int("112233445566778899aabbccddeeff00" * 2, 16)
            hdr = 0
            hdr |= dwlen & 0x3FF
            hdr |= 0b0001 << 11  # write reqtype
            d &= ~(((1 << 64) - 1) << 64)
            d |= hdr << 64
            return d

        stream = [
            # Packet 1: dwlen=5 (threshold), 2-beat packet.
            dict(data=make_sop(5),  user=(1 << 41), last=0),
            dict(data=int("00112233445566778899aabbccddeeff" * 2, 16), user=(1 << 41), last=1),
            # Packet 2: dwlen=4, back-to-back no idle (this one creates delayed-last behavior).
            dict(data=make_sop(4),  user=(1 << 41), last=0),
            dict(data=int("ffeeddccbbaa99887766554433221100" * 2, 16), user=(1 << 41), last=1),
        ]

        out_beats = []

        @passive
        def monitor():
            for _ in range(32):
                if (yield dut.m_axis_tvalid) and (yield dut.m_axis_tready):
                    out_beats.append({
                        "data": (yield dut.m_axis_tdata),
                        "last": (yield dut.m_axis_tlast),
                    })
                yield

        def stim():
            yield dut.m_axis_tready.eq(1)
            yield
            i = 0
            while i < len(stream):
                beat = stream[i]
                yield dut.s_axis_tvalid.eq(1)
                yield dut.s_axis_tdata.eq(beat["data"])
                yield dut.s_axis_tuser.eq(beat["user"])
                yield dut.s_axis_tlast.eq(beat["last"])
                yield dut.s_axis_tkeep.eq(0)
                if (yield dut.s_axis_tready[0]):
                    i += 1
                yield
            yield dut.s_axis_tvalid.eq(0)
            for _ in range(16):
                yield

        run_simulation(dut, [stim(), monitor()], vcd_name=None)

        # No boundary loss across back-to-back packets:
        # pkt1 -> 1 beat, pkt2 -> 2 beats (delayed last), total 3.
        self.assertEqual(len(out_beats), 3)
        self.assertEqual([b["last"] for b in out_beats], [1, 0, 1])
        # Header is in low 64b of first output beat for each packet.
        self.assertEqual((out_beats[0]["data"] >> 0) & 0x3FF, 5)
        self.assertEqual((out_beats[1]["data"] >> 0) & 0x3FF, 4)
