from litex.gen import *

from litex.soc.interconnect.csr import *

from litepcie.common import *


class MSI(Module, AutoCSR):
    def __init__(self, n=32):
        self.irqs = Signal(n)
        self.source = Source(interrupt_layout())

        self._enable = CSRStorage(n)
        self._clear = CSR(n)
        self._vector = CSRStatus(n)

        # # #

        enable = self._enable.storage
        clear = Signal(n)
        self.comb += If(self._clear.re, clear.eq(self._clear.r))

        # memorize and clear irqs
        vector = self._vector.status
        self.sync += vector.eq(~clear & (vector | self.irqs))

        # send irq
        self.comb += self.source.stb.eq((vector & enable) != 0)
