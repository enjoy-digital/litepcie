#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import random

import pytest
from migen import ResetInserter, Signal
from migen.sim import run_simulation

from litepcie.tlp import packetizer

# Helpers ------------------------------------------------------------------------------------------

def inserter(width, reset=False):
    fmt = Signal(2)
    cls = getattr(packetizer, f"LitePCIeTLPHeaderInserter{width}b")
    dut = cls(fmt)
    dut.comb += fmt.eq(dut.sink.fmt)
    return ResetInserter()(dut) if reset else dut


def packets(width, seed):
    rng = random.Random(seed)
    lanes = width//8
    result = []
    # Every byte position around two word boundaries, then larger payloads.
    for length in list(range(2*lanes + 2)) + [127, 128, 129, 511, 512, 513, 4096]:
        for header_dwords in [3, 4]:
            header = bytes(rng.randrange(256) for _ in range(4*header_dwords))
            payload = bytes(rng.randrange(256) for _ in range(length))
            fmt = header_dwords - 3 + (2 if length else 0)
            result.append((fmt, header, payload))
    return result


def traffic_vectors(width, traffic):
    """Independent byte concatenation oracle, with no hardware header/mask helpers."""
    lanes = width//8
    inputs = []
    expected = []
    for fmt, header, payload in traffic:
        chunks = [payload[i:i + lanes] for i in range(0, len(payload), lanes)] or [b""]
        for i, chunk in enumerate(chunks):
            inputs.append((fmt, int.from_bytes(header, "little"),
                int.from_bytes(chunk, "little"), (1 << len(chunk)) - 1,
                int(i == 0), int(i == len(chunks) - 1)))
        wire = header + payload
        for i in range(0, len(wire), lanes):
            chunk = wire[i:i + lanes]
            expected.append((chunk, (1 << len(chunk)) - 1, int(i == 0), int(i + lanes >= len(wire))))
    return inputs, expected


def transfer(dut, width, traffic, seed):
    lanes = width//8
    rng = random.Random(seed)
    inputs, expected = traffic_vectors(width, traffic)

    sent = received = idle = 0
    pending = False
    stalled = None
    for cycle in range(100000):
        # Seed zero exercises consecutive transfers with no idle cycles. Other seeds
        # include long stalls, producer bubbles and changing invalid input fields.
        ready = seed == 0 or (cycle % 97 >= 23 and rng.randrange(4) != 0)
        yield dut.source.ready.eq(ready)
        if not pending and sent < len(inputs):
            pending = seed == 0 or rng.randrange(4) != 0
        yield dut.sink.valid.eq(pending)
        if pending:
            fmt, header, data, be, first, last = inputs[sent]
        else:
            fmt, header, data, be, first, last = (
                rng.randrange(4), rng.getrandbits(128), rng.getrandbits(width),
                rng.getrandbits(lanes), rng.randrange(2), rng.randrange(2))
        yield dut.sink.fmt.eq(fmt)
        yield dut.sink.header.eq(header)
        yield dut.sink.dat.eq(data)
        yield dut.sink.be.eq(be)
        yield dut.sink.first.eq(first)
        yield dut.sink.last.eq(last)
        yield

        valid = (yield dut.source.valid)
        beat = ((yield dut.source.dat), (yield dut.source.be),
            (yield dut.source.first), (yield dut.source.last))
        if stalled is not None:
            assert valid and beat == stalled, "Output changed while stalled"
        stalled = beat if valid and not ready else None
        if valid and ready:
            assert received < len(expected), "Unexpected output beat"
            chunk, mask, first, last = expected[received]
            data, be, got_first, got_last = beat
            assert (be, got_first, got_last) == (mask, first, last), (received, beat, expected[received])
            assert data.to_bytes(lanes, "little")[:len(chunk)] == chunk, received
            received += 1
        if pending and (yield dut.sink.ready):
            sent += 1
            pending = False
        if sent == len(inputs) and received == len(expected):
            idle += 1
            if idle == 32:
                return
    raise AssertionError(f"Traffic stalled: input {sent}/{len(inputs)}, output {received}/{len(expected)}")

# Tests --------------------------------------------------------------------------------------------

@pytest.mark.parametrize("width", [32, 64, 128, 256, 512])
@pytest.mark.parametrize("seed", [0, 1, 42])
def test_mixed_formats_and_byte_tails(width, seed):
    dut = inserter(width)
    run_simulation(dut, transfer(dut, width, packets(width, seed), seed))


@pytest.mark.parametrize("width", [32, 64, 128, 256, 512])
@pytest.mark.parametrize("header_dwords", [3, 4])
def test_reset_during_header_payload_and_flush(width, header_dwords):
    lanes = width//8
    # Reset before/within headers, after buffered payload, and with a stalled flush.
    for stop_after in range((4*header_dwords + 3*lanes - 1)//lanes):
        dut = inserter(width, reset=True)
        old_payload = bytes([0xde])*(2*lanes)
        old_header = bytes([0xad])*(4*header_dwords)

        def stimulus():
            accepted = sent = 0
            for _ in range(100):
                yield dut.sink.valid.eq(sent < 2)
                yield dut.sink.first.eq(sent == 0)
                yield dut.sink.last.eq(sent == 1)
                yield dut.sink.fmt.eq(header_dwords - 1)
                yield dut.sink.header.eq(int.from_bytes(old_header, "little"))
                yield dut.sink.dat.eq(int.from_bytes(old_payload[:lanes], "little"))
                yield dut.sink.be.eq((1 << lanes) - 1)
                yield dut.source.ready.eq(accepted < stop_after)
                yield
                if (yield dut.source.valid) and accepted == stop_after:
                    break
                if (yield dut.source.valid):
                    accepted += 1
                if (yield dut.sink.valid) and (yield dut.sink.ready):
                    sent += 1
            else:
                raise AssertionError("Did not reach reset point")
            yield dut.reset.eq(1)
            yield dut.sink.valid.eq(0)
            yield
            yield
            yield dut.reset.eq(0)
            # Start with the opposite format after reset; stale mux and tail state
            # must not survive.
            fresh = [(2 if header_dwords == 4 else 3, bytes(range(12 if header_dwords == 4 else 16)), b"\xa5")]
            fresh += packets(width, 17)[:8]
            yield from transfer(dut, width, fresh, 42)

        run_simulation(dut, stimulus())
