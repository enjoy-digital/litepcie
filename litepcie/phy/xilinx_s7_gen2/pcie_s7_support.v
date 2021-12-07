//-----------------------------------------------------------------------------
//
// (c) Copyright 2010-2011 Xilinx, Inc. All rights reserved.
//
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
//
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
//
//-----------------------------------------------------------------------------
// Project    : Series-7 Integrated Block for PCI Express
// File       : pcie_support.v
// Version    : 3.3
//--
//-- Description:  PCI Express Endpoint Shared Logic Wrapper
//--
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

(* DowngradeIPIdentifiedWarnings = "yes" *)
module pcie_support # (
  parameter LINK_CAP_MAX_LINK_WIDTH = 8,                       // PCIe Lane Width
  parameter CLK_SHARING_EN          = "FALSE",                 // Enable Clock Sharing
  parameter C_DATA_WIDTH            = 256,                     // AXI interface data width
  parameter KEEP_WIDTH              = C_DATA_WIDTH / 8,        // TSTRB width
  parameter PCIE_REFCLK_FREQ        = 0,                       // PCIe reference clock frequency
  parameter PCIE_USERCLK1_FREQ      = 2,                       // PCIe user clock 1 frequency
  parameter PCIE_USERCLK2_FREQ      = 2,                       // PCIe user clock 2 frequency
  parameter PCIE_GT_DEVICE          = "GTX",                   // PCIe GT device
  parameter PCIE_USE_MODE           = "2.1"                    // PCIe use mode
)
(

  //----------------------------------------------------------------------------------------------------------------//
  // PCI Express (pci_exp) Interface                                                                                //
  //----------------------------------------------------------------------------------------------------------------//

  // Tx
  output  [(LINK_CAP_MAX_LINK_WIDTH - 1) : 0] pci_exp_txn,
  output  [(LINK_CAP_MAX_LINK_WIDTH - 1) : 0] pci_exp_txp,

  // Rx
  input   [(LINK_CAP_MAX_LINK_WIDTH - 1) : 0] pci_exp_rxn,
  input   [(LINK_CAP_MAX_LINK_WIDTH - 1) : 0] pci_exp_rxp,

  //----------------------------------------------------------------------------------------------------------------//
  // Clocking Sharing Interface                                                                                     //
  //----------------------------------------------------------------------------------------------------------------//
  output                                     pipe_pclk_out_slave,
  output                                     pipe_rxusrclk_out,
  output [(LINK_CAP_MAX_LINK_WIDTH - 1) : 0] pipe_rxoutclk_out,
  output                                     pipe_dclk_out,
  output                                     pipe_userclk1_out,
  output                                     pipe_userclk2_out,
  output                                     pipe_oobclk_out,
  output                                     pipe_mmcm_lock_out,
  input  [(LINK_CAP_MAX_LINK_WIDTH - 1) : 0] pipe_pclk_sel_slave,
  input                                      pipe_mmcm_rst_n,

  //----------------------------------------------------------------------------------------------------------------//
  // AXI-S Interface                                                                                                //
  //----------------------------------------------------------------------------------------------------------------//

  // Common
  output                                     user_clk_out,
  output                                     user_reset_out,
  output                                     user_lnk_up,
  output                                     user_app_rdy,

  input                                      tx_cfg_gnt,
  input                                      rx_np_ok,
  input                                      rx_np_req,
  input                                      cfg_turnoff_ok,
  input                                      cfg_trn_pending,
  input                                      cfg_pm_halt_aspm_l0s,
  input                                      cfg_pm_halt_aspm_l1,
  input                                      cfg_pm_force_state_en,
  input    [1:0]                             cfg_pm_force_state,
  input    [63:0]                            cfg_dsn,
  input                                      cfg_pm_send_pme_to,
  input    [7:0]                             cfg_ds_bus_number,
  input    [4:0]                             cfg_ds_device_number,
  input    [2:0]                             cfg_ds_function_number,
  input                                      cfg_pm_wake,

  // AXI TX
  //-----------
  input   [C_DATA_WIDTH-1:0]                 s_axis_tx_tdata,
  input                                      s_axis_tx_tvalid,
  output                                     s_axis_tx_tready,
  input   [KEEP_WIDTH-1:0]                   s_axis_tx_tkeep,
  input                                      s_axis_tx_tlast,
  input   [3:0]                              s_axis_tx_tuser,

  // AXI RX
  //-----------
  output  [C_DATA_WIDTH-1:0]                 m_axis_rx_tdata,
  output                                     m_axis_rx_tvalid,
  input                                      m_axis_rx_tready,
  output  [KEEP_WIDTH-1:0]                   m_axis_rx_tkeep,
  output                                     m_axis_rx_tlast,
  output  [21:0]                             m_axis_rx_tuser,

  // Flow Control
  output  [11:0]                             fc_cpld,
  output  [7:0]                              fc_cplh,
  output  [11:0]                             fc_npd,
  output  [7:0]                              fc_nph,
  output  [11:0]                             fc_pd,
  output  [7:0]                              fc_ph,
  input   [2:0]                              fc_sel,

  //----------------------------------------------------------------------------------------------------------------//
  // Configuration (CFG) Interface                                                                                  //
  //----------------------------------------------------------------------------------------------------------------//
  //------------------------------------------------//
  // EP and RP                                      //
  //------------------------------------------------//
  output                                     tx_err_drop,
  output                                     tx_cfg_req,
  output  [5:0]                              tx_buf_av,
  output   [15:0]                            cfg_status,
  output   [15:0]                            cfg_command,
  output   [15:0]                            cfg_dstatus,
  output   [15:0]                            cfg_dcommand,
  output   [15:0]                            cfg_lstatus,
  output   [15:0]                            cfg_lcommand,
  output   [15:0]                            cfg_dcommand2,
  output   [2:0]                             cfg_pcie_link_state,
  output                                     cfg_to_turnoff,
  output   [7:0]                             cfg_bus_number,
  output   [4:0]                             cfg_device_number,
  output   [2:0]                             cfg_function_number,

  output                                     cfg_pmcsr_pme_en,
  output   [1:0]                             cfg_pmcsr_powerstate,
  output                                     cfg_pmcsr_pme_status,
  output                                     cfg_received_func_lvl_rst,

  //------------------------------------------------//
  // RP Only                                        //
  //------------------------------------------------//
  output                                     cfg_bridge_serr_en,
  output                                     cfg_slot_control_electromech_il_ctl_pulse,
  output                                     cfg_root_control_syserr_corr_err_en,
  output                                     cfg_root_control_syserr_non_fatal_err_en,
  output                                     cfg_root_control_syserr_fatal_err_en,
  output                                     cfg_root_control_pme_int_en,
  output                                     cfg_aer_rooterr_corr_err_reporting_en,
  output                                     cfg_aer_rooterr_non_fatal_err_reporting_en,
  output                                     cfg_aer_rooterr_fatal_err_reporting_en,
  output                                     cfg_aer_rooterr_corr_err_received,
  output                                     cfg_aer_rooterr_non_fatal_err_received,
  output                                     cfg_aer_rooterr_fatal_err_received,
  //----------------------------------------------------------------------------------------------------------------//
  // VC interface                                                                                                   //
  //----------------------------------------------------------------------------------------------------------------//

  output   [6:0]                              cfg_vc_tcvc_map,

  // Management Interface
  output   [31:0]                             cfg_mgmt_do,
  output                                      cfg_mgmt_rd_wr_done,
  input    [31:0]                             cfg_mgmt_di,
  input    [3:0]                              cfg_mgmt_byte_en,
  input    [9:0]                              cfg_mgmt_dwaddr,
  input                                       cfg_mgmt_wr_en,
  input                                       cfg_mgmt_rd_en,
  input                                       cfg_mgmt_wr_readonly,
  input                                       cfg_mgmt_wr_rw1c_as_rw,

  // Error Reporting Interface
  input                                       cfg_err_ecrc,
  input                                       cfg_err_ur,
  input                                       cfg_err_cpl_timeout,
  input                                       cfg_err_cpl_unexpect,
  input                                       cfg_err_cpl_abort,
  input                                       cfg_err_posted,
  input                                       cfg_err_cor,
  input                                       cfg_err_atomic_egress_blocked,
  input                                       cfg_err_internal_cor,
  input                                       cfg_err_malformed,
  input                                       cfg_err_mc_blocked,
  input                                       cfg_err_poisoned,
  input                                       cfg_err_norecovery,
  input   [47:0]                              cfg_err_tlp_cpl_header,
  output                                      cfg_err_cpl_rdy,
  input                                       cfg_err_locked,
  input                                       cfg_err_acs,
  input                                       cfg_err_internal_uncor,
  //----------------------------------------------------------------------------------------------------------------//
  // AER interface                                                                                                  //
  //----------------------------------------------------------------------------------------------------------------//
  input   [127:0]                             cfg_err_aer_headerlog,
  input   [4:0]                               cfg_aer_interrupt_msgnum,
  output                                      cfg_err_aer_headerlog_set,
  output                                      cfg_aer_ecrc_check_en,
  output                                      cfg_aer_ecrc_gen_en,

  output                                      cfg_msg_received,
  output   [15:0]                             cfg_msg_data,
  output                                      cfg_msg_received_pm_as_nak,
  output                                      cfg_msg_received_setslotpowerlimit,
  output                                      cfg_msg_received_err_cor,
  output                                      cfg_msg_received_err_non_fatal,
  output                                      cfg_msg_received_err_fatal,
  output                                      cfg_msg_received_pm_pme,
  output                                      cfg_msg_received_pme_to_ack,
  output                                      cfg_msg_received_assert_int_a,
  output                                      cfg_msg_received_assert_int_b,
  output                                      cfg_msg_received_assert_int_c,
  output                                      cfg_msg_received_assert_int_d,
  output                                      cfg_msg_received_deassert_int_a,
  output                                      cfg_msg_received_deassert_int_b,
  output                                      cfg_msg_received_deassert_int_c,
  output                                      cfg_msg_received_deassert_int_d,

  //------------------------------------------------//
  // EP Only                                        //
  //------------------------------------------------//
  // Interrupt Interface Signals
  input                                       cfg_interrupt,
  output                                      cfg_interrupt_rdy,
  input                                       cfg_interrupt_assert,
  input    [7:0]                              cfg_interrupt_di,
  output   [7:0]                              cfg_interrupt_do,
  output   [2:0]                              cfg_interrupt_mmenable,
  output                                      cfg_interrupt_msienable,
  output                                      cfg_interrupt_msixenable,
  output                                      cfg_interrupt_msixfm,
  input                                       cfg_interrupt_stat,
  input    [4:0]                              cfg_pciecap_interrupt_msgnum,

  //----------------------------------------------------------------------------------------------------------------//
  // Physical Layer Control and Status (PL) Interface                                                               //
  //----------------------------------------------------------------------------------------------------------------//
  //------------------------------------------------//
  // EP and RP                                      //
  //------------------------------------------------//
  input    [1:0]                              pl_directed_link_change,
  input    [1:0]                              pl_directed_link_width,
  input                                       pl_directed_link_speed,
  input                                       pl_directed_link_auton,
  input                                       pl_upstream_prefer_deemph,

  output                                      pl_sel_lnk_rate,
  output   [1:0]                              pl_sel_lnk_width,
  output   [5:0]                              pl_ltssm_state,
  output   [1:0]                              pl_lane_reversal_mode,
  output                                      pl_phy_lnk_up,
  output   [2:0]                              pl_tx_pm_state,
  output   [1:0]                              pl_rx_pm_state,
  output                                      pl_link_upcfg_cap,
  output                                      pl_link_gen2_cap,
  output                                      pl_link_partner_gen2_supported,
  output   [2:0]                              pl_initial_link_width,
  output                                      pl_directed_change_done,

  //------------------------------------------------//
  // EP Only                                        //
  //------------------------------------------------//
  output                                      pl_received_hot_rst,

  //------------------------------------------------//
  // RP Only                                        //
  //------------------------------------------------//
  input                                       pl_transmit_hot_rst,
  input                                       pl_downstream_deemph_source,

  //----------------------------------------------------------------------------------------------------------------//
  // PCIe DRP (PCIe DRP) Interface                                                                                  //
  //----------------------------------------------------------------------------------------------------------------//
  input                                       pcie_drp_clk,
  input                                       pcie_drp_en,
  input                                       pcie_drp_we,
  input    [8:0]                              pcie_drp_addr,
  input    [15:0]                             pcie_drp_di,
  output                                      pcie_drp_rdy,
  output   [15:0]                             pcie_drp_do,

  input                                       sys_clk,
  input                                       sys_rst_n

);
  // Wires used for external clocking connectivity
  wire                                        pipe_pclk_out;
  wire                                        pipe_txoutclk_in;
  wire [(LINK_CAP_MAX_LINK_WIDTH - 1) : 0]    pipe_rxoutclk_in;
  wire [(LINK_CAP_MAX_LINK_WIDTH - 1) : 0]    pipe_pclk_sel_in;
  wire                                        pipe_gen3_in;


  // Wires used for external GT COMMON connectivity
  wire [11:0]                                 qpll_drp_crscode;
  wire [17:0]                                 qpll_drp_fsm;
  wire [1:0]                                  qpll_drp_done;
  wire [1:0]                                  qpll_drp_reset;
  wire                                        qpll_qplld;
  wire [1:0]                                  qpll_qpllreset;
  wire                                        qpll_drp_clk;
  wire                                        qpll_drp_rst_n;
  wire                                        qpll_drp_ovrd;
  wire                                        qpll_drp_gen3;
  wire                                        qpll_drp_start;


      //---------- PIPE Clock Shared Mode ------------------------------//

