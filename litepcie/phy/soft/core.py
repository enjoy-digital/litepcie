#
# This file is part of LitePCIe.
#
# Copyright (c) 2026 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

"""SoftPCIEPHY: the soft PCIe PHY with the LitePCIe PHY contract (see the hard-IP PHYs): Physical
Layer, Data Link Layer and Transaction Layer glue on FPGA transceivers. 2.5 GT/s x1 for now."""

from migen import *
from migen.genlib.cdc import MultiReg

from litex.gen import *

from litex.soc.interconnect     import stream
from litex.soc.interconnect.csr import *

from litepcie.common     import phy_layout, msi_layout, get_bar_mask
from litepcie.phy.common import PHYTXDatapath, PHYRXDatapath, LTSSMTracer

from litepcie.phy.soft.pipe       import PCIePhysicalLayer
from litepcie.phy.soft.dll.core   import DataLinkLayer
from litepcie.phy.soft.tl.core    import SoftTransactionLayer
from litepcie.phy.soft.tl.wide   import WideTransactionLayer, WideTXAdapter, WideRXAdapter
from litepcie.phy.soft.lanes     import PCIeMultiLanePhysicalLayer
from litepcie.phy.soft.tl.adapter import TXAdapter, RXAdapter

# SoftPCIEPHY --------------------------------------------------------------------------------------

