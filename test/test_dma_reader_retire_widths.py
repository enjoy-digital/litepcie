#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Enjoy-Digital <enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
#

"""Exercise the production Reader's host-buffer ownership at the ordered port."""

from collections import deque
from types import SimpleNamespace

import pytest
from migen import Module, Signal, run_simulation
from migen.sim import passive
from litex.soc.interconnect import stream
from litepcie.common import completion_layout, request_layout
from litepcie.frontend.dma import LitePCIeDMAReader


pytestmark = pytest.mark.slow


@pytest.mark.parametrize("phy_width,user_width", [(64, 64), (128, 128), (256, 256), (512, 256)])
@pytest.mark.parametrize("mrrs", [128, 512])
def test_rewrite_on_completion_with_delays_and_split_packets(phy_width, user_width, mrrs):
    dut = Module()
    port = SimpleNamespace(channel=0,
        source=stream.Endpoint(request_layout(phy_width, address_width=64)),
        sink=stream.Endpoint(completion_layout(phy_width)))
    endpoint = SimpleNamespace(max_pending_requests=16, phy=SimpleNamespace(
        data_width=phy_width, id=0x400, max_request_size=Signal(16, reset=mrrs)))
    dut.submodules.reader = reader = LitePCIeDMAReader(endpoint, port,
        address_width=64, data_width=user_width)
    base, length, count = 0x123400000000, 1088, 4
    memory = [(i * 0x1020305 + 0x98765432) & 0xffffffff for i in range(length * count // 4)]
    expected = memory.copy()
    requests, delivered, irqs = deque(), [], []
    respond, release_output = False, False
    completed = 0

    @passive
    def request_monitor():
        cycle = 0
        while True:
            yield port.source.ready.eq(cycle % 5 != 0)
            if (yield port.source.valid) and (yield port.source.ready):
                requests.append(((yield port.source.adr), (yield port.source.len) * 4,
                                 (yield port.source.user_id)))
            if (yield reader.irq):
                assert ((yield port.sink.valid) and (yield port.sink.ready) and
                        (yield port.sink.last) and (yield port.sink.end) and
                        (yield reader.request_metadata.source.descriptor_last)), \
                    "IRQ precedes final completion acceptance"
                irqs.append((yield port.sink.user_id))
            cycle += 1
            yield

    @passive
    def completions():
        nonlocal completed
        while True:
            if not respond or not requests:
                yield
                continue
            address, size, user_id = requests.popleft()
            for _ in range(19):
                yield
            # Split each request into 128-byte Completion packets. Only the
            # last packet ends the request; packet-last alone must not retire it.
            for offset in range(0, size, 128):
                packet_size = min(128, size - offset)
                for beat in range(0, packet_size, phy_width // 8):
                    words = min(phy_width // 32, (packet_size - beat) // 4)
                    index = (address - base + offset + beat) // 4
                    data = sum(memory[index + n] << (32 * n) for n in range(words))
                    final = beat + words * 4 == packet_size
                    end = offset + packet_size == size
                    yield port.sink.dat.eq(data)
                    yield port.sink.be.eq((1 << (4 * words)) - 1)
                    yield port.sink.first.eq(beat == 0)
                    yield port.sink.last.eq(final)
                    yield port.sink.end.eq(end)
                    yield port.sink.user_id.eq(user_id)
                    yield port.sink.valid.eq(1)
                    yield
                    while not (yield port.sink.ready):
                        yield
                    if final and end and (address - base + size) % length == 0:
                        completed += 1
                    yield port.sink.valid.eq(0)
                    yield
                for _ in range(7):
                    yield

    @passive
    def output():
        cycle = 0
        while True:
            yield reader.source.ready.eq(release_output and cycle % 7 not in (0, 1, 2))
            if (yield reader.source.valid) and (yield reader.source.ready):
                value = (yield reader.source.data)
                delivered.extend((value >> (32 * n)) & 0xffffffff for n in range(user_width // 32))
            cycle += 1
            yield

    def stimulus():
        nonlocal respond, release_output
        yield from reader.table.loop_prog_n.write(0)
        yield from reader.table.reset.write(1)
        for i in range(count):
            address = base + i * length
            value = (address & 0xffffffff) | (length << 32) | ((i == 1) << 56)
            yield from reader.table.value.write(value)
            yield from reader.table.we.write(address >> 32)
        yield from reader._enable.write(1)
        for _ in range(200):
            yield
        assert requests, "No read requests were issued"
        assert (yield reader.table.loop_status.fields.index) == 0, "Status advanced before completions"
        assert not irqs
        respond = True
        rewritten = 0
        for _ in range(30000):
            retired = (yield reader.table.loop_status.fields.index)
            assert retired <= completed, "Status advanced before final completion acceptance"
            while rewritten < retired:
                start = rewritten * length // 4
                memory[start:start + length // 4] = [0xdeadbeef] * (length // 4)
                rewritten += 1
            if rewritten == count:
                break
            yield
        assert rewritten == count, "Retirement timed out with downstream stalled"
        assert not delivered
        assert (yield reader.data_fifo.level) > 0
        release_output = True
        for _ in range(10000):
            if len(delivered) == len(expected):
                break
            yield
        assert delivered == expected
        assert irqs == [0, 2, 3]

    run_simulation(dut, [stimulus(), request_monitor(), completions(), output()])
