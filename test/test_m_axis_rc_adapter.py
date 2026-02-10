#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Enjoy-Digital <enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import unittest

from litex.gen import *

from litepcie.phy.xilinx.axis_adapters import MAxisRCAdapter


def _field(value, msb, lsb):
    return (value >> lsb) & ((1 << (msb - lsb + 1)) - 1)


def _rc_headers(data):
    dwlen       = _field(data, 41, 32)
    attr        = _field(data, 93, 92)
    tc          = _field(data, 91, 89)
    bytecnt     = _field(data, 27, 16)
    cmpstatus   = _field(data, 45, 43)
    completerid = _field(data, 87, 72)
    lowaddr     = _field(data, 6, 0)
    tag         = _field(data, 71, 64)
    requesterid = _field(data, 63, 48)

    if _field(data, 29, 29):
        fmt = 0b000 if bytecnt == 0 else 0b010
        typ = 0b01011
    else:
        fmt = 0b000 if bytecnt == 0 else 0b010
        typ = 0b01010

    header0 = 0
    header0 |= dwlen
    header0 |= attr << 12
    header0 |= tc << 20
    header0 |= typ << 24
    header0 |= fmt << 29
    header0 |= bytecnt << 32
    header0 |= cmpstatus << 45
    header0 |= completerid << 48

    header1 = 0
    header1 |= lowaddr
    header1 |= tag << 8
    header1 |= requesterid << 16
    header1 |= _field(data, 127, 96) << 32
    return header0, header1


class TestMAxisRCAdapter(unittest.TestCase):
    def _run_case(self, data_width):
        keep_width = data_width // 8
        dut = MAxisRCAdapter(data_width)

        data0 = int("123456789abcdef0fedcba9876543210" * (data_width // 128), 16)
        data1 = int("0f1e2d3c4b5a69788796a5b4c3d2e1f0" * (data_width // 128), 16)
        user0 = (1 << 42) | 0x1555_aa55_1234
        user1 = 0x0f0f_aaaa_55aa
        user0 &= (1 << 85) - 1
        user1 &= (1 << 85) - 1

        beats = []

        @passive
        def monitor():
            while len(beats) < 2:
                if (yield dut.m_axis_tvalid):
                    beats.append({
                        "data":  (yield dut.m_axis_tdata),
                        "keep":  (yield dut.m_axis_tkeep),
                        "last":  (yield dut.m_axis_tlast),
                        "user":  (yield dut.m_axis_tuser),
                        "sop":   (yield dut.m_axis_sop),
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

        self.assertEqual(len(beats), 2)
        self.assertEqual(beats[0]["ready"], 0b1111)
        self.assertEqual(beats[1]["ready"], 0b1111)

        header0, header1 = _rc_headers(data0)
        if data_width == 128:
            exp_data0 = (header1 << 64) | header0
            exp_keep0 = (1 << keep_width) - 1
            exp_user0 = ((user0 >> 42) & 0x1) | (((data0 >> 46) & 0x1) << 1) | (1 << 14)
        else:
            exp_data0 = ((data0 >> 128) << 128) | (header1 << 64) | header0
            exp_keep0 = ((((user0 >> 12) << 12) | 0xFFF) & ((1 << keep_width) - 1))
            exp_user0 = ((user0 >> 42) & 0x1) | (((data0 >> 46) & 0x1) << 1)

        exp_data1 = data1
        exp_keep1 = user1 & ((1 << keep_width) - 1)
        exp_user1 = ((user1 >> 42) & 0x1) | (((data0 >> 46) & 0x1) << 1)

        self.assertEqual(beats[0]["sop"], 1)
        self.assertEqual(beats[1]["sop"], 0)
        self.assertEqual(beats[0]["data"], exp_data0)
        self.assertEqual(beats[0]["keep"], exp_keep0)
        self.assertEqual(beats[0]["last"], 0)
        self.assertEqual(beats[0]["user"] & ((1 << 22) - 1), exp_user0)
        self.assertEqual(beats[1]["data"], exp_data1)
        self.assertEqual(beats[1]["keep"], exp_keep1)
        self.assertEqual(beats[1]["last"], 1)
        self.assertEqual(beats[1]["user"] & ((1 << 22) - 1), exp_user1)

    def test_m_axis_rc_adapter_128(self):
        self._run_case(data_width=128)

    def test_m_axis_rc_adapter_256(self):
        self._run_case(data_width=256)

    def test_m_axis_rc_adapter_512(self):
        self._run_case(data_width=512)

    def test_m_axis_rc_adapter_256_backpressure(self):
        in_beats = [
            dict(
                data=int("123456789abcdef0fedcba9876543210" * 2, 16),
                user=((1 << 42) | 0x1234_5678_9abc) & ((1 << 85) - 1),
                last=0,
            ),
            dict(
                data=int("0f1e2d3c4b5a69788796a5b4c3d2e1f0" * 2, 16),
                user=(0x0f0f_aaaa_55aa) & ((1 << 85) - 1),
                last=1,
            ),
        ]

        def run(ready_pattern):
            dut = MAxisRCAdapter(256)
            out_beats = []

            @passive
            def monitor():
                while len(out_beats) < 2:
                    if (yield dut.m_axis_tvalid) and (yield dut.m_axis_tready):
                        out_beats.append((
                            (yield dut.m_axis_tdata),
                            (yield dut.m_axis_tkeep),
                            (yield dut.m_axis_tlast),
                            (yield dut.m_axis_tuser),
                            (yield dut.m_axis_sop),
                        ))
                    yield

            def stim():
                yield dut.s_axis_tvalid.eq(0)
                yield dut.s_axis_tlast.eq(0)
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
        ready_bursty = [1 if ((i * 17 + 3) % 7) not in [0, 1] else 0 for i in range(128)]
        ref = run(ready_all_ones)
        got = run(ready_bursty)
        self.assertEqual(got, ref)

    def _run_poison_ecrc_matrix_case(self, data_width, poison_data, ecrc_user):
        dut = MAxisRCAdapter(data_width)
        beats = []

        data = int("123456789abcdef0fedcba9876543210" * (data_width // 128), 16)
        data &= ~(1 << 46)
        data |= (poison_data & 0x1) << 46
        user = (ecrc_user & 0x1) << 42

        @passive
        def monitor():
            for _ in range(8):
                if (yield dut.m_axis_tvalid):
                    beats.append((yield dut.m_axis_tuser))
                yield

        def stim():
            yield dut.m_axis_tready.eq(1)
            yield
            yield dut.s_axis_tvalid.eq(1)
            yield dut.s_axis_tlast.eq(1)
            yield dut.s_axis_tdata.eq(data)
            yield dut.s_axis_tuser.eq(user)
            yield dut.s_axis_tkeep.eq(0)
            yield
            yield dut.s_axis_tvalid.eq(0)
            yield

        run_simulation(dut, [stim(), monitor()], vcd_name=None)
        self.assertGreaterEqual(len(beats), 1)
        return beats[0]

    def test_poison_ecrc_matrix_all_widths(self):
        for data_width in [128, 256, 512]:
            for poison_data in [0, 1]:
                for ecrc_user in [0, 1]:
                    out_user = self._run_poison_ecrc_matrix_case(
                        data_width=data_width,
                        poison_data=poison_data,
                        ecrc_user=ecrc_user,
                    )
                    self.assertEqual(out_user & 0x1, ecrc_user)
                    self.assertEqual((out_user >> 1) & 0x1, poison_data)
