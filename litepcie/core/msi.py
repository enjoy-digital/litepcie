#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2023 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

from migen import *

from litex.gen import *

from litex.soc.interconnect.csr     import *
from litex.soc.interconnect.csr_bus import SRAM

from litepcie.common import *

# LitePCIeMSI --------------------------------------------------------------------------------------

class LitePCIeMSI(LiteXModule):
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
        self.comb += self.source.valid.eq(msi != 0)
        self.sync += [
            msi.eq((msi | self.irqs) & enable),
            If(self.source.ready,
                msi.eq(self.irqs & enable)
            )
        ]

# LitePCIeMSIMultiVector ---------------------------------------------------------------------------

class LitePCIeMSIMultiVector(LiteXModule):
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

class LitePCIeMSIX(LiteXModule):
    def __init__(self, endpoint, width=32, default_enable=0):
        assert width <= 64
        self.irqs           = Signal(width)
        self.enable         = CSRStorage(width, description="""MSI-X Enable Control.\n
           Write bit(s) to ``1`` to enable corresponding MSI-X IRQ(s).""",
           reset = default_enable*(2**width-1))
        if width <= 32:
            self.reserved0 = CSRStorage() # For 64-bit alignment.
        self.pba            = CSRStatus(width, description="""MSI-X PBA Table.""")
        if width <= 32:
            self.reserved1 = CSRStorage() # For 64-bit alignment.
        self.specials.table = Memory(4*32, width, init=[0b1 for _ in range(width)]) # MSI-X Table / Masked by default.

        # # #

        enable = Signal(width)
        clear  = Signal(width)
        vector = Signal(width)

        # Memorize and clear IRQ Vector ------------------------------------------------------------
        self.comb += enable.eq(self.enable.storage)
        self.sync += vector.eq(enable & ((vector & ~clear) | self.irqs))
        self.comb += self.pba.status.eq(vector)

        # Generate MSI-X ---------------------------------------------------------------------------
        msix_valid          = Signal()
        msix_num            = Signal(max=width)
        msix_clear          = Signal(width)
        msix_clear_on_ready = Signal(width)

        for i in reversed(range(width)): # Priority given to lower indexes.
            self.comb += [
                If(vector[i],
                    msix_valid.eq(1),
                    msix_num.eq(i),
                    msix_clear.eq(1 << i),
                )
            ]

        # Send MSI-X as TLP-Write ------------------------------------------------------------------
        self.port       = port       = endpoint.crossbar.get_master_port()
        self.table_port = table_port = self.table.get_port(has_re=True)
        self.specials += table_port

        # Table decoding.
        msix_adr  = table_port.dat_r[96:128] # Lower Address.
        msix_dat  = table_port.dat_r[32:64]  # Message Data.
        msix_mask = table_port.dat_r[0]      # Mask, when set to 1, MSI-X message is not generated.

        # FSM.
        self.fsm = fsm = FSM(reset_state="IDLE")
        fsm.act("IDLE",
            table_port.adr.eq(msix_num),
            table_port.re.eq(1),
            If(msix_valid,
                NextValue(msix_clear_on_ready, msix_clear),
                NextState("ISSUE-WRITE")
            )
        )
        self.comb += [
            port.source.channel.eq(port.channel),
            port.source.first.eq(1),
            port.source.last.eq(1),
            port.source.adr.eq(msix_adr),
            port.source.req_id.eq(endpoint.phy.id),
            port.source.tag.eq(0),
            port.source.len.eq(1),
            port.source.dat.eq(msix_dat),
        ]
        fsm.act("ISSUE-WRITE",
            port.source.valid.eq(~msix_mask),
            port.source.we.eq(1),
            If(port.source.ready | msix_mask,
                clear.eq(msix_clear_on_ready),
                NextState("IDLE")
            )
        )
