# Copyright (c) 2026 Enjoy-Digital <enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
"""Check compaction and parity-bank wraparound against an independent queue."""
import random
import shutil
import subprocess
import pytest
from migen import Module, ClockDomain
from litex.gen.fhdl import verilog
from litepcie.frontend.ptm.pipe import PCIeLaneSymbolBuffer, SKP


def test_lane_buffer_generated_verilog(tmp_path):
    if not shutil.which('iverilog') or not shutil.which('vvp'):
        pytest.skip('Icarus Verilog is required (installed in CI)')
    dut = Module()
    dut.clock_domains.cd_sys = ClockDomain('sys')
    dut.submodules.buffer = buffer = PCIeLaneSymbolBuffer()
    ports = dict(clk=dut.cd_sys.clk, rst=dut.cd_sys.rst, valid=buffer.valid,
        data=buffer.data, ctrl=buffer.ctrl, pop=buffer.pop,
        discard_first=buffer.discard_first, level=buffer.level,
        overflow=buffer.overflow, head0=buffer.head[0], head1=buffer.head[1])
    for name, signal in ports.items():
        signal.name_override = name
    verilog.convert(dut, ios=set(ports.values()), name='lane_buffer').write(str(tmp_path/'buffer.v'))
    bench = '''`timescale 1ns/1ps
module tb;
reg clk=0; always #2 clk=~clk;
reg rst=1, valid=0, discard_first=0;
reg [15:0] data=0; reg [1:0] ctrl=0, pop=0;
wire [4:0] level; wire overflow; wire [8:0] head0, head1;
lane_buffer dut(.*);
initial begin
repeat(5) @(negedge clk); rst=0;
'''
    rng, queue = random.Random(155), []
    for cycle in range(1500):
        symbols = [(rng.randrange(256), rng.randrange(2)) for _ in range(2)]
        for i in range(2):
            if rng.randrange(4) == 0:
                symbols[i] = (SKP, 1)
        valid, discard = rng.randrange(4) != 0, rng.randrange(5) == 0
        pop = rng.randrange(min(2, len(queue))+1)
        kept = [(value | (ctrl << 8)) for i, (value, ctrl) in enumerate(symbols)
            if valid and not (i == 0 and discard) and (value, ctrl) != (SKP, 1)]
        overflow = len(queue)+len(kept) > 16
        data = symbols[0][0] | (symbols[1][0] << 8)
        ctrl = symbols[0][1] | (symbols[1][1] << 1)
        bench += f'@(negedge clk); valid={int(valid)}; discard_first={int(discard)}; pop={pop}; data=16\'h{data:x}; ctrl={ctrl}; #1;\n'
        bench += f'if(overflow !== 1\'b{int(overflow)}) $fatal(1, "overflow cycle {cycle}");\n'
        if not overflow:
            queue = queue[pop:]+kept
        bench += '@(posedge clk); #1;\n'
        bench += f'if(level !== 5\'d{len(queue)}) $fatal(1, "level cycle {cycle}");\n'
        for i, value in enumerate(queue[:2]):
            bench += f'if(head{i} !== 9\'h{value:x}) $fatal(1, "head{i} cycle {cycle}");\n'
    bench += '$display("PASS"); $finish; end endmodule\n'
    (tmp_path/'tb.v').write_text(bench)
    result = subprocess.run(['iverilog', '-g2012', '-s', 'tb', '-o', 'sim', 'buffer.v', 'tb.v'],
        cwd=tmp_path, capture_output=True, text=True)
    assert result.returncode == 0, result.stdout+result.stderr
    result = subprocess.run(['vvp', 'sim'], cwd=tmp_path, capture_output=True, text=True, timeout=30)
    assert result.returncode == 0 and 'PASS' in result.stdout, result.stdout+result.stderr