pcie_pipe_clock #
      (
          .PCIE_ASYNC_EN                  ( "FALSE" ),                 // PCIe async enable
          .PCIE_TXBUF_EN                  ( "FALSE" ),                 // PCIe TX buffer enable for Gen1/Gen2 only
          .PCIE_LANE                      ( LINK_CAP_MAX_LINK_WIDTH ), // PCIe number of lanes
          // synthesis translate_off
          .PCIE_LINK_SPEED                ( 2 ),
          // synthesis translate_on
          .PCIE_REFCLK_FREQ               ( PCIE_REFCLK_FREQ ),        // PCIe reference clock frequency
          .PCIE_USERCLK1_FREQ             ( PCIE_USERCLK1_FREQ ),      // PCIe user clock 1 frequency
          .PCIE_USERCLK2_FREQ             ( PCIE_USERCLK2_FREQ ),      // PCIe user clock 2 frequency
          .PCIE_DEBUG_MODE                ( 0 )
      )
      pipe_clock_i
      (

          //---------- Input -------------------------------------
          .CLK_CLK                        ( sys_clk ),
          .CLK_TXOUTCLK                   ( pipe_txoutclk_in ),     // Reference clock from lane 0
          .CLK_RXOUTCLK_IN                ( pipe_rxoutclk_in ),
          .CLK_RST_N                      ( pipe_mmcm_rst_n ),      // Allow system reset for error_recovery
          .CLK_PCLK_SEL                   ( pipe_pclk_sel_in ),
          .CLK_PCLK_SEL_SLAVE             ( pipe_pclk_sel_slave),
          .CLK_GEN3                       ( pipe_gen3_in ),

          //---------- Output ------------------------------------
          .CLK_PCLK                       ( pipe_pclk_out),
          .CLK_PCLK_SLAVE                 ( pipe_pclk_out_slave),
          .CLK_RXUSRCLK                   ( pipe_rxusrclk_out),
          .CLK_RXOUTCLK_OUT               ( pipe_rxoutclk_out),
          .CLK_DCLK                       ( pipe_dclk_out),
          .CLK_OOBCLK                     ( pipe_oobclk_out),
          .CLK_USERCLK1                   ( pipe_userclk1_out),
          .CLK_USERCLK2                   ( pipe_userclk2_out),
          .CLK_MMCM_LOCK                  ( pipe_mmcm_lock_out)

      );




    //---------- GT COMMON Internal Mode---------------------------------------

            wire [1:0]                          qpll_qplllock;
            wire [1:0]                          qpll_qplloutclk;
            wire [1:0]                          qpll_qplloutrefclk;

	    assign qpll_drp_done                         =  2'd0;
            assign qpll_drp_reset                        =  2'd0;
            assign qpll_drp_crscode                      =  12'd0;
            assign qpll_drp_fsm                          =  18'd0;
            assign qpll_qplloutclk                       =  2'd0;
            assign qpll_qplloutrefclk                    =  2'd0;
            assign qpll_qplllock                         =  2'd0;



