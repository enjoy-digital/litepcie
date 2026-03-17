#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Enjoy-Digital <enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import unittest

from migen import Module, Signal
from litex.gen.sim import run_simulation

from litepcie.phy.xilinx_tuser import cq_tuser_full_to_raw_expr, rc_tuser_full_to_raw_expr


class _RCMappingDUT(Module):
    def __init__(self, pcie_data_width):
        full_width = 161 if pcie_data_width == 512 else 75
        self.full = Signal(full_width)
        self.raw = Signal(85)
        self.comb += self.raw.eq(rc_tuser_full_to_raw_expr(self.full, pcie_data_width))


class _CQMappingDUT(Module):
    def __init__(self, pcie_data_width):
        full_width = 183 if pcie_data_width == 512 else 88
        self.full = Signal(full_width)
        self.raw = Signal(256)
        self.comb += self.raw.eq(cq_tuser_full_to_raw_expr(self.full, pcie_data_width))


def _simulate_value(dut, value):
    captured = {}

    def stim():
        yield dut.full.eq(value)
        yield
        captured["raw"] = (yield dut.raw)

    run_simulation(dut, stim(), vcd_name=None)
    return captured["raw"]


class TestXilinxTUserMapping(unittest.TestCase):
    def test_rc_128_mapping_keeps_legacy_layout(self):
        dut = _RCMappingDUT(128)
        full = (1 << 0) | (1 << 10) | (1 << 74)
        raw = _simulate_value(dut, full)
        self.assertEqual(raw & ((1 << 75) - 1), full)
        self.assertEqual(raw >> 75, 0)

    def test_rc_256_mapping_keeps_legacy_layout(self):
        dut = _RCMappingDUT(256)
        full = (1 << 0) | (1 << 10) | (1 << 74)
        raw = _simulate_value(dut, full)
        self.assertEqual(raw & ((1 << 75) - 1), full)
        self.assertEqual(raw >> 75, 0)

    def test_rc_512_mapping_keeps_only_low_keep_bits(self):
        dut = _RCMappingDUT(512)
        full = (1 << 0) | (1 << 42) | (1 << 63) | (1 << 64) | (1 << 160)
        raw = _simulate_value(dut, full)
        self.assertEqual(raw & ((1 << 64) - 1), full & ((1 << 64) - 1))
        self.assertEqual(raw >> 64, 0)

    def test_cq_256_mapping_keeps_legacy_layout(self):
        dut = _CQMappingDUT(256)
        full = (1 << 0) | (1 << 15) | (1 << 87)
        raw = _simulate_value(dut, full)
        self.assertEqual(raw & ((1 << 88) - 1), full)
        self.assertEqual(raw >> 88, 0)

    def test_cq_128_mapping_keeps_legacy_layout(self):
        dut = _CQMappingDUT(128)
        full = (1 << 0) | (1 << 15) | (1 << 87)
        raw = _simulate_value(dut, full)
        self.assertEqual(raw & ((1 << 88) - 1), full)
        self.assertEqual(raw >> 88, 0)

    def test_cq_512_mapping_preserves_sparse_bits(self):
        dut = _CQMappingDUT(512)
        full = (
            (1 << 0) |
            (1 << 79) |
            (1 << 80) |
            (1 << 95) |
            (1 << 96) |
            (1 << 97) |
            (1 << 182)
        )
        raw = _simulate_value(dut, full)
        self.assertEqual(raw & ((1 << 80) - 1), full & ((1 << 80) - 1))
        self.assertEqual((raw >> 96) & 0x1, 1)
        self.assertEqual((raw >> 80) & 0xffff, 0)
        self.assertEqual((raw >> 97), 0)
