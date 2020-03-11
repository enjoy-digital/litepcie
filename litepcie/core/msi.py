from migen import *

from litex.soc.interconnect.csr import *

from litepcie.common import *

# --------------------------------------------------------------------------------------------------

class LitePCIeMSI(Module, AutoCSR):
    def __init__(self, width=32):
        self.irqs   = Signal(width)
        self.source = stream.Endpoint(msi_layout())

        self.enable = CSRStorage(width, description="""MSI Enable Control.\n
           Write bit(s) to ``1`` to enable corresponding MSI IRQ(s).""")
        self.clear  = CSRStorage(width, description="""MSI Clear Control.\n
           Write bit(s) to ``1`` to clear corresponding MSI IRQ(s).""")
        self.vector = CSRStatus(width,  description="""MSI Vector Status.\n
           Current MSI IRQs vector value.""")

        # # #

        enable = Signal(width)
        clear  = Signal(width)
        vector = Signal(width)

        # Memorize and clear IRQ Vector ------------------------------------------------------------
        self.comb += If(self.clear.re, clear.eq(self.clear.storage))
        self.comb += enable.eq(self.enable.storage)
        self.comb += self.vector.status.eq(vector)
        self.sync += vector.eq(enable & ((vector & ~clear) | self.irqs))

        # Generate MSI -----------------------------------------------------------------------------
        msi = Signal(width)
        self.sync += [
            If(enable,
                If(self.source.ready,
                    msi.eq(self.irqs)
                ).Else(
                    msi.eq(msi | self.irqs)
                )
            ).Else(
                msi.eq(0)
            )
        ]
        self.comb += self.source.valid.eq(msi != 0)
