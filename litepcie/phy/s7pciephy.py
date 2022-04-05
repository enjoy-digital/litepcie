#
# This file is part of LitePCIe.
#
# Copyright (c) 2015-2020 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import os

from migen import *
from migen.genlib.cdc import MultiReg

from litex.soc.interconnect.csr import *

from litepcie.common import *
from litepcie.phy.common import *

# S7PCIEPHY ----------------------------------------------------------------------------------------

class S7PCIEPHY(Module, AutoCSR):
    endianness    = "big"
    qword_aligned = False
    def __init__(self, platform, pads, data_width=64, bar0_size=1*MB, cd="sys", pcie_data_width=None):
        # Streams ----------------------------------------------------------------------------------
        self.sink   = stream.Endpoint(phy_layout(data_width))
        self.source = stream.Endpoint(phy_layout(data_width))
        self.msi    = stream.Endpoint(msi_layout())

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
        self._bus_master_enable = CSRStatus(description="Bus Mastering Status. ``1``: Bus Mastering enabled.")
        self._max_request_size  = CSRStatus(16, description="Negiotiated Max Request Size (in bytes).")
        self._max_payload_size  = CSRStatus(16, description="Negiotiated Max Payload Size (in bytes).")

        # Parameters/Locals ------------------------------------------------------------------------
        if pcie_data_width is None: pcie_data_width = data_width
        self.platform         = platform
        self.data_width       = data_width
        self.pcie_data_width  = pcie_data_width

        self.id               = Signal(16, reset_less=True)
        self.bar0_size        = bar0_size
        self.bar0_mask        = get_bar_mask(bar0_size)
        self.max_request_size = Signal(16, reset_less=True)
        self.max_payload_size = Signal(16, reset_less=True)

        self.external_hard_ip = False

        # # #

        self.nlanes = nlanes = len(pads.tx_p)

        assert nlanes          in [1, 2, 4, 8]
        assert data_width      in [64, 128]
        assert pcie_data_width in [64, 128]

        # Clocking / Reset -------------------------------------------------------------------------
        self.pcie_refclk = pcie_refclk = Signal()
        self.pcie_rst_n  = pcie_rst_n  = Signal(reset=1)
        if hasattr(pads, "rst_n"):
            self.comb += pcie_rst_n.eq(pads.rst_n)
        self.specials += Instance("IBUFDS_GTE2",
            i_CEB = 0,
            i_I   = pads.clk_p,
            i_IB  = pads.clk_n,
            o_O   = pcie_refclk
        )
        platform.add_period_constraint(pads.clk_p, 1e9/100e6)
        self.clock_domains.cd_pcie = ClockDomain()
        pcie_clk_freq = max(125e6, nlanes*62.5e6*64/pcie_data_width)

        # TX (FPGA --> HOST) CDC / Data Width Conversion -------------------------------------------
        self.submodules.tx_datapath = PHYTXDatapath(
            core_data_width = data_width,
            pcie_data_width = pcie_data_width,
            clock_domain    = cd)
        self.comb += self.sink.connect(self.tx_datapath.sink)
        s_axis_tx = self.tx_datapath.source

        # RX (HOST --> FPGA) CDC / Data Width Conversion -------------------------------------------
        self.submodules.rx_datapath = PHYRXDatapath(
            core_data_width = data_width,
            pcie_data_width = pcie_data_width,
            clock_domain    = cd,
            with_aligner    = True)
        m_axis_rx = self.rx_datapath.sink
        self.comb += self.rx_datapath.source.connect(self.source)

        # MSI CDC (FPGA --> HOST) ------------------------------------------------------------------
        if cd == "pcie":
            cfg_msi = self.msi
        else:
            self.submodules.msi_cdc = msi_cdc = stream.ClockDomainCrossing(
                layout          = msi_layout(),
                cd_from         = cd,
                cd_to           = "pcie",
                with_common_rst = True
            )
            self.comb += self.msi.connect(msi_cdc.sink)
            cfg_msi = msi_cdc.source

        # Hard IP Configuration --------------------------------------------------------------------
        def convert_size(command, size, max_size):
            cases = {}
            value = 128
            for i in range(6):
                cases[i] = size.eq(value)
                value = min(value*2, max_size)
            return Case(command, cases)

        bus_number      = Signal(8)
        device_number   = Signal(5)
        function_number = Signal(3)
        command         = Signal(16)
        dcommand        = Signal(16)
        self.sync.pcie += [
            convert_size(dcommand[12:15], self.max_request_size, max_size=512),
            convert_size(dcommand[5:8],   self.max_payload_size, max_size=512),
            self.id.eq(Cat(function_number, device_number, bus_number))
        ]
        self.specials += [
            MultiReg(command[2],            self._bus_master_enable.status),
            MultiReg(self.max_request_size, self._max_request_size.status),
            MultiReg(self.max_payload_size, self._max_payload_size.status)
        ]

        # Hard IP ----------------------------------------------------------------------------------
        class Open(Signal): pass
        m_axis_rx_tlast = Signal()
        m_axis_rx_tuser = Signal(32)
        self.pcie_gt_device  = {"xc7a": "GTP", "xc7k": "GTX", "xc7v": "GTX"}[platform.device[:4]]
        self.pcie_phy_params = dict(
            # Parameters ---------------------------------------------------------------------------
            p_LINK_CAP_MAX_LINK_WIDTH = nlanes,
            p_C_DATA_WIDTH            = pcie_data_width,
            p_KEEP_WIDTH              = pcie_data_width//8,
            p_PCIE_REFCLK_FREQ        = 0, # 100MHz refclk
            p_PCIE_USERCLK1_FREQ      = 3 if nlanes <= 2 else 4,
            p_PCIE_USERCLK2_FREQ      = 3 if (pcie_clk_freq == 125e6) else 4,
            p_PCIE_GT_DEVICE          = self.pcie_gt_device,

            # PCI Express Interface ----------------------------------------------------------------
            # Clk/Rst
            i_sys_clk     = pcie_refclk,
            i_sys_rst_n   = pcie_rst_n,

            # TX
            o_pci_exp_txp = pads.tx_p,
            o_pci_exp_txn = pads.tx_n,

            # RX
            i_pci_exp_rxp = pads.rx_p,
            i_pci_exp_rxn = pads.rx_n,

            # Clocking Sharing Interface -----------------------------------------------------------
            o_pipe_pclk_out_slave = Open(),
            o_pipe_rxusrclk_out   = Open(),
            o_pipe_rxoutclk_out   = Open(),
            o_pipe_dclk_out       = Open(),
            o_pipe_userclk1_out   = Open(),
            o_pipe_userclk2_out   = Open(),
            o_pipe_oobclk_out     = Open(),
            o_pipe_mmcm_lock_out  = Open(),
            i_pipe_pclk_sel_slave = 0b00,
            i_pipe_mmcm_rst_n     = 1,

            # AXI-S Interface ----------------------------------------------------------------------
            # Common
            o_user_clk_out     = ClockSignal("pcie"),
            o_user_reset_out   = ResetSignal("pcie"),
            o_user_lnk_up      = self._link_status.fields.status,
            o_user_app_rdy     = Open(),

            # TX
            o_tx_buf_av        = Open(),
            o_tx_err_drop      = Open(),
            o_tx_cfg_req       = Open(),
            i_tx_cfg_gnt       = 1,
            i_s_axis_tx_tvalid = s_axis_tx.valid,
            i_s_axis_tx_tlast  = s_axis_tx.last,
            o_s_axis_tx_tready = s_axis_tx.ready,
            i_s_axis_tx_tdata  = s_axis_tx.dat,
            i_s_axis_tx_tkeep  = s_axis_tx.be,
            i_s_axis_tx_tuser  = 0,

            # RX
            i_rx_np_ok         = 1,
            i_rx_np_req        = 1,
            o_m_axis_rx_tvalid = m_axis_rx.valid,
            o_m_axis_rx_tlast  = m_axis_rx_tlast,
            i_m_axis_rx_tready = m_axis_rx.ready,
            o_m_axis_rx_tdata  = m_axis_rx.dat,
            o_m_axis_rx_tkeep  = m_axis_rx.be,
            o_m_axis_rx_tuser  = m_axis_rx_tuser,

            # Flow Control
            o_fc_cpld          = Open(),
            o_fc_cplh          = Open(),
            o_fc_npd           = Open(),
            o_fc_nph           = Open(),
            o_fc_pd            = Open(),
            o_fc_ph            = Open(),
            i_fc_sel           = 0,

            # Management Interface -----------------------------------------------------------------
            o_cfg_mgmt_do            = Open(),
            o_cfg_mgmt_rd_wr_done    = Open(),
            i_cfg_mgmt_di            = 0,
            i_cfg_mgmt_byte_en       = 0,
            i_cfg_mgmt_dwaddr        = 0,
            i_cfg_mgmt_wr_en         = 0,
            i_cfg_mgmt_rd_en         = 0,
            i_cfg_mgmt_wr_readonly   = 0,
            i_cfg_mgmt_wr_rw1c_as_rw = 0,

            # Error Reporting Interface ------------------------------------------------------------
            i_cfg_err_ecrc                  = 0,
            i_cfg_err_ur                    = 0,
            i_cfg_err_cpl_timeout           = 0,
            i_cfg_err_cpl_unexpect          = 0,
            i_cfg_err_cpl_abort             = 0,
            i_cfg_err_posted                = 0,
            i_cfg_err_cor                   = 0,
            i_cfg_err_atomic_egress_blocked = 0,
            i_cfg_err_internal_cor          = 0,
            i_cfg_err_malformed             = 0,
            i_cfg_err_mc_blocked            = 0,
            i_cfg_err_poisoned              = 0,
            i_cfg_err_norecovery            = 0,
            i_cfg_err_tlp_cpl_header        = 0,
            o_cfg_err_cpl_rdy               = Open(),
            i_cfg_err_locked                = 0,
            i_cfg_err_acs                   = 0,
            i_cfg_err_internal_uncor        = 0,

            # AER interface ------------------------------------------------------------------------
            i_cfg_err_aer_headerlog     = 0,
            i_cfg_aer_interrupt_msgnum  = 0,
            o_cfg_err_aer_headerlog_set = Open(),
            o_cfg_aer_ecrc_check_en     = Open(),
            o_cfg_aer_ecrc_gen_en       = Open(),

            i_cfg_turnoff_ok            = 0,
            i_cfg_trn_pending           = 0,
            i_cfg_pm_halt_aspm_l0s      = 0,
            i_cfg_pm_halt_aspm_l1       = 0,
            i_cfg_pm_force_state_en     = 0,
            i_cfg_pm_force_state        = 0,
            i_cfg_dsn                   = 0,
            i_cfg_pm_send_pme_to        = 0,
            i_cfg_ds_bus_number         = 0,
            i_cfg_ds_device_number      = 0,
            i_cfg_ds_function_number    = 0,
            i_cfg_pm_wake               = 0,

            # Interrupt Interface ------------------------------------------------------------------
            i_cfg_interrupt                = cfg_msi.valid,
            o_cfg_interrupt_rdy            = cfg_msi.ready,
            i_cfg_interrupt_assert         = 0,
            i_cfg_interrupt_di             = cfg_msi.dat,
            o_cfg_interrupt_do             = Open(),
            o_cfg_interrupt_mmenable       = Open(),
            o_cfg_interrupt_msienable      = self._msi_enable.status,
            o_cfg_interrupt_msixenable     = self._msix_enable.status,
            o_cfg_interrupt_msixfm         = Open(),
            i_cfg_interrupt_stat           = 0,
            i_cfg_pciecap_interrupt_msgnum = 0,

            # Configuration Interface --------------------------------------------------------------
            o_cfg_status                                 = Open(),
            o_cfg_command                                = command,
            o_cfg_dstatus                                = Open(),
            o_cfg_dcommand                               = dcommand,
            o_cfg_lstatus                                = Open(),
            o_cfg_lcommand                               = Open(),
            o_cfg_dcommand2                              = Open(),
            o_cfg_pcie_link_state                        = Open(),
            o_cfg_to_turnoff                             = Open(),
            o_cfg_bus_number                             = bus_number,
            o_cfg_device_number                          = device_number,
            o_cfg_function_number                        = function_number,

            o_cfg_pmcsr_pme_en                           = Open(),
            o_cfg_pmcsr_powerstate                       = Open(),
            o_cfg_pmcsr_pme_status                       = Open(),
            o_cfg_received_func_lvl_rst                  = Open(),
            o_cfg_bridge_serr_en                         = Open(),
            o_cfg_slot_control_electromech_il_ctl_pulse  = Open(),
            o_cfg_root_control_syserr_corr_err_en        = Open(),
            o_cfg_root_control_syserr_non_fatal_err_en   = Open(),
            o_cfg_root_control_syserr_fatal_err_en       = Open(),
            o_cfg_root_control_pme_int_en                = Open(),
            o_cfg_aer_rooterr_corr_err_reporting_en      = Open(),
            o_cfg_aer_rooterr_non_fatal_err_reporting_en = Open(),
            o_cfg_aer_rooterr_fatal_err_reporting_en     = Open(),
            o_cfg_aer_rooterr_corr_err_received          = Open(),
            o_cfg_aer_rooterr_non_fatal_err_received     = Open(),
            o_cfg_aer_rooterr_fatal_err_received         = Open(),

            # VC Interface -------------------------------------------------------------------------
            o_cfg_vc_tcvc_map                    = Open(),

            o_cfg_msg_received                   = Open(),
            o_cfg_msg_data                       = Open(),
            o_cfg_msg_received_pm_as_nak         = Open(),
            o_cfg_msg_received_setslotpowerlimit = Open(),
            o_cfg_msg_received_err_cor           = Open(),
            o_cfg_msg_received_err_non_fatal     = Open(),
            o_cfg_msg_received_err_fatal         = Open(),
            o_cfg_msg_received_pm_pme            = Open(),
            o_cfg_msg_received_pme_to_ack        = Open(),
            o_cfg_msg_received_assert_int_a      = Open(),
            o_cfg_msg_received_assert_int_b      = Open(),
            o_cfg_msg_received_assert_int_c      = Open(),
            o_cfg_msg_received_assert_int_d      = Open(),
            o_cfg_msg_received_deassert_int_a    = Open(),
            o_cfg_msg_received_deassert_int_b    = Open(),
            o_cfg_msg_received_deassert_int_c    = Open(),
            o_cfg_msg_received_deassert_int_d    = Open(),


            # Physical Layer Interface -------------------------------------------------------------
            i_pl_directed_link_change        = 0,
            i_pl_directed_link_width         = 0,
            i_pl_directed_link_speed         = 0,
            i_pl_directed_link_auton         = 0,
            i_pl_upstream_prefer_deemph      = 1,
            o_pl_sel_lnk_rate                = self._link_status.fields.rate,
            o_pl_sel_lnk_width               = self._link_status.fields.width,
            o_pl_ltssm_state                 = self._link_status.fields.ltssm,
            o_pl_lane_reversal_mode          = Open(),
            o_pl_phy_lnk_up                  = Open(),
            o_pl_tx_pm_state                 = Open(),
            o_pl_rx_pm_state                 = Open(),
            o_pl_link_upcfg_cap              = Open(),
            o_pl_link_gen2_cap               = Open(),
            o_pl_link_partner_gen2_supported = Open(),
            o_pl_initial_link_width          = Open(),
            o_pl_directed_change_done        = Open(),
            o_pl_received_hot_rst            = Open(),
            i_pl_transmit_hot_rst            = 0,
            i_pl_downstream_deemph_source    = 0,

            # PCIe DRP Interface -------------------------------------------------------------------
            i_pcie_drp_clk  = 1,
            i_pcie_drp_en   = 0,
            i_pcie_drp_we   = 0,
            i_pcie_drp_addr = 0,
            i_pcie_drp_di   = 0,
            o_pcie_drp_rdy  = Open(),
            o_pcie_drp_do   = Open(),
        )
        if pcie_data_width == 128:
            rx_is_sof = m_axis_rx_tuser[10:15] # Start of a new packet header in m_axis_rx_tdata.
            rx_is_eof = m_axis_rx_tuser[17:22] # End of a packet in m_axis_rx_tdata.
            self.comb += [
                m_axis_rx.first.eq(rx_is_sof[-1]),
                m_axis_rx.last.eq( rx_is_eof[-1]),
                If(rx_is_sof == 0b11000, self.rx_datapath.aligner.first_dword.eq(2)),
            ]
        else:
            self.comb += [
                m_axis_rx.first.eq(0),
                m_axis_rx.last.eq(m_axis_rx_tlast),
            ]

    # LTSSM Tracer ---------------------------------------------------------------------------------
    def add_ltssm_tracer(self):
        self.submodules.ltssm_tracer = LTSSMTracer(self._link_status.fields.ltssm)

    # Hard IP sources ------------------------------------------------------------------------------
    def add_sources(self, platform, phy_path, phy_filename=None):
        platform.add_source(os.path.join(phy_path, "pcie_pipe_clock.v"))
        platform.add_source(os.path.join(phy_path, "pcie_s7_support.v"))
        if phy_filename is not None:
            platform.add_ip(os.path.join(phy_path, phy_filename))
        else:
            config = {
                "Bar0_Scale"         : "Megabytes",
                "Bar0_Size"          : 1,
                "Buf_Opt_BMA"        : True,
                "Component_Name"     : "pcie",
                "Device_ID"          : 7020 + self.nlanes,
                "IntX_Generation"    : False,
                "Interface_Width"    : f"{self.pcie_data_width}_bit",
                "Legacy_Interrupt"   : None,
                "Multiple_Message_Capable"  : '1_vector',
                "Link_Speed"         : "5.0_GT/s",
                "MSI_64b"            : False,
                "Max_Payload_Size"   : "512_bytes",
                "Maximum_Link_Width" : f"X{self.nlanes}",
                "PCIe_Blk_Locn"      : "X0Y0",
                "Ref_Clk_Freq"       : "100_MHz",
                "Trans_Buf_Pipeline" : None,
                "Trgt_Link_Speed"    : "4'h2",
                "User_Clk_Freq"      : 125,
            }
            ip_tcl = []
            ip_tcl.append("create_ip -vendor xilinx.com -name pcie_7x -module_name pcie_s7")
            ip_tcl.append("set obj [get_ips pcie_s7]")
            ip_tcl.append("set_property -dict [list \\")
            for config, value in config.items():
                ip_tcl.append("CONFIG.{} {} \\".format(config, '{{' + str(value) + '}}'))
            ip_tcl.append(f"] $obj")
            ip_tcl.append("synth_ip $obj")
            platform.toolchain.pre_synthesis_commands += ip_tcl
        # Reset LOC constraints on GTPE2_COMMON and BRAM36 from .xci (we only want to keep Timing constraints).
        if self.pcie_gt_device == "GTP":
            platform.toolchain.pre_placement_commands.append("reset_property LOC [get_cells -hierarchical -filter {{NAME=~pcie_support/*gtp_common.gtpe2_common_i}}]")
        else:
            platform.toolchain.pre_placement_commands.append("reset_property LOC [get_cells -hierarchical -filter {{NAME=~pcie_support/*gtx_common.gtxe2_common_i}}]")
        platform.toolchain.pre_placement_commands.append("reset_property LOC [get_cells -hierarchical -filter {{NAME=~pcie_support/*genblk*.bram36_tdp_bl.bram36_tdp_bl}}]")

    # External Hard IP -----------------------------------------------------------------------------
    def use_external_hard_ip(self, hard_ip_path, hard_ip_filename):
        self.external_hard_ip = True
        self.add_sources(self.platform, hard_ip_path, hard_ip_filename)

    # Finalize -------------------------------------------------------------------------------------
    def do_finalize(self):
        if not self.external_hard_ip:
            phy_path     = "xilinx_s7_gen2"
            self.add_sources(self.platform,
                phy_path     = os.path.join(os.path.abspath(os.path.dirname(__file__)), phy_path),
            )
        self.specials += Instance("pcie_support", **self.pcie_phy_params)
