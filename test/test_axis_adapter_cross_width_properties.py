#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Enjoy-Digital <enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import unittest

from litex.gen import *

from litepcie.phy.axis_adapters import MAxisCQAdapter, MAxisRCAdapter, SAxisRQAdapter


def _rq_run_single(width, data, tkeep, tuser):
    dut = SAxisRQAdapter(width)
    beats = []

    @passive
    def monitor():
        for _ in range(10):
            if (yield dut.m_axis_tvalid):
                beats.append({
                    "data": (yield dut.m_axis_tdata),
                    "user": (yield dut.m_axis_tuser),
                    "last": (yield dut.m_axis_tlast),
                })
            yield

    def stim():
        yield dut.m_axis_tready.eq(1)
        yield
        yield dut.s_axis_tvalid.eq(1)
        yield dut.s_axis_tlast.eq(1)
        yield dut.s_axis_tdata.eq(data)
        yield dut.s_axis_tkeep.eq(tkeep)
        yield dut.s_axis_tuser.eq(tuser)
        yield
        yield dut.s_axis_tvalid.eq(0)
        yield

    run_simulation(dut, [stim(), monitor()], vcd_name=None)
    return beats


def _cq_run_packet(width, data0, data1, user0, user1):
    dut = MAxisCQAdapter(width)
    beats = []

    @passive
    def monitor():
        for _ in range(16):
            if (yield dut.m_axis_tvalid):
                beats.append({
                    "data": (yield dut.m_axis_tdata),
                    "user": (yield dut.m_axis_tuser),
                    "last": (yield dut.m_axis_tlast),
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
        yield dut.s_axis_tvalid.eq(1)
        yield dut.s_axis_tlast.eq(1)
        yield dut.s_axis_tdata.eq(data1)
        yield dut.s_axis_tuser.eq(user1)
        yield dut.s_axis_tkeep.eq(0)
        yield
        yield dut.s_axis_tvalid.eq(0)
        yield

    run_simulation(dut, [stim(), monitor()], vcd_name=None)
    return beats


def _rc_run_packet(width, data0, data1, user0, user1):
    dut = MAxisRCAdapter(width)
    beats = []

    @passive
    def monitor():
        for _ in range(16):
            if (yield dut.m_axis_tvalid):
                beats.append({
                    "data": (yield dut.m_axis_tdata),
                    "user": (yield dut.m_axis_tuser),
                    "last": (yield dut.m_axis_tlast),
                    "sop": (yield dut.m_axis_sop),
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
        yield dut.s_axis_tvalid.eq(1)
        yield dut.s_axis_tlast.eq(1)
        yield dut.s_axis_tdata.eq(data1)
        yield dut.s_axis_tuser.eq(user1)
        yield dut.s_axis_tkeep.eq(0)
        yield
        yield dut.s_axis_tvalid.eq(0)
        yield

    run_simulation(dut, [stim(), monitor()], vcd_name=None)
    return beats


def _decode_cq_reqtype(fmt, typ):
    inv = {
        (0b000, 0b00000): 0b0000,
        (0b000, 0b00001): 0b0111,
        (0b010, 0b00000): 0b0001,
        (0b000, 0b00010): 0b0010,
        (0b010, 0b00010): 0b0011,
        (0b000, 0b00100): 0b1000,
        (0b010, 0b00100): 0b1010,
        (0b000, 0b00101): 0b1001,
        (0b010, 0b00101): 0b1011,
    }
    return inv[(fmt, typ)]


class TestAxisAdapterCrossWidthProperties(unittest.TestCase):
    def test_s_axis_rq_cross_width_invariants(self):
        # One logical memory-read request payload, same intent across widths.
        firstbe = 0x5
        lastbe = 0xA
        tuser = 0b0011  # ecrc/poison sideband contributions.

        ref = None
        for width in [128, 256, 512]:
            data = int("0123456789abcdeffedcba9876543210" * (width // 128), 16)
            data &= ~0x3FF
            data |= 0x11
            data &= ~(0xFF << 24)  # reqtype class -> mem read (0000)
            data &= ~((0xFF) << 32)
            data |= (firstbe << 32) | (lastbe << 36)
            tkeep = (1 << (width // 8)) - 1

            out = _rq_run_single(width=width, data=data, tkeep=tkeep, tuser=tuser)
            self.assertGreaterEqual(len(out), 1)
            self.assertEqual(out[0]["last"], 1)

            header = (out[0]["data"] >> 64) & ((1 << 64) - 1)
            reqtype = (header >> 11) & 0xF

            if width in [128, 256]:
                out_firstbe = out[0]["user"] & 0xF
                out_lastbe = (out[0]["user"] >> 4) & 0xF
            else:
                out_firstbe = out[0]["user"] & 0xF
                out_lastbe = (out[0]["user"] >> 8) & 0xF

            norm = {
                "header": header,
                "reqtype": reqtype,
                "firstbe": out_firstbe,
                "lastbe": out_lastbe,
            }
            if ref is None:
                ref = norm
            self.assertEqual(norm, ref)
            self.assertEqual(reqtype, 0b0000)
            self.assertEqual(out_firstbe, firstbe)
            self.assertEqual(out_lastbe, lastbe)

    def test_m_axis_cq_cross_width_invariants(self):
        # One logical memory-write request as seen on CQ.
        reqtype_in = 0b0011
        firstbe = 0x9
        lastbe = 0x6
        be_byte = (lastbe << 4) | firstbe
        barhit_expected = (0 << 7) | (0b101 << 4) | reqtype_in

        ref = None
        for width in [128, 256, 512]:
            data0 = int("00112233445566778899aabbccddeeff" * (width // 128), 16)
            data1 = int("ffeeddccbbaa99887766554433221100" * (width // 128), 16)

            hdr = 0
            hdr |= 0x2A              # dwlen
            hdr |= 0b01 << 60        # attr
            hdr |= 0b101 << 57       # tc
            hdr |= 0xAB << 32        # tag
            hdr |= 0xCDEF << 16      # requesterid
            hdr |= reqtype_in << 11  # reqtype
            hdr |= 0b101 << 48       # bar
            data0 &= ~(((1 << 64) - 1) << 64)
            data0 |= hdr << 64

            if width == 512:
                user0 = (firstbe & 0xF) | ((lastbe & 0xF) << 8)
                user1 = 1 << 96
            else:
                user0 = be_byte
                user1 = 1 << 41

            out = _cq_run_packet(width=width, data0=data0, data1=data1, user0=user0, user1=user1)
            self.assertGreaterEqual(len(out), 1)

            header = out[0]["data"] & ((1 << 64) - 1)
            fmt = (header >> 29) & 0x7
            typ = (header >> 24) & 0x1F
            reqtype = _decode_cq_reqtype(fmt, typ)
            be = (header >> 32) & 0xFF
            barhit = (out[0]["user"] >> 2) & 0xFF

            norm = {
                "header": header,
                "reqtype": reqtype,
                "barhit": barhit,
                "firstbe": be & 0xF,
                "lastbe": (be >> 4) & 0xF,
            }
            if ref is None:
                ref = norm
            self.assertEqual(norm, ref)
            self.assertEqual(reqtype, reqtype_in)
            self.assertEqual(barhit, barhit_expected)
            self.assertEqual(be, be_byte)

    def test_m_axis_rc_cross_width_invariants(self):
        # One logical RC completion packet over two beats.
        # Keep bytecnt!=0 and bcm=0 so fmt/type are deterministic.
        ecrc = 1
        poison = 1

        ref = None
        for width in [128, 256, 512]:
            data0 = int("123456789abcdef0fedcba9876543210" * (width // 128), 16)
            data1 = int("0f1e2d3c4b5a69788796a5b4c3d2e1f0" * (width // 128), 16)
            user0 = (ecrc << 42) & ((1 << 85) - 1)
            user1 = 0  # second-beat ECRC source.

            # Program RC header source fields (in incoming RC stream layout).
            data0 &= ~((0x3FF) << 32)
            data0 |= 0x155 << 32      # dwlen
            data0 &= ~((0x3) << 92)
            data0 |= 0b10 << 92       # attr
            data0 &= ~((0x7) << 89)
            data0 |= 0b101 << 89      # tc
            data0 &= ~((0xFFF) << 16)
            data0 |= 0x2A5 << 16      # bytecnt
            data0 &= ~((0x7) << 43)
            data0 |= 0b011 << 43      # cmpstatus
            data0 &= ~((0xFFFF) << 72)
            data0 |= 0x4567 << 72     # completerid
            data0 &= ~((0x7F) << 0)
            data0 |= 0x35             # lowaddr
            data0 &= ~((0xFF) << 64)
            data0 |= 0xAB << 64       # tag
            data0 &= ~((0xFFFF) << 48)
            data0 |= 0xCDEF << 48     # requesterid
            data0 &= ~(1 << 29)       # bcm=0 path
            data0 &= ~(1 << 46)
            data0 |= poison << 46

            out = _rc_run_packet(width=width, data0=data0, data1=data1, user0=user0, user1=user1)
            self.assertEqual(len(out), 2)
            self.assertEqual(out[0]["sop"], 1)
            self.assertEqual(out[1]["sop"], 0)
            self.assertEqual(out[0]["last"], 0)
            self.assertEqual(out[1]["last"], 1)

            header0 = out[0]["data"] & ((1 << 64) - 1)
            header1 = (out[0]["data"] >> 64) & ((1 << 64) - 1)
            typ = (header0 >> 24) & 0x1F
            fmt = (header0 >> 29) & 0x7
            user_first = out[0]["user"] & 0x3
            user_second = out[1]["user"] & 0x3

            norm = {
                "header0": header0,
                "header1": header1,
                "fmt": fmt,
                "typ": typ,
                "user_first": user_first,
                "user_second": user_second,
            }
            if ref is None:
                ref = norm
            self.assertEqual(norm, ref)
            self.assertEqual((fmt, typ), (0b010, 0b01010))
            self.assertEqual(user_first, (ecrc << 0) | (poison << 1))
            self.assertEqual(user_second, (0 << 0) | (poison << 1))
