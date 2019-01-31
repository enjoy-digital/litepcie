from migen import *

from litex.soc.interconnect.csr import *

from litepcie.common import *


class LitePCIeMSI(Module, AutoCSR):
    def __init__(self, width=32, transmit_interval=2):
        self.irqs = Signal(width)
        self.source = stream.Endpoint(msi_layout())

        self.enable = CSRStorage(width)
        self.clear = CSR(width)
        self.vector = CSRStatus(width)

        # # #

        enable = self.enable.storage
        clear = Signal(width)
        self.comb += If(self.clear.re, clear.eq(self.clear.r))

        # memorize and clear irqs
        vector = self.vector.status
        vector_d = Signal(width)
        self.sync += vector.eq(~clear & (vector | self.irqs))
        self.sync += vector_d.eq(vector)

        # transmit irq
        transmit_request = Signal()
        transmit_grant = Signal()
        transmit_counter = Signal(max=transmit_interval)
        self.comb += [
            transmit_request.eq((vector & enable) != 0),
            transmit_grant.eq(transmit_counter == 0)
        ]
        self.sync += \
            If(~transmit_request | (vector != vector_d),
                transmit_counter.eq(0)
            ).Else(
                transmit_counter.eq(transmit_counter + 1)
            )
        self.comb += \
            If(transmit_grant,
                self.source.valid.eq(transmit_request)
            )
