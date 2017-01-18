from litex.gen import *

from litex.soc.interconnect.csr import *

from litepcie.common import *


class LitePCIeMSI(Module, AutoCSR):
    def __init__(self, n=32):
        self.irqs = Signal(n)
        self.source = stream.Endpoint(interrupt_layout())

        self.enable = CSRStorage(n)
        self.clear = CSR(n)
        self.vector = CSRStatus(n)

        # # #

        enable = self.enable.storage
        clear = Signal(n)
        self.comb += If(self.clear.re, clear.eq(self.clear.r))

        # memorize and clear irqs
        vector = self.vector.status
        self.sync += vector.eq(~clear & (vector | self.irqs))

        # send irq
        self.comb += self.source.valid.eq((vector & enable) != 0)
