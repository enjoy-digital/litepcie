import random

import pytest
from migen import ClockDomain
from migen.sim import passive, run_simulation
from litex.soc.interconnect.stream import ClockDomainCrossing

from litepcie.phy.common import PHYRXDatapath


@pytest.mark.parametrize("phy_width", [128, 256, 512])
@pytest.mark.parametrize("core_width", [128, 256, 512])
def test_rx_width_conversion(phy_width, core_width):
    dut = PHYRXDatapath(core_width, phy_width, "sys")
    dut.clock_domains.cd_sys = ClockDomain("sys")
    dut.clock_domains.cd_pcie = ClockDomain("pcie")
    cdc = next(module for _, module in dut._submodules if isinstance(module, ClockDomainCrossing))
    packets = [[0xAB000000 + length * 256 + i for i in range(length)]
               for length in [1, 3, 4, 7, 8, 15, 16, 17, 31, 32, 33, 128]]
    received = []

    def stimulus():
        rng = random.Random(19)
        lanes = phy_width // 32
        for packet in packets:
            for offset in range(0, len(packet), lanes):
                chunk = packet[offset:offset + lanes]
                yield dut.sink.valid.eq(0)
                for _ in range(rng.randrange(3)):
                    yield
                yield dut.sink.dat.eq(sum(word << (32 * lane) for lane, word in enumerate(chunk)))
                yield dut.sink.be.eq((1 << (4 * len(chunk))) - 1)
                yield dut.sink.first.eq(offset == 0)
                yield dut.sink.last.eq(offset + lanes >= len(packet))
                yield dut.sink.valid.eq(1)
                yield
                while not (yield dut.sink.ready):
                    yield
        yield dut.sink.valid.eq(0)
        for _ in range(200):
            yield

    @passive
    def monitor():
        rng = random.Random(25)
        packet = []
        while True:
            if (yield dut.source.valid) and (yield dut.source.ready):
                data = (yield dut.source.dat)
                be = (yield dut.source.be)
                assert bool((yield dut.source.first)) == (not packet)
                packet.extend((data >> (32 * lane)) & 0xffffffff for lane in range(core_width // 32)
                              if be & (15 << (4 * lane)))
                if (yield dut.source.last):
                    received.append(packet)
                    packet = []
            yield dut.source.ready.eq(rng.randrange(3) != 0)
            yield

    @passive
    def watchdog():
        for _ in range(10000):
            yield
        raise AssertionError("RX converter stalled")

    # Migen needs explicit schedules for the common-reset CDC's clock aliases.
    run_simulation(dut, {"pcie": [stimulus(), watchdog()], "sys": monitor()}, clocks={
        "pcie": (10, 3), "sys": 14,
        f"from{cdc.duid}": (10, 3), f"to{cdc.duid}": 14,
    })
    assert received == packets
