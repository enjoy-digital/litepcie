#
# This file is part of LitePCIe.
#
# Copyright (c) 2024-2025 Enjoy-Digital <enjoy-digital.fr>
#
# SPDX-License-Identifier: BSD-2-Clause

# Use latticesemi.com_ip_pcie_x4_1.1.0
# FIXME: switch to 2.3.0

import os
from shutil import which
import subprocess

from migen import *

from litex.gen import *

from litex.soc.interconnect import axi
from litex.soc.interconnect.csr import *

from litepcie.common import *
from litepcie.tlp.common import *
from litepcie.phy.common import *

# LFCPNXPCIEPHY ------------------------------------------------------------------------------------

class LFCPNXPCIEPHY(LiteXModule):
    endianness = "big"
    qword_aligned = False
    lmmi_layout = [
        ("request",      1),
        ("wr_rdn",       1),
        ("wdata",       32),
        ("offset",      15),
        ("rdata",       64),
        ("rdata_valid",  5),
        ("ready",        5),
    ]

    def __init__(self, platform, pads, data_width=128, pcie_data_width=128, cd="pcie", bar0_size=65536):
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
            CSRField("ltssm", size=6, description="LTSSM State"),
        ])
        self._msi_enable        = CSRStatus(description="MSI Enable Status. ``1``: MSI is enabled.")
        self._msix_enable       = CSRStatus(description="MSI-X Enable Status. ``1``: MSI-X is enabled.")

        # Parameters/Locals ------------------------------------------------------------------------
        self.platform   = platform
        self.perst_n_i  = pads.perst
        self.data_width = data_width
        self.pcie_data_width = pcie_data_width
        self.id         = Signal(16, reset_less=True)
        self.bar0_size  = bar0_size
        self.bar0_mask  = get_bar_mask(bar0_size)

        self.max_request_size = Signal(16, reset=128) # FIXME.
        self.max_payload_size = Signal(16, reset=128) # FIXME.

        # # #

        completer_id = Signal(16)
        nlanes = len(pads.tx_p)

        assert data_width in [64, 128]
        assert pcie_data_width == 128
        assert nlanes in [4]

        self.comb += self.id.eq(completer_id)

        # Clocking / Reset -------------------------------------------------------------------------
        sys_clk  = platform.request("clkin125")
        pcie_clk = Signal()
        self.cd_pcie = ClockDomain()
        self.comb += self.cd_pcie.clk.eq(pcie_clk)

        # Link Status ------------------------------------------------------------------------------
        link_up          = Signal()
        link0_pl_link_up = Signal()
        link0_dl_link_up = Signal()
        link0_tl_link_up = Signal()
        self.comb += [
            link_up.eq(link0_pl_link_up & link0_dl_link_up & link0_tl_link_up),
            self._link_status.fields.status.eq(link_up),
        ]

        # TX (FPGA --> HOST) CDC / Data Width Conversion -------------------------------------------
        tx_data_p = Signal(pcie_data_width//8)
        self.tx_datapath = PHYTXDatapath(
            core_data_width = data_width,
            pcie_data_width = pcie_data_width,
            clock_domain    = cd,
        )
        self.comb += self.sink.connect(self.tx_datapath.sink, omit={"dat", "be"})
        self.comb += dword_endianness_swap(
            src        = self.sink.dat,
            dst        = self.tx_datapath.sink.dat,
            data_width = data_width,
            endianness = "big",
            mode       = "dat",
        )
        self.comb += dword_endianness_swap(
            src        = self.sink.be,
            dst        = self.tx_datapath.sink.be,
            data_width = data_width,
            endianness = "big",
            mode       = "be",
        )
        self.s_axis_tx = s_axis_tx = self.tx_datapath.source

        for i in range(pcie_data_width//8):
            self.comb += tx_data_p[i].eq(Reduce("XOR", self.s_axis_tx.dat[i*8:(i+1)*8]))

        # RX (HOST --> FPGA) CDC / Data Width Conversion -------------------------------------------
        self.rx_datapath = PHYRXDatapath(
            core_data_width = data_width,
            pcie_data_width = pcie_data_width,
            clock_domain    = cd,
        )
        rx_sop = Signal()
        self.m_axis_rx = m_axis_rx = self.rx_datapath.sink
        self.comb += [
            m_axis_rx.first.eq(rx_sop),
            m_axis_rx.be.eq(2**len(m_axis_rx.be) - 1),
        ]
        self.comb += self.rx_datapath.source.connect(self.source, omit={"dat", "be"})
        self.comb += dword_endianness_swap(
            src        = self.rx_datapath.source.dat,
            dst        = self.source.dat,
            data_width = data_width,
            endianness = "big",
            mode       = "dat",
        )
        self.comb += dword_endianness_swap(
            src        = self.rx_datapath.source.be, # FIXME: Should be adapted.
            dst        = self.source.be,
            data_width = data_width,
            endianness = "big",
            mode       = "be",
        )

        # LMMI (Configuration) ---------------------------------------------------------------------
        usr_lmmi         = Record(self.lmmi_layout)
        lmmi_app         = Record(self.lmmi_layout)
        lmmi_fixup       = Record(self.lmmi_layout)
        usr_lmmi_resetn  = Signal(1, reset_less=True)
        lmmi_app_done    = Signal()
        lmmi_fixup_done  = Signal()
        config_done      = Signal()
        self.sync.pcie += If(~pads.perst, usr_lmmi_resetn.eq(0)).Else(usr_lmmi_resetn.eq(1))
        self.comb += [
            lmmi_app.rdata.eq(usr_lmmi.rdata),
            lmmi_app.rdata_valid.eq(usr_lmmi.rdata_valid),
            lmmi_app.ready.eq(usr_lmmi.ready),
            lmmi_fixup.rdata.eq(usr_lmmi.rdata),
            lmmi_fixup.rdata_valid.eq(usr_lmmi.rdata_valid),
            lmmi_fixup.ready.eq(usr_lmmi.ready),
            config_done.eq(lmmi_app_done & lmmi_fixup_done),
            If(lmmi_app_done & ~lmmi_fixup_done,
                usr_lmmi.request.eq(lmmi_fixup.request),
                usr_lmmi.wr_rdn.eq( lmmi_fixup.wr_rdn),
                usr_lmmi.wdata.eq(  lmmi_fixup.wdata),
                usr_lmmi.offset.eq( lmmi_fixup.offset),
            ).Else(
                usr_lmmi.request.eq(lmmi_app.request),
                usr_lmmi.wr_rdn.eq( lmmi_app.wr_rdn),
                usr_lmmi.wdata.eq(  lmmi_app.wdata),
                usr_lmmi.offset.eq( lmmi_app.offset),
            )
        ]

        # Lattice's raw TLP wrapper exposes MSI-X capability registers, but the
        # generated IP defaults do not match LitePCIe's standalone CSR map.
        lmmi_fixup_index  = Signal(max=3)
        lmmi_fixup_active = Signal()
        lmmi_fixup_wdata  = Signal(32)
        lmmi_fixup_offset = Signal(15)
        self.comb += [
            lmmi_fixup_active.eq(lmmi_app_done & ~lmmi_fixup_done),
            lmmi_fixup.wr_rdn.eq(1),
            lmmi_fixup.wdata.eq(lmmi_fixup_wdata),
            lmmi_fixup.offset.eq(lmmi_fixup_offset),
            Case(lmmi_fixup_index, {
                # Disable MSI capability since this raw TLP wrapper has no MSI request/ack pins.
                0 : [
                    lmmi_fixup_offset.eq(0x040e8 >> 2),
                    lmmi_fixup_wdata.eq(0x0000_0001),
                ],
                # MSI-X Table and PBA offsets must match the LitePCIe standalone CSR map.
                1 : [
                    lmmi_fixup_offset.eq(0x040f4 >> 2),
                    lmmi_fixup_wdata.eq(0x0000_2000),
                ],
                2 : [
                    lmmi_fixup_offset.eq(0x040f8 >> 2),
                    lmmi_fixup_wdata.eq(0x0000_1808),
                ],
            })
        ]
        lmmi_fixup_state = Signal(2)
        self.comb += lmmi_fixup.request.eq(lmmi_fixup_active & (lmmi_fixup_state != 0))
        self.sync.pcie += [
            If(~lmmi_app_done,
                lmmi_fixup_index.eq(0),
                lmmi_fixup_state.eq(0),
                lmmi_fixup_done.eq(0),
            ).Elif(~lmmi_fixup_done,
                Case(lmmi_fixup_state, {
                    0 : lmmi_fixup_state.eq(1),
                    1 : lmmi_fixup_state.eq(2),
                    2 : If(lmmi_fixup.ready[0],
                        If(lmmi_fixup_index == 2,
                            lmmi_fixup_done.eq(1),
                        ).Else(
                            lmmi_fixup_index.eq(lmmi_fixup_index + 1),
                            lmmi_fixup_state.eq(0),
                        )
                    ),
                })
            )
        ]

        self.ip_params      = dict()
        self.lmmi_ip_params = dict()

        # PCIe hard IP -----------------------------------------------------------------------------

        self.ip_params.update(    
            # PCI Express Interface ----------------------------------------------------------------
            # Clk/Rst
            i_refclkp_i                         = pads.clk_p,
            i_refclkn_i                         = pads.clk_n,

            # TX
            o_link0_txp_o                       = pads.tx_p,
            o_link0_txn_o                       = pads.tx_n,

            # RX
            i_link0_rxp_i                       = pads.rx_p,
            i_link0_rxn_i                       = pads.rx_n,

            i_refret_i                          = pads.refret,
            i_rext_i                            = pads.rext,
            i_sys_clk_i                         = sys_clk,
            i_link0_aux_clk_i                   = sys_clk,
            i_link0_perst_n_i                   = pads.perst,
            i_link0_rst_usr_n_i                 = config_done,
            o_link0_clk_usr_o                   = pcie_clk,
            o_link0_pl_link_up_o                = link0_pl_link_up,
            o_link0_dl_link_up_o                = link0_dl_link_up,
            o_link0_tl_link_up_o                = link0_tl_link_up,
                
            i_link0_user_aux_power_detected_i   = Constant(0, 1),
            i_link0_user_transactions_pending_i = Constant(0, 1),

            # TLP Receive Interface ----------------------------------------------------------------
            # TLP Receive Interface Ports
            i_link0_rx_ready_i                  = m_axis_rx.ready,
            o_link0_rx_valid_o                  = m_axis_rx.valid,
            o_link0_rx_sel_o                    = Open(2),
            o_link0_rx_cmd_data_o               = Open(13),
            o_link0_rx_sop_o                    = rx_sop,
            o_link0_rx_data_o                   = m_axis_rx.dat,
            o_link0_rx_datap_o                  = Open(16),
            o_link0_rx_eop_o                    = m_axis_rx.last,
            o_link0_rx_err_ecrc_o               = Open(),
            o_link0_rx_f_o                      = Open(2),

            # TLP Receive Credit Interface Ports
            i_link0_rx_credit_init_i            = Constant(1, 1),
            i_link0_rx_credit_nh_i              = Constant(0, 12),
            i_link0_rx_credit_nh_inf_i          = Constant(1, 1),
            i_link0_rx_credit_return_i          = Constant(1, 1),
        
            # TLP Transmit Interface ---------------------------------------------------------------
            # TLP Transmit Interface Ports
            i_link0_tx_valid_i                  = s_axis_tx.valid,
            i_link0_tx_eop_i                    = s_axis_tx.last,
            i_link0_tx_eop_n_i                  = Constant(0, 1),
            i_link0_tx_sop_i                    = s_axis_tx.first, # CHECKME/FIXME: Verify it's generated by LitePCie.
            i_link0_tx_data_i                   = s_axis_tx.dat,
            i_link0_tx_datap_i                  = tx_data_p,
            o_link0_tx_ready_o                  = s_axis_tx.ready,

            # TLP Transmit Credit Interface Ports
            o_link0_tx_credit_init_o            = Open(),
            o_link0_tx_credit_return_o          = Open(),
            o_link0_tx_credit_nh_o              = Open(12),

            # Lattice Memory Mapped Interface (LMMI) -----------------------------------------------
            i_usr_lmmi_clk_i                    = ClockSignal("pcie"),
            i_usr_lmmi_resetn_i                 = usr_lmmi_resetn,
            i_usr_lmmi_request_i                = Cat(usr_lmmi.request, Constant(0, 4)),
            i_usr_lmmi_wr_rdn_i                 = usr_lmmi.wr_rdn,
            i_usr_lmmi_wdata_i                  = usr_lmmi.wdata,
            i_usr_lmmi_offset_i                 = Cat(Constant(0, 2), usr_lmmi.offset),
            o_usr_lmmi_rdata_o                  = usr_lmmi.rdata,
            o_usr_lmmi_rdata_valid_o            = usr_lmmi.rdata_valid,
            o_usr_lmmi_ready_o                  = usr_lmmi.ready,
                
            i_ucfg_link_i                       = Constant(0, 1),
            i_ucfg_valid_i                      = Constant(0, 1),
            i_ucfg_wr_rd_n_i                    = Constant(0, 1),
            i_ucfg_addr_i                       = Constant(0, 10),
            i_ucfg_f_i                          = Constant(0, 3),
            i_ucfg_wr_be_i                      = Constant(0, 4),
            i_ucfg_wr_data_i                    = Constant(0, 32),
            o_ucfg_rd_data_o                    = Open(32),
            o_ucfg_rd_done_o                    = Open(2),
            o_ucfg_ready_o                      = Open(),
        )

        self.lmmi_ip_params.update(
            # Clk/Rst
            i_clk                    = ClockSignal("pcie"),
            i_rst_n                  = usr_lmmi_resetn,

            # LMMI interface
            o_usr_lmmi_request_o     = lmmi_app.request,
            o_usr_lmmi_wr_rdn_o      = lmmi_app.wr_rdn,
            o_usr_lmmi_wdata_o       = lmmi_app.wdata,
            o_usr_lmmi_offset_o      = lmmi_app.offset,
            i_usr_lmmi_rdata_i       = lmmi_app.rdata[0:32],
            i_usr_lmmi_rdata_valid_i = lmmi_app.rdata_valid[0],
            i_usr_lmmi_ready_i       = lmmi_app.ready[0],

            # completer id for tx engine
            o_completer_id_o         = completer_id,
            o_config_done            = lmmi_app_done,
        )

    # Finalize -------------------------------------------------------------------------------------
    def do_finalize(self):
        src_dir = os.path.join(self.platform.output_dir, "lfcpnxpciephy")
        src_zip = os.path.join(self.platform.output_dir, "lfcpnxpciephy.zip")
        url     = "https://github.com/user-attachments/files/18943678/lfcpnxpciephy.zip"
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

        self.platform.add_source(os.path.join(src_dir, "rtl", "lfcpnxpciephy.v"))
        self.platform.add_source(os.path.join(src_dir, "LMMI_app.v"))

        self.specials += [
            Instance("lfcpnxpciephy", **self.ip_params),
            Instance("LMMI_app",      **self.lmmi_ip_params),
            Instance("GSR",
                i_CLK   = ClockSignal("pcie"),
                i_GSR_N = self.perst_n_i,
            )
        ]
