from migen import *

from litex.soc.interconnect.csr import *

from litepcie.core.tlp.depacketizer import LitePCIeTLPDepacketizer
from litepcie.core.tlp.packetizer import LitePCIeTLPPacketizer
from litepcie.core.crossbar import LitePCIeCrossbar


class LitePCIeEndpoint(Module):
    def __init__(self, phy, max_pending_requests=4, with_reordering=False):
        self.phy = phy
        self.max_pending_requests = max_pending_requests

        # # #

        # TLP Packetizer / Depacketizer
        depacketizer = LitePCIeTLPDepacketizer(phy.data_width, phy.bar0_mask)
        packetizer = LitePCIeTLPPacketizer(phy.data_width)
        self.submodules.depacketizer = depacketizer
        self.submodules.packetizer = packetizer
        self.comb += [
            phy.source.connect(depacketizer.sink),
            packetizer.source.connect(phy.sink)
        ]

        # Crossbar
        crossbar = LitePCIeCrossbar(phy.data_width, max_pending_requests, with_reordering)
        self.submodules.crossbar = crossbar

        # (Slave) HOST initiates the transactions
        self.comb += [
            depacketizer.req_source.connect(crossbar.phy_slave.sink),
            crossbar.phy_slave.source.connect(packetizer.cmp_sink)
        ]

        # (Master) FPGA initiates the transactions
        self.comb += [
            crossbar.phy_master.source.connect(packetizer.req_sink),
            depacketizer.cmp_source.connect(crossbar.phy_master.sink)
        ]
