#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import shutil
import subprocess

import pytest
from migen import ClockDomain

from litex.gen.fhdl import verilog

from test.test_header_inserter_properties import inserter, packets, traffic_vectors


@pytest.mark.parametrize("width", [32, 64, 128, 256, 512])
def test_generated_header_inserter(tmp_path, width):
    if not shutil.which("iverilog") or not shutil.which("vvp"):
        pytest.skip("Icarus Verilog is required (installed in CI)")
    lanes = width//8
    dut = inserter(width)
    dut.clock_domains.cd_sys = ClockDomain("sys")
    ports = dict(clk=dut.cd_sys.clk, rst=dut.cd_sys.rst,
        ivalid=dut.sink.valid, iready=dut.sink.ready, ifirst=dut.sink.first, ilast=dut.sink.last,
        idata=dut.sink.dat, ibe=dut.sink.be, iheader=dut.sink.header, ifmt=dut.sink.fmt,
        ovalid=dut.source.valid, oready=dut.source.ready, ofirst=dut.source.first, olast=dut.source.last,
        odata=dut.source.dat, obe=dut.source.be)
    for name, signal in ports.items():
        signal.name_override = name
    verilog.convert(dut, ios=set(ports.values()), name="header_inserter").write(str(tmp_path/"dut.v"))

    inputs, expected = traffic_vectors(width, packets(width, 43))
    vectors = []
    for fmt, header, data, be, first, last in inputs:
        value = (((((fmt << 128) | header) << width) | data) << lanes) | be
        vectors.append(f"{(value << 2) | (first << 1) | last:x}")
    (tmp_path/"inputs.hex").write_text("\n".join(vectors) + "\n")
    vectors = []
    for chunk, be, first, last in expected:
        value = (int.from_bytes(chunk, "little") << lanes) | be
        vectors.append(f"{(value << 2) | (first << 1) | last:x}")
    (tmp_path/"expected.hex").write_text("\n".join(vectors) + "\n")

    bench = f"""`timescale 1ns/1ps
module tb;
reg clk=0; always #5 clk=~clk;
reg rst=1, ivalid=0, ifirst=0, ilast=0, oready=0;
reg [{width-1}:0] idata=0;
reg [{lanes-1}:0] ibe=0;
reg [127:0] iheader=0;
reg [1:0] ifmt=0;
wire iready, ovalid, ofirst, olast;
wire [{width-1}:0] odata;
wire [{lanes-1}:0] obe;
reg [{width+lanes+131}:0] inputs [0:{len(inputs)-1}];
reg [{width+lanes+1}:0] expected [0:{len(expected)-1}];
reg [{width+lanes+1}:0] previous;
reg pending=0, blocked=0;
reg [31:0] rng=32'h12345678;
integer sent=0, received=0, cycle=0, drained=0, lane;
header_inserter dut(.*);
initial begin
    $readmemh("inputs.hex", inputs);
    $readmemh("expected.hex", expected);
    repeat(5) @(negedge clk);
    rst=0;
end
always @(negedge clk) if(!rst) begin
    rng = {{rng[30:0], rng[31]^rng[21]^rng[1]^rng[0]}};
    oready = cycle % 97 >= 23 && rng[2:1] != 0;
    if(!pending) begin
        ivalid = sent < {len(inputs)} && rng[4:3] != 0;
        pending = ivalid;
        if(ivalid) {{ifmt, iheader, idata, ibe, ifirst, ilast}} = inputs[sent];
        else begin ifmt=rng[6:5]; iheader=~iheader; idata=~idata; ibe=~ibe; end
    end
end
always @(posedge clk) if(!rst) begin
    cycle=cycle+1;
    if(cycle > 100000) $fatal(1, "Watchdog: input %0d output %0d", sent, received);
    if(blocked && (!ovalid || {{odata,obe,ofirst,olast}} !== previous))
        $fatal(1, "Output changed under backpressure");
    blocked=ovalid && !oready;
    previous={{odata,obe,ofirst,olast}};
    if(ovalid && oready) begin
        if(received >= {len(expected)}) $fatal(1, "Extra output");
        if({{obe,ofirst,olast}} !== expected[received][{lanes+1}:0])
            $fatal(1, "Mask/framing mismatch at beat %0d", received);
        for(lane=0; lane<{lanes}; lane=lane+1)
            if(obe[lane] && odata[8*lane+:8] !== expected[received][{lanes+2}+8*lane+:8])
                $fatal(1, "Data mismatch at beat %0d lane %0d", received, lane);
        received=received+1;
    end
    if(ivalid && iready) begin sent=sent+1; pending=0; end
    if(sent == {len(inputs)} && received == {len(expected)}) begin
        drained=drained+1;
        if(drained == 32) begin $display("PASS"); $finish; end
    end
end
endmodule
"""
    (tmp_path/"tb.v").write_text(bench)
    compiled = subprocess.run(["iverilog", "-g2012", "-s", "tb", "-o", "sim", "dut.v", "tb.v"],
        cwd=tmp_path, capture_output=True, text=True, timeout=60)
    assert compiled.returncode == 0, compiled.stdout + compiled.stderr
    result = subprocess.run(["vvp", "sim"], cwd=tmp_path, capture_output=True, text=True, timeout=60)
    assert result.returncode == 0, result.stdout + result.stderr
    assert "PASS" in result.stdout
