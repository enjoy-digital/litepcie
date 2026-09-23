#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Enjoy-Digital <enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import sys
import json
import random
import subprocess

from pathlib import Path

import pytest

from migen import *

from litepcie.frontend.ptm.core import PTMExtendedCapability
from litepcie.phy.axis_adapters import SAxisRQAdapter


@pytest.mark.parametrize('base,limit', [(0x120, 0x140), (0x3a0, 0x400)])
def test_native_capability(base, limit):
    dut = PTMExtendedCapability(base, limit)
    bus = dut.bus

    def access(address, *, write=None, be=15, function=0):
        yield bus.register_number.eq(address)
        yield bus.function_number.eq(function)
        yield bus.read_received.eq(write is None)
        yield bus.write_received.eq(write is not None)
        yield bus.write_data.eq(write or 0)
        yield bus.write_byte_enable.eq(be)
        yield
        yield bus.read_received.eq(0)
        yield bus.write_received.eq(0)
        yield

    def check_read(address, expected, function=0, valid=1):
        yield from access(address, function=function)
        assert (yield bus.read_data_valid) == valid
        if valid:
            assert (yield bus.read_data) == expected
        yield
        assert (yield bus.read_data_valid) == 0

    def run():
        yield from check_read(base, 0x1001f)
        yield from check_read(base+1, 0x801)
        yield from access(base, write=0xffffffff)
        yield from access(base+1, write=0xffffffff)
        yield from check_read(base, 0x1001f)
        yield from check_read(base+1, 0x801)
        yield from access(base+2, write=0xffffffff, be=1)
        yield from check_read(base+2, 1)
        yield from access(base+2, write=0x1234, be=2)
        yield from check_read(base+2, 0x1201)
        yield from access(base+2, write=0, be=12)
        yield from access(base+2, write=0, function=1)
        yield from check_read(base+2, 0x1201)
        yield from check_read(base+3, 0)
        yield from check_read(limit-1, 0)
        yield from check_read(limit, 0, valid=0)
        yield from check_read(base-1, 0, valid=0)
        yield from check_read(base, 0, function=1, valid=0)
    run_simulation(dut, run())


def transmit(dut, beats, seed=41):
    outputs = []
    rng = random.Random(seed)

    @passive
    def ready():
        while True:
            yield dut.m_axis_tready.eq(rng.randrange(3) != 0)
            yield

    @passive
    def monitor():
        while True:
            if (yield dut.m_axis_tvalid) and (yield dut.m_axis_tready):
                outputs.append(((yield dut.m_axis_tdata), (yield dut.m_axis_tkeep),
                    (yield dut.m_axis_tlast), (yield dut.m_axis_tuser)))
            yield

    def drive():
        for data, keep, last in beats:
            yield dut.s_axis_tdata.eq(data)
            yield dut.s_axis_tkeep.eq(keep)
            yield dut.s_axis_tlast.eq(last)
            yield dut.s_axis_tvalid.eq(1)
            yield
            while not (yield dut.s_axis_tready):
                yield
        yield dut.s_axis_tvalid.eq(0)
        for _ in range(20):
            yield
    run_simulation(dut, [drive(), ready(), monitor()])
    # Bytes outside tkeep and BE on continuation beats are unspecified.
    normalized = []
    first = True
    for data, keep, last, user in outputs:
        mask = sum(0xffffffff << (32*i) for i in range(len(dut.m_axis_tkeep)) if keep & (1 << i))
        normalized.append((data & mask, keep, last, user if first else 0))
        first = bool(last)
    return normalized


