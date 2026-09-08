import random

import pytest
from migen.sim import passive, run_simulation

from litepcie.tlp.packetizer import LitePCIeTLPHeaderInserter3DWs, LitePCIeTLPHeaderInserter4DWs


def pack(words):
    return sum(word << (32 * lane) for lane, word in enumerate(words))


@pytest.mark.parametrize("width", [128, 256, 512])
@pytest.mark.parametrize("header_dwords", [3, 4])
def test_all_partial_tails(width, header_dwords):
    cls = {3: LitePCIeTLPHeaderInserter3DWs, 4: LitePCIeTLPHeaderInserter4DWs}[header_dwords]
    dut = cls(width)
    lanes = width // 32
    expected = []
    received = []
    for length in range(129):
        header = [0x10000000 + length * 256 + lane for lane in range(header_dwords)]
        payload = [0xA0000000 + length * 256 + lane for lane in range(length)]
        words = header + payload
        for offset in range(0, len(words), lanes):
            chunk = words[offset:offset + lanes]
            expected.append((chunk, int(offset == 0), int(offset + lanes >= len(words))))

    def stimulus():
        rng = random.Random(100 + width + header_dwords)
        for length in range(129):
            header = [0x10000000 + length * 256 + lane for lane in range(header_dwords)]
            payload = [0xA0000000 + length * 256 + lane for lane in range(length)]
            chunks = [payload[i:i + lanes] for i in range(0, length, lanes)] or [[]]
            for index, chunk in enumerate(chunks):
                yield dut.sink.valid.eq(0)
                for _ in range(rng.randrange(3)):
                    yield
                yield dut.sink.header.eq(pack(header))
                yield dut.sink.dat.eq(pack(chunk))
                yield dut.sink.be.eq((1 << (4 * len(chunk))) - 1)
                yield dut.sink.first.eq(index == 0)
                yield dut.sink.last.eq(index == len(chunks) - 1)
                yield dut.sink.valid.eq(1)
                yield
                while not (yield dut.sink.ready):
                    yield
        yield dut.sink.valid.eq(0)
        for _ in range(50):
            yield

    @passive
    def monitor():
        rng = random.Random(42)
        blocked = None
        while True:
            valid = (yield dut.source.valid)
            ready = (yield dut.source.ready)
            data = (yield dut.source.dat)
            be = (yield dut.source.be)
            first = (yield dut.source.first)
            last = (yield dut.source.last)
            beat = (data, be, first, last)
            if blocked is not None:
                assert valid and beat == blocked, "Output changed during backpressure"
            blocked = beat if valid and not ready else None
            if valid and ready:
                assert be and not (be & (be + 1)), "Empty or noncontiguous beat"
                if not last:
                    assert be == (1 << (width // 8)) - 1, "Partial nonfinal beat"
                words = [(data >> (32 * lane)) & 0xffffffff
                         for lane in range(lanes) if be & (15 << (4 * lane))]
                received.append((words, first, last))
            yield dut.source.ready.eq(rng.randrange(4) != 0)
            yield

    @passive
    def watchdog():
        for _ in range(50000):
            yield
        raise AssertionError("Header inserter stalled")

    run_simulation(dut, [stimulus(), monitor(), watchdog()])
    assert received == expected
