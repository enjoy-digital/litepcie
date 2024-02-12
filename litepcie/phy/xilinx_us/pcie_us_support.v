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
// Project    : Ultrascale Integrated Block for PCI Express
// File       : pcie_support.v
// Version    : 4.4
//--
//-- Description:  PCI Express Endpoint Shared Logic Wrapper
//--
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

// Adaptation from/to Xilinx format to/from standardized TLPs Copyright (c) 2020 Enjoy-Digital <enjoy-digital.fr>

//----------------------------------------------------------------------------------------------------------------//
// PCIe                                                                                                           //
//----------------------------------------------------------------------------------------------------------------//

(* DowngradeIPIdentifiedWarnings = "yes" *)
module pcie_support # (
  parameter LINK_CAP_MAX_LINK_WIDTH = 4,                       // PCIe Lane Width
  parameter C_DATA_WIDTH            = 128,                     // AXI interface data width
  parameter KEEP_WIDTH              = C_DATA_WIDTH / 8,        // TSTRB width
  parameter PCIE_GT_DEVICE          = "GTH",                   // PCIe GT device
  parameter PCIE_USE_MODE           = "2.0"                    // PCIe use mode
)
(

  input                                       sys_clk,
  input                                       sys_clk_gt,
  input                                       sys_rst_n,

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
  // AXI-S Interface                                                                                                //
  //----------------------------------------------------------------------------------------------------------------//

  output                                     user_clk_out,
  output                                     user_reset_out,
  output                                     user_lnk_up,
  output                                     user_app_rdy,

  //Requester Request
  output   [1:0]                             pcie_tfc_nph_av,   //Transmit flow control non-posted header credit & data available
  output   [1:0]                             pcie_tfc_npd_av,
  output                           [3:0]     pcie_rq_seq_num,
  output                                     pcie_rq_seq_num_vld,
  output                           [5:0]     pcie_rq_tag,
  output                                     pcie_rq_tag_vld,
  output                           [1:0]     pcie_rq_tag_av,
  input                                      s_axis_rq_tlast,
  input               [C_DATA_WIDTH-1:0]     s_axis_rq_tdata,
  input                            [3:0]     s_axis_rq_tuser,
  input                 [KEEP_WIDTH-1:0]     s_axis_rq_tkeep,
  output                                     s_axis_rq_tready,
  input                                      s_axis_rq_tvalid,

  //Requester Completion
  output               [C_DATA_WIDTH-1:0]    m_axis_rc_tdata,
  output                           [21:0]    m_axis_rc_tuser,
  output                                     m_axis_rc_tlast,
  output                 [KEEP_WIDTH-1:0]    m_axis_rc_tkeep,
  output                                     m_axis_rc_tvalid,
  input                                      m_axis_rc_tready,

  //Completer Request
  output               [C_DATA_WIDTH-1:0]    m_axis_cq_tdata,
  output                           [21:0]    m_axis_cq_tuser,
  output                                     m_axis_cq_tlast,
  output                 [KEEP_WIDTH-1:0]    m_axis_cq_tkeep,
  output                                     m_axis_cq_tvalid,
  input                                      m_axis_cq_tready,

  //Completer Completion
  input                [C_DATA_WIDTH-1:0]    s_axis_cc_tdata,
  input                            [3:0]     s_axis_cc_tuser,
  input                                      s_axis_cc_tlast,
  input                  [KEEP_WIDTH-1:0]    s_axis_cc_tkeep,
  input                                      s_axis_cc_tvalid,
  output                                     s_axis_cc_tready,

  //----------------------------------------------------------------------------------------------------------------//
  // Sequence & Tag Report                                                                                          //
  //----------------------------------------------------------------------------------------------------------------//


  input                                      pcie_cq_np_req,
  output                           [5:0]     pcie_cq_np_req_count,

  //----------------------------------------------------------------------------------------------------------------//
  // Error Reporting Interface                                                                                      //
  //----------------------------------------------------------------------------------------------------------------//

  output                                     cfg_phy_link_down,
  output                            [1:0]    cfg_phy_link_status,
  output                            [3:0]    cfg_negotiated_width,
  output                            [2:0]    cfg_current_speed,
  output                            [2:0]    cfg_max_payload,
  output                            [2:0]    cfg_max_read_req,
  output                           [15:0]    cfg_function_status,
  output                           [11:0]    cfg_function_power_state,
  output                           [15:0]    cfg_vf_status,
  output                           [23:0]    cfg_vf_power_state,
  output                            [1:0]    cfg_link_power_state,

  output                                     cfg_err_cor_out,
  output                                     cfg_err_nonfatal_out,
  output                                     cfg_err_fatal_out,
  output                                     cfg_ltr_enable,
  output                           [5:0]     cfg_ltssm_state,
  output                           [3:0]     cfg_rcb_status,
  output                           [3:0]     cfg_dpa_substate_change,
  output                           [1:0]     cfg_obff_enable,
  output                                     cfg_pl_status_change,

  output                           [3:0]     cfg_tph_requester_enable,
  output                          [11:0]     cfg_tph_st_mode,
  output                           [7:0]     cfg_vf_tph_requester_enable,
  output                          [23:0]     cfg_vf_tph_st_mode,

  //----------------------------------------------------------------------------------------------------------------//
  // Management Interface                                                                                           //
  //----------------------------------------------------------------------------------------------------------------//

  output   [31:0]                             cfg_mgmt_do,
  output                                      cfg_mgmt_rd_wr_done,
  input    [31:0]                             cfg_mgmt_di,
  input    [3:0]                              cfg_mgmt_byte_en,
  input    [18:0]                             cfg_mgmt_dwaddr,
  input                                       cfg_mgmt_wr_en,
  input                                       cfg_mgmt_rd_en,

  //----------------------------------------------------------------------------------------------------------------//
  // Flow control                                                                                                   //
  //----------------------------------------------------------------------------------------------------------------//

  output                            [7:0]     cfg_fc_ph,
  output                           [11:0]     cfg_fc_pd,
  output                            [7:0]     cfg_fc_nph,
  output                           [11:0]     cfg_fc_npd,
  output                            [7:0]     cfg_fc_cplh,
  output                           [11:0]     cfg_fc_cpld,
  input                             [2:0]     cfg_fc_sel,

  //----------------------------------------------------------------------------------------------------------------//
  // Configuration Tx/Rx Message                                                                                    //
  //----------------------------------------------------------------------------------------------------------------//

  output                                      cfg_msg_received,
  output   [7:0]                              cfg_msg_received_data,
  output   [4:0]                              cfg_msg_received_type,

  input                                       cfg_msg_transmit,
  input    [31:0]                             cfg_msg_transmit_data,
  input    [2:0]                              cfg_msg_transmit_type,
  output                                      cfg_msg_transmit_done,

  //----------------------------------------------------------------------------------------------------------------//
  // Configuration Control Interface                                                                                //
  //----------------------------------------------------------------------------------------------------------------//

  output                                      pl_received_hot_rst,
  input                                       pl_transmit_hot_rst,

  // power-down request TLP
  input                                       cfg_power_state_change_ack,
  output                                      cfg_power_state_change_interrupt,

  // Indentication & Routing                                                                                        //

  input                            [63:0]     cfg_dsn,            //Device Serial Number
  input                             [7:0]     cfg_ds_bus_number,
  input                             [4:0]     cfg_ds_device_number,
  input                             [2:0]     cfg_ds_function_number,
  input                             [7:0]     cfg_ds_port_number,
  input                            [15:0]     cfg_subsys_vend_id,
  //----------------------------------------------------------------------------------------------------------------//
  // Interrupt Interface Signals
  //----------------------------------------------------------------------------------------------------------------//
  input                              [3:0]    cfg_interrupt_int,
  input                                       cfg_interrupt_pending,
  output                                      cfg_interrupt_sent,

  output                                      cfg_interrupt_msi_enable,     //0: Legacy; 1: MSI
  input                            [7:0]      cfg_interrupt_msi_int,
  input                                       cfg_interrupt_msi_int_valid,
  output                                      cfg_interrupt_msi_sent,
  output                                      cfg_interrupt_msi_fail,

  output                           [11:0]     cfg_interrupt_msi_mmenable,
  output                                      cfg_interrupt_msi_mask_update,
  output                           [31:0]     cfg_interrupt_msi_data,
  output                            [7:0]     cfg_interrupt_msi_vf_enable
);

  //----------------------------------------------------------------------------------------------------------------//
  //    System(SYS) Interface                                                                                       //
  //----------------------------------------------------------------------------------------------------------------//

  wire                            [7:0]       led_out;

  //----------------------------------------------------------------------------------------------------------------//
  // Function  request                                                                                              //
  //----------------------------------------------------------------------------------------------------------------//

  wire                             [2:0]     cfg_per_func_status_control = 3'b0; //request only function #0
  wire                             [15:0]    cfg_per_func_status_data;

  //----------------------------------------------------------------------------------------------------------------//
  //   Function Level Reset Handle                                                                                  //
  //----------------------------------------------------------------------------------------------------------------//

  wire                             [3:0]     cfg_flr_in_process;
  wire                             [7:0]     cfg_vf_flr_in_process;
  reg                              [3:0]     cfg_flr_done_reg0;
  reg                              [7:0]     cfg_vf_flr_done_reg0;
  reg                              [3:0]     cfg_flr_done_reg1;
  reg                              [7:0]     cfg_vf_flr_done_reg1;

  wire                             [1:0]     cfg_flr_done;
  wire                             [5:0]     cfg_vf_flr_done;

  always @(posedge user_clk_out)
      if (user_reset_out) begin
         cfg_flr_done_reg0       <= 4'b0;
         cfg_vf_flr_done_reg0    <= 8'b0;
         cfg_flr_done_reg1       <= 4'b0;
         cfg_vf_flr_done_reg1    <= 8'b0;
      end
      else begin
         cfg_flr_done_reg0       <= cfg_flr_in_process;
         cfg_vf_flr_done_reg0    <= cfg_vf_flr_in_process;
         cfg_flr_done_reg1       <= cfg_flr_done_reg0;
         cfg_vf_flr_done_reg1    <= cfg_vf_flr_done_reg0;
      end

  assign cfg_flr_done[0] = ~cfg_flr_done_reg1[0] && cfg_flr_done_reg0[0];
  assign cfg_flr_done[1] = ~cfg_flr_done_reg1[1] && cfg_flr_done_reg0[1];

  assign cfg_vf_flr_done[0] = ~cfg_vf_flr_done_reg1[0] && cfg_vf_flr_done_reg0[0];
  assign cfg_vf_flr_done[1] = ~cfg_vf_flr_done_reg1[1] && cfg_vf_flr_done_reg0[1];
  assign cfg_vf_flr_done[2] = ~cfg_vf_flr_done_reg1[2] && cfg_vf_flr_done_reg0[2];
  assign cfg_vf_flr_done[3] = ~cfg_vf_flr_done_reg1[3] && cfg_vf_flr_done_reg0[3];
  assign cfg_vf_flr_done[4] = ~cfg_vf_flr_done_reg1[4] && cfg_vf_flr_done_reg0[4];
  assign cfg_vf_flr_done[5] = ~cfg_vf_flr_done_reg1[5] && cfg_vf_flr_done_reg0[5];

  // Device Information
  wire  [15:0]                               cfg_vend_id = 16'h10EE;
  wire  [15:0]                               cfg_dev_id = 16'h7021;
  wire  [15:0]                               cfg_subsys_id = 16'h0007;
  wire  [7:0]                                cfg_rev_id = 8'h00;

  //----------------------------------------------------------------------------------------------------------------//
  //   AXIS Adaption Logic                                                                                          //
  //----------------------------------------------------------------------------------------------------------------//

   //----------------------------------------------------- RQ AXIS -------------------------------------------------//

  wire                     s_axis_rq_tvalid_a;
  wire                     s_axis_rq_tready_a;
  wire [KEEP_WIDTH/4-1 :0] s_axis_rq_tkeep_a;
  wire [C_DATA_WIDTH-1 :0] s_axis_rq_tdata_a;
  wire [255            :0] s_axis_rq_tuser_a;
  wire                     s_axis_rq_tlast_a;

   s_axis_rq_adapt #(
    .DATA_WIDTH(C_DATA_WIDTH),
    .KEEP_WIDTH(KEEP_WIDTH)
   ) s_axis_rq_adapt_i (
    .user_clk(user_clk_out),
    .user_reset(user_reset_out),

    .s_axis_rq_tdata(s_axis_rq_tdata),
    .s_axis_rq_tkeep(s_axis_rq_tkeep),
    .s_axis_rq_tlast(s_axis_rq_tlast),
    .s_axis_rq_tready(s_axis_rq_tready),
    .s_axis_rq_tuser(s_axis_rq_tuser),
    .s_axis_rq_tvalid(s_axis_rq_tvalid),

    .s_axis_rq_tdata_a(s_axis_rq_tdata_a),
    .s_axis_rq_tkeep_a(s_axis_rq_tkeep_a),
    .s_axis_rq_tlast_a(s_axis_rq_tlast_a),
    .s_axis_rq_tready_a(s_axis_rq_tready_a),
    .s_axis_rq_tuser_a(s_axis_rq_tuser_a),
    .s_axis_rq_tvalid_a(s_axis_rq_tvalid_a)
   );

  //----------------------------------------------------- RC AXIS --------------------------------------------------//

  wire                     m_axis_rc_tvalid_a;
  wire                     m_axis_rc_tready_a;
  wire [KEEP_WIDTH/4-1 :0] m_axis_rc_tkeep_a;
  wire [C_DATA_WIDTH-1 :0] m_axis_rc_tdata_a;
  wire [255            :0] m_axis_rc_tuser_a;
  wire                     m_axis_rc_tlast_a;

   m_axis_rc_adapt #(
    .DATA_WIDTH(C_DATA_WIDTH),
    .KEEP_WIDTH(KEEP_WIDTH)
   ) m_axis_rc_adapt_i (
    .user_clk(user_clk_out),
    .user_reset(user_reset_out),

    .m_axis_rc_tdata( m_axis_rc_tdata),
    .m_axis_rc_tkeep( m_axis_rc_tkeep),
    .m_axis_rc_tlast( m_axis_rc_tlast),
    .m_axis_rc_tready(m_axis_rc_tready),
    .m_axis_rc_tuser( m_axis_rc_tuser),
    .m_axis_rc_tvalid(m_axis_rc_tvalid),

    .m_axis_rc_tdata_a( m_axis_rc_tdata_a),
    .m_axis_rc_tkeep_a( m_axis_rc_tkeep_a),
    .m_axis_rc_tlast_a( m_axis_rc_tlast_a),
    .m_axis_rc_tready_a(m_axis_rc_tready_a),
    .m_axis_rc_tuser_a( m_axis_rc_tuser_a),
    .m_axis_rc_tvalid_a(m_axis_rc_tvalid_a)
   );

  //----------------------------------------------------- CQ AXIS --------------------------------------------------//

  wire                     m_axis_cq_tvalid_a;
  wire                     m_axis_cq_tready_a;
  wire [KEEP_WIDTH/4-1 :0] m_axis_cq_tkeep_a;
  wire [C_DATA_WIDTH-1 :0] m_axis_cq_tdata_a;
  wire [255            :0] m_axis_cq_tuser_a;
  wire                     m_axis_cq_tlast_a;

   m_axis_cq_adapt #(
    .DATA_WIDTH(C_DATA_WIDTH),
    .KEEP_WIDTH(KEEP_WIDTH)
   ) m_axis_cq_adapt_i (
    .user_clk(user_clk_out),
    .user_reset(user_reset_out),

    .m_axis_cq_tdata( m_axis_cq_tdata),
    .m_axis_cq_tkeep( m_axis_cq_tkeep),
    .m_axis_cq_tlast( m_axis_cq_tlast),
    .m_axis_cq_tready(m_axis_cq_tready),
    .m_axis_cq_tuser( m_axis_cq_tuser),
    .m_axis_cq_tvalid(m_axis_cq_tvalid),

    .m_axis_cq_tdata_a( m_axis_cq_tdata_a),
    .m_axis_cq_tkeep_a( m_axis_cq_tkeep_a),
    .m_axis_cq_tlast_a( m_axis_cq_tlast_a),
    .m_axis_cq_tready_a(m_axis_cq_tready_a),
    .m_axis_cq_tuser_a( m_axis_cq_tuser_a),
    .m_axis_cq_tvalid_a(m_axis_cq_tvalid_a)
   );

  //----------------------------------------------------- CC AXIS --------------------------------------------------//

  wire                     s_axis_cc_tvalid_a;
  wire                     s_axis_cc_tready_a;
  wire [KEEP_WIDTH/4-1 :0] s_axis_cc_tkeep_a;
  wire [C_DATA_WIDTH-1 :0] s_axis_cc_tdata_a;
  wire [255            :0] s_axis_cc_tuser_a;
  wire                     s_axis_cc_tlast_a;

  s_axis_cc_adapt #(
    .DATA_WIDTH(C_DATA_WIDTH),
    .KEEP_WIDTH(KEEP_WIDTH)
   ) s_axis_cc_adapt_i (
    .user_clk(user_clk_out),
    .user_reset(user_reset_out),

    .s_axis_cc_tdata(s_axis_cc_tdata),
    .s_axis_cc_tkeep(s_axis_cc_tkeep),
    .s_axis_cc_tlast(s_axis_cc_tlast),
    .s_axis_cc_tready(s_axis_cc_tready),
    .s_axis_cc_tuser(s_axis_cc_tuser),
    .s_axis_cc_tvalid(s_axis_cc_tvalid),

    .s_axis_cc_tdata_a(s_axis_cc_tdata_a),
    .s_axis_cc_tkeep_a(s_axis_cc_tkeep_a),
    .s_axis_cc_tlast_a(s_axis_cc_tlast_a),
    .s_axis_cc_tready_a(s_axis_cc_tready_a),
    .s_axis_cc_tuser_a(s_axis_cc_tuser_a),
    .s_axis_cc_tvalid_a(s_axis_cc_tvalid_a)
   );

  //---------------------------------------------------------------------------------------------------------------//
  //   MSI Adaptation Logic                                                                                        //
  //---------------------------------------------------------------------------------------------------------------//

  wire [3:0]      cfg_interrupt_msi_enable_x4;
  assign          cfg_interrupt_msi_enable = cfg_interrupt_msi_enable_x4[0];

  reg [31:0]      cfg_interrupt_msi_int_enc;
  always @(cfg_interrupt_msi_mmenable[2:0])
      case (cfg_interrupt_msi_mmenable[2:0])
          3'd0 : cfg_interrupt_msi_int_enc <= 32'h0000_0001;
          3'd1 : cfg_interrupt_msi_int_enc <= 32'h0000_0002;
          3'd2 : cfg_interrupt_msi_int_enc <= 32'h0000_0010;
          3'd3 : cfg_interrupt_msi_int_enc <= 32'h0000_0100;
          3'd4 : cfg_interrupt_msi_int_enc <= 32'h0001_0000;
          default: cfg_interrupt_msi_int_enc <= 32'h8000_0000;
       endcase

  //edge detect valid
  reg [1:0]       cfg_interrupt_msi_int_valid_sh;
  wire            cfg_interrupt_msi_int_valid_edge = cfg_interrupt_msi_int_valid_sh == 2'b01;
  always @(posedge user_clk_out)
      if (user_reset_out) cfg_interrupt_msi_int_valid_sh <= 2'd0;
      else cfg_interrupt_msi_int_valid_sh <= {cfg_interrupt_msi_int_valid_sh[0], cfg_interrupt_msi_int_valid & ~(cfg_interrupt_msi_sent | cfg_interrupt_msi_fail)};

  //latch int_enc
  reg [31:0]      cfg_interrupt_msi_int_enc_lat = 32'b0;
  always @(posedge user_clk_out)
      if (cfg_interrupt_msi_int_valid_edge) cfg_interrupt_msi_int_enc_lat <= cfg_interrupt_msi_int_enc;
      else if (cfg_interrupt_msi_sent) cfg_interrupt_msi_int_enc_lat <= 32'b0;


  reg             cfg_interrupt_msi_int_valid_edge1;
  wire [31:0]     cfg_interrupt_msi_int_enc_mux = cfg_interrupt_msi_int_valid_edge1 ? cfg_interrupt_msi_int_enc_lat : 32'b0;
  always @(posedge user_clk_out)
      if (user_reset_out) cfg_interrupt_msi_int_valid_edge1 <= 1'd0;
      else cfg_interrupt_msi_int_valid_edge1 <= cfg_interrupt_msi_int_valid_edge;

  //----------------------------------------------------------------------------------------------------------------//
  //   Core instance                                                                                                //
  //----------------------------------------------------------------------------------------------------------------//

  pcie_us  pcie_us_i (

    //---------------------------------------------------------------------------------------//
    //  PCI Express (pci_exp) Interface                                                      //
    //---------------------------------------------------------------------------------------//

    // Tx
    .pci_exp_txn                                    ( pci_exp_txn ),
    .pci_exp_txp                                    ( pci_exp_txp ),

    // Rx
    .pci_exp_rxn                                    ( pci_exp_rxn ),
    .pci_exp_rxp                                    ( pci_exp_rxp ),

    //---------- Shared Logic Internal -------------------------
    .int_qpll1lock_out                              (  ),
    .int_qpll1outrefclk_out                         (  ),
    .int_qpll1outclk_out                            (  ),

    //---------------------------------------------------------------------------------------//
    //  AXI Interface                                                                        //
    //---------------------------------------------------------------------------------------//

    .user_clk                                       ( user_clk_out ),
    .user_reset                                     ( user_reset_out ),
    .user_lnk_up                                    ( user_lnk_up ),
    .phy_rdy_out                                    ( user_app_rdy ),

    .s_axis_rq_tlast                                ( s_axis_rq_tlast_a ),
    .s_axis_rq_tdata                                ( s_axis_rq_tdata_a ),
    .s_axis_rq_tuser                                ( s_axis_rq_tuser_a ),
    .s_axis_rq_tkeep                                ( s_axis_rq_tkeep_a ),
    .s_axis_rq_tready                               ( s_axis_rq_tready_a ),
    .s_axis_rq_tvalid                               ( s_axis_rq_tvalid_a ),

    .m_axis_rc_tdata                                ( m_axis_rc_tdata_a ),
    .m_axis_rc_tuser                                ( m_axis_rc_tuser_a ),
    .m_axis_rc_tlast                                ( m_axis_rc_tlast_a ),
    .m_axis_rc_tkeep                                ( m_axis_rc_tkeep_a ),
    .m_axis_rc_tvalid                               ( m_axis_rc_tvalid_a ),
    .m_axis_rc_tready                               ( m_axis_rc_tready_a ),

    .m_axis_cq_tdata                                ( m_axis_cq_tdata_a ),
    .m_axis_cq_tuser                                ( m_axis_cq_tuser_a ),
    .m_axis_cq_tlast                                ( m_axis_cq_tlast_a ),
    .m_axis_cq_tkeep                                ( m_axis_cq_tkeep_a ),
    .m_axis_cq_tvalid                               ( m_axis_cq_tvalid_a ),
    .m_axis_cq_tready                               ( m_axis_cq_tready_a ),

    .s_axis_cc_tdata                                ( s_axis_cc_tdata_a ),
    .s_axis_cc_tuser                                ( s_axis_cc_tuser_a ),
    .s_axis_cc_tlast                                ( s_axis_cc_tlast_a ),
    .s_axis_cc_tkeep                                ( s_axis_cc_tkeep_a ),
    .s_axis_cc_tvalid                               ( s_axis_cc_tvalid_a ),
    .s_axis_cc_tready                               ( s_axis_cc_tready_a ),

    //---------------------------------------------------------------------------------------//
    //  Configuration (CFG) Interface                                                        //
    //---------------------------------------------------------------------------------------//
    .pcie_rq_seq_num                                ( pcie_rq_seq_num ),
    .pcie_rq_seq_num_vld                            ( pcie_rq_seq_num_vld ),
    .pcie_rq_tag                                    ( pcie_rq_tag ),
    .pcie_rq_tag_vld                                ( pcie_rq_tag_vld ),
    .pcie_cq_np_req_count                           ( pcie_cq_np_req_count ),
    .pcie_cq_np_req                                 ( pcie_cq_np_req ),
    .pcie_rq_tag_av                                 ( pcie_rq_tag_av ),

    //---------------------------------------------------------------------------------------//
    // Error Reporting Interface
    //---------------------------------------------------------------------------------------//
    .cfg_phy_link_down                              ( cfg_phy_link_down ),
    .cfg_phy_link_status                            ( cfg_phy_link_status ),
    .cfg_negotiated_width                           ( cfg_negotiated_width ),
    .cfg_current_speed                              ( cfg_current_speed ),
    .cfg_max_payload                                ( cfg_max_payload ),
    .cfg_max_read_req                               ( cfg_max_read_req ),
    .cfg_function_status                            ( cfg_function_status ),
    .cfg_function_power_state                       ( cfg_function_power_state ),
    .cfg_vf_status                                  ( cfg_vf_status ),
    .cfg_vf_power_state                             ( cfg_vf_power_state ),
    .cfg_link_power_state                           ( cfg_link_power_state ),

    .cfg_err_cor_out                                ( cfg_err_cor_out ),
    .cfg_err_nonfatal_out                           ( cfg_err_nonfatal_out ),
    .cfg_err_fatal_out                              ( cfg_err_fatal_out ),
    .cfg_ltr_enable                                 ( cfg_ltr_enable ),
    .cfg_ltssm_state                                ( cfg_ltssm_state ),
    .cfg_rcb_status                                 ( cfg_rcb_status ),
    .cfg_dpa_substate_change                        ( cfg_dpa_substate_change ),
    .cfg_obff_enable                                ( cfg_obff_enable ),
    .cfg_pl_status_change                           ( cfg_pl_status_change ),

    .cfg_tph_requester_enable                       ( cfg_tph_requester_enable ),
    .cfg_tph_st_mode                                ( cfg_tph_st_mode ),
    .cfg_vf_tph_requester_enable                    ( cfg_vf_tph_requester_enable ),
    .cfg_vf_tph_st_mode                             ( cfg_vf_tph_st_mode ),

    //-------------------------------------------------------------------------------//
    // Management Interface                                                          //
    //-------------------------------------------------------------------------------//
    .cfg_mgmt_addr                                  ( cfg_mgmt_dwaddr ),
    .cfg_mgmt_write                                 ( cfg_mgmt_wr_en ),
    .cfg_mgmt_write_data                            ( cfg_mgmt_di ),
    .cfg_mgmt_byte_enable                           ( cfg_mgmt_byte_en ),
    .cfg_mgmt_read                                  ( cfg_mgmt_rd_en ),
    .cfg_mgmt_read_data                             ( cfg_mgmt_do ),
    .cfg_mgmt_read_write_done                       ( cfg_mgmt_rd_wr_done ),
    .cfg_mgmt_type1_cfg_reg_access                  ( 1'b0 ),                    //This input has no effect when the core is in the Endpoint mode

    //-------------------------------------------------------------------------------//
    // Flow control                                                                  //
    //-------------------------------------------------------------------------------//

    .pcie_tfc_nph_av                                ( pcie_tfc_nph_av ),      //Transmit flow control non-posted header credit available
    .pcie_tfc_npd_av                                ( pcie_tfc_npd_av ),      //Transmit flow control non-posted payload credit available
    .cfg_msg_received                               ( cfg_msg_received ),
    .cfg_msg_received_data                          ( cfg_msg_received_data ),
    .cfg_msg_received_type                          ( cfg_msg_received_type ),

    .cfg_msg_transmit                               ( cfg_msg_transmit ),
    .cfg_msg_transmit_type                          ( cfg_msg_transmit_type ),
    .cfg_msg_transmit_data                          ( cfg_msg_transmit_data ),
    .cfg_msg_transmit_done                          ( cfg_msg_transmit_done ),

    .cfg_fc_ph                                      ( cfg_fc_ph ),
    .cfg_fc_pd                                      ( cfg_fc_pd ),
    .cfg_fc_nph                                     ( cfg_fc_nph ),
    .cfg_fc_npd                                     ( cfg_fc_npd ),
    .cfg_fc_cplh                                    ( cfg_fc_cplh ),
    .cfg_fc_cpld                                    ( cfg_fc_cpld ),
    .cfg_fc_sel                                     ( cfg_fc_sel ),

    .cfg_per_func_status_control                    ( cfg_per_func_status_control ), //Request only for PF#0
    .cfg_per_func_status_data                       ( cfg_per_func_status_data ),

    //-----------------------------------------------------------------------------//
    // Configuration Control Interface                                             //
    // ----------------------------------------------------------------------------//

    // Hot reset enable
    .cfg_hot_reset_in                               ( pl_transmit_hot_rst ),
    .cfg_hot_reset_out                              ( pl_received_hot_rst ),

    .cfg_per_function_number                        ( 4'b0 ),
    .cfg_per_function_output_request                ( 1'b0 ),  // Do not request configuration status update
    .cfg_per_function_update_done                   (  ),

    //Power state change interupt
    .cfg_power_state_change_ack                     ( cfg_power_state_change_ack ),
    .cfg_power_state_change_interrupt               ( cfg_power_state_change_interrupt ),

    .cfg_err_cor_in                                 ( 1'b0 ),  // Never report Correctable Error
    .cfg_err_uncor_in                               ( 1'b0 ),  // Never report UnCorrectable Error

    .cfg_flr_in_process                             ( cfg_flr_in_process ),
    .cfg_flr_done                                   ( {2'b0,cfg_flr_done} ),
    .cfg_vf_flr_in_process                          ( cfg_vf_flr_in_process ),
    .cfg_vf_flr_done                                ( {2'b0,cfg_vf_flr_done} ),
    .cfg_local_error                                ( ),

    .cfg_link_training_enable                       ( 1'b1 ),  // Always enable LTSSM to bring up the Link

    // EP only
    .cfg_config_space_enable                        ( 1'b1 ),  //ref pcie_app_uscale
    .cfg_req_pm_transition_l23_ready                ( 1'b0 ),

    //----------------------------------------------------------------------------------------------------------------//
    // Indentication & Routing                                                                                        //
    //----------------------------------------------------------------------------------------------------------------//

    .cfg_dsn                                        ( cfg_dsn ),
    .cfg_ds_bus_number                              ( cfg_ds_bus_number ),
    .cfg_ds_device_number                           ( cfg_ds_device_number ),
    .cfg_ds_function_number                         ( cfg_ds_function_number ),
    .cfg_ds_port_number                             ( cfg_ds_port_number ),
    .cfg_subsys_vend_id                             ( cfg_subsys_vend_id ),

    //-------------------------------------------------------------------------------//
    // Interrupt Interface Signals
    //-------------------------------------------------------------------------------//
    .cfg_interrupt_int                              ( cfg_interrupt_int ),
    .cfg_interrupt_pending                          ( {3'b0,cfg_interrupt_pending} ), //only one function 0
    .cfg_interrupt_sent                             ( cfg_interrupt_sent ),

    .cfg_interrupt_msi_enable                       ( cfg_interrupt_msi_enable_x4 ),
    .cfg_interrupt_msi_int                          ( cfg_interrupt_msi_int_enc_mux ),
    .cfg_interrupt_msi_sent                         ( cfg_interrupt_msi_sent ),
    .cfg_interrupt_msi_fail                         ( cfg_interrupt_msi_fail ),

    .cfg_interrupt_msi_vf_enable                    ( cfg_interrupt_msi_vf_enable ),
    .cfg_interrupt_msi_mmenable                     ( cfg_interrupt_msi_mmenable ),
    .cfg_interrupt_msi_mask_update                  ( cfg_interrupt_msi_mask_update ),
    .cfg_interrupt_msi_data                         ( cfg_interrupt_msi_data ),
    .cfg_interrupt_msi_select                       ( 4'b0 ),
    .cfg_interrupt_msi_pending_status               ( cfg_interrupt_msi_int_enc_lat ),
    .cfg_interrupt_msi_attr                         ( 3'b0 ),
    .cfg_interrupt_msi_tph_present                  ( 1'b0 ),
    .cfg_interrupt_msi_tph_type                     ( 2'b0 ),
    .cfg_interrupt_msi_tph_st_tag                   ( 9'b0 ),
    .cfg_interrupt_msi_pending_status_function_num  ( 4'b0 ),
    .cfg_interrupt_msi_pending_status_data_enable   ( 1'b0 ),
    .cfg_interrupt_msi_function_number              ( 4'b0 ),

    //--------------------------------------------------------------------------------------//
    // Reset Pass Through Signals
    //  - Only used for PCIe_X0Y0
    //--------------------------------------------------------------------------------------//
    .pcie_perstn0_out       (),
    .pcie_perstn1_in        (1'b0),
    .pcie_perstn1_out       (),

    //--------------------------------------------------------------------------------------//
    //  System(SYS) Interface                                                               //
    //--------------------------------------------------------------------------------------//

    .sys_clk                                        ( sys_clk ),
    .sys_clk_gt                                     ( sys_clk_gt ),
    .sys_reset                                      ( sys_rst_n )
  );

endmodule
