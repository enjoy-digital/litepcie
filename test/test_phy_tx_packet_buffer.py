import random
import unittest

from migen import ClockDomain, Module
from migen.sim import passive, run_simulation
from litex.soc.interconnect.stream import ClockDomainCrossing
from litepcie.phy.common import PHYTXDatapath


class TestPHYTXPacketBuffer(unittest.TestCase):
    def test_complete_packets_cross_independent_clocks(self):
        for width in (128, 256, 512):
            for ready_always in (False, True):
                with self.subTest(width=width, ready_always=ready_always):
                    dut = Module()
                    dut.clock_domains.cd_sys = ClockDomain("sys")
                    dut.clock_domains.cd_pcie = ClockDomain("pcie")
                    dut.submodules.path = path = PHYTXDatapath(width, width, "sys", with_packet_buffer=True)
                    lengths = [1, 3, (512+16+width//8-1)//(width//8)]*2
                    expected, received = [], []
                    for packet, length in enumerate(lengths):
                        for beat in range(length):
                            expected.append((packet*1000+beat, (1 << (width//8))-1,
                                             int(beat == 0), int(beat == length-1)))

                    def source():
                        rng = random.Random(213)
                        for data, be, first, last in expected:
                            yield path.sink.valid.eq(0)
                            for _ in range(rng.randrange(4)):
                                yield
                            yield path.sink.dat.eq(data)
                            yield path.sink.be.eq(be)
                            yield path.sink.first.eq(first)
                            yield path.sink.last.eq(last)
                            yield path.sink.valid.eq(1)
                            yield
                            while not (yield path.sink.ready):
                                yield
                        yield path.sink.valid.eq(0)
                        for _ in range(4000):
                            if len(received) == len(expected):
                                return
                            yield
                        self.fail("packet buffer did not drain")

                    @passive
                    def monitor():
                        rng = random.Random(512)
                        active, stalled = False, None
                        while True:
                            valid, ready = (yield path.source.valid), (yield path.source.ready)
                            word = ((yield path.source.dat), (yield path.source.be),
                                    (yield path.source.first), (yield path.source.last))
                            if active or stalled is not None:
                                self.assertTrue(valid, "TVALID gap within a complete packet")
                            if stalled is not None:
                                self.assertEqual(word, stalled)
                            stalled = word if valid and not ready else None
                            if valid and ready:
                                received.append(word)
                                active = not word[3]
                            yield path.source.ready.eq(1 if ready_always else rng.randrange(4) != 0)
                            yield

                    cdc = next(module for _, module in path._submodules
                               if isinstance(module, ClockDomainCrossing))
                    clocks = {"sys": 14, "pcie": (10, 3),
                              f"from{cdc.duid}": 14, f"to{cdc.duid}": (10, 3)}
                    run_simulation(dut, {"sys": source(), "pcie": monitor()}, clocks=clocks)
                    self.assertEqual(received, expected)
