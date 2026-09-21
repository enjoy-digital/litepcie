import random

import pytest
from migen import Module, Signal, run_simulation

from litepcie.frontend.ptm.pipe import (
    PCIe8b10bLaneDescrambler, PCIePTMSymbolReceiver, COM, SKP, STP, END, EDB,
)
from litepcie.frontend.ptm.sniffer import ScramblerUnit


def test_lane_lfsr_matches_existing_x1_scrambler():
    dut = Module()
    dut.submodules.lane = lane = PCIe8b10bLaneDescrambler()
    dut.submodules.reference = ref = ScramblerUnit(reset=0xffff)

    phase = Signal()
    dut.sync += phase.eq(~phase)
    dut.comb += ref.ce.eq(phase)

    def stimulus():
        for _ in range(120):
            expected = (yield ref.value)
            if (yield phase):
                expected >>= 16
            assert (yield lane.decoded) == expected & 0xffff
            yield
    run_simulation(dut, stimulus())


def response(timestamp, delay, with_data=True, bad=False):
    header = bytes([0x74 if with_data else 0x34, 0, 0, int(with_data), 0x12, 0x34, 0, 0x53])
    header += timestamp.to_bytes(8, "big") if with_data else bytes(8)
    payload = delay.to_bytes(4, "big") if with_data else b""
    return [(STP, 1), (0, 0), (0, 0)] + [(b, 0) for b in header + payload + bytes(4)] + [(EDB if bad else END, 1)]


@pytest.mark.parametrize("width", [2, 4, 8, 16])
def test_parallel_ptm_receiver_alignment_gaps_and_backpressure(width):
    dut = PCIePTMSymbolReceiver(width)
    rng = random.Random(44)
    symbols = []
    expected = []
    for alignment in range(width):
        symbols += [(0, 0)] * (alignment + 5)
        timestamp, delay = rng.getrandbits(64), rng.getrandbits(32)
        symbols += response(timestamp, delay)
        expected.append((0x53, timestamp, delay))
        symbols += [(0xfb, 0)] * 32 # A payload byte cannot act as a K/STP symbol.
        symbols += response(0, 0, with_data=False)
        expected.append((0x53, 0, 0))
        symbols += response(timestamp, delay, bad=True)
        # Truncated payload and incorrect TLP length must not publish time.
        symbols += response(timestamp, delay)[:19] + [(END, 1)] + [(0, 0)]*20
        malformed = response(timestamp, delay)
        malformed[6] = (2, 0)
        symbols += malformed
        # Non-PTM memory TLP with PTM-like bytes in its payload.
        symbols += [(STP, 1), (0, 0), (0, 0)] + [(0x40, 0)] + response(timestamp, delay)[4:-1] + [(END, 1)]
    symbols += [(0, 0)] * (width * 30)
    received = []

    def stimulus():
        for offset in range(0, len(symbols), width):
            beat = symbols[offset:offset+width]
            yield dut.valid.eq(0)
            for _ in range(rng.randrange(3)):
                yield
            yield dut.valid.eq(1)
            yield dut.nbytes.eq(len(beat))
            yield dut.data.eq(sum(b << (8*i) for i, (b, k) in enumerate(beat)))
            yield dut.ctrl.eq(sum(k << i for i, (b, k) in enumerate(beat)))
            yield
        yield dut.valid.eq(0)
        for _ in range(30):
            yield

    def monitor():
        for cycle in range(len(symbols)*3):
            yield dut.source.ready.eq(cycle % 7 != 0)
            if (yield dut.source.valid) and (yield dut.source.ready):
                received.append(((yield dut.source.message_code), (yield dut.source.master_time), (yield dut.source.link_delay)))
            assert not (yield dut.overflow)
            yield

    run_simulation(dut, [stimulus(), monitor()])
    assert received == expected


def scramble_symbols(symbols):
    # Independent bit-serial PCIe recurrence, with symbol-specific advancement.
    state = 0xffff
    result = []
    for data, ctrl in symbols:
        if ctrl and data == SKP:
            result.append((data, ctrl))
            continue
        mask = 0
        for bit in range(8):
            feedback = state >> 15
            mask |= feedback << bit
            state = ((state << 1) & 0xffff) ^ (0x39 if feedback else 0)
        result.append((data if ctrl else data ^ mask, ctrl))
        if ctrl and data == COM:
            state = 0xffff
    return result


