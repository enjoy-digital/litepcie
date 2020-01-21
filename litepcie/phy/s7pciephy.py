# This file is Copyright (c) 2015-2019 Florent Kermarrec <florent@enjoy-digital.fr>
# License: BSD

import os

from migen import *
from migen.genlib.cdc import MultiReg

from litex.soc.interconnect.csr import *

from litepcie.common import *
from litepcie.phy.constraints import *

# --------------------------------------------------------------------------------------------------

class S7PCIEPHY(Module, AutoCSR):
    def __init__(self, platform, pads, data_width=64, bar0_size=1*MB, cd="sys"):
        # Streams ----------------------------------------------------------------------------------
        self.sink   = stream.Endpoint(phy_layout(data_width))
        self.source = stream.Endpoint(phy_layout(data_width))
        self.msi    = stream.Endpoint(msi_layout())

        # Registers --------------------------------------------------------------------------------
        self._lnk_up            = CSRStatus()
        self._msi_enable        = CSRStatus()
        self._bus_master_enable = CSRStatus()
        self._max_request_size  = CSRStatus(16)
        self._max_payload_size  = CSRStatus(16)

        # Parameters/Locals ------------------------------------------------------------------------
        self.platform         = platform
        self.data_width       = data_width

        self.id               = Signal(16)
        self.bar0_size        = bar0_size
        self.bar0_mask        = get_bar_mask(bar0_size)
        self.max_request_size = Signal(16)
        self.max_payload_size = Signal(16)

        self.external_hard_ip = False

        # # #

        nlanes = len(pads.tx_p)

        # Clocking ---------------------------------------------------------------------------------
        pcie_refclk = Signal()
        self.specials += Instance("IBUFDS_GTE2",
            i_CEB=0,
            i_I=pads.clk_p,
            i_IB=pads.clk_n,
            o_O=pcie_refclk
        )
        self.clock_domains.cd_pcie = ClockDomain()

        # TX CDC (FPGA --> HOST) -------------------------------------------------------------------
        if (cd == "pcie") and (data_width == 64):
            s_axis_tx = self.sink
        else:
            tx_buffer    = stream.Buffer(phy_layout(data_width))
            tx_buffer    = ClockDomainsRenamer(cd)(tx_buffer)
            tx_cdc       = stream.AsyncFIFO(phy_layout(data_width), 4)
            tx_cdc       = ClockDomainsRenamer({"write": cd, "read": "pcie"})(tx_cdc)
            tx_converter = stream.StrideConverter(phy_layout(data_width), phy_layout(64))
            tx_converter = ClockDomainsRenamer("pcie")(tx_converter)
            self.submodules += tx_buffer, tx_cdc, tx_converter
            self.comb += [
                self.sink.connect(tx_buffer.sink),
                tx_buffer.source.connect(tx_cdc.sink),
                tx_cdc.source.connect(tx_converter.sink),
            ]
            s_axis_tx = tx_converter.source

        # RX CDC (HOST --> FPGA) -------------------------------------------------------------------
        if (cd == "pcie") and (data_width == 64):
            m_axis_rx = self.source
        else:
            rx_converter    = stream.StrideConverter(phy_layout(64), phy_layout(data_width))
            rx_converter    = ClockDomainsRenamer("pcie")(rx_converter)
            rx_cdc          = stream.AsyncFIFO(phy_layout(data_width), 4)
            rx_cdc          = ClockDomainsRenamer({"write": "pcie", "read": cd})(rx_cdc)
            rx_buffer       = stream.Buffer(phy_layout(data_width))
            rx_buffer       = ClockDomainsRenamer(cd)(rx_buffer)
            self.submodules += rx_converter, rx_buffer, rx_cdc
            self.comb += [
                rx_converter.source.connect(rx_cdc.sink),
                rx_cdc.source.connect(rx_buffer.sink),
                rx_buffer.source.connect(self.source),
            ]
            m_axis_rx = rx_converter.sink


        # MSI CDC (FPGA --> HOST) ------------------------------------------------------------------
        if cd == "pcie":
            cfg_msi = self.msi
        else:
            msi_cdc = stream.AsyncFIFO(msi_layout(), 4)
            msi_cdc = ClockDomainsRenamer({"write": cd, "read": "pcie"})(msi_cdc)
            self.submodules += msi_cdc
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

        lnk_up          = Signal()
        msienable       = Signal()
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
            MultiReg(lnk_up, self._lnk_up.status),
            MultiReg(command[2], self._bus_master_enable.status),
            MultiReg(msienable, self._msi_enable.status),
            MultiReg(self.max_request_size, self._max_request_size.status),
            MultiReg(self.max_payload_size, self._max_payload_size.status)
        ]

        # Hard IP ----------------------------------------------------------------------------------
        m_axis_rx_tlast = Signal()
        m_axis_rx_tuser = Signal(32)
        self.pcie_phy_params = dict(
            # Parameters ---------------------------------------------------------------------------
            p_LINK_CAP_MAX_LINK_WIDTH                    = nlanes,
            p_C_DATA_WIDTH                               = 64,
            p_KEEP_WIDTH                                 = 64//8,
            p_PCIE_REFCLK_FREQ                           = 0, # 100MHz refclk
            p_PCIE_USERCLK1_FREQ                         = 3 if nlanes <= 2 else 4,
            p_PCIE_USERCLK2_FREQ                         = 3 if nlanes <= 2 else 4,
            p_PCIE_GT_DEVICE                             = {"xc7a": "GTP",
                                                            "xc7k": "GTX",
                                                            "xc7v": "GTX"}[platform.device[:4]],
            p_PCIE_USE_MODE                              = "1.0",

            # PCI Express Interface ----------------------------------------------------------------
            i_sys_clk                                    = pcie_refclk,
            i_sys_rst_n                                  = 1 if not hasattr(pads, "rst_n") else pads.rst_n,
            # TX
            o_pci_exp_txp                                = pads.tx_p,
            o_pci_exp_txn                                = pads.tx_n,
            # RX
            i_pci_exp_rxp                                = pads.rx_p,
            i_pci_exp_rxn                                = pads.rx_n,

            # Clocking Sharing Interface -----------------------------------------------------------
            o_pipe_pclk_out_slave                        = Signal(),
            o_pipe_rxusrclk_out                          = Signal(),
            o_pipe_rxoutclk_out                          = Signal(),
            o_pipe_dclk_out                              = Signal(),
            o_pipe_userclk1_out                          = Signal(),
            o_pipe_userclk2_out                          = Signal(),
            o_pipe_oobclk_out                            = Signal(),
            o_pipe_mmcm_lock_out                         = Signal(),
            i_pipe_pclk_sel_slave                        = 0b00,
            i_pipe_mmcm_rst_n                            = 1,

            # AXI-S Interface ----------------------------------------------------------------------
            # Common
            o_user_clk_out                               = ClockSignal("pcie"),
            o_user_reset_out                             = ResetSignal("pcie"),
            o_user_lnk_up                                = lnk_up,
            o_user_app_rdy                               = Signal(),

            # TX
            o_tx_buf_av                                  = Signal(),
            o_tx_err_drop                                = Signal(),
            o_tx_cfg_req                                 = Signal(),
            i_tx_cfg_gnt                                 = 1,
            i_s_axis_tx_tvalid                           = s_axis_tx.valid,
            i_s_axis_tx_tlast                            = s_axis_tx.last,
            o_s_axis_tx_tready                           = s_axis_tx.ready,
            i_s_axis_tx_tdata                            = s_axis_tx.dat,
            i_s_axis_tx_tkeep                            = s_axis_tx.be,
            i_s_axis_tx_tuser                            = 0,

            # RX
            i_rx_np_ok                                   = 1,
            i_rx_np_req                                  = 1,
            o_m_axis_rx_tvalid                           = m_axis_rx.valid,
            o_m_axis_rx_tlast                            = m_axis_rx.last,
            i_m_axis_rx_tready                           = m_axis_rx.ready,
            o_m_axis_rx_tdata                            = m_axis_rx.dat,
            o_m_axis_rx_tkeep                            = m_axis_rx.be,
            #o_m_axis_rx_tuser                           = ,

            # Flow Control
            o_fc_cpld                                    = Signal(),
            o_fc_cplh                                    = Signal(),
            o_fc_npd                                     = Signal(),
            o_fc_nph                                     = Signal(),
            o_fc_pd                                      = Signal(),
            o_fc_ph                                      = Signal(),
            i_fc_sel                                     = 0,

            # Management Interface -----------------------------------------------------------------
            o_cfg_mgmt_do                                = Signal(),
            o_cfg_mgmt_rd_wr_done                        = Signal(),
            i_cfg_mgmt_di                                = 0,
            i_cfg_mgmt_byte_en                           = 0,
            i_cfg_mgmt_dwaddr                            = 0,
            i_cfg_mgmt_wr_en                             = 0,
            i_cfg_mgmt_rd_en                             = 0,
            i_cfg_mgmt_wr_readonly                       = 0,
            i_cfg_mgmt_wr_rw1c_as_rw                     = 0,

            # Error Reporting Interface ------------------------------------------------------------
            i_cfg_err_ecrc                               = 0,
            i_cfg_err_ur                                 = 0,
            i_cfg_err_cpl_timeout                        = 0,
            i_cfg_err_cpl_unexpect                       = 0,
            i_cfg_err_cpl_abort                          = 0,
            i_cfg_err_posted                             = 0,
            i_cfg_err_cor                                = 0,
            i_cfg_err_atomic_egress_blocked              = 0,
            i_cfg_err_internal_cor                       = 0,
            i_cfg_err_malformed                          = 0,
            i_cfg_err_mc_blocked                         = 0,
            i_cfg_err_poisoned                           = 0,
            i_cfg_err_norecovery                         = 0,
            i_cfg_err_tlp_cpl_header                     = 0,
            o_cfg_err_cpl_rdy                            = Signal(),
            i_cfg_err_locked                             = 0,
            i_cfg_err_acs                                = 0,
            i_cfg_err_internal_uncor                     = 0,

            # AER interface ------------------------------------------------------------------------
            i_cfg_err_aer_headerlog                      = 0,
            i_cfg_aer_interrupt_msgnum                   = 0,
            o_cfg_err_aer_headerlog_set                  = Signal(),
            o_cfg_aer_ecrc_check_en                      = Signal(),
            o_cfg_aer_ecrc_gen_en                        = Signal(),

            i_cfg_turnoff_ok                             = 0,
            i_cfg_trn_pending                            = 0,
            i_cfg_pm_halt_aspm_l0s                       = 0,
            i_cfg_pm_halt_aspm_l1                        = 0,
            i_cfg_pm_force_state_en                      = 0,
            i_cfg_pm_force_state                         = 0,
            i_cfg_dsn                                    = 0,
            i_cfg_pm_send_pme_to                         = 0,
            i_cfg_ds_bus_number                          = 0,
            i_cfg_ds_device_number                       = 0,
            i_cfg_ds_function_number                     = 0,
            i_cfg_pm_wake                                = 0,

            # Interrupt Interface ------------------------------------------------------------------
            i_cfg_interrupt                              = cfg_msi.valid,
            o_cfg_interrupt_rdy                          = cfg_msi.ready,
            i_cfg_interrupt_assert                       = 0,
            i_cfg_interrupt_di                           = cfg_msi.dat,
            o_cfg_interrupt_do                           = Signal(),
            o_cfg_interrupt_mmenable                     = Signal(),
            o_cfg_interrupt_msienable                    = msienable,
            o_cfg_interrupt_msixenable                   = Signal(),
            o_cfg_interrupt_msixfm                       = Signal(),
            i_cfg_interrupt_stat                         = 0,
            i_cfg_pciecap_interrupt_msgnum               = 0,

            # Configuration Interface --------------------------------------------------------------
            o_cfg_status                                 = Signal(),
            o_cfg_command                                = command,
            o_cfg_dstatus                                = Signal(),
            o_cfg_dcommand                               = dcommand,
            o_cfg_lstatus                                = Signal(),
            o_cfg_lcommand                               = Signal(),
            o_cfg_dcommand2                              = Signal(),
            o_cfg_pcie_link_state                        = Signal(),
            o_cfg_to_turnoff                             = Signal(),
            o_cfg_bus_number                             = bus_number,
            o_cfg_device_number                          = device_number,
            o_cfg_function_number                        = function_number,

            o_cfg_pmcsr_pme_en                           = Signal(),
            o_cfg_pmcsr_powerstate                       = Signal(),
            o_cfg_pmcsr_pme_status                       = Signal(),
            o_cfg_received_func_lvl_rst                  = Signal(),
            o_cfg_bridge_serr_en                         = Signal(),
            o_cfg_slot_control_electromech_il_ctl_pulse  = Signal(),
            o_cfg_root_control_syserr_corr_err_en        = Signal(),
            o_cfg_root_control_syserr_non_fatal_err_en   = Signal(),
            o_cfg_root_control_syserr_fatal_err_en       = Signal(),
            o_cfg_root_control_pme_int_en                = Signal(),
            o_cfg_aer_rooterr_corr_err_reporting_en      = Signal(),
            o_cfg_aer_rooterr_non_fatal_err_reporting_en = Signal(),
            o_cfg_aer_rooterr_fatal_err_reporting_en     = Signal(),
            o_cfg_aer_rooterr_corr_err_received          = Signal(),
            o_cfg_aer_rooterr_non_fatal_err_received     = Signal(),
            o_cfg_aer_rooterr_fatal_err_received         = Signal(),

            # VC Interface -------------------------------------------------------------------------
            o_cfg_vc_tcvc_map                            = Signal(),

            o_cfg_msg_received                           = Signal(),
            o_cfg_msg_data                               = Signal(),
            o_cfg_msg_received_pm_as_nak                 = Signal(),
            o_cfg_msg_received_setslotpowerlimit         = Signal(),
            o_cfg_msg_received_err_cor                   = Signal(),
            o_cfg_msg_received_err_non_fatal             = Signal(),
            o_cfg_msg_received_err_fatal                 = Signal(),
            o_cfg_msg_received_pm_pme                    = Signal(),
            o_cfg_msg_received_pme_to_ack                = Signal(),
            o_cfg_msg_received_assert_int_a              = Signal(),
            o_cfg_msg_received_assert_int_b              = Signal(),
            o_cfg_msg_received_assert_int_c              = Signal(),
            o_cfg_msg_received_assert_int_d              = Signal(),
            o_cfg_msg_received_deassert_int_a            = Signal(),
            o_cfg_msg_received_deassert_int_b            = Signal(),
            o_cfg_msg_received_deassert_int_c            = Signal(),
            o_cfg_msg_received_deassert_int_d            = Signal(),


            # Physical Layer Interface -------------------------------------------------------------
            i_pl_directed_link_change                    = 0,
            i_pl_directed_link_width                     = 0,
            i_pl_directed_link_speed                     = 0,
            i_pl_directed_link_auton                     = 0,
            i_pl_upstream_prefer_deemph                  = 1,
            o_pl_sel_lnk_rate                            = Signal(),
            o_pl_sel_lnk_width                           = Signal(),
            o_pl_ltssm_state                             = Signal(),
            o_pl_lane_reversal_mode                      = Signal(),
            o_pl_phy_lnk_up                              = Signal(),
            o_pl_tx_pm_state                             = Signal(),
            o_pl_rx_pm_state                             = Signal(),
            o_pl_link_upcfg_cap                          = Signal(),
            o_pl_link_gen2_cap                           = Signal(),
            o_pl_link_partner_gen2_supported             = Signal(),
            o_pl_initial_link_width                      = Signal(),
            o_pl_directed_change_done                    = Signal(),
            o_pl_received_hot_rst                        = Signal(),
            i_pl_transmit_hot_rst                        = 0,
            i_pl_downstream_deemph_source                = 0,

            # PCIe DRP Interface -------------------------------------------------------------------
            i_pcie_drp_clk                               = 1,
            i_pcie_drp_en                                = 0,
            i_pcie_drp_we                                = 0,
            i_pcie_drp_addr                              = 0,
            i_pcie_drp_di                                = 0,
            o_pcie_drp_rdy                               = Signal(),
            o_pcie_drp_do                                = Signal()
        )

    # Hard IP sources ------------------------------------------------------------------------------
    @staticmethod
    def add_sources(platform, phy_path):
        platform.add_source_dir(os.path.join(phy_path, "common"))
        if platform.device[:4] == "xc7v":
            platform.add_source_dir(os.path.join(phy_path, "virtex7"))
        elif platform.device[:4] == "xc7k":
            platform.add_source_dir(os.path.join(phy_path, "kintex7"))
        elif platform.device[:4] == "xc7a":
            platform.add_source_dir(os.path.join(phy_path, "artix7"))

    # External Hard IP -----------------------------------------------------------------------------
    def use_external_hard_ip(self, hard_ip_path):
        self.external_hard_ip = True
        self.add_sources(self.platform, hard_ip_path)

    # Timing constraints ---------------------------------------------------------------------------
    @staticmethod
    def add_timing_constraints(platform):
        if platform.device[:4] == "xc7v":
            add_virtex7_timing_constraints(platform)
        elif platform.device[:4] == "xc7k":
            add_kintex7_timing_constraints(platform)
        elif platform.device[:4] == "xc7a":
            add_artix7_timing_constraints(platform)
        else:
            raise ValueError

    # Finalize -------------------------------------------------------------------------------------
    def do_finalize(self):
        if not self.external_hard_ip:
            self.add_sources(self.platform, os.path.join(
                os.path.abspath(os.path.dirname(__file__)),
                "xilinx",
                "7-series"))
        self.specials += Instance("pcie_support", **self.pcie_phy_params)
