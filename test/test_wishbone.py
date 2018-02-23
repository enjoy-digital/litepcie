import unittest

from migen import *

from litex.soc.interconnect import wishbone
from litex.soc.interconnect.stream_sim import seed_to_data

from litepcie.core import LitePCIeEndpoint
from litepcie.frontend.wishbone import LitePCIeWishboneBridge

from test.model.host import *

root_id = 0x100
endpoint_id = 0x400


class DUT(Module):
    def __init__(self):
        self.submodules.host = Host(64, root_id, endpoint_id,
            phy_debug=False,
            chipset_debug=False,
            host_debug=False)
        self.submodules.endpoint = LitePCIeEndpoint(self.host.phy)

        self.submodules.wishbone_bridge = LitePCIeWishboneBridge(self.endpoint, lambda a: 1)
        self.submodules.sram = wishbone.SRAM(1024, bus=self.wishbone_bridge.wishbone)


wr_datas = [seed_to_data(i, True) for i in range(64)]
rd_datas = []


def main_generator(dut):
    for i in range(64):
        yield from dut.host.chipset.wr32(i, [wr_datas[i]])

    for i in range(64):
        yield from dut.host.chipset.rd32(i)
        rd_datas.append(dut.host.chipset.rd32_data[0])


class TestBIST(unittest.TestCase):
    def test(self):
        dut = DUT()
        generators = {
            "sys" : [
                main_generator(dut),
                dut.host.chipset.phy.phy_sink.generator(),
                dut.host.chipset.phy.phy_source.generator()
            ]
        }
        clocks = {"sys": 10}
        run_simulation(dut, generators, clocks, vcd_name="sim.vcd")
        self.assertEqual(wr_datas, rd_datas)
