#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Enjoy-Digital <enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import unittest

from litex.gen import *

from litepcie.phy.xilinx.axis_adapters import SAxisCCAdapter


def _field(value, msb, lsb):
    return (value >> lsb) & ((1 << (msb - lsb + 1)) - 1)


def _header_words(data, tuser):
    lowaddr = _field(data, 70, 64)
    bytecnt = _field(data, 43, 32)
    lockedrdcmp = 1 if _field(data, 29, 24) == 0b001011 else 0
    dwordcnt = _field(data, 9, 0)
    cmpstatus = _field(data, 47, 45)
    poison = _field(data, 14, 14)
    requesterid = _field(data, 95, 80)
    tag = _field(data, 79, 72)
    completerid = _field(data, 63, 48)
    tc = _field(data, 22, 20)
    attr = _field(data, 13, 12)
    td = _field(data, 15, 15) | (tuser & 0x1)

    header0 = 0
    header0 |= lowaddr
    header0 |= bytecnt << 16
    header0 |= lockedrdcmp << 29
    header0 |= dwordcnt << 32
    header0 |= cmpstatus << 42
    header0 |= poison << 45
    header0 |= requesterid << 48

    header1 = 0
    header1 |= tag
    header1 |= completerid << 8
    header1 |= tc << 25
    header1 |= attr << 28
    header1 |= td << 31
    header1 |= _field(data, 127, 96) << 32
    return header0, header1


class TestSAxisCCAdapter(unittest.TestCase):
    def _expected_keep(self, data_width, keep):
        if data_width == 128:
            return sum(((1 if ((keep >> (4*i)) & 0xF) else 0) << i) for i in range(4))
        if data_width == 256:
            return sum(((1 if ((keep >> (4*i)) & 0xF) else 0) << i) for i in range(8))
        return sum((((keep >> (4*i)) & 0x1) << i) for i in range(16))

    def _run_case(self, data_width):
        dut = SAxisCCAdapter(data_width)
        keep_width = data_width // 8

        data = int("ffeeddccbbaa99887766554433221100" * (data_width // 128), 16)
        # Force meaningful header fields.
        data &= ~((1 << 128) - 1)
        data |= 0x89ABCDEF << 96
        data |= 0x1357 << 80
        data |= 0x42 << 72
        data |= 0x2468 << 48
        data |= 0b101 << 45
        data |= 0x155 << 32
        data |= 0b001011 << 24
        data |= 0b110 << 20
        data |= 0b10 << 12
        data |= 0x2AA
        data |= 0x3F << 64

        if data_width == 128:
            keep = 0xF0F3
        elif data_width == 256:
            keep = 0x00FF_0F0F
        else:
            keep = int("1111000011110000", 2)  # nibble-lsb pattern.
            keep = sum((((keep >> i) & 0x1) << (4*i)) for i in range(16))

        tuser = 0b1001  # td contribution + discontinue.
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
            yield dut.s_axis_tlast.eq(1)
            yield dut.s_axis_tdata.eq(data)
            yield dut.s_axis_tkeep.eq(keep)
            yield dut.s_axis_tuser.eq(tuser)
            yield
            yield dut.s_axis_tvalid.eq(0)
            yield

        run_simulation(dut, [stim(), monitor()], vcd_name=None)

        self.assertEqual(len(beats), 1)
        out = beats[0]

        header0, header1 = _header_words(data, tuser)
        if data_width == 128:
            expected_data = (header1 << 64) | header0
        else:
            expected_data = ((data >> 128) << 128) | (header1 << 64) | header0

        self.assertEqual(out["ready"], 1)
        self.assertEqual(out["last"], 1)
        self.assertEqual(out["user"], 1)  # only discontinue bit is propagated.
        self.assertEqual(out["keep"], self._expected_keep(data_width, keep))
        self.assertEqual(out["data"], expected_data)

    def test_s_axis_cc_adapter_128(self):
        self._run_case(data_width=128)

    def test_s_axis_cc_adapter_256(self):
        self._run_case(data_width=256)

    def test_s_axis_cc_adapter_512(self):
        self._run_case(data_width=512)

    def test_s_axis_cc_adapter_256_backpressure(self):
        data = int("ffeeddccbbaa99887766554433221100" * 2, 16)
        keep = 0x00FF_0F0F
        user = 0b1001

        in_beats = [dict(data=data, keep=keep, user=user, last=1)]

        def run(ready_pattern):
            dut = SAxisCCAdapter(256)
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
                    yield dut.s_axis_tkeep.eq(beat["keep"])
                    yield dut.s_axis_tuser.eq(beat["user"])
                    yield dut.s_axis_tlast.eq(beat["last"])
                    if (yield dut.s_axis_tready):
                        i += 1
                    cyc += 1
                    yield
                yield dut.s_axis_tvalid.eq(0)
                for _ in range(16):
                    yield dut.m_axis_tready.eq(1 if ready_pattern[cyc % len(ready_pattern)] else 0)
                    cyc += 1
                    yield

            run_simulation(dut, [stim(), monitor()], vcd_name=None)
            return out_beats

        ready_all_ones = [1] * 64
        ready_bursty = [1 if ((i * 11 + 5) % 8) not in [0, 1] else 0 for i in range(64)]
        self.assertEqual(run(ready_bursty), run(ready_all_ones))

    def _run_poison_ecrc_matrix_case(self, data_width, poison_data, td_data, td_user):
        dut = SAxisCCAdapter(data_width)
        beats = []

        data = int("ffeeddccbbaa99887766554433221100" * (data_width // 128), 16)
        data &= ~(1 << 14)
        data &= ~(1 << 15)
        data |= (poison_data & 0x1) << 14
        data |= (td_data & 0x1) << 15
        keep = (1 << (data_width // 8)) - 1
        tuser = td_user & 0x1

        @passive
        def monitor():
            for _ in range(8):
                if (yield dut.m_axis_tvalid):
                    beats.append((yield dut.m_axis_tdata))
                yield

        def stim():
            yield dut.m_axis_tready.eq(1)
            yield
            yield dut.s_axis_tvalid.eq(1)
            yield dut.s_axis_tlast.eq(1)
            yield dut.s_axis_tdata.eq(data)
            yield dut.s_axis_tkeep.eq(keep)
            yield dut.s_axis_tuser.eq(tuser)
            yield
            yield dut.s_axis_tvalid.eq(0)
            yield

        run_simulation(dut, [stim(), monitor()], vcd_name=None)
        self.assertGreaterEqual(len(beats), 1)
        return beats[0]

    def test_poison_ecrc_matrix_all_widths(self):
        for data_width in [128, 256, 512]:
            for poison_data in [0, 1]:
                for td_data in [0, 1]:
                    for td_user in [0, 1]:
                        out_data = self._run_poison_ecrc_matrix_case(
                            data_width=data_width,
                            poison_data=poison_data,
                            td_data=td_data,
                            td_user=td_user,
                        )
                        expected_poison = poison_data
                        expected_td = td_data | td_user
                        self.assertEqual((out_data >> 45) & 0x1, expected_poison)
                        self.assertEqual((out_data >> 95) & 0x1, expected_td)
