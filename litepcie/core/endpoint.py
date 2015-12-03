from litex.gen import *

from litex.soc.interconnect.csr import *

from litepcie.core.tlp.depacketizer import LitePCIeTLPDepacketizer
from litepcie.core.tlp.packetizer import LitePCIeTLPPacketizer
from litepcie.core.crossbar import LitePCIeCrossbar


class LitePCIeEndpoint(Module):
    def __init__(self, phy, max_pending_requests=4, with_reordering=False):
        self.phy = phy
        self.max_pending_requests = max_pending_requests

        # # #

        # TLP Packetizer / LitePCIeTLPDepacketizer
        depacketizer = LitePCIeTLPDepacketizer(phy.data_width, phy.bar0_mask)
        packetizer = LitePCIeTLPPacketizer(phy.data_width)
        self.submodules += depacketizer, packetizer
        self.comb += [
            phy.source.connect(depacketizer.sink),
            packetizer.source.connect(phy.sink)
        ]

        # Crossbar
        crossbar = LitePCIeCrossbar(phy.data_width, max_pending_requests, with_reordering)
        self.submodules.crossbar = crossbar

        # (Slave) HOST initiates the transactions
        self.comb += [
            Record.connect(depacketizer.req_source, crossbar.phy_slave.sink),
            Record.connect(crossbar.phy_slave.source, packetizer.cmp_sink)
        ]

        # (Master) FPGA initiates the transactions
        self.comb += [
            Record.connect(crossbar.phy_master.source, packetizer.req_sink),
            Record.connect(depacketizer.cmp_source, crossbar.phy_master.sink)
        ]
