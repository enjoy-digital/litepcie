#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Enjoy-Digital <enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import unittest

from litex.gen import *

from litepcie.phy.xilinx.axis_adapters import SAxisRQAdapter


def _rq_header(data, tuser):
    dwlen = data & 0x3FF
    req_class = (((data >> 30) & 0x3) << 5) | ((data >> 24) & 0x1F)
    if req_class == 0b0000000:
        reqtype = 0b0000
    elif req_class == 0b0000001:
        reqtype = 0b0111
    elif req_class == 0b0100000:
        reqtype = 0b0001
    elif ((data >> 24) & 0xFF) == 0b00000010:
        reqtype = 0b0010
    elif ((data >> 24) & 0xFF) == 0b01000010:
        reqtype = 0b0011
    elif ((data >> 24) & 0xFF) == 0b00000100:
        reqtype = 0b1000
    elif ((data >> 24) & 0xFF) == 0b01000100:
        reqtype = 0b1010
    elif ((data >> 24) & 0xFF) == 0b00000101:
        reqtype = 0b1001
    elif ((data >> 24) & 0xFF) == 0b01000101:
        reqtype = 0b1011
    else:
        reqtype = 0b1111

    poisoning = ((data >> 14) & 1) | ((tuser >> 1) & 1)
    requesterid = (data >> 48) & 0xFFFF
    tag = (data >> 40) & 0xFF
    tc = (data >> 20) & 0x7
    attr = (data >> 12) & 0x3
    ecrc = ((data >> 15) & 1) | (tuser & 1)

    header = 0
    header |= dwlen
    header |= reqtype << 11
    header |= poisoning << 15
    header |= requesterid << 16
    header |= tag << 32
    header |= tc << 57
    header |= attr << 60
    header |= ecrc << 63
    return header


