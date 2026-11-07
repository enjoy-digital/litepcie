#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""Soft PCIe PHY Transaction Layer glue.

Received TLPs (DW stream, byte 0 on bits 7:0): 32-bit Memory Requests and Completions go to LitePCIe,
Type 0 Configuration Requests to function 0 are answered from the configuration space (Bus/Device
Numbers captured on CfgWr0, 2.2.6.2), other non-posted requests get an Unsupported Request Completion
(2.3.1), Messages and other posted requests are dropped. Transmitted TLPs: completions, LitePCIe TLPs
and MSI Memory Writes, arbitrated per TLP.

Limitations: no BAR/Memory Space Enable decoding (LitePCIe masks the address), no PME_TO_Ack.
"""

from migen import *

from litex.gen import *

from litex.soc.interconnect import stream

from litepcie.common import msi_layout
from litepcie.phy.soft.tl.config_space import PCIeConfigSpace

CPL_STATUS_SC = 0b000
CPL_STATUS_UR = 0b001

def dw_bytes(b0, b1, b2, b3):
    return Cat(b0, b1, b2, b3)

# TLP Arbiter --------------------------------------------------------------------------------------

class TLPArbiter(LiteXModule):
    """Fixed priority (lowest index first), the grant is held until the last DW."""
    def __init__(self, sinks, source):
        grant = Signal(max=max(len(sinks), 2))
        busy  = Signal()
        sel   = Signal(max=max(len(sinks), 2))
        self.comb += sel.eq(grant)
        if not isinstance(sinks, (list, tuple)):
            raise ValueError
        select = None
        for i in reversed(range(len(sinks))):
            select = If(sinks[i].valid, sel.eq(i)) if select is None else If(sinks[i].valid, sel.eq(i)).Else(select)
        self.comb += If(~busy, select)
        self.comb += Case(sel, {i: sinks[i].connect(source) for i in range(len(sinks))})
        self.sync += [
            If(source.valid & source.ready,
                grant.eq(sel),
                busy.eq(~source.last),
            )
        ]

# Transaction Layer --------------------------------------------------------------------------------

class SoftTransactionLayer(LiteXModule):
    def __init__(self, bar0_mask, nlanes=1, vendor_id=0x10ee, device_id=0x7021, msi_vectors=1, gen2_capable=False, gen3_capable=False):
        self.sink       = sink       = stream.Endpoint([("data", 32)]) # i: from the Data Link Layer.
        self.source     = source     = stream.Endpoint([("data", 32)]) # o: to the Data Link Layer.
        self.ep_source  = ep_source  = stream.Endpoint([("data", 32)]) # o: to LitePCIe.
        self.ep_sink    = ep_sink    = stream.Endpoint([("data", 32)]) # i: from LitePCIe.
        self.msi        = msi        = stream.Endpoint(msi_layout())   # i
        self.id         = Signal(16)                                   # o: Cat(function, device, bus).
        self.ur_count   = Signal(16)                                   # o

        # # #

        self.cfg = cfg = PCIeConfigSpace(bar0_mask,
            nlanes       = nlanes,
            vendor_id    = vendor_id,
            device_id    = device_id,
            msi_vectors  = msi_vectors,
            gen2_capable = gen2_capable,
            gen3_capable = gen3_capable,
        )
        self.link_width = Signal(6, reset=nlanes) # i: negotiated width (Link Status).
        self.comb += cfg.link_width.eq(self.link_width)

        # Received TLPs ----------------------------------------------------------------------------
        fmt  = sink.data[5:8]
        type = sink.data[0:5]
        is_mem32  = (fmt[0] == 0) & (type == 0)
        is_cpl    = (fmt[0] == 0) & (type == 0b01010)

        dw0 = Signal(32)
        dw1 = Signal(32)
        dw2 = Signal(32)
        dw3 = Signal(32)
        rx_index = Signal(3)

        cpl_status = Signal(3)
        cpl_data   = Signal()   # Completion with Data (1 DW).
        cpl_dat    = Signal(32)
        cpl_id     = Signal(16) # Completer ID (bytes 4/5 of the completion).

        r_fmt      = dw0[5:8]
        r_type     = dw0[0:5]
        r_has_data = r_fmt[1]
        r_posted   = (r_has_data & (r_type == 0)) | (r_type[3:5] == 0b10)
        r_is_cfg0  = r_type == 0b00100
        r_function = dw2[8:11]
        r_cfg_adr  = Cat(dw2[26:32], dw2[16:20]) # Register Number, Extended Register Number.
        r_cfg_be   = dw1[24:28]                  # First DW BE.

        self.rx_fsm = rx_fsm = FSM(reset_state="IDLE")
        rx_fsm.act("IDLE",
            If(sink.valid,
                If(is_mem32 | is_cpl,
                    NextState("TO-EP")
                ).Else(
                    NextValue(rx_index, 0),
                    NextState("CAPTURE")
                )
            )
        )
        rx_fsm.act("TO-EP",
            sink.connect(ep_source),
            If(sink.valid & sink.ready & sink.last,
                NextState("IDLE")
            )
        )
        rx_fsm.act("CAPTURE",
            sink.ready.eq(1),
            If(sink.valid,
                NextValue(rx_index, rx_index + 1),
                Case(rx_index, {
                    0: NextValue(dw0, sink.data),
                    1: NextValue(dw1, sink.data),
                    2: NextValue(dw2, sink.data),
                    3: NextValue(dw3, sink.data),
                }),
                If(sink.last,
                    NextState("DECODE")
                )
            )
        )
        rx_fsm.act("DECODE",
            If(r_is_cfg0 & (r_function == 0),
                NextState("CFG")
            ).Elif(r_posted,
                NextState("IDLE")
            ).Else(
                cfg.ur_detected.eq(1),
                NextValue(self.ur_count, self.ur_count + 1),
                NextValue(cpl_status, CPL_STATUS_UR),
                NextValue(cpl_data, 0),
                NextValue(cpl_id, self.id[0:16]),
                NextState("CPL-0")
            )
        )
        # Configuration access; completer ID from the request (target Bus/Device/Function).
        bus    = dw2[0:8]
        devfn  = dw2[8:16]
        rx_fsm.act("CFG",
            NextValue(cpl_status, CPL_STATUS_SC),
            NextValue(cpl_data, ~r_has_data),
            NextValue(cpl_dat, cfg.dat_r),
            NextValue(cpl_id, Cat(devfn, bus)),
            cfg.we.eq(r_has_data),
            If(r_has_data,
                NextValue(self.id, Cat(devfn[0:3], devfn[3:8], bus)),
            ),
            NextState("CPL-0")
        )
        self.comb += [
            cfg.adr.eq(r_cfg_adr),
            cfg.be.eq(r_cfg_be),
            cfg.dat_w.eq(dw3),
        ]

        # Completions ------------------------------------------------------------------------------
        # Byte 2/3 of DW0: Attr from the request, Length. Byte Count 4, Lower Address 0.
        cpl = stream.Endpoint([("data", 32)])
        cpl_dw0 = dw_bytes(
            Cat(Constant(0b01010, 5), Constant(0, 1), cpl_data, Constant(0, 1)), # Fmt/Type: (CplD) / Cpl.
            dw0[8:16] & 0x70,                                                     # TC.
            dw0[16:24] & 0x30,                                                    # Attr.
            Cat(cpl_data, Constant(0, 7)),                                        # Length.
        )
        cpl_dw1 = dw_bytes(
            cpl_id[8:16],                                                         # Completer ID: Bus,
            cpl_id[0:8],                                                          # Device/Function.
            Cat(Constant(0, 5), cpl_status),                                      # Status, Byte Count[11:8].
            Constant(4, 8),                                                       # Byte Count[7:0].
        )
        cpl_dw2 = dw_bytes(
            dw1[0:8], dw1[8:16],                                                  # Requester ID.
            dw1[16:24],                                                           # Tag.
            Constant(0, 8),                                                       # Lower Address.
        )
        rx_fsm.act("CPL-0",
            cpl.valid.eq(1), cpl.first.eq(1), cpl.data.eq(cpl_dw0),
            If(cpl.ready, NextState("CPL-1"))
        )
        rx_fsm.act("CPL-1",
            cpl.valid.eq(1), cpl.data.eq(cpl_dw1),
            If(cpl.ready, NextState("CPL-2"))
        )
        rx_fsm.act("CPL-2",
            cpl.valid.eq(1), cpl.data.eq(cpl_dw2), cpl.last.eq(~cpl_data),
            If(cpl.ready,
                If(cpl_data,
                    NextState("CPL-3")
                ).Else(
                    NextState("IDLE")
                )
            )
        )
        rx_fsm.act("CPL-3",
            cpl.valid.eq(1), cpl.data.eq(cpl_dat), cpl.last.eq(1),
            If(cpl.ready, NextState("IDLE"))
        )

        # MSI --------------------------------------------------------------------------------------
        msi_tlp  = stream.Endpoint([("data", 32)])
        address  = cfg.msi_address
        is_64    = address[32:64] != 0
        msi_dat  = Signal(16)
        mme_mask = Signal(5)
        self.comb += [
            Case(cfg.msi_mme, {
                0: mme_mask.eq(0b00000), 1: mme_mask.eq(0b00001), 2: mme_mask.eq(0b00011),
                3: mme_mask.eq(0b00111), 4: mme_mask.eq(0b01111), "default": mme_mask.eq(0b11111),
            }),
            msi_dat.eq(Cat((cfg.msi_data[0:5] & ~mme_mask) | (msi.dat[0:5] & mme_mask), cfg.msi_data[5:16])),
        ]
        self.msi_fsm = msi_fsm = FSM(reset_state="IDLE")
        msi_fsm.act("IDLE",
            If(msi.valid,
                If(cfg.msi_enable & cfg.bme,
                    NextState("DW0")
                ).Else(
                    # MSI disabled: interrupt dropped.
                    msi.ready.eq(1)
                )
            )
        )
        msi_fsm.act("DW0",
            msi_tlp.valid.eq(1), msi_tlp.first.eq(1),
            msi_tlp.data.eq(dw_bytes(Mux(is_64, Constant(0x60, 8), Constant(0x40, 8)), Constant(0, 8), Constant(0, 8), Constant(1, 8))),
            If(msi_tlp.ready, NextState("DW1"))
        )
        msi_fsm.act("DW1",
            msi_tlp.valid.eq(1),
            msi_tlp.data.eq(dw_bytes(self.id[8:16], self.id[0:8], Constant(0, 8), Constant(0x0f, 8))),
            If(msi_tlp.ready,
                If(is_64,
                    NextState("ADR-HI")
                ).Else(
                    NextState("ADR-LO")
                )
            )
        )
        msi_fsm.act("ADR-HI",
            msi_tlp.valid.eq(1),
            msi_tlp.data.eq(dw_bytes(address[56:64], address[48:56], address[40:48], address[32:40])),
            If(msi_tlp.ready, NextState("ADR-LO"))
        )
        msi_fsm.act("ADR-LO",
            msi_tlp.valid.eq(1),
            msi_tlp.data.eq(dw_bytes(address[24:32], address[16:24], address[8:16], address[0:8])),
            If(msi_tlp.ready, NextState("DATA"))
        )
        msi_fsm.act("DATA",
            msi_tlp.valid.eq(1), msi_tlp.last.eq(1),
            msi_tlp.data.eq(Cat(msi_dat, Constant(0, 16))),
            If(msi_tlp.ready,
                msi.ready.eq(1),
                NextState("IDLE")
            )
        )

        # Transmitted TLPs -------------------------------------------------------------------------
        # MSI goes before LitePCIe: DMA keeps the stream busy and keeps running without the driver,
        # an interrupt left to the gaps would be starved. It's a short TLP at a bounded rate, LitePCIe
        # isn't starved in return.
        self.arbiter = TLPArbiter([cpl, msi_tlp, ep_sink], source)