@pytest.mark.parametrize('width', [128, 256, 512])
def test_native_ptm_request_and_dma_interleave(width):
    # Literal PCIe Request header -> independently specified PG213 descriptor.
    request = (0x34 << 24) | (0x52 << 32) | (0x1234 << 48)
    expected = (0xc << 75) | (0x1234 << 80) | (0x52 << 104) | (4 << 112)
    user = (1 << 20) | (1 << 26) | (3 << 28) if width == 512 else 0
    request_beat = (request, 0xffff, 1)
    assert transmit(SAxisRQAdapter(width, with_ptm=True), [request_beat]*5) == [(expected, 15, 1, user)]*5

    # 3-DW write forces a trailing beat at 128 bits and exercises the held
    # packet state. A PTM-looking payload must not become a Message.
    length = width//32-3
    write = (0x40 << 24) | length | (0xff << 32) | (0x4000 << 64)
    write |= 0xaabbccdd << (width-32)
    reads = [(1 | (0xf << 32) | (0x5000 << 64), 0xfff, 1)]
    dma = [(write, (1 << (width//8))-1, 1)] + reads
    baseline = transmit(SAxisRQAdapter(width), dma)
    actual = transmit(SAxisRQAdapter(width, with_ptm=True), dma[:1] + [request_beat] + dma[1:])
    assert [beat for beat in actual if beat[0] != expected] == baseline
    assert sum(beat[0] == expected for beat in actual) == 1

    dma = [(write, (1 << (width//8))-1, 0), (request, (1 << (width//8))-1, 1)]
    assert transmit(SAxisRQAdapter(width, with_ptm=True), dma) == transmit(SAxisRQAdapter(width), dma)


@pytest.mark.parametrize('phy,device,lanes', [
    ('S7PCIEPHY', 'xc7k325tffg900-2', 4),
    ('USPPCIEPHY', 'xcau15p-ffvb676-2-i', 8),
])
def test_standalone_wide_ptm_generator(tmp_path, phy, device, lanes):
    config = dict(phy=phy, phy_device=device, phy_lanes=lanes,
        phy_pcie_data_width=128 if phy == 'S7PCIEPHY' else 256,
        phy_data_width=128 if phy == 'S7PCIEPHY' else 256,
        phy_bar0_size=0x40000, phy_speed='gen2', clk_freq=125000000,
        dma_channels=1, msi_irqs=1, ptm=True)
    if phy == 'S7PCIEPHY':
        config.pop('phy_speed')
    config_path = tmp_path/'ptm.yml'
    config_path.write_text(json.dumps(config))
    result = subprocess.run([sys.executable, '-m', 'litepcie.gen', str(config_path),
        '--output-dir', str(tmp_path/'build'), '--header-dir', str(tmp_path)],
        cwd=Path(__file__).resolve().parents[1], capture_output=True, text=True)
    assert result.returncode == 0, result.stdout + result.stderr
    tcl = (tmp_path/'build/gateware/litepcie_core.tcl').read_text()
    rtl = (tmp_path/'build/gateware/litepcie_core.v').read_text()
    assert 'pcie_ptm_pipe_tap' in rtl
    assert 'CSR_PTM_REQUESTER_CONTROL_ADDR' in (tmp_path/'csr.h').read_text()
    if phy == 'S7PCIEPHY':
        assert 'gt_rx_data_wire_filter[111]' in tcl
    else:
        assert 'CONFIG.ext_pcie_cfg_space_enabled {True}' in tcl
        assert 'CONFIG.PL_DISABLE_LANE_REVERSAL {True}' in tcl
        assert 'CONFIG.PL_LINK_CAP_MAX_LINK_SPEED {5.0_GT/s}' in tcl
        assert 'PIPERX07DATA[15]' in tcl
        import re
        assert re.search(r'\.cfg_ext_read_data\s*\(', rtl)
        for speed in ('gen3', 'gen4'):
            config['phy_speed'] = speed
            config_path.write_text(json.dumps(config))
            result = subprocess.run([sys.executable, '-m', 'litepcie.gen', str(config_path),
                '--output-dir', str(tmp_path/speed), '--header-dir', str(tmp_path)],
                cwd=Path(__file__).resolve().parents[1], capture_output=True, text=True)
            assert result.returncode == 0, result.stdout + result.stderr
            tcl = (tmp_path/speed/'gateware/litepcie_core.tcl').read_text()
            assert 'PIPERX07DATA[31]' in tcl
            if speed == 'gen4':
                assert 'PIPERX15DATA[31]' in tcl
