#
# This file is part of LiteX.
#
# Copyright (c) 2024-2025 Enjoy-Digital <enjoy-digital.fr>
#
# SPDX-License-Identifier: BSD-2-Clause

import os
from shutil import which
import subprocess

from migen import *

from litex.gen import *

from litex.soc.interconnect import axi
from litex.soc.interconnect.csr import *

from litepcie.common import *
from litepcie.phy.common import *

# GW5APCIEPHY --------------------------------------------------------------------------------------

class GW5APCIEPHY(LiteXModule):
    endianness = "big" # CHECKME.

    def __init__(self, platform, pads, nlanes=1, data_width=256, cd="sys", bar0_size=0x100000):
        # Streams ---------------------------------------------------------------------------------
        self.sink   = stream.Endpoint(phy_layout(data_width))
        self.source = stream.Endpoint(phy_layout(data_width))
        self.msi    = stream.Endpoint(msi_layout()) # FIXME: Connect.

        # Registers --------------------------------------------------------------------------------
        self._link_status = CSRStatus(fields=[
            CSRField("status", size=1, values=[
                ("``0b0``", "Link Down."),
                ("``0b1``", "Link Up."),
            ]),
            CSRField("rate", size=1, values=[
                ("``0b0``", "2.5 Gb/s."),
                ("``0b1``", "5.0 Gb/s."),
            ]),
            CSRField("width", size=2, values=[
                ("``0b00``", "1-Lane link."),
                ("``0b01``", "2-Lane link."),
                ("``0b10``", "4-Lane link."),
                ("``0b11``", "8-Lane link."),
            ]),
            CSRField("ltssm", size=5, description="LTSSM State"),
        ])

        self._msi_enable  = CSRStatus(description="MSI Enable Status. ``1``: MSI is enabled.")
        self._msix_enable = CSRStatus(description="MSI-X Enable Status. ``1``: MSI-X is enabled.")

        self._tl_cfg_busdev    = CSRStatus(13,
            description="Bus Number and DeviceNumber information for PCIe devices.")
        self._tl_rx_bardec     = CSRStatus(6, description="Target BAR decoding.")
        self._tl_rx_err        = CSRStatus(8, description="Receive data error signal.")
        self._tl_tx_creditsp   = CSRStatus(32,
            description="Posted TLP controls the number of credits sent.")
        self._tl_tx_creditsnp  = CSRStatus(32,
            description="Non-Posted TLP controls the number of credits sent.")
        self._tl_tx_creditscpl = CSRStatus(32,
            description="Completion TLP controls the number of credits sent.")

        self.comb += [
            self._msi_enable.status.eq(1),
            self._msix_enable.status.eq(0),
        ]

        # Parameters/Locals ------------------------------------------------------------------------
        self.platform         = platform
        pcie_data_width       = data_width
        self.data_width       = data_width
        self.id               = Signal(16, reset_less=True) # FIXME: Todo
        self.bar0_size        = bar0_size
        self.bar0_mask        = get_bar_mask(bar0_size)

        self.max_request_size = Signal(16, reset=256) # FIXME.
        self.max_payload_size = Signal(16, reset=256) # FIXME.

        # # #

        self.nlanes = nlanes

        assert nlanes in [1, 4]

        # Clocking / Reset -------------------------------------------------------------------------
        self.cd_pcie = ClockDomain()
        self.comb += [
            self.cd_pcie.clk.eq(ClockSignal("crg_pcie")),
            self.cd_pcie.rst.eq(~pads.rst_n),
        ]

        if hasattr(pads, "wake_n"):
            self.comb += pads.wake_n.eq(0)

        # TX (FPGA --> HOST) CDC / Data Width Conversion -------------------------------------------
        tl_tx_ready      = Signal()
        tl_tx_valid      = Signal(8)

        self.tx_datapath = PHYTXDatapath(
            core_data_width = data_width,
            pcie_data_width = pcie_data_width,
            clock_domain    = cd)
        s_axis_tx = self.tx_datapath.source
        self.comb += [
            self.sink.connect(self.tx_datapath.sink, omit={"dat"}),
            s_axis_tx.ready.eq(~tl_tx_ready),
        ]
        for i in range(8):
            self.comb += tl_tx_valid[7-i].eq(Reduce("OR", s_axis_tx.be[i*4:(i+1)*4]) & s_axis_tx.valid)

        self.comb += self.swap_dwords(self.sink.dat, self.tx_datapath.sink.dat)

        # RX (HOST --> FPGA) CDC / Data Width Conversion -------------------------------------------
        tl_rx_valid      = Signal(8)

        self.rx_datapath = PHYRXDatapath(
            core_data_width = data_width,
            pcie_data_width = pcie_data_width,
            clock_domain    = cd)
        m_axis_rx = self.rx_datapath.sink
        self.comb += [
            self.rx_datapath.source.connect(self.source, omit={"dat"}),
            m_axis_rx.valid.eq(Reduce("OR", tl_rx_valid)), # FIXME: need something more clever
        ]
        for i in range(8):
            self.comb += m_axis_rx.be[i*4: (i+1)*4].eq(Replicate(tl_rx_valid[7-i], 4))

        self.comb += self.swap_dwords(self.rx_datapath.source.dat, self.source.dat)

        # MSI CDC (FPGA --> HOST) ------------------------------------------------------------------
        msi_int_status = Signal()
        msi_req        = Signal()
        msi_dat        = Signal(5)
        msi_valid_d    = Signal()
        if cd == "pcie":
            cfg_msi = self.msi
        else:
            self.msi_cdc = msi_cdc = stream.ClockDomainCrossing(
                layout          = msi_layout(),
                cd_from         = cd,
                cd_to           = "pcie",
                with_common_rst = True,
            )
            self.comb += self.msi.connect(msi_cdc.sink)
            cfg_msi = msi_cdc.source

        self.comb += msi_int_status.eq(cfg_msi.valid)
        self.comb += msi_req.eq(cfg_msi.valid & ~msi_valid_d)
        self.comb += msi_dat.eq(Cat(msi_req, Constant(0, 4)))
        self.sync.pcie += msi_valid_d.eq(cfg_msi.valid)

        # PCIe hard IP -----------------------------------------------------------------------------

        self.ip_params = dict()
        self.ip_params.update(    
            # PCI Express Interface ----------------------------------------------------------------
            # Clk/Rst
            i_PCIE_Controller_Top_pcie_rstn_i             = ~ResetSignal("pcie"),
            i_PCIE_Controller_Top_pcie_tl_clk_i           = ClockSignal("pcie"),

            # Control
            o_PCIE_Controller_Top_pcie_linkup_o           = self.add_resync(self._link_status.fields.status, "sys"),
            o_PCIE_Controller_Top_pcie_ltssm_o            = self.add_resync(self._link_status.fields.ltssm,  "sys"),
            o_PCIE_Controller_Top_pcie_tl_cfg_busdev_o    = self.add_resync(self._tl_cfg_busdev.status,      "sys"),

            # TLP Receive Interface ----------------------------------------------------------------
            # TLP Receive Interface Ports
            i_PCIE_Controller_Top_pcie_tl_rx_wait_i       = ~m_axis_rx.ready,
            o_PCIE_Controller_Top_pcie_tl_rx_valid_o      = tl_rx_valid,
            o_PCIE_Controller_Top_pcie_tl_rx_bardec_o     = self.add_resync(self._tl_rx_bardec.status, "sys"),
            o_PCIE_Controller_Top_pcie_tl_rx_sop_o        = m_axis_rx.first,
            o_PCIE_Controller_Top_pcie_tl_rx_data_o       = m_axis_rx.dat,
            o_PCIE_Controller_Top_pcie_tl_rx_eop_o        = m_axis_rx.last,
            i_PCIE_Controller_Top_pcie_tl_rx_masknp_i     = Constant(0, 1),
            o_PCIE_Controller_Top_pcie_tl_rx_err_o        = self.add_resync(self._tl_rx_err.status, "sys"),

            # TLP Transmit Interface ---------------------------------------------------------------
            # TLP Transmit Interface Ports
            i_PCIE_Controller_Top_pcie_tl_tx_valid_i      = tl_tx_valid,
            i_PCIE_Controller_Top_pcie_tl_tx_eop_i        = s_axis_tx.last,
            i_PCIE_Controller_Top_pcie_tl_tx_sop_i        = s_axis_tx.first, # CHECKME/FIXME: Verify it's generated by LitePCie.
            i_PCIE_Controller_Top_pcie_tl_tx_data_i       = s_axis_tx.dat,
            o_PCIE_Controller_Top_pcie_tl_tx_wait_o       = tl_tx_ready,
            # TLP Transmit Credit Interface Ports
            o_PCIE_Controller_Top_pcie_tl_tx_creditsp_o   = self.add_resync(self._tl_tx_creditsp.status,   "sys"),
            o_PCIE_Controller_Top_pcie_tl_tx_creditsnp_o  = self.add_resync(self._tl_tx_creditsnp.status,  "sys"),
            o_PCIE_Controller_Top_pcie_tl_tx_creditscpl_o = self.add_resync(self._tl_tx_creditscpl.status, "sys"),

            # DRP ----------------------------------------------------------------------------------
            o_PCIE_Controller_Top_pcie_tl_drp_clk_o       = Open(),
            o_PCIE_Controller_Top_pcie_tl_drp_rddata_o    = Open(32),
            o_PCIE_Controller_Top_pcie_tl_drp_resp_o      = Open(),
            o_PCIE_Controller_Top_pcie_tl_drp_rd_valid_o  = Open(),
            o_PCIE_Controller_Top_pcie_tl_drp_ready_o     = Open(),
            i_PCIE_Controller_Top_pcie_tl_drp_addr_i      = Constant(0, 24),
            i_PCIE_Controller_Top_pcie_tl_drp_wrdata_i    = Constant(0, 32),
            i_PCIE_Controller_Top_pcie_tl_drp_strb_i      = Constant(0,  8),
            i_PCIE_Controller_Top_pcie_tl_drp_wr_i        = Constant(0,  1),
            i_PCIE_Controller_Top_pcie_tl_drp_rd_i        = Constant(0,  1),

            # MSI
            o_PCIE_Controller_Top_pcie_tl_int_ack_o       = cfg_msi.ready,
            i_PCIE_Controller_Top_pcie_tl_int_status_i    = msi_int_status,
            i_PCIE_Controller_Top_pcie_tl_int_req_i       = msi_req,
            i_PCIE_Controller_Top_pcie_tl_int_msinum_i    = msi_dat,
        )

        if nlanes == 1:
            self.ip_params.update(
                # Unused/undocumented
                i_gpio_refclk3_i = Constant(0, 1),
                i_gpio_refclk2_i = Constant(0, 1),
                i_gpio_refclk1_i = Constant(0, 1),
                i_gpio_refclk0_i = Constant(0, 1),
            )

    # Data Ordering Helper -------------------------------------------------------------------------
    def swap_dwords(self, src, dst):
        assert len(src) == len(dst)
        ndwords = len(src)//32
        r = []
        for i in range(ndwords):
            r.append(dst[i*32:(i + 1)*32].eq(src[(ndwords - i - 1)*32:(ndwords - i - 0)*32]))
        return r

    # Resync Helper --------------------------------------------------------------------------------
    def add_resync(self, sig, clk="sys"):
        _sig = Signal.like(sig)
        self.specials += MultiReg(_sig, sig, clk)
        return _sig

    # Finalize -------------------------------------------------------------------------------------
    def do_finalize(self):
        src_dir = os.path.join(self.platform.output_dir, "gw5apciephy")
        src_zip = os.path.join(self.platform.output_dir, "gw5apciephy.zip")
        url     = "https://github.com/user-attachments/files/18846086/gw5apciephy.zip"
        if not os.path.exists(src_dir):
            # If zip archive is not available
            if not os.path.exists(src_zip):
                # Download archive.
                # Build the wget command
                command = ["wget", "-O" , src_zip, url]
                try:
                    print(f"Downloading {url}...")
                    # Execute the wget command
                    result = subprocess.run(command, check=True)
                    print(f"Downloaded {src_zip} successfully!")
                except subprocess.CalledProcessError as e:
                    print(f"Failed to download {url}. Error: {e}")
                except FileNotFoundError:
                    print("The 'wget' command is not available. Please install wget and try again.")

            # Extract archive.
            # Build the wget command
            command = ["unzip", src_zip, "-d" , self.platform.output_dir]
            try:
                print(f"Unzipping {src_zip}...")
                # Execute the wget command
                result = subprocess.run(command, check=True)
                print(f"Unzipped {src_zip} successfully!")
            except subprocess.CalledProcessError as e:
                print(f"Failed to unzip {src_zip}. Error: {e}")
            except FileNotFoundError:
                print("The 'unzip' command is not available. Please install unzip and try again.")

        src_dir = os.path.join(src_dir, f"gw5apciephyx{self.nlanes}")

        self.platform.add_source(os.path.join(src_dir, "gw5apciephy.v"))
        self.platform.add_source(os.path.join(src_dir, "pcie_controller", "pcie_controller.v"))
        self.platform.add_source(os.path.join(src_dir, "upar_arbiter",    "upar_arbiter.v"))

        self.specials += Instance("GW5APCIEPHY_Top", **self.ip_params)