class TestSAxisRQAdapter(unittest.TestCase):
    def test_128_read_single_beat(self):
        dut = SAxisRQAdapter(128)
        data = 0x0123456789ABCDEFFEDCBA9876543210
        data &= ~(0x3 << 30)  # read
        data &= ~0x3FF
        data |= 0x010  # dwlen
        tuser = 0b1000

        beats = []

        @passive
        def monitor():
            for _ in range(8):
                if (yield dut.m_axis_tvalid):
                    beats.append(((yield dut.m_axis_tdata), (yield dut.m_axis_tkeep), (yield dut.m_axis_tlast), (yield dut.m_axis_tuser)))
                yield

        def stim():
            yield dut.m_axis_tready.eq(1)
            yield
            yield dut.s_axis_tvalid.eq(1)
            yield dut.s_axis_tlast.eq(1)
            yield dut.s_axis_tdata.eq(data)
            yield dut.s_axis_tkeep.eq(0xFFFF)
            yield dut.s_axis_tuser.eq(tuser)
            yield
            yield dut.s_axis_tvalid.eq(0)
            yield

        run_simulation(dut, [stim(), monitor()], vcd_name=None)
        self.assertEqual(len(beats), 1)
        out_data, out_keep, out_last, out_user = beats[0]
        expected_data = ((data >> 64) & 0xFFFFFFFF)
        expected_data |= _rq_header(data, tuser) << 64
        self.assertEqual(out_data, expected_data)
        self.assertEqual(out_keep, 0xF)
        self.assertEqual(out_last, 1)
        self.assertEqual(out_user & 0xFF, (((data >> 36) & 0xF) << 4) | ((data >> 32) & 0xF))

    def test_128_write_single_beat_delayed_last(self):
        dut = SAxisRQAdapter(128)
        data = 0x0F1E2D3C4B5A69788796A5B4C3D2E1F1
        data &= ~(0x3 << 30)
        data |= (0x1 << 30)  # write
        data &= ~0x3
        data |= 0x1          # trigger delayed-last path

        beats = []

        @passive
        def monitor():
            for _ in range(10):
                if (yield dut.m_axis_tvalid):
                    beats.append(((yield dut.m_axis_tkeep), (yield dut.m_axis_tlast)))
                yield

        def stim():
            yield dut.m_axis_tready.eq(1)
            yield
            yield dut.s_axis_tvalid.eq(1)
            yield dut.s_axis_tlast.eq(1)
            yield dut.s_axis_tdata.eq(data)
            yield dut.s_axis_tkeep.eq(0xFFFF)
            yield dut.s_axis_tuser.eq(0)
            yield
            yield dut.s_axis_tvalid.eq(0)
            yield
            yield

        run_simulation(dut, [stim(), monitor()], vcd_name=None)
        self.assertEqual(len(beats), 2)
        self.assertEqual(beats[0], (0xF, 0))
        self.assertEqual(beats[1], (0x1, 1))

    def test_256_first_beat_rewrite(self):
        dut = SAxisRQAdapter(256)
        data = int("112233445566778899aabbccddeeff00" * 2, 16)
        data &= ~0x3FF
        data |= 0x055
        tuser = 0b1000

        beats = []

        @passive
        def monitor():
            for _ in range(6):
                if (yield dut.m_axis_tvalid):
                    beats.append(((yield dut.m_axis_tdata), (yield dut.m_axis_tkeep), (yield dut.m_axis_tlast), (yield dut.m_axis_tuser)))
                yield

        def stim():
            yield dut.m_axis_tready.eq(1)
            yield
            yield dut.s_axis_tvalid.eq(1)
            yield dut.s_axis_tlast.eq(1)
            yield dut.s_axis_tdata.eq(data)
            yield dut.s_axis_tkeep.eq((1 << 32) - 1)
            yield dut.s_axis_tuser.eq(tuser)
            yield
            yield dut.s_axis_tvalid.eq(0)
            yield

        run_simulation(dut, [stim(), monitor()], vcd_name=None)
        self.assertEqual(len(beats), 1)
        out_data, out_keep, out_last, out_user = beats[0]
        expected_data = ((data >> 128) << 128)
        expected_data |= (_rq_header(data, tuser) << 64)
        expected_data |= ((data >> 64) & 0xFFFFFFFF) << 32
        expected_data |= ((data >> 96) & 0xFFFFFFFF)
        self.assertEqual(out_data, expected_data)
        self.assertEqual(out_keep, 0xFF)
        self.assertEqual(out_last, 1)
        self.assertEqual(out_user & 0xFF, (((data >> 36) & 0xF) << 4) | ((data >> 32) & 0xF))

    def test_512_read_short_single_beat(self):
        dut = SAxisRQAdapter(512)
        data = int("00112233445566778899aabbccddeeff" * 4, 16)
        data &= ~(0x3 << 30)  # read
        data &= ~0x3FF
        data |= 0x005         # < 13, should end on first beat
        tkeep = (1 << 64) - 1

        beats = []

        @passive
        def monitor():
            for _ in range(8):
                if (yield dut.m_axis_tvalid):
                    beats.append(((yield dut.m_axis_tkeep), (yield dut.m_axis_tlast), (yield dut.m_axis_tuser)))
                yield

        def stim():
            yield dut.m_axis_tready.eq(1)
            yield
            yield dut.s_axis_tvalid.eq(1)
            yield dut.s_axis_tlast.eq(1)
            yield dut.s_axis_tdata.eq(data)
            yield dut.s_axis_tkeep.eq(tkeep)
            yield dut.s_axis_tuser.eq(0b1000)
            yield
            yield dut.s_axis_tvalid.eq(0)
            yield

        run_simulation(dut, [stim(), monitor()], vcd_name=None)
        self.assertEqual(len(beats), 1)
        out_keep, out_last, out_user = beats[0]
        self.assertEqual(out_last, 1)
        self.assertEqual(out_keep, 0xFFFF)
        self.assertEqual((out_user >> 36) & 0x1, 1)

    def test_256_be_latched_on_second_beat(self):
        dut = SAxisRQAdapter(256)
        data0 = int("00112233445566778899aabbccddeeff" * 2, 16)
        data1 = int("ffeeddccbbaa99887766554433221100" * 2, 16)

        # First beat BE values that must be reused on second beat.
        data0 &= ~((0xFF) << 32)
        data0 |= (0xA << 36) | (0x5 << 32)

        beats = []

        @passive
        def monitor():
            for _ in range(8):
                if (yield dut.m_axis_tvalid):
                    beats.append((yield dut.m_axis_tuser) & 0xFF)
                yield

        def stim():
            yield dut.m_axis_tready.eq(1)
            yield
            yield dut.s_axis_tvalid.eq(1)
            yield dut.s_axis_tlast.eq(0)
            yield dut.s_axis_tdata.eq(data0)
            yield dut.s_axis_tkeep.eq((1 << 32) - 1)
            yield dut.s_axis_tuser.eq(0)
            yield
            yield dut.s_axis_tlast.eq(1)
            yield dut.s_axis_tdata.eq(data1)
            yield
            yield dut.s_axis_tvalid.eq(0)
            yield

        run_simulation(dut, [stim(), monitor()], vcd_name=None)
        self.assertEqual(len(beats), 2)
        self.assertEqual(beats[0], 0xA5)
        self.assertEqual(beats[1], 0xA5)

    def test_512_write_dwlen_13_delayed_last(self):
        dut = SAxisRQAdapter(512)
        data = int("89abcdef01234567fedcba9876543210" * 4, 16)
        data |= (0x1 << 30)      # write
        data &= ~0x3FF
        data |= 13               # dwlen == 13 triggers delayed-last path

        beats = []

        @passive
        def monitor():
            for _ in range(10):
                if (yield dut.m_axis_tvalid):
                    beats.append(((yield dut.m_axis_tkeep), (yield dut.m_axis_tlast)))
                yield

        def stim():
            yield dut.m_axis_tready.eq(1)
            yield
            yield dut.s_axis_tvalid.eq(1)
            yield dut.s_axis_tlast.eq(1)
            yield dut.s_axis_tdata.eq(data)
            yield dut.s_axis_tkeep.eq((1 << 64) - 1)
            yield dut.s_axis_tuser.eq(0)
            yield
            yield dut.s_axis_tvalid.eq(0)
            yield
            yield

        run_simulation(dut, [stim(), monitor()], vcd_name=None)
        self.assertEqual(len(beats), 2)
        self.assertEqual(beats[0], (0xFFFF, 0))
        self.assertEqual(beats[1], (0x0001, 1))
