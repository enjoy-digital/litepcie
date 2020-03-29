# This file is Copyright (c) 2015-2020 Florent Kermarrec <florent@enjoy-digital.fr>
# License: BSD

import os

from migen import *
from migen.genlib.cdc import MultiReg

from litex.soc.interconnect.csr import *

from litepcie.common import *

# AXISRX128BAligner --------------------------------------------------------------------------------

class AXISRX128BAligner(Module):
    def __init__(self):
        self.sink   = sink   = stream.Endpoint(phy_layout(128))
        self.source = source = stream.Endpoint(phy_layout(128))
        self.first_dword = Signal(2)

        # # #

        dat_last = Signal(64)
        be_last  = Signal(8)
        self.sync += [
            If(sink.valid & sink.ready,
                dat_last.eq(sink.dat[64:]),
                be_last.eq( sink.be[8:]),
            )
        ]

        self.submodules.fsm = fsm = FSM(reset_state="ALIGNED")
        fsm.act("ALIGNED",
            sink.connect(source, omit={"first"}),
            # If "first" on DWORD2 and "last" on the same cycle, switch to UNALIGNED.
            If(sink.valid & sink.last & sink.first & (self.first_dword == 2),
                source.be[8:].eq(0),
                If(source.ready,
                    NextState("UNALIGNED")
                )
            )
        )
        fsm.act("UNALIGNED",
            sink.connect(source, omit={"first", "dat", "be"}),
            source.dat.eq(Cat(dat_last, sink.dat)),
            source.be.eq( Cat(be_last,  sink.be)),
            # If "last" and not "first" on the same cycle, switch to ALIGNED.
            If(sink.valid & sink.last & ~sink.first,
                source.be[8:].eq(0),
                If(source.ready,
                    NextState("ALIGNED")
                )
            )
        )

# S7PCIEPHY ----------------------------------------------------------------------------------------

