from migen import *

from litex.soc.interconnect.csr import *
from litex.soc.interconnect.csr_bus import SRAM

from litepcie.common import *

# LitePCIeMSI --------------------------------------------------------------------------------------

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

# LitePCIeMSIMultiVector ---------------------------------------------------------------------------

class LitePCIeMSIMultiVector(Module, AutoCSR):
  def __init__(self, width=32):
        self.irqs   = Signal(width)
        self.source = stream.Endpoint(msi_layout())

        self.enable = CSRStorage(width, description="""MSI Enable Control.\n
           Write bit(s) to ``1`` to enable corresponding MSI IRQ(s).""")

        # # #

        enable = Signal(width)
        clear  = Signal(width)
        vector = Signal(width)

        # Memorize and clear IRQ Vector ------------------------------------------------------------
        self.comb += enable.eq(self.enable.storage)
        self.sync += vector.eq(enable & ((vector & ~clear) | self.irqs))

        # Generate MSI -----------------------------------------------------------------------------
        for i in reversed(range(width)): # Priority given to lower indexes.
            self.comb += [
                If(vector[i],
                    self.source.valid.eq(1),
                    self.source.dat.eq(i),
                    If(self.source.ready,
                        clear.eq(1 << i)
                    )
                )
            ]

# LitePCIeMSIX -------------------------------------------------------------------------------------

class LitePCIeMSIX(Module, AutoCSR):
  def __init__(self, endpoint, width=32):
        self.irqs         = Signal(width)
        self.enable       = CSRStorage(width, description="""MSI-X Enable Control.\n
           Write bit(s) to ``1`` to enable corresponding MSI-X IRQ(s).""")
        self.specials.mem = Memory(64, width)

        # # #

        enable = Signal(width)
        clear  = Signal(width)
        vector = Signal(width)

        # Memorize and clear IRQ Vector ------------------------------------------------------------
        self.comb += enable.eq(self.enable.storage)
        self.sync += vector.eq(enable & ((vector & ~clear) | self.irqs))

        # Generate MSI-X ---------------------------------------------------------------------------
        msix_valid = Signal()
        msix_ready = Signal()
        msix_num   = Signal(max=width)

        for i in reversed(range(width)): # Priority given to lower indexes.
            self.comb += [
                If(vector[i],
                    msix_valid.eq(1),
                    msix_num.eq(i),
                    If(msix_ready,
                        clear.eq(1 << i)
                    )
                )
            ]

        # Send MSI-X as TLP-Write ------------------------------------------------------------------
        port     = endpoint.crossbar.get_master_port()
        mem_port = self.mem.get_port(has_re=True)
        self.specials += mem_port

        self.submodules.fsm = fsm = FSM(reset_state="IDLE")
        fsm.act("IDLE",
            mem_port.adr.eq(msix_num),
            mem_port.re.eq(1),
            If(msix_valid,
                NextState("ISSUE-WRITE")
            )
        )
        self.comb += [
            port.source.channel.eq(port.channel),
            port.source.first.eq(1),
            port.source.last.eq(1),
            port.source.adr[2:].eq(mem_port.dat_r[32:]), # CHECKME: LSB/MSB
            port.source.req_id.eq(endpoint.phy.id),
            port.source.tag.eq(0),
            port.source.len.eq(1),
            port.source.dat.eq(mem_port.dat_r[:32]), # CHECKME: LSB/MSB
        ]
        fsm.act("ISSUE-WRITE",
            port.source.valid.eq(1),
            port.source.we.eq(1),
            If(port.source.ready,
                msix_ready.eq(1),
                NextState("IDLE")
            )
        )