pcie_s7 pcie_i
(
    .pci_exp_txn(pci_exp_txn),
    .pci_exp_txp(pci_exp_txp),
    .pci_exp_rxn(pci_exp_rxn),
    .pci_exp_rxp(pci_exp_rxp),
    .pipe_pclk_in(pipe_pclk_out),
    .pipe_rxusrclk_in(pipe_rxusrclk_out),
    .pipe_rxoutclk_in(pipe_rxoutclk_out),
    .pipe_mmcm_rst_n(pipe_mmcm_rst_n),
    .pipe_dclk_in(pipe_dclk_out),
    .pipe_userclk1_in(pipe_userclk1_out),
    .pipe_userclk2_in(pipe_userclk2_out),
  .pipe_oobclk_in( pipe_oobclk_out ),
    .pipe_mmcm_lock_in(pipe_mmcm_lock_out),
    .pipe_txoutclk_out(pipe_txoutclk_in),
    .pipe_rxoutclk_out(pipe_rxoutclk_in),
    .pipe_pclk_sel_out(pipe_pclk_sel_in),
    .pipe_gen3_out(pipe_gen3_in),
    .user_clk_out(user_clk_out),
    .user_reset_out(user_reset_out),
    .user_lnk_up(user_lnk_up),
    .user_app_rdy(user_app_rdy),
    .s_axis_tx_tdata(s_axis_tx_tdata),
    .s_axis_tx_tvalid(s_axis_tx_tvalid),
    .s_axis_tx_tready(s_axis_tx_tready),
    .s_axis_tx_tkeep(s_axis_tx_tkeep),
    .s_axis_tx_tlast(s_axis_tx_tlast),
    .s_axis_tx_tuser(s_axis_tx_tuser),
    .m_axis_rx_tdata(m_axis_rx_tdata),
    .m_axis_rx_tvalid(m_axis_rx_tvalid),
    .m_axis_rx_tready(m_axis_rx_tready),
    .m_axis_rx_tkeep(m_axis_rx_tkeep),
    .m_axis_rx_tlast(m_axis_rx_tlast),
    .m_axis_rx_tuser(m_axis_rx_tuser),
    .tx_cfg_gnt(tx_cfg_gnt),
    .rx_np_ok(rx_np_ok),
    .rx_np_req(rx_np_req),
    .cfg_trn_pending(cfg_trn_pending),
    .cfg_pm_halt_aspm_l0s(cfg_pm_halt_aspm_l0s),
    .cfg_pm_halt_aspm_l1(cfg_pm_halt_aspm_l1),
    .cfg_pm_force_state_en(cfg_pm_force_state_en),
    .cfg_pm_force_state(cfg_pm_force_state),
    .cfg_dsn(cfg_dsn),
    .cfg_turnoff_ok(cfg_turnoff_ok),
    .cfg_pm_wake(cfg_pm_wake),
    .cfg_pm_send_pme_to(cfg_pm_send_pme_to),
    .cfg_ds_bus_number(cfg_ds_bus_number),
    .cfg_ds_device_number(cfg_ds_device_number),
    .cfg_ds_function_number(cfg_ds_function_number),
    .fc_cpld(fc_cpld),
    .fc_cplh(fc_cplh),
    .fc_npd(fc_npd),
    .fc_nph(fc_nph),
    .fc_pd(fc_pd),
    .fc_ph(fc_ph),
    .fc_sel(fc_sel),
    .cfg_mgmt_do(cfg_mgmt_do),
    .cfg_mgmt_rd_wr_done(cfg_mgmt_rd_wr_done),
    .cfg_mgmt_di(cfg_mgmt_di),
    .cfg_mgmt_byte_en(cfg_mgmt_byte_en),
    .cfg_mgmt_dwaddr(cfg_mgmt_dwaddr),
    .cfg_mgmt_wr_en(cfg_mgmt_wr_en),
    .cfg_mgmt_rd_en(cfg_mgmt_rd_en),
    .cfg_mgmt_wr_readonly(cfg_mgmt_wr_readonly),
    .cfg_mgmt_wr_rw1c_as_rw(cfg_mgmt_wr_rw1c_as_rw),
    .tx_buf_av(tx_buf_av),
    .tx_err_drop(tx_err_drop),
    .tx_cfg_req(tx_cfg_req),
    .cfg_status(cfg_status),
    .cfg_command(cfg_command),
    .cfg_dstatus(cfg_dstatus),
    .cfg_dcommand(cfg_dcommand),
    .cfg_lstatus(cfg_lstatus),
    .cfg_lcommand(cfg_lcommand),
    .cfg_dcommand2(cfg_dcommand2),
    .cfg_pcie_link_state(cfg_pcie_link_state),
    .cfg_pmcsr_pme_en(cfg_pmcsr_pme_en),
    .cfg_pmcsr_powerstate(cfg_pmcsr_powerstate),
    .cfg_pmcsr_pme_status(cfg_pmcsr_pme_status),
    .cfg_vc_tcvc_map(cfg_vc_tcvc_map),
    .cfg_to_turnoff(cfg_to_turnoff),
    .cfg_bus_number(cfg_bus_number),
    .cfg_device_number(cfg_device_number),
    .cfg_function_number(cfg_function_number),
    .cfg_bridge_serr_en(cfg_bridge_serr_en),
    .cfg_slot_control_electromech_il_ctl_pulse(cfg_slot_control_electromech_il_ctl_pulse),
    .cfg_root_control_syserr_corr_err_en(cfg_root_control_syserr_corr_err_en),
    .cfg_root_control_syserr_non_fatal_err_en(cfg_root_control_syserr_non_fatal_err_en),
    .cfg_root_control_syserr_fatal_err_en(cfg_root_control_syserr_fatal_err_en),
    .cfg_root_control_pme_int_en(cfg_root_control_pme_int_en),
    .cfg_aer_rooterr_corr_err_reporting_en(cfg_aer_rooterr_corr_err_reporting_en),
    .cfg_aer_rooterr_non_fatal_err_reporting_en(cfg_aer_rooterr_non_fatal_err_reporting_en),
    .cfg_aer_rooterr_fatal_err_reporting_en(cfg_aer_rooterr_fatal_err_reporting_en),
    .cfg_aer_rooterr_corr_err_received(cfg_aer_rooterr_corr_err_received),
    .cfg_aer_rooterr_non_fatal_err_received(cfg_aer_rooterr_non_fatal_err_received),
    .cfg_aer_rooterr_fatal_err_received(cfg_aer_rooterr_fatal_err_received),
    .cfg_received_func_lvl_rst(cfg_received_func_lvl_rst),
    .cfg_err_ecrc(cfg_err_ecrc),
    .cfg_err_ur(cfg_err_ur),
    .cfg_err_cpl_timeout(cfg_err_cpl_timeout),
    .cfg_err_cpl_unexpect(cfg_err_cpl_unexpect),
    .cfg_err_cpl_abort(cfg_err_cpl_abort),
    .cfg_err_posted(cfg_err_posted),
    .cfg_err_cor(cfg_err_cor),
    .cfg_err_atomic_egress_blocked(cfg_err_atomic_egress_blocked),
    .cfg_err_internal_cor(cfg_err_internal_cor),
    .cfg_err_malformed(cfg_err_malformed),
    .cfg_err_mc_blocked(cfg_err_mc_blocked),
    .cfg_err_poisoned(cfg_err_poisoned),
    .cfg_err_norecovery(cfg_err_norecovery),
    .cfg_err_tlp_cpl_header(cfg_err_tlp_cpl_header),
    .cfg_err_cpl_rdy(cfg_err_cpl_rdy),
    .cfg_err_locked(cfg_err_locked),
    .cfg_err_acs(cfg_err_acs),
    .cfg_err_internal_uncor(cfg_err_internal_uncor),
    .cfg_aer_ecrc_check_en(cfg_aer_ecrc_check_en),
    .cfg_aer_ecrc_gen_en(cfg_aer_ecrc_gen_en),
    .cfg_err_aer_headerlog(cfg_err_aer_headerlog),
    .cfg_err_aer_headerlog_set(cfg_err_aer_headerlog_set),
    .cfg_aer_interrupt_msgnum(cfg_aer_interrupt_msgnum),
    .cfg_interrupt(cfg_interrupt),
    .cfg_interrupt_rdy(cfg_interrupt_rdy),
    .cfg_interrupt_assert(cfg_interrupt_assert),
    .cfg_interrupt_di(cfg_interrupt_di),
    .cfg_interrupt_do(cfg_interrupt_do),
    .cfg_interrupt_mmenable(cfg_interrupt_mmenable),
    .cfg_interrupt_msienable(cfg_interrupt_msienable),
    .cfg_interrupt_msixenable(cfg_interrupt_msixenable),
    .cfg_interrupt_msixfm(cfg_interrupt_msixfm),
    .cfg_interrupt_stat(cfg_interrupt_stat),
    .cfg_pciecap_interrupt_msgnum(cfg_pciecap_interrupt_msgnum),
    .cfg_msg_received(cfg_msg_received),
    .cfg_msg_data(cfg_msg_data),
    .cfg_msg_received_pm_as_nak(cfg_msg_received_pm_as_nak),
    .cfg_msg_received_setslotpowerlimit(cfg_msg_received_setslotpowerlimit),
    .cfg_msg_received_err_cor(cfg_msg_received_err_cor),
    .cfg_msg_received_err_non_fatal(cfg_msg_received_err_non_fatal),
    .cfg_msg_received_err_fatal(cfg_msg_received_err_fatal),
    .cfg_msg_received_pm_pme(cfg_msg_received_pm_pme),
    .cfg_msg_received_pme_to_ack(cfg_msg_received_pme_to_ack),
    .cfg_msg_received_assert_int_a(cfg_msg_received_assert_int_a),
    .cfg_msg_received_assert_int_b(cfg_msg_received_assert_int_b),
    .cfg_msg_received_assert_int_c(cfg_msg_received_assert_int_c),
    .cfg_msg_received_assert_int_d(cfg_msg_received_assert_int_d),
    .cfg_msg_received_deassert_int_a(cfg_msg_received_deassert_int_a),
    .cfg_msg_received_deassert_int_b(cfg_msg_received_deassert_int_b),
    .cfg_msg_received_deassert_int_c(cfg_msg_received_deassert_int_c),
    .cfg_msg_received_deassert_int_d(cfg_msg_received_deassert_int_d),
    .pl_directed_link_change(pl_directed_link_change),
    .pl_directed_link_width(pl_directed_link_width),
    .pl_directed_link_speed(pl_directed_link_speed),
    .pl_directed_link_auton(pl_directed_link_auton),
    .pl_upstream_prefer_deemph(pl_upstream_prefer_deemph),
    .pl_sel_lnk_rate(pl_sel_lnk_rate),
    .pl_sel_lnk_width(pl_sel_lnk_width),
    .pl_ltssm_state(pl_ltssm_state),
    .pl_lane_reversal_mode(pl_lane_reversal_mode),
    .pl_phy_lnk_up(pl_phy_lnk_up),
    .pl_tx_pm_state(pl_tx_pm_state),
    .pl_rx_pm_state(pl_rx_pm_state),
    .pl_link_upcfg_cap(pl_link_upcfg_cap),
    .pl_link_gen2_cap(pl_link_gen2_cap),
    .pl_link_partner_gen2_supported(pl_link_partner_gen2_supported),
    .pl_initial_link_width(pl_initial_link_width),
    .pl_directed_change_done(pl_directed_change_done),
    .pl_received_hot_rst(pl_received_hot_rst),
    .pl_transmit_hot_rst(pl_transmit_hot_rst),
    .pl_downstream_deemph_source(pl_downstream_deemph_source),
    .pcie_drp_clk(pcie_drp_clk),
    .pcie_drp_en(pcie_drp_en),
    .pcie_drp_we(pcie_drp_we),
    .pcie_drp_addr(pcie_drp_addr),
    .pcie_drp_di(pcie_drp_di),
    .pcie_drp_rdy(pcie_drp_rdy),
    .pcie_drp_do(pcie_drp_do),
    .sys_clk(sys_clk),
    .sys_rst_n(sys_rst_n)
  );

endmodule