class S7PCIEPHY(Module, AutoCSR):
    def __init__(self, platform, pads, data_width=64, bar0_size=1*MB, cd="sys", pcie_data_width=64):
        # Streams ----------------------------------------------------------------------------------
        self.sink   = stream.Endpoint(phy_layout(data_width))
        self.source = stream.Endpoint(phy_layout(data_width))
        self.msi    = stream.Endpoint(msi_layout())

        # Registers --------------------------------------------------------------------------------
        self._link_up           = CSRStatus(description="Link Up Status. ``1``: Link is Up.")
        self._msi_enable        = CSRStatus(description="MSI Enable Status. ``1``: MSI is enabled.")
        self._bus_master_enable = CSRStatus(description="Bus Mastering Status. ``1``: Bus Mastering enabled.")
        self._max_request_size  = CSRStatus(16, description="Negiotiated Max Request Size (in bytes).")
        self._max_payload_size  = CSRStatus(16, description="Negiotiated Max Payload Size (in bytes).")

        # Parameters/Locals ------------------------------------------------------------------------
        self.platform         = platform
        self.data_width       = data_width
        self.pcie_data_width  = pcie_data_width

        self.id               = Signal(16)
        self.bar0_size        = bar0_size
        self.bar0_mask        = get_bar_mask(bar0_size)
        self.max_request_size = Signal(16)
        self.max_payload_size = Signal(16)

        self.external_hard_ip = False

        # # #

        self.nlanes = nlanes = len(pads.tx_p)

        assert nlanes          in [1, 2, 4, 8]
        assert data_width      in [64, 128]
        assert pcie_data_width in [64, 128]

        # Clocking ---------------------------------------------------------------------------------
        pcie_refclk = Signal()
        self.specials += Instance("IBUFDS_GTE2",
            i_CEB = 0,
            i_I   = pads.clk_p,
            i_IB  = pads.clk_n,
            o_O   = pcie_refclk
        )
        platform.add_period_constraint(pads.clk_p, 1e9/100e6)
        self.clock_domains.cd_pcie = ClockDomain()
        pcie_clk_freq = max(125e6, nlanes*62.5e6*64/pcie_data_width)
        platform.add_period_constraint(self.cd_pcie.clk, 1e9/pcie_clk_freq)

        # TX (FPGA --> HOST) CDC / Data Width Convertion -------------------------------------------
        if (cd == "pcie") and (data_width == pcie_data_width):
            s_axis_tx = self.sink
        else:
            tx_pipe_valid = stream.PipeValid(phy_layout(data_width))
            tx_pipe_valid = ClockDomainsRenamer(cd)(tx_pipe_valid)
            tx_cdc        = stream.AsyncFIFO(phy_layout(data_width), 4)
            tx_cdc        = ClockDomainsRenamer({"write": cd, "read": "pcie"})(tx_cdc)
            tx_converter  = stream.StrideConverter(phy_layout(data_width), phy_layout(pcie_data_width))
            tx_converter  = ClockDomainsRenamer("pcie")(tx_converter)
            tx_pipe_ready = stream.PipeValid(phy_layout(pcie_data_width))
            tx_pipe_ready = ClockDomainsRenamer("pcie")(tx_pipe_ready)
            self.submodules += tx_pipe_valid, tx_cdc, tx_converter, tx_pipe_ready
            self.comb += [
                self.sink.connect(tx_pipe_valid.sink),
                tx_pipe_valid.source.connect(tx_cdc.sink),
                tx_cdc.source.connect(tx_converter.sink),
                tx_converter.source.connect(tx_pipe_ready.sink)
            ]
            s_axis_tx = tx_pipe_ready.source

        # RX (HOST --> FPGA) CDC / Data Width Convertion -------------------------------------------
        if (cd == "pcie") and (data_width == pcie_data_width):
            m_axis_rx = self.source
        else:
            rx_pipe_ready = stream.PipeReady(phy_layout(pcie_data_width))
            rx_pipe_ready = ClockDomainsRenamer("pcie")(rx_pipe_ready)
            rx_converter  = stream.StrideConverter(phy_layout(pcie_data_width), phy_layout(data_width))
            rx_converter  = ClockDomainsRenamer("pcie")(rx_converter)
            rx_cdc        = stream.AsyncFIFO(phy_layout(data_width), 4)
            rx_cdc        = ClockDomainsRenamer({"write": "pcie", "read": cd})(rx_cdc)
            rx_pipe_valid = stream.PipeValid(phy_layout(data_width))
            rx_pipe_valid = ClockDomainsRenamer(cd)(rx_pipe_valid)
            self.submodules += rx_pipe_ready, rx_converter, rx_pipe_valid, rx_cdc
            self.comb += [
                rx_pipe_ready.source.connect(rx_converter.sink),
                rx_converter.source.connect(rx_cdc.sink),
                rx_cdc.source.connect(rx_pipe_valid.sink),
                rx_pipe_valid.source.connect(self.source),
            ]
            m_axis_rx = rx_pipe_ready.sink
        if pcie_data_width == 128:
            rx_aligner = AXISRX128BAligner()
            rx_aligner = ClockDomainsRenamer("pcie")(rx_aligner)
            self.submodules += rx_aligner
            self.comb += rx_aligner.source.connect(m_axis_rx)
            m_axis_rx = rx_aligner.sink

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

        link_up         = Signal()
        msi_enable      = Signal()
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
            MultiReg(link_up, self._link_up.status),
            MultiReg(command[2], self._bus_master_enable.status),
            MultiReg(msi_enable, self._msi_enable.status),
            MultiReg(self.max_request_size, self._max_request_size.status),
            MultiReg(self.max_payload_size, self._max_payload_size.status)
        ]

        # Hard IP ----------------------------------------------------------------------------------
        class Open(Signal): pass
        m_axis_rx_tlast = Signal()
        m_axis_rx_tuser = Signal(32)
        self.pcie_phy_params = dict(
            # Parameters ---------------------------------------------------------------------------
            p_LINK_CAP_MAX_LINK_WIDTH                    = nlanes,
            p_C_DATA_WIDTH                               = pcie_data_width,
            p_KEEP_WIDTH                                 = pcie_data_width//8,
            p_PCIE_REFCLK_FREQ                           = 0, # 100MHz refclk
            p_PCIE_USERCLK1_FREQ                         = 3 if nlanes <= 2 else 4,
            p_PCIE_USERCLK2_FREQ                         = 3 if (pcie_clk_freq == 125e6) else 4,
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
            o_pipe_pclk_out_slave                        = Open(),
            o_pipe_rxusrclk_out                          = Open(),
            o_pipe_rxoutclk_out                          = Open(),
            o_pipe_dclk_out                              = Open(),
            o_pipe_userclk1_out                          = Open(),
            o_pipe_userclk2_out                          = Open(),
            o_pipe_oobclk_out                            = Open(),
            o_pipe_mmcm_lock_out                         = Open(),
            i_pipe_pclk_sel_slave                        = 0b00,
            i_pipe_mmcm_rst_n                            = 1,

            # AXI-S Interface ----------------------------------------------------------------------
            # Common
            o_user_clk_out                               = ClockSignal("pcie"),
            o_user_reset_out                             = ResetSignal("pcie"),
            o_user_lnk_up                                = link_up,
            o_user_app_rdy                               = Open(),

            # TX
            o_tx_buf_av                                  = Open(),
            o_tx_err_drop                                = Open(),
            o_tx_cfg_req                                 = Open(),
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
            o_m_axis_rx_tlast                            = m_axis_rx_tlast,
            i_m_axis_rx_tready                           = m_axis_rx.ready,
            o_m_axis_rx_tdata                            = m_axis_rx.dat,
            o_m_axis_rx_tkeep                            = m_axis_rx.be,
            o_m_axis_rx_tuser                            = m_axis_rx_tuser,

            # Flow Control
            o_fc_cpld                                    = Open(),
            o_fc_cplh                                    = Open(),
            o_fc_npd                                     = Open(),
            o_fc_nph                                     = Open(),
            o_fc_pd                                      = Open(),
            o_fc_ph                                      = Open(),
            i_fc_sel                                     = 0,

            # Management Interface -----------------------------------------------------------------
            o_cfg_mgmt_do                                = Open(),
            o_cfg_mgmt_rd_wr_done                        = Open(),
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
            o_cfg_err_cpl_rdy                            = Open(),
            i_cfg_err_locked                             = 0,
            i_cfg_err_acs                                = 0,
            i_cfg_err_internal_uncor                     = 0,

            # AER interface ------------------------------------------------------------------------
            i_cfg_err_aer_headerlog                      = 0,
            i_cfg_aer_interrupt_msgnum                   = 0,
            o_cfg_err_aer_headerlog_set                  = Open(),
            o_cfg_aer_ecrc_check_en                      = Open(),
            o_cfg_aer_ecrc_gen_en                        = Open(),

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
            o_cfg_interrupt_do                           = Open(),
            o_cfg_interrupt_mmenable                     = Open(),
            o_cfg_interrupt_msienable                    = msi_enable,
            o_cfg_interrupt_msixenable                   = Open(),
            o_cfg_interrupt_msixfm                       = Open(),
            i_cfg_interrupt_stat                         = 0,
            i_cfg_pciecap_interrupt_msgnum               = 0,

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
            o_cfg_vc_tcvc_map                            = Open(),

            o_cfg_msg_received                           = Open(),
            o_cfg_msg_data                               = Open(),
            o_cfg_msg_received_pm_as_nak                 = Open(),
            o_cfg_msg_received_setslotpowerlimit         = Open(),
            o_cfg_msg_received_err_cor                   = Open(),
            o_cfg_msg_received_err_non_fatal             = Open(),
            o_cfg_msg_received_err_fatal                 = Open(),
            o_cfg_msg_received_pm_pme                    = Open(),
            o_cfg_msg_received_pme_to_ack                = Open(),
            o_cfg_msg_received_assert_int_a              = Open(),
            o_cfg_msg_received_assert_int_b              = Open(),
            o_cfg_msg_received_assert_int_c              = Open(),
            o_cfg_msg_received_assert_int_d              = Open(),
            o_cfg_msg_received_deassert_int_a            = Open(),
            o_cfg_msg_received_deassert_int_b            = Open(),
            o_cfg_msg_received_deassert_int_c            = Open(),
            o_cfg_msg_received_deassert_int_d            = Open(),


            # Physical Layer Interface -------------------------------------------------------------
            i_pl_directed_link_change                    = 0,
            i_pl_directed_link_width                     = 0,
            i_pl_directed_link_speed                     = 0,
            i_pl_directed_link_auton                     = 0,
            i_pl_upstream_prefer_deemph                  = 1,
            o_pl_sel_lnk_rate                            = Open(),
            o_pl_sel_lnk_width                           = Open(),
            o_pl_ltssm_state                             = Open(),
            o_pl_lane_reversal_mode                      = Open(),
            o_pl_phy_lnk_up                              = Open(),
            o_pl_tx_pm_state                             = Open(),
            o_pl_rx_pm_state                             = Open(),
            o_pl_link_upcfg_cap                          = Open(),
            o_pl_link_gen2_cap                           = Open(),
            o_pl_link_partner_gen2_supported             = Open(),
            o_pl_initial_link_width                      = Open(),
            o_pl_directed_change_done                    = Open(),
            o_pl_received_hot_rst                        = Open(),
            i_pl_transmit_hot_rst                        = 0,
            i_pl_downstream_deemph_source                = 0,

            # PCIe DRP Interface -------------------------------------------------------------------
            i_pcie_drp_clk                               = 1,
            i_pcie_drp_en                                = 0,
            i_pcie_drp_we                                = 0,
            i_pcie_drp_addr                              = 0,
            i_pcie_drp_di                                = 0,
            o_pcie_drp_rdy                               = Open(),
            o_pcie_drp_do                                = Open(),
        )
        if pcie_data_width == 128:
            rx_is_sof = m_axis_rx_tuser[10:15] # Start of a new packet header in m_axis_rx_tdata.
            rx_is_eof = m_axis_rx_tuser[17:22] # End of a packet in m_axis_rx_tdata.
            self.comb += [
                m_axis_rx.first.eq(rx_is_sof[-1]),
                m_axis_rx.last.eq( rx_is_eof[-1]),
                If(rx_is_sof == 0b11000, rx_aligner.first_dword.eq(2)),
            ]
        else:
            self.comb += [
                m_axis_rx.first.eq(0),
                m_axis_rx.last.eq(m_axis_rx_tlast),
            ]

    # Hard IP sources ------------------------------------------------------------------------------
    def add_sources(self, platform, phy_path, phy_filename):
        platform.add_ip(os.path.join(phy_path, phy_filename))
        platform.add_source(os.path.join(phy_path, "pcie_pipe_clock.v"))
        platform.add_source(os.path.join(phy_path, "pcie_s7_x{}_support.v".format(self.nlanes)))

    # External Hard IP -----------------------------------------------------------------------------
    def use_external_hard_ip(self, hard_ip_path, hard_ip_filename):
        self.external_hard_ip = True
        self.add_sources(self.platform, hard_ip_path, hard_ip_filename)

    # Finalize -------------------------------------------------------------------------------------
    def do_finalize(self):
        if not self.external_hard_ip:
            phy_path     = "xilinx_s7_x{}".format(self.nlanes)
            phy_filename = "pcie_s7_x{}.xci".format(self.nlanes)
            self.add_sources(self.platform,
                phy_path     = os.path.join(os.path.abspath(os.path.dirname(__file__)), phy_path),
                phy_filename = "pcie_s7_x{}.xci".format(self.nlanes)
            )
        self.specials += Instance("pcie_support", **self.pcie_phy_params)