@pytest.mark.parametrize("width,active,reverse", [(2,2,0),(4,4,0),(4,4,1),(4,2,0),(4,1,0),(8,8,0),(8,4,1)])
def test_multilane_descramble_deskew_and_width(width, active, reverse):
    from litepcie.frontend.ptm.pipe import PCIePTM8b10bReceiver
    dut = PCIePTM8b10bReceiver(width)
    timestamp, delay = 0x1020304050607080, 0x12345678
    wire = [(0, 0)] * (active*8) + response(timestamp, delay)
    wire += [(0, 0)] * (active*80)
    lanes = []
    for lane in range(width):
        logical = width-1-lane if reverse else lane
        if logical < active:
            # Skew the initial COM by a different number of symbols per lane.
            lane_symbols = [(0,0)] * (lane % 5) + [(COM,1)]
            lane_symbols += wire[logical::active]
            # SKP can be removed independently by each lane's elastic buffer.
            lane_symbols[8:8] = [(SKP,1)] * (lane % 3)
            lanes.append(scramble_symbols(lane_symbols))
        else:
            lanes.append([(0,0)] * 400)
    length = max(map(len, lanes))
    for lane in lanes:
        lane += [(0,0)] * (length + 200 - len(lane))
    received = []

    def stimulus():
        yield dut.link_up.eq(0)
        yield dut.lanes.eq(active)
        yield dut.reverse.eq(reverse)
        yield dut.source.ready.eq(1)
        for _ in range(4):
            yield
        yield dut.link_up.eq(1)
        for _ in range(3):
            yield
        for offset in range(0, length+100, 2):
            data, ctrl = 0, 0
            for lane in range(width):
                for byte in range(2):
                    value, k = lanes[lane][offset+byte]
                    data |= value << (16*lane+8*byte)
                    ctrl |= k << (2*lane+byte)
            yield dut.data.eq(data)
            yield dut.ctrl.eq(ctrl)
            yield
        yield dut.valid.eq(0)
        for _ in range(30):
            yield

    def monitor():
        for _ in range(length+200):
            if (yield dut.source.valid) and (yield dut.source.ready):
                received.append(((yield dut.source.master_time), (yield dut.source.link_delay)))
            yield
    run_simulation(dut, [stimulus(), monitor()])
    assert received == [(timestamp, delay)]


def test_lane_valid_bubbles_and_retraining():
    from litepcie.frontend.ptm.pipe import PCIePTM8b10bReceiver
    from migen import passive
    dut = PCIePTM8b10bReceiver(4)
    received = []
    rng = random.Random(19)
    @passive
    def monitor():
        while True:
            if (yield dut.source.valid) and (yield dut.source.ready):
                received.append(((yield dut.source.master_time), (yield dut.source.link_delay)))
            yield
    def run():
        yield dut.source.ready.eq(1)
        for reverse in (0, 1):
            yield dut.link_up.eq(0)
            yield dut.reverse.eq(reverse)
            yield dut.lane_valid.eq(0)
            for _ in range(5):
                yield
            yield dut.link_up.eq(1)
            for _ in range(3):
                yield
            wire = [(0, 0)]*32 + response(0x10203040+reverse, 0x55+reverse) + [(0, 0)]*240
            lanes = [scramble_symbols([(COM, 1)] + wire[lane::4] + [(0, 0)]) for lane in range(4)]
            if reverse:
                lanes.reverse()
            offsets = [0]*4
            for cycle in range(120):
                # Independent PIPE RxValid bubbles, bounded skew below FIFO depth.
                enabled = [offsets[lane] < len(lanes[lane])-1 and
                    (offsets[lane] <= min(offsets)+4) and rng.randrange(4) != 0 for lane in range(4)]
                data, ctrl = 0, 0
                for lane in range(4):
                    if enabled[lane]:
                        for byte in range(2):
                            b, k = lanes[lane][offsets[lane]+byte]
                            data |= b << (16*lane+8*byte)
                            ctrl |= k << (2*lane+byte)
                        offsets[lane] += 2
                yield dut.data.eq(data)
                yield dut.ctrl.eq(ctrl)
                yield dut.lane_valid.eq(sum(int(value) << lane for lane, value in enumerate(enabled)))
                yield
            yield dut.lane_valid.eq(0)
            for _ in range(30):
                yield
    run_simulation(dut, [run(), monitor()])
    assert received == [(0x10203040, 0x55), (0x10203041, 0x56)]


def test_overflow_discards_alignment_and_reacquires():
    from litepcie.frontend.ptm.pipe import PCIePTM8b10bReceiver
    from migen import passive
    dut = PCIePTM8b10bReceiver(4)
    received, overflows = [], []
    @passive
    def monitor():
        while True:
            if (yield dut.overflow):
                overflows.append(True)
            if (yield dut.source.valid):
                received.append((yield dut.source.master_time))
            yield
    def run():
        yield dut.source.ready.eq(1)
        yield dut.link_up.eq(1)
        for _ in range(4):
            yield
        yield dut.data.eq(sum(COM << (16*i) for i in range(4)))
        yield dut.ctrl.eq(0x55)
        yield
        yield dut.ctrl.eq(0)
        yield dut.data.eq(0)
        for _ in range(6):
            yield
        # One stalled lane causes the other elastic buffers to fill.
        yield dut.lane_valid.eq(0xe)
        for _ in range(40):
            yield
        assert overflows
        assert not (yield dut.locked)
        yield dut.lane_valid.eq(0xf)
        wire = [(0, 0)]*32 + response(0xabcdef, 12) + [(0, 0)]*200
        lanes = [scramble_symbols([(COM, 1)] + wire[i::4] + [(0, 0)]) for i in range(4)]
        for offset in range(0, min(map(len, lanes))-1, 2):
            yield dut.data.eq(sum(lanes[i][offset+j][0] << (16*i+8*j) for i in range(4) for j in range(2)))
            yield dut.ctrl.eq(sum(lanes[i][offset+j][1] << (2*i+j) for i in range(4) for j in range(2)))
            yield
        yield dut.lane_valid.eq(0)
        for _ in range(20):
            yield
    run_simulation(dut, [run(), monitor()])
    assert received == [0xabcdef]
