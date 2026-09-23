#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Enjoy-Digital <enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import pytest

from migen import *

from litepcie.frontend.ptm.pipe_gen34 import (
    PCIe128b130bLaneReceiver,
    PCIePTM128b130bMatcher,
)


def scramble(data, state):
    output = bytearray()
    for byte in data:
        mask = 0
        for bit in range(8):
            feedback = (state >> 22) & 1
            state = (state << 1) & 0x7fffff
            if feedback:
                state ^= 0x210125
                mask |= 1 << bit
        output.append(byte ^ mask)
    return bytes(output), state


@pytest.mark.parametrize("data_width", [32, 64])
def test_gen34_lane_sos_and_descrambling(data_width):
    lane = PCIe128b130bLaneReceiver(data_width)
    seed = 0x123456
    sos = bytes([0xaa] + [0] * 11 + [0xe1, 0x12, 0x34, 0x56])
    plain = bytes(range(16))
    encoded, _ = scramble(plain, seed)
    actual = []

    def send(block, header):
        for offset in range(0, 16, data_width // 8):
            yield lane.valid.eq(1)
            yield lane.start_block.eq(offset == 0)
            yield lane.header.eq(header)
            yield lane.data.eq(int.from_bytes(block[offset:offset+data_width//8], "little"))
            yield
        yield lane.valid.eq(0)
        for _ in range(5):
            yield
            if (yield lane.out_valid):
                actual.append((yield lane.out_data).to_bytes(16, "little"))

    def stimulus():
        yield lane.link_up.eq(1)
        yield from send(sos, 2)
        assert (yield lane.locked)
        yield from send(encoded, 1)
        assert actual == [plain]

    run_simulation(lane, stimulus())


@pytest.mark.parametrize("nlanes", [4, 8])
@pytest.mark.parametrize("start", [0, 16, 48, 56])
def test_gen34_matcher_cross_block(nlanes, start):
    block_bytes = 16 * nlanes
    if start >= block_bytes:
        return
    matcher = PCIePTM128b130bMatcher(nlanes)
    timestamp = 0x0123456789abcdef
    delay = 0x89abcdef
    header = bytes([0x74, 0, 0, 1, 0x12, 0x34, 0, 0x53])
    response = bytes([0x7f, 0, 0, 0]) + header
    response += timestamp.to_bytes(8, "big") + delay.to_bytes(4, "big") + bytes(4)
    stream_data = bytearray(3*block_bytes)
    stream_data[start:start+len(response)] = response
    received = []

    def stimulus():
        yield matcher.source.ready.eq(1)
        for index in range(3):
            block = stream_data[index*block_bytes:(index+1)*block_bytes]
            yield matcher.valid.eq(1)
            yield matcher.data.eq(int.from_bytes(block, "little"))
            yield
            yield matcher.valid.eq(0)
            for _ in range(5):
                yield
                if (yield matcher.source.valid):
                    received.append(((yield matcher.source.master_time),
                        (yield matcher.source.link_delay)))
        assert received == [(timestamp, delay)]

    run_simulation(matcher, stimulus())


@pytest.mark.parametrize("nlanes,data_width", [(4, 32), (8, 64)])
def test_gen34_receive_striped_ptm(nlanes, data_width):
    from litepcie.frontend.ptm.pipe_gen34 import PCIePTM128b130bReceiver

    receiver = PCIePTM128b130bReceiver(nlanes, data_width)
    seed = 0x123456
    sos = bytes([0xaa] + [0] * 11 + [0xe1, 0x12, 0x34, 0x56])
    timestamp = 0x0123456789abcdef
    delay = 0x89abcdef
    header = bytes([0x74, 0, 0, 1, 0x12, 0x34, 0, 0x53])
    response = bytes([0x7f, 0, 0, 0]) + header
    response += timestamp.to_bytes(8, "big") + delay.to_bytes(4, "big") + bytes(4)
    block_bytes = 16*nlanes
    logical = bytearray(block_bytes*3)
    logical[block_bytes-8:block_bytes-8+len(response)] = response
    blocks = []
    states = [seed]*nlanes
    for block_index in range(3):
        lane_blocks = []
        for lane in range(nlanes):
            plain = bytes(logical[block_index*block_bytes+row*nlanes+lane]
                for row in range(16))
            encoded, states[lane] = scramble(plain, states[lane])
            lane_blocks.append(encoded)
        blocks.append(lane_blocks)
    captured = []

    def send(lane_blocks, header):
        for offset in range(0, 16, data_width//8):
            cycle = b"".join(block[offset:offset+data_width//8] for block in lane_blocks)
            yield receiver.valid.eq(1)
            yield receiver.start_block.eq((1 << nlanes)-1 if offset == 0 else 0)
            yield receiver.header.eq(sum(header << (2*lane) for lane in range(nlanes)))
            yield receiver.data.eq(int.from_bytes(cycle, "little"))
            yield
        yield receiver.valid.eq(0)
        for _ in range(5):
            yield
            if (yield receiver.source.valid) and (yield receiver.source.ready):
                captured.append(((yield receiver.source.master_time),
                    (yield receiver.source.link_delay)))

    def stimulus():
        yield receiver.link_up.eq(1)
        yield receiver.lane_valid.eq((1 << nlanes)-1)
        yield receiver.source.ready.eq(0)
        yield from send([sos]*nlanes, 2)
        for block in blocks:
            yield from send(block, 1)
        yield receiver.source.ready.eq(1)
        for _ in range(10):
            yield
            if (yield receiver.source.valid):
                captured.append(((yield receiver.source.master_time),
                    (yield receiver.source.link_delay)))
        assert captured == [(timestamp, delay)]

    run_simulation(receiver, stimulus())


@pytest.mark.parametrize("token,code,expected", [
    (0x4f, 0x53, True),
    (0x3f, 0x53, False),
    (0x4f, 0x52, False),
    (0x00, 0x53, False),
])
def test_gen34_matcher_requires_frame_and_ptm_header(token, code, expected):
    matcher = PCIePTM128b130bMatcher(4)
    block_bytes = 64
    logical = bytearray(2*block_bytes)
    logical[28:44] = bytes([token, 0, 0, 0, 0x34, 0, 0, 0, 0x12, 0x34, 0, code, 0, 0, 0, 0])
    received = []

    def stimulus():
        yield matcher.source.ready.eq(1)
        for index in range(2):
            yield matcher.valid.eq(1)
            yield matcher.data.eq(int.from_bytes(logical[index*block_bytes:(index+1)*block_bytes], "little"))
            yield
            yield matcher.valid.eq(0)
            for _ in range(6):
                yield
                if (yield matcher.source.valid):
                    received.append((yield matcher.source.master_time))
        assert received == ([0] if expected else [])

    run_simulation(matcher, stimulus())


def test_gen3_receive_lane_skew_and_pipe_bubbles():
    from litepcie.frontend.ptm.pipe_gen34 import PCIePTM128b130bReceiver

    receiver = PCIePTM128b130bReceiver(4, 32)
    seed = 0x123456
    sos = bytes([0xaa] + [0]*11 + [0xe1, 0x12, 0x34, 0x56])
    timestamp = 0x1122334455667788
    delay = 0x10203040
    logical = bytearray(3*64)
    logical[52:80] = bytes([0x7f, 0, 0, 0, 0x74, 0, 0, 1, 0x12, 0x34, 0, 0x53]) + \
        timestamp.to_bytes(8, "big") + delay.to_bytes(4, "big") + bytes(4)
    lane_streams = []
    for lane in range(4):
        state = seed
        blocks = [sos]
        for block in range(3):
            plain = bytes(logical[64*block+4*row+lane] for row in range(16))
            encoded, state = scramble(plain, state)
            blocks.append(encoded)
        lane_streams.append(blocks)

    def stimulus():
        yield receiver.link_up.eq(1)
        yield receiver.source.ready.eq(0)
        for cycle in range(20):
            data = []
            lane_valid = start = header = 0
            for lane in range(4):
                position = cycle - lane
                if 0 <= position < 16:
                    block, segment = divmod(position, 4)
                    data.append(lane_streams[lane][block][4*segment:4*(segment+1)])
                    lane_valid |= 1 << lane
                    start |= (segment == 0) << lane
                    header |= (2 if block == 0 else 1) << (2*lane)
                else:
                    data.append(bytes(4))
            yield receiver.valid.eq(1)
            yield receiver.lane_valid.eq(lane_valid)
            yield receiver.start_block.eq(start)
            yield receiver.header.eq(header)
            yield receiver.data.eq(int.from_bytes(b"".join(data), "little"))
            yield
        yield receiver.valid.eq(0)
        for _ in range(15):
            yield
        assert (yield receiver.locked)
        yield receiver.source.ready.eq(1)
        yield
        assert (yield receiver.source.valid)
        assert (yield receiver.source.master_time) == timestamp
        assert (yield receiver.source.link_delay) == delay

    run_simulation(receiver, stimulus())


@pytest.mark.parametrize("nlanes,data_width", [(4, 32), (8, 64)])
def test_generated_gen34_receiver(tmp_path, nlanes, data_width):
    import shutil
    import subprocess

    from migen.fhdl import verilog
    from litepcie.frontend.ptm.pipe_gen34 import PCIePTM128b130bReceiver

    if not shutil.which("iverilog") or not shutil.which("vvp"):
        pytest.skip("Icarus Verilog is required")
    dut = Module()
    dut.clock_domains.cd_sys = ClockDomain("sys")
    dut.submodules.receiver = receiver = PCIePTM128b130bReceiver(nlanes, data_width)
    ports = dict(clk=dut.cd_sys.clk, rst=dut.cd_sys.rst,
        valid=receiver.valid, lane_valid=receiver.lane_valid,
        start_block=receiver.start_block, header=receiver.header,
        data=receiver.data, link_up=receiver.link_up,
        out_valid=receiver.source.valid, out_ready=receiver.source.ready,
        out_time=receiver.source.master_time, out_delay=receiver.source.link_delay)
    for name, signal in ports.items():
        signal.name_override = name
    verilog.convert(dut, ios=set(ports.values()), name="ptm_gen34").write(str(tmp_path/"receiver.v"))

    seed = 0x123456
    sos = bytes([0xaa] + [0]*11 + [0xe1, 0x12, 0x34, 0x56])
    timestamp, delay = 0x0123456789abcdef, 0x89abcdef
    response = bytes([0x7f, 0, 0, 0, 0x74, 0, 0, 1, 0x12, 0x34, 0, 0x53])
    response += timestamp.to_bytes(8, "big") + delay.to_bytes(4, "big") + bytes(4)
    block_bytes = 16*nlanes
    logical = bytearray(block_bytes*3)
    logical[block_bytes-8:block_bytes-8+len(response)] = response
    states = [seed]*nlanes
    blocks = [[sos]*nlanes]
    for block_index in range(3):
        lane_blocks = []
        for lane in range(nlanes):
            plain = bytes(logical[block_index*block_bytes+row*nlanes+lane]
                for row in range(16))
            encoded, states[lane] = scramble(plain, states[lane])
            lane_blocks.append(encoded)
        blocks.append(lane_blocks)

    bench = f'''`timescale 1ns/1ps
module tb;
reg clk=0; always #2 clk=~clk;
reg rst=1, valid=0, link_up=0;
reg [{nlanes-1}:0] lane_valid={(1 << nlanes)-1};
reg [{nlanes-1}:0] start_block=0;
reg [{2*nlanes-1}:0] header=0;
reg [{data_width*nlanes-1}:0] data=0;
wire out_valid; reg out_ready=1;
wire [63:0] out_time; wire [31:0] out_delay;
ptm_gen34 dut(.*);
always @(posedge clk) if(out_valid && out_ready) $display("RESPONSE %h %h", out_time, out_delay);
initial begin
repeat(5) @(negedge clk); rst=0; link_up=1;
'''
    for block_index, lane_blocks in enumerate(blocks):
        for offset in range(0, 16, data_width//8):
            cycle = b"".join(block[offset:offset+data_width//8] for block in lane_blocks)
            data = int.from_bytes(cycle, "little")
            start = (1 << nlanes)-1 if offset == 0 else 0
            header = sum((2 if block_index == 0 else 1) << (2*lane)
                for lane in range(nlanes))
            bench += f"valid=1; start_block={nlanes}'h{start:x}; header={2*nlanes}'h{header:x}; "
            bench += f"data={data_width*nlanes}'h{data:x}; @(negedge clk);\n"
        bench += "valid=0; repeat(6) @(negedge clk);\n"
    bench += "repeat(20) @(negedge clk); $finish; end\nendmodule\n"
    (tmp_path/"tb.v").write_text(bench)
    compiled = subprocess.run(["iverilog", "-g2012", "-s", "tb", "-o", "sim",
        "receiver.v", "tb.v"], cwd=tmp_path, capture_output=True, text=True)
    assert compiled.returncode == 0, compiled.stdout + compiled.stderr
    result = subprocess.run(["vvp", "sim"], cwd=tmp_path,
        capture_output=True, text=True, timeout=30)
    assert result.returncode == 0, result.stdout + result.stderr
    assert result.stdout.strip() == f"RESPONSE {timestamp:016x} {delay:08x}"
