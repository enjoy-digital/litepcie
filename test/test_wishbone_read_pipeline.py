#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Enjoy-Digital <enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Check the emitted bridge RTL against read/byte-enable transaction semantics."""

import shutil
import subprocess

from types import SimpleNamespace

import pytest

from migen import ClockDomain, Module

from litex.gen.fhdl import verilog
from litex.soc.interconnect import stream

from litepcie.common import request_layout, completion_layout
from litepcie.frontend.wishbone import LitePCIeWishboneMaster


@pytest.mark.parametrize('base_address', [0, 0x1000, -0x1000])
def test_registered_read_controls(tmp_path, base_address):
    if not shutil.which('iverilog') or not shutil.which('vvp'):
        pytest.skip('Icarus Verilog is required (installed in CI)')
    dut = Module()
    dut.clock_domains.cd_sys = ClockDomain('sys')
    req, cmp = stream.Endpoint(request_layout(64)), stream.Endpoint(completion_layout(64))
    endpoint = SimpleNamespace(
        phy=SimpleNamespace(id=0x400),
        crossbar=SimpleNamespace(get_slave_port=lambda decoder: SimpleNamespace(sink=req, source=cmp)),
    )
    dut.submodules.bridge = bridge = LitePCIeWishboneMaster(endpoint, base_address=base_address)
    bus = bridge.bus
    dut.comb += bus.dat_r.eq((bus.adr << 2) ^ 0xa5a50000)
    ports = dict(clk=dut.cd_sys.clk, rst=dut.cd_sys.rst)
    request_signals = (
        'valid', 'ready', 'first', 'last', 'we', 'adr', 'len', 'first_be',
        'last_be', 'tag', 'req_id', 'tc', 'attr', 'dat',
    )
    completion_signals = (
        'valid', 'ready', 'first', 'last', 'adr', 'len', 'byte_count',
        'tag', 'req_id', 'cmp_id', 'tc', 'attr', 'dat', 'err',
    )
    ports.update(('req_'+name, getattr(req, name)) for name in request_signals)
    ports.update(('cmp_'+name, getattr(cmp, name)) for name in completion_signals)
    ports.update(('wb_'+name, getattr(bus, name)) for name in
        ('adr', 'sel', 'cyc', 'stb', 'ack', 'we', 'dat_w'))
    for name, signal in ports.items():
        signal.name_override = name
    verilog.convert(dut, ios=set(ports.values()), name='bridge').write(str(tmp_path/'bridge.v'))
    request_inputs = (
        'valid', 'first', 'last', 'we', 'adr', 'len', 'first_be',
        'last_be', 'tag', 'req_id', 'tc', 'attr', 'dat',
    )
    inputs = {'clk', 'rst', 'cmp_ready', 'wb_ack'} | {'req_'+name for name in request_inputs}
    bench = '`timescale 1ns/1ps\nmodule tb;\n'
    for name, signal in ports.items():
        kind = 'reg' if name in inputs else 'wire'
        bench += f'{kind} [{len(signal)-1}:0] {name}' + ('=0' if kind == 'reg' else '') + ';\n'
    bench += '''bridge dut(.*);
always #2 clk=~clk;
integer cycle=0;
always @(negedge clk) begin
    cycle=cycle+1; wb_ack=(cycle%4 != 0); cmp_ready=(cycle%5 > 1);
end
always @(posedge clk) begin
    if(wb_cyc && wb_stb && wb_ack) $display("WB %h %h %h %h", wb_adr, wb_sel, wb_we, wb_dat_w);
    if(cmp_valid && cmp_ready) $display("CMP %h %h %h %h %h %h %h %h %h %h %h %h",
        cmp_adr, cmp_byte_count, cmp_dat, cmp_tag, cmp_req_id, cmp_cmp_id, cmp_tc, cmp_attr,
        cmp_len, cmp_first, cmp_last, cmp_err);
end
initial begin #1000000; $fatal(1, "bridge timeout"); end
initial begin
rst=1; repeat(5) @(negedge clk); rst=0; req_first=1; req_last=1;
req_req_id=16'h100; req_tc=3; req_attr=2;
'''
    expected_wb, expected_cmp = [], []
    cases = [(1, be, 6) for be in (0, 1, 8, 5, 15)] + [
        (2, 12, 3), (5, 6, 8), (1024, 15, 15),
    ]
    address_mask = (1 << len(bus.adr))-1
    for tag, (count, first_be, last_be) in enumerate(cases):
        address = 0x2000 if count == 1024 else 0x107c
        enables = [first_be] if count == 1 else [first_be] + [15]*(count-2) + [last_be]
        remaining = sum(bin(be).count('1') for be in enables) or 1
        for index, be in enumerate(enables):
            word = ((address >> 2) + (base_address >> 2) + index) & address_mask
            expected_wb.append((word, be, 0, None))
            offset = next((bit for bit in range(4) if be & (1 << bit)), 0)
            expected_cmp.append((
                address + 4*index + offset, remaining & 0xfff,
                ((word << 2) ^ 0xa5a50000) & 0xffffffff,
                tag, 0x100, 0x400, 3, 2, 1, 1, 1, 0,
            ))
            remaining -= bin(be).count('1')
        bench += f'''@(negedge clk); req_we=0; req_adr=32'h{address:x}; req_len={count & 1023};
req_first_be={first_be}; req_last_be={last_be}; req_tag={tag}; req_valid=1;
do @(posedge clk); while(!req_ready);
@(negedge clk); req_valid=0; repeat(2) @(negedge clk);
'''
        # A following write must still use the incoming address and all byte enables.
        write_address = 0x3000 + 4*tag
        expected_wb.append((
            ((write_address >> 2) + (base_address >> 2)) & address_mask,
            15, 1, 0x9abcdef0,
        ))
        bench += f'''req_we=1; req_adr=32'h{write_address:x}; req_len=1; req_dat=64'h123456789abcdef0; req_valid=1;
do @(posedge clk); while(!req_ready);
@(negedge clk); req_valid=0; repeat(2) @(negedge clk);
'''
    bench += 'repeat(10) @(negedge clk); $finish; end endmodule\n'
    (tmp_path/'tb.v').write_text(bench)
    result = subprocess.run(['iverilog', '-g2012', '-s', 'tb', '-o', 'sim', 'bridge.v', 'tb.v'],
        cwd=tmp_path, capture_output=True, text=True)
    assert result.returncode == 0, result.stdout + result.stderr
    result = subprocess.run(['vvp', 'sim'], cwd=tmp_path, capture_output=True, text=True, timeout=30)
    assert result.returncode == 0, result.stdout + result.stderr
    wb = [
        tuple(int(value, 16) for value in line.split()[1:])
        for line in result.stdout.splitlines() if line.startswith('WB ')
    ]
    wb = [(adr, be, we, data if we else None) for adr, be, we, data in wb]
    cmps = [
        tuple(int(value, 16) for value in line.split()[1:])
        for line in result.stdout.splitlines() if line.startswith('CMP ')
    ]
    assert wb == expected_wb
    assert cmps == expected_cmp
