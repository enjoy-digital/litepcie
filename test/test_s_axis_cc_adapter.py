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
