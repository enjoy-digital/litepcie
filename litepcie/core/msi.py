from migen import *

from litex.soc.interconnect.csr import *

from litepcie.common import *


class LitePCIeMSI(Module, AutoCSR):
    def __init__(self, width=32):
        self.irqs   = Signal(width)
        self.source = stream.Endpoint(msi_layout())

        self.enable = CSRStorage(width)
        self.clear  = CSR(width)
        self.vector = CSRStatus(width)

        # # #

        enable = Signal(width)
        clear  = Signal(width)
        vector = Signal(width)

        # Memorize and clear IRQ Vector ------------------------------------------------------------
        self.comb += If(self.clear.re, clear.eq(self.clear.r))
        self.comb += enable.eq(self.enable.storage)
        self.comb += self.vector.status.eq(vector)
        self.sync += vector.eq(enable & ((vector & ~clear) | self.irqs))

        # Generate MSI -----------------------------------------------------------------------------
        msi = Signal(width)
        self.sync += [
            If(self.source.ready,
                msi.eq(self.irqs)
            ).Else(
                msi.eq(msi | self.irqs)
            )
        ]
        self.comb += self.source.valid.eq(msi != 0)
