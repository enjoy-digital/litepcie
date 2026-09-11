"""PTM filtering preserves packet data through gaps and output backpressure."""
import random

from migen import run_simulation

from litepcie.frontend.ptm.sniffer import TLPFilterFormater
from litepcie.tlp.common import fmt_type_dict


def test_ptm_filter_packets():
    rng = random.Random(27)
    dut = TLPFilterFormater()
    packets = []
    expected = []
    for index in range(60):
        kind = ('ptm_req', 'ptm_res', 'mem_rd32')[index % 3]
        words = [(fmt_type_dict[kind] << 24) | rng.getrandbits(24)]
        words += [rng.getrandbits(32) for _ in range(5 if kind == 'ptm_res' else 3)]
        packets.append(words)
        if kind != 'mem_rd32':
            # The existing filter forwards four words for a request and five
            # for a response, then waits for the physical packet end.
            expected.append(words[:5] if kind == 'ptm_res' else words)
    received = []

    def stimulus():
        for words in packets:
            for index, word in enumerate(words):
                for _ in range(rng.randrange(3)):
                    yield dut.sink.valid.eq(0)
                    yield dut.sink.data.eq(rng.getrandbits(32))
                    yield
                yield dut.sink.valid.eq(1)
                yield dut.sink.data.eq(word)
                yield dut.sink.last.eq(index == len(words) - 1)
                yield
            yield dut.sink.valid.eq(0)
            yield dut.sink.last.eq(0)
            for _ in range(16):
                yield dut.sink.data.eq(rng.getrandbits(32))
                yield
        for _ in range(20):
            yield

    def observe():
        packet = []
        for cycle in range(2200):
            yield dut.source.ready.eq(cycle % 5 != 0)
            if (yield dut.source.valid) and (yield dut.source.ready):
                data = (yield dut.source.dat)
                be = (yield dut.source.be)
                for word in range(2):
                    if (be >> (4 * word)) & 15:
                        packet.append((data >> (32 * word)) & 0xffffffff)
                if (yield dut.source.last):
                    # The 64-bit converter pads the odd five-word response.
                    # Its upper final word is not part of the PTM message.
                    if packet[0] >> 24 == fmt_type_dict["ptm_res"]:
                        assert len(packet) == 6
                        packet = packet[:5]
                    received.append(packet)
                    packet = []
            yield

    run_simulation(dut, [stimulus(), observe()])
    assert received == expected
