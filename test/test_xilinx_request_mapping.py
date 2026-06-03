#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Enjoy-Digital <enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import unittest

from litex.gen import *
from litex.soc.interconnect import stream

from litepcie.phy.axis_adapters import SAxisCCAdapter, SAxisRQAdapter
from test.test_s_axis_rq_adapter import _rq_256_first_beat_data, _rq_256_first_beat_keep, _rq_header
from test.test_s_axis_cc_adapter import _header_words


class _DirectRQDUT(LiteXModule):
    def __init__(self, pcie_data_width):
        rq_tuser_width = 137 if pcie_data_width == 512 else 60

        self.s_axis_rq = stream.Endpoint([("dat", pcie_data_width), ("be", pcie_data_width//8)])
        self.s_axis_rq_tdata_raw  = Signal(pcie_data_width)
        self.s_axis_rq_tkeep_raw  = Signal(pcie_data_width//32)
        self.s_axis_rq_tuser_raw  = Signal(rq_tuser_width)
        self.s_axis_rq_tlast_raw  = Signal()
        self.s_axis_rq_tvalid_raw = Signal()
        self.s_axis_rq_tready_raw = Signal(4)

        self.submodules.s_axis_rq_adapt = s_axis_rq_adapt = SAxisRQAdapter(pcie_data_width)
        self.comb += [
            s_axis_rq_adapt.s_axis_tdata.eq(self.s_axis_rq.dat),
            s_axis_rq_adapt.s_axis_tkeep.eq(self.s_axis_rq.be),
            s_axis_rq_adapt.s_axis_tlast.eq(self.s_axis_rq.last),
            s_axis_rq_adapt.s_axis_tuser.eq(Constant(0b0000)),
            s_axis_rq_adapt.s_axis_tvalid.eq(self.s_axis_rq.valid),
            self.s_axis_rq.ready.eq(s_axis_rq_adapt.s_axis_tready),

            self.s_axis_rq_tdata_raw.eq(s_axis_rq_adapt.m_axis_tdata),
            self.s_axis_rq_tkeep_raw.eq(s_axis_rq_adapt.m_axis_tkeep),
            self.s_axis_rq_tlast_raw.eq(s_axis_rq_adapt.m_axis_tlast),
            self.s_axis_rq_tuser_raw.eq(s_axis_rq_adapt.m_axis_tuser),
            self.s_axis_rq_tvalid_raw.eq(s_axis_rq_adapt.m_axis_tvalid),
            s_axis_rq_adapt.m_axis_tready.eq(self.s_axis_rq_tready_raw[0]),
        ]


class _DirectCCDUT(LiteXModule):
    def __init__(self, pcie_data_width):
        self.s_axis_cc = stream.Endpoint([("dat", pcie_data_width), ("be", pcie_data_width//8)])
        self.s_axis_cc_tdata_raw  = Signal(pcie_data_width)
        self.s_axis_cc_tkeep_raw  = Signal(pcie_data_width//32)
        self.s_axis_cc_tuser_raw  = Signal(33)
        self.s_axis_cc_tlast_raw  = Signal()
        self.s_axis_cc_tvalid_raw = Signal()
        self.s_axis_cc_tready_raw = Signal(4)

        self.submodules.s_axis_cc_adapt = s_axis_cc_adapt = SAxisCCAdapter(pcie_data_width)
        self.comb += [
            s_axis_cc_adapt.s_axis_tdata.eq(self.s_axis_cc.dat),
            s_axis_cc_adapt.s_axis_tkeep.eq(self.s_axis_cc.be),
            s_axis_cc_adapt.s_axis_tlast.eq(self.s_axis_cc.last),
            s_axis_cc_adapt.s_axis_tuser.eq(Constant(0b0000)),
            s_axis_cc_adapt.s_axis_tvalid.eq(self.s_axis_cc.valid),
            self.s_axis_cc.ready.eq(s_axis_cc_adapt.s_axis_tready),

            self.s_axis_cc_tdata_raw.eq(s_axis_cc_adapt.m_axis_tdata),
            self.s_axis_cc_tkeep_raw.eq(s_axis_cc_adapt.m_axis_tkeep),
            self.s_axis_cc_tlast_raw.eq(s_axis_cc_adapt.m_axis_tlast),
            self.s_axis_cc_tuser_raw.eq(s_axis_cc_adapt.m_axis_tuser),
            self.s_axis_cc_tvalid_raw.eq(s_axis_cc_adapt.m_axis_tvalid),
            s_axis_cc_adapt.m_axis_tready.eq(self.s_axis_cc_tready_raw[0]),
        ]


def _run_direct_request_once(dut, endpoint_name, data, be):
    out = {}
    endpoint = getattr(dut, endpoint_name)

    def stim():
        yield getattr(dut, f"{endpoint_name}_tready_raw").eq(0b1111)
        yield
        yield endpoint.valid.eq(1)
        yield endpoint.last.eq(1)
        yield endpoint.dat.eq(data)
        yield endpoint.be.eq(be)
        yield
        out["data"] = (yield getattr(dut, f"{endpoint_name}_tdata_raw"))
        out["keep"] = (yield getattr(dut, f"{endpoint_name}_tkeep_raw"))
        out["user"] = (yield getattr(dut, f"{endpoint_name}_tuser_raw"))
        out["last"] = (yield getattr(dut, f"{endpoint_name}_tlast_raw"))
        out["valid"] = (yield getattr(dut, f"{endpoint_name}_tvalid_raw"))
        yield endpoint.valid.eq(0)
        yield

    run_simulation(dut, stim(), vcd_name=None)
    return out


class TestXilinxRequestMapping(unittest.TestCase):
    @staticmethod
    def _expected_cc_keep(data_width, keep):
        if data_width == 128:
            return sum(((1 if ((keep >> (4*i)) & 0xF) else 0) << i) for i in range(4))
        if data_width == 256:
            return sum(((1 if ((keep >> (4*i)) & 0xF) else 0) << i) for i in range(8))
        return sum((((keep >> (4*i)) & 0x1) << i) for i in range(16))

    def test_direct_rq_mapping_256bit(self):
        for is_4dw in [False, True]:
            with self.subTest(is_4dw=is_4dw):
                data = int("112233445566778899aabbccddeeff00" * 2, 16)
                data &= ~0x3FF
                data &= ~(1 << 29)
                data |= 0x055
                data |= int(is_4dw) << 29
                be   = (1 << 32) - 1
                dut  = _DirectRQDUT(256)
                out  = _run_direct_request_once(dut, "s_axis_rq", data, be)

                self.assertEqual(len(dut.s_axis_rq_tuser_raw), 60)
                self.assertEqual(out["data"], _rq_256_first_beat_data(data, 0))
                self.assertEqual(out["keep"], _rq_256_first_beat_keep(data, be))
                self.assertEqual(out["last"], 1)
                self.assertEqual(out["valid"], 1)

    def test_direct_rq_mapping_512bit(self):
        data = int("00112233445566778899aabbccddeeff" * 4, 16)
        data &= ~(0x3 << 30)
        data &= ~0x3FF
        data |= 0x005
        be   = (1 << 64) - 1
        dut  = _DirectRQDUT(512)
        out  = _run_direct_request_once(dut, "s_axis_rq", data, be)

        self.assertEqual(len(dut.s_axis_rq_tuser_raw), 137)
        self.assertEqual((out["data"] >> 64) & ((1 << 64) - 1), _rq_header(data, 0))
        self.assertEqual(out["keep"], 0xFFFF)
        self.assertEqual(out["last"], 1)
        self.assertEqual(out["valid"], 1)
        self.assertEqual(out["user"] & 0xF, (data >> 32) & 0xF)
        self.assertEqual((out["user"] >> 8) & 0xF, (data >> 36) & 0xF)

    def test_direct_cc_mapping_256bit(self):
        data = int("ffeeddccbbaa99887766554433221100" * 2, 16)
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
        be   = 0x00FF_0F0F
        dut  = _DirectCCDUT(256)
        out  = _run_direct_request_once(dut, "s_axis_cc", data, be)
        header0, header1 = _header_words(data, 0)
        expected_data = ((data >> 128) << 128) | (header1 << 64) | header0

        self.assertEqual(len(dut.s_axis_cc_tuser_raw), 33)
        self.assertEqual(out["data"], expected_data)
        self.assertEqual(out["keep"], self._expected_cc_keep(256, be))
        self.assertEqual(out["last"], 1)
        self.assertEqual(out["valid"], 1)

    def test_direct_cc_mapping_512bit(self):
        data = int("ffeeddccbbaa99887766554433221100" * 4, 16)
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
        keep = int("1111000011110000", 2)
        be   = sum((((keep >> i) & 0x1) << (4*i)) for i in range(16))
        dut  = _DirectCCDUT(512)
        out  = _run_direct_request_once(dut, "s_axis_cc", data, be)
        header0, header1 = _header_words(data, 0)
        expected_data = ((data >> 128) << 128) | (header1 << 64) | header0

        self.assertEqual(len(dut.s_axis_cc_tuser_raw), 33)
        self.assertEqual(out["data"], expected_data)
        self.assertEqual(out["keep"], self._expected_cc_keep(512, be))
        self.assertEqual(out["last"], 1)
        self.assertEqual(out["valid"], 1)
