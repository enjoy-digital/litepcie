#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import random

import pytest
from migen.sim import run_simulation

from litepcie.tlp.packetizer import LitePCIeTLPPacketizer


def wire_bytes(header, payload, endianness):
    # Headers are protocol DWs in either interface byte order; the packetizer
    # swaps header bytes before insertion and again at its big-endian output.
    result = b"".join(dw.to_bytes(4, "little") for dw in header)
    return result + b"".join(dw.to_bytes(4, endianness) for dw in payload)


@pytest.mark.parametrize("width", [32, 64, 128, 256, 512])
@pytest.mark.parametrize("endianness", ["little", "big"])
@pytest.mark.parametrize("seed", [0, 7])
def test_concurrent_requests_and_completions(width, endianness, seed):
    dut = LitePCIeTLPPacketizer(width, endianness, address_width=32 if width == 32 else 64)
    rng = random.Random(100 + seed)
    lanes = width//32
    lengths = sorted({1, 2, max(1, lanes - 1), lanes, lanes + 1, 2*lanes - 1, 2*lanes, 2*lanes + 1, 127, 128, 129})
    requests = []
    completions = []
    expected = [[], []]
    for tag, length in enumerate(lengths*2):
        payload = [rng.getrandbits(32) for _ in range(length)]
        attr = tag % 4
        address = 0x12340000 + 4*tag
        high_address = width != 32 and tag % 2 == 0
        if high_address:
            address |= 0x98765432 << 32
        write = tag % 3 != 0
        fmt = int(high_address) + 2*write
        header = [fmt << 29 | attr << 12 | length,
            0x1234 << 16 | tag << 8 | (0xf0 if length > 1 else 0) | 0xf]
        header += [address >> 32, address & 0xffffffff] if high_address else [address]
        params = dict(we=write, adr=address, len=length, req_id=0x1234, tag=tag, attr=attr)
        requests.append((params, payload if write else []))
        expected[0].append(wire_bytes(header, payload if write else [], endianness))

        error = tag % 4 == 0
        tc = tag % 8
        params = dict(len=length, byte_count=4*length, adr=0x24, req_id=0xabcd,
            cmp_id=0x4321, tag=tag, attr=attr, tc=tc, err=error)
        header = [(0 if error else 2) << 29 | 0x0a << 24 | tc << 20 | attr << 12 | (0 if error else length),
            0x4321 << 16 | (1 << 13 if error else 4*length),
            0xabcd << 16 | tag << 8 | (0 if error else 0x24)]
        completions.append((params, payload if not error else []))
        expected[1].append(wire_bytes(header, payload if not error else [], endianness))

    def stimulus():
        streams = [dut.req_sink, dut.cmp_sink]
        traffic = [requests, completions]
        indices = [0, 0]
        offsets = [0, 0]
        pending = [False, False]
        received = [0, 0]
        current = bytearray()
        stalled = None
        drained = 0
        for cycle in range(30000):
            ready = seed == 0 or (cycle % 79 >= 19 and rng.randrange(3) != 0)
            yield dut.source.ready.eq(ready)
            for n, sink in enumerate(streams):
                if not pending[n] and indices[n] < len(traffic[n]):
                    pending[n] = seed == 0 or rng.randrange(3) != 0
                yield sink.valid.eq(pending[n])
                if pending[n]:
                    params, payload = traffic[n][indices[n]]
                    for name, value in params.items():
                        yield getattr(sink, name).eq(value)
                    chunk = payload[offsets[n]:offsets[n] + lanes]
                    yield sink.dat.eq(sum(dw << (32*i) for i, dw in enumerate(chunk)))
                    yield sink.first.eq(offsets[n] == 0)
                    yield sink.last.eq(offsets[n] + lanes >= len(payload))
            yield
            valid = (yield dut.source.valid)
            beat = ((yield dut.source.dat), (yield dut.source.be),
                (yield dut.source.first), (yield dut.source.last))
            if stalled is not None:
                assert valid and beat == stalled, "Output changed during backpressure"
            stalled = beat if valid and not ready else None
            if valid and ready:
                data, be, first, last = beat
                assert be and not (be & (be + 1)), "Empty or noncontiguous output"
                assert first == (len(current) == 0), "Interleaved packets or missing first"
                if not last:
                    assert be == (1 << (width//8)) - 1
                current.extend((data >> (8*i)) & 0xff for i in range(width//8) if be & (1 << i))
                if last:
                    kind = int(((int.from_bytes(current[:4], "little") >> 24) & 0x1f) == 0x0a)
                    assert received[kind] < len(expected[kind]), "Duplicated packet"
                    assert bytes(current) == expected[kind][received[kind]], (kind, received[kind])
                    received[kind] += 1
                    current.clear()
            for n, sink in enumerate(streams):
                if pending[n] and (yield sink.ready):
                    offsets[n] += lanes
                    if offsets[n] >= len(traffic[n][indices[n]][1]):
                        indices[n] += 1
                        offsets[n] = 0
                    pending[n] = False
            if received == [len(requests), len(completions)] and indices == received:
                drained += 1
                if drained == 32:
                    assert not current
                    return
        raise AssertionError(f"Packetizer stalled: input {indices}, output {received}")

    run_simulation(dut, stimulus())