class SoftPCIEPHY(LiteXModule, AutoCSR):
    endianness    = "big"
    qword_aligned = False

    def __init__(self, platform, pads, data_width=64, pcie_data_width=None, cd="sys", bar0_size=1*1024*1024,
        speed       = "gen1",
        vendor_id   = 0x10ee,
        device_id   = None,
        msi_vectors = 1,
        serdes      = None,
        link_freq   = 125e6,
        **phy_kwargs):
        assert data_width in [64, 128, 256, 512]
        assert speed in ["gen1", "gen2", "gen3"]
        gen2_capable = speed in ["gen2", "gen3"]
        gen3_capable = speed == "gen3"
        self.platform   = platform
        self.data_width = data_width
        self.sink       = stream.Endpoint(phy_layout(data_width))
        self.source     = stream.Endpoint(phy_layout(data_width))
        self.msi        = stream.Endpoint(msi_layout())

        self._link_status = CSRStatus(fields=[
            CSRField("status", size=1, values=[
                ("``0b0``", "Link Down."),
                ("``0b1``", "Link Up (Data Link Layer active)."),
            ]),
            CSRField("rate",  size=2, description="Link rate (``0b00``: 2.5 GT/s, ``0b01``: 5 GT/s, ``0b10``: 8 GT/s)."),
            CSRField("width", size=2, description="Negotiated link width (``0b00``: x1)."),
            CSRField("ltssm", size=6, description="LTSSM state (UltraScale encoding, L0 = 0x10)."),
        ])
        self._msi_enable        = CSRStatus(description="MSI Enable Status. ``1``: MSI is enabled.")
        self._msix_enable       = CSRStatus(description="MSI-X Enable Status (not implemented, always 0).")
        self._bus_master_enable = CSRStatus(description="Bus Mastering Status. ``1``: Bus Mastering enabled.")
        self._max_request_size  = CSRStatus(16, description="Negotiated Max Request Size (in bytes).")
        self._max_payload_size  = CSRStatus(16, description="Negotiated Max Payload Size (in bytes).")

        self.id               = Signal(16, reset_less=True)
        self.bar0_size        = bar0_size
        self.bar0_mask        = get_bar_mask(bar0_size)
        self.max_request_size = Signal(16, reset=512)
        self.max_payload_size = Signal(16, reset=128)

        # # #

        # SerDes -----------------------------------------------------------------------------------
        if serdes is None:
            if platform.device.startswith("xc7k"):
                from litepcie.phy.soft.serdes.gtx_7series import K7PCIeSerDes as SerDes
            elif platform.device.startswith("xc7a"):
                from litepcie.phy.soft.serdes.gtp_7series import A7PCIeSerDes as SerDes
            elif platform.device.startswith(("xcku3p", "xcku5p")):
                # Kintex UltraScale+ with GTY transceivers only.
                from litepcie.phy.soft.serdes.gty_ultrascale import USPPCIeSerDes as SerDes
            else:
                raise NotImplementedError(f"No soft PCIe PHY transceiver support for {platform.device}.")
            serdes = SerDes(platform, pads, sys_clk_freq=phy_kwargs.pop("sys_clk_freq", 125e6),
                speedgrade=phy_kwargs.pop("speedgrade", -1), rate_change=gen2_capable,
                **({"gen3": True} if gen3_capable else {}))
            self.serdes = serdes
        else:
            object.__setattr__(self, "serdes", serdes) # The caller's submodule: reference only.
        self.nlanes = nlanes = serdes.nlanes
        # Multi-lane path: x2 and above, and x1 at 8.0 GT/s (2 DWs per cycle).
        wide = (nlanes > 1) or gen3_capable
        # A DW per lane and per cycle at the Physical Layer's output (2 at 8.0 GT/s), LitePCIe at the same width.
        ndw = 2*nlanes if gen3_capable else nlanes
        if wide:
            assert data_width == 32*ndw
        if device_id is None:
            device_id = 0x7020 + nlanes # In the driver's table (litepcie/software/kernel/main.c).

        # Physical Layer / Data Link Layer ---------------------------------------------------------
        phy_layer_cls = PCIeMultiLanePhysicalLayer if wide else PCIePhysicalLayer
        if gen3_capable:
            phy_kwargs.update(gen3_capable=True, ndw=ndw)
        self.phy_layer = phy = phy_layer_cls(serdes, link_freq, upstream=True, gen2_capable=gen2_capable, **phy_kwargs)
        dll_kwargs = dict(ndw=ndw, nlanes=nlanes, rx_depth=2048*max(ndw//2, 1), tx_depth=1024*ndw,
            descriptors=16*max(ndw//2, 1), framing="both" if gen3_capable else "8b10b") if wide else {}
        self.dll       = dll = ClockDomainsRenamer("pcie_link")(DataLinkLayer(link_freq, **dll_kwargs))
        if wide:
            # PAD only when running above x4.
            pad_enable = Signal()
            self.specials += MultiReg(phy.width > 4, pad_enable, "pcie_link")
            self.comb += dll.tx.framer.pad_enable.eq(pad_enable)
        self.sync.pcie_link += [
            # Registered (timing): decoded from the LTSSM state, gate the DLL transmit path.
            dll.link_up.eq(phy.ltssm.link_up),
            dll.l0.eq(phy.ltssm.l0),
            # Framing of the rate (changed out of L0).
            dll.gen3.eq(phy.ltssm.rate == 2),
        ]
        self.comb += [
            phy.link_error.eq(dll.link_error),
            dll.phy_sink.connect(phy.sink),
            phy.source.connect(dll.phy_source),
        ]

        # Clocking: "pcie" is "pcie_link" held in reset while the Data Link Layer is not active -----
        self.cd_pcie = ClockDomain()
        pcie_rst = Signal(reset=1)
        self.sync.pcie_link += pcie_rst.eq(~dll.dl_active)
        self.comb += [
            self.cd_pcie.clk.eq(ClockSignal("pcie_link")),
            self.cd_pcie.rst.eq(pcie_rst),
        ]

        # Transaction Layer ------------------------------------------------------------------------
        tl_cls  = (lambda *args, **kwargs: WideTransactionLayer(ndw, *args, **kwargs)) if wide else SoftTransactionLayer
        self.tl = tl = ClockDomainsRenamer("pcie")(tl_cls(self.bar0_mask,
            nlanes      = nlanes,
            vendor_id   = vendor_id,
            device_id   = device_id,
            msi_vectors = msi_vectors,
            gen2_capable = gen2_capable,
            **({"gen3_capable": True} if gen3_capable else {}),
        ))
        link_speed = Signal(4)
        self.comb += link_speed.eq(phy.ltssm.rate + 1) # Link Status: 1: 2.5 GT/s, 2: 5.0 GT/s, 3: 8.0 GT/s.
        self.specials += MultiReg(link_speed, tl.cfg.link_speed, "pcie")
        if wide:
            self.specials += MultiReg(phy.width, tl.link_width, "pcie")
        self.comb += [
            # TLPs held in the Data Link Layer buffers while "pcie" is in reset.
            tl.sink.valid.eq(dll.source.valid & ~pcie_rst),
            tl.sink.first.eq(dll.source.first),
            tl.sink.last.eq(dll.source.last),
            tl.sink.data.eq(dll.source.data),
            *([tl.sink.dws.eq(dll.source.dws), dll.sink.dws.eq(tl.source.dws)] if wide else []),
            dll.source.ready.eq(tl.sink.ready & ~pcie_rst),
            dll.sink.valid.eq(tl.source.valid & ~pcie_rst),
            dll.sink.first.eq(tl.source.first),
            dll.sink.last.eq(tl.source.last),
            dll.sink.data.eq(tl.source.data),
            tl.source.ready.eq(dll.sink.ready & ~pcie_rst),
        ]

        # LitePCIe streams -------------------------------------------------------------------------
        self.tx_datapath = PHYTXDatapath(data_width, data_width, cd)
        self.rx_datapath = PHYRXDatapath(data_width, data_width, cd)
        self.tx_adapter  = tx_adapter = ClockDomainsRenamer("pcie")((WideTXAdapter if wide else TXAdapter)(data_width))
        self.rx_adapter  = rx_adapter = ClockDomainsRenamer("pcie")((WideRXAdapter if wide else RXAdapter)(data_width))
        self.comb += [
            self.sink.connect(self.tx_datapath.sink),
            self.tx_datapath.source.connect(tx_adapter.sink),
            tx_adapter.source.connect(tl.ep_sink),
            tl.ep_source.connect(rx_adapter.sink),
            rx_adapter.source.connect(self.rx_datapath.sink),
            self.rx_datapath.source.connect(self.source),
        ]

        # MSI --------------------------------------------------------------------------------------
        self.msi_cdc = msi_cdc = stream.ClockDomainCrossing(msi_layout(), cd_from=cd, cd_to="pcie")
        self.comb += [
            self.msi.connect(msi_cdc.sink),
            msi_cdc.source.connect(tl.msi),
        ]

        # Status -----------------------------------------------------------------------------------
        def convert_size(command, size, max_size=512):
            cases = {}
            value = 128
            for i in range(6):
                cases[i] = size.eq(value)
                value = min(value*2, max_size)
            return Case(command, cases)

        max_request_size = Signal(16, reset=512)
        max_payload_size = Signal(16, reset=128)
        self.comb += [
            convert_size(tl.cfg.mrrs, max_request_size),
            convert_size(tl.cfg.mps,  max_payload_size),
        ]
        self.specials += [
            MultiReg(tl.id,            self.id,                odomain=cd, reset=0),
            MultiReg(max_request_size, self.max_request_size,  odomain=cd, reset=512),
            MultiReg(max_payload_size, self.max_payload_size,  odomain=cd, reset=128),
            MultiReg(dll.dl_active,    self._link_status.fields.status, "sys"),
            MultiReg(phy.ltssm.state,  self._link_status.fields.ltssm,  "sys"),
            MultiReg(phy.ltssm.rate,   self._link_status.fields.rate,   "sys"),
            MultiReg(tl.cfg.msi_enable, self._msi_enable.status,        "sys"),
            MultiReg(tl.cfg.bme,        self._bus_master_enable.status, "sys"),
            MultiReg(max_request_size,  self._max_request_size.status,  "sys"),
            MultiReg(max_payload_size,  self._max_payload_size.status,  "sys"),
        ]

    # Timing Constraints ---------------------------------------------------------------------------
    def add_timing_constraints(self, sys_clk):
        self.serdes.add_timing_constraints(sys_clk)

    # Debug ----------------------------------------------------------------------------------------
    def add_debug(self, enable_reset=0):
        """Optional bring-up CSRs (LTSSM enable/retrain, status, counters), see doc/softphy.md. Without
        them the LTSSM starts on its own; with them it waits for the enable CSR (enable_reset=0)."""
        from litepcie.phy.soft.debug import SoftPHYDebug
        self.debug = SoftPHYDebug(self.phy_layer, self.serdes, with_tracer=False, enable_reset=enable_reset, dll=self.dll)

    # LTSSM Tracer ---------------------------------------------------------------------------------
    def add_ltssm_tracer(self):
        """Optional LTSSM state history (128 entries), as the hard-IP PHYs."""
        self.ltssm_tracer = LTSSMTracer(self._link_status.fields.ltssm)
