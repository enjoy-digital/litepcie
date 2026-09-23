# Copyright (c) 2026 Enjoy-Digital <enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
"""Exercise emitted Verilog, including self-sized shift operands, in Icarus."""
import shutil
import subprocess
import pytest
from migen import Module, ClockDomain
from litex.gen.fhdl import verilog
from litepcie.frontend.ptm.pipe import PCIePTM8b10bReceiver, COM, END
from test.test_ptm_pipe import scramble_symbols, response


@pytest.mark.parametrize('width,reverse', [(1, 0), (2, 0), (4, 0), (4, 1), (8, 0)])
def test_generated_receiver_decodes_ptm(tmp_path, width, reverse):
    if not shutil.which('iverilog') or not shutil.which('vvp'):
        pytest.skip('Icarus Verilog is required (installed in CI)')
    dut = Module()
    dut.clock_domains.cd_sys = ClockDomain('sys')
    dut.submodules.receiver = receiver = PCIePTM8b10bReceiver(width)
    ports = dict(clk=dut.cd_sys.clk, rst=dut.cd_sys.rst,
        valid=receiver.valid, link_up=receiver.link_up, lanes=receiver.lanes,
        reverse=receiver.reverse, data=receiver.data, ctrl=receiver.ctrl,
        lane_valid=receiver.lane_valid, out_valid=receiver.source.valid,
        out_ready=receiver.source.ready, out_time=receiver.source.master_time,
        out_delay=receiver.source.link_delay)
    for name, signal in ports.items():
        signal.name_override = name
    verilog.convert(dut, ios=set(ports.values()), name='ptm_receiver').write(str(tmp_path/'receiver.v'))
    expected, wire = [], [(0, 0)]*(8*width)
    for alignment in range(2*width):
        wire += [(0, 0)]*(3*width+alignment)
        timestamp, delay = 0x1020304050607080+alignment, 0x12345678+alignment
        wire += response(timestamp, delay)
        expected.append((timestamp, delay))
        wire += response(0, 0, with_data=False)
        expected.append((0, 0))
        wire += response(timestamp, delay, bad=True)
        wire += response(timestamp, delay)[:19] + [(END, 1)] + [(0, 0)]*20
    wire += [(0, 0)]*(100*width)
    lane_symbols = [scramble_symbols([(COM, 1)] + wire[i::width] + [(0, 0)]) for i in range(width)]
    if reverse:
        lane_symbols.reverse()
    bench = f'''`timescale 1ns/1ps
module tb;
reg clk=0; always #2 clk=~clk;
reg rst=1, valid=0, link_up=0, reverse={reverse};
reg [{len(receiver.lanes)-1}:0] lanes={width};
reg [{width-1}:0] lane_valid={(1 << width)-1};
reg [{16*width-1}:0] data=0;
reg [{2*width-1}:0] ctrl=0;
wire out_valid; reg out_ready=1;
wire [63:0] out_time; wire [31:0] out_delay;
integer cycle=0;
ptm_receiver dut(.*);
always @(posedge clk) begin
    if(out_valid && out_ready) $display("RESPONSE %h %h", out_time, out_delay);
end
always @(negedge clk) begin
    cycle=cycle+1; out_ready=(cycle % 7 > 1);
end
initial begin
repeat(5) @(negedge clk);
rst=0; link_up=1;
repeat(5) @(negedge clk);
valid=1;
'''
    for offset in range(0, min(map(len, lane_symbols))-1, 2):
        data = sum(lane_symbols[i][offset+j][0] << (16*i+8*j) for i in range(width) for j in range(2))
        ctrl = sum(lane_symbols[i][offset+j][1] << (2*i+j) for i in range(width) for j in range(2))
        bench += f"data={16*width}'h{data:x}; ctrl={2*width}'h{ctrl:x}; @(negedge clk);\n"
    bench += 'valid=0; repeat(40) @(negedge clk); $finish; end\nendmodule\n'
    (tmp_path/'tb.v').write_text(bench)
    compiled = subprocess.run(['iverilog', '-g2012', '-s', 'tb', '-o', 'sim', 'receiver.v', 'tb.v'],
        cwd=tmp_path, capture_output=True, text=True)
    assert compiled.returncode == 0, compiled.stdout + compiled.stderr
    result = subprocess.run(['vvp', 'sim'], cwd=tmp_path, capture_output=True, text=True, timeout=30)
    assert result.returncode == 0, result.stdout + result.stderr
    actual = [tuple(int(value, 16) for value in line.split()[1:])
        for line in result.stdout.splitlines() if line.startswith('RESPONSE ')]
    assert actual == expected
