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
        self.comb += If(self.clear.wr_stb, clear.eq(self.clear.storage))
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
        # MSI-X Table: 4 x 32-bit words per vector (Lower Address, Upper Address, Message Data, Vector
        # Control), masked by default. A 32-bit wide Memory maps word for word on the CSR bus and lets
        # the message generation read every bit column through its own port: with a 128-bit wide entry
        # the Vector Control reserved bits (31:1) were only ever read back by the CSR port, and Vivado
        # 2024.1 turned those dual-port LUTRAM columns into cells it could not place or route (DRC
        # RTSTAT-4/RTSTAT-6, no bitstream).
        self.specials.table = Memory(32, 4*width, init=[0, 0, 0, 0b1]*width)

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
        msix_skip           = Signal(width) # Pending IRQs found masked, skipped until next scan.
        msix_skip_set       = Signal(width)
        msix_pending        = Signal(width)

        # Masked IRQs remain pending (PBA) and are skipped to avoid blocking the other IRQs. Once all
        # pending IRQs have been skipped, re-scan them so IRQs unmasked by software are generated.
        self.comb += msix_pending.eq(vector & ~msix_skip)
        self.sync += [
            If(msix_pending == 0,
                msix_skip.eq(0)
            ).Else(
                msix_skip.eq((msix_skip | msix_skip_set) & vector)
            )
        ]

        for i in reversed(range(width)): # Priority given to lower indexes.
            self.comb += [
                If(msix_pending[i],
                    msix_valid.eq(1),
                    msix_num.eq(i),
                    msix_clear.eq(1 << i),
                )
            ]

        # Send MSI-X as TLP-Write ------------------------------------------------------------------
        self.port       = port       = endpoint.crossbar.get_master_port()
        self.table_port = table_port = self.table.get_port(has_re=True)
        self.specials += table_port

        # Table entry read: the 4 words of the vector are read one after the other.
        msix_vector  = Signal(max=max(width, 2))
        msix_word    = Signal(2)
        msix_adr_lsb = Signal(32) # Lower Address.
        msix_adr_msb = Signal(32) # Upper Address.
        msix_dat     = Signal(32) # Message Data.
        msix_ctrl    = Signal(32) # Vector Control.
        msix_mask    = Signal()   # When set to 1, MSI-X message is not generated (IRQ kept pending).
        msix_adr     = Signal(len(port.source.adr))
        self.comb += table_port.adr.eq(Cat(msix_word, msix_vector))
        self.comb += msix_mask.eq(msix_ctrl[0])
        if len(port.source.adr) >= 64:
            self.comb += msix_adr.eq(Cat(msix_adr_lsb, msix_adr_msb))
        else:
            # Upper Address can't be expressed on a 32-bit Endpoint: Handle the IRQ as masked instead
            # of writing to the truncated (wrong) address.
            self.comb += msix_adr.eq(msix_adr_lsb)
            self.comb += If(msix_adr_msb != 0, msix_mask.eq(1))

        # FSM.
        self.fsm = fsm = FSM(reset_state="IDLE")
        fsm.act("IDLE",
            If(msix_valid,
                NextValue(msix_clear_on_ready, msix_clear),
                NextValue(msix_vector, msix_num),
                NextValue(msix_word, 0),
                NextState("READ-TABLE")
            )
        )
        fsm.act("READ-TABLE",
            table_port.re.eq(1),
            NextState("LOAD-TABLE")
        )
        fsm.act("LOAD-TABLE",
            Case(msix_word, {
                0 : NextValue(msix_adr_lsb, table_port.dat_r),
                1 : NextValue(msix_adr_msb, table_port.dat_r),
                2 : NextValue(msix_dat,     table_port.dat_r),
                3 : NextValue(msix_ctrl,    table_port.dat_r),
            }),
            NextValue(msix_word, msix_word + 1),
            If(msix_word == 3,
                NextState("ISSUE-WRITE")
            ).Else(
                NextState("READ-TABLE")
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
            port.source.we.eq(1),
            If(msix_mask,
                # Masked: Keep IRQ pending and skip it.
                msix_skip_set.eq(msix_clear_on_ready),
                NextState("IDLE")
            ).Else(
                port.source.valid.eq(1),
                If(port.source.ready,
                    clear.eq(msix_clear_on_ready),
                    NextState("IDLE")
                )
            )
        )
