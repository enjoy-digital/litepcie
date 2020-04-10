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

(* DowngradeIPIdentifiedWarnings = "yes" *)
module pcie_support # (
  parameter LINK_CAP_MAX_LINK_WIDTH = 4,                       // PCIe Lane Width
  parameter C_DATA_WIDTH            = 64,                      // AXI interface data width
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
  input                            [31:0]     cfg_interrupt_msi_int,
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


  wire                            [3:0]      cfg_interrupt_msi_enable_x4;
  assign                                     cfg_interrupt_msi_enable = cfg_interrupt_msi_enable_x4[0];
  // Device Information
  wire  [15:0]                               cfg_vend_id = 16'h10EE;
  wire  [15:0]                               cfg_dev_id = 16'h7021;
  wire  [15:0]                               cfg_subsys_id = 16'h0007;                                
  wire  [7:0]                                cfg_rev_id = 8'h00; 

  //----------------------------------------------------------------------------------------------------------------//
  //   Core instance                                                                                                //
  //----------------------------------------------------------------------------------------------------------------//

  //-------------- RQ AXIS ------------//
  reg [1:0]       s_axis_rq_cnt;  //0-2
  always @(posedge user_clk_out)
      if (user_reset_out) s_axis_rq_cnt <= 2'd0;
      else if (s_axis_rq_tvalid && s_axis_rq_tready)
          begin
              if (s_axis_rq_tlast) s_axis_rq_cnt <= 2'd0;
              else if (!s_axis_rq_cnt[1]) s_axis_rq_cnt <= s_axis_rq_cnt + 1;
          end

  wire            s_axis_rq_tfirst = s_axis_rq_cnt == 0;
  wire            s_axis_rq_tsecond = s_axis_rq_cnt == 1;

  //mask tready
  wire [3:0]      s_axis_rq_tready_a;
  reg             s_axis_rq_tready_mask;
  always @(posedge user_clk_out)
      if (user_reset_out) s_axis_rq_tready_mask <= 1'b0;
      else if (s_axis_rq_tvalid && s_axis_rq_tready && s_axis_rq_tfirst) s_axis_rq_tready_mask <= 1'b1;
      else s_axis_rq_tready_mask <= 1'b0;


  wire [10:0]     s_axis_rq_dwordcnt = {1'b0, s_axis_rq_tdata[9:0]};
  wire [3:0]      s_axis_rq_reqtype = {s_axis_rq_tdata[31:30], s_axis_rq_tdata[28:24]} == 7'b0000000 ? 4'b0000 :  //Mem read Request
                                      {s_axis_rq_tdata[31:30], s_axis_rq_tdata[28:24]} == 7'b0000001 ? 4'b0111 :  //Mem Read request-locked
                                      {s_axis_rq_tdata[31:30], s_axis_rq_tdata[28:24]} == 7'b0100000 ? 4'b0001 :  //Mem write request
                                       s_axis_rq_tdata[31:24] == 8'b00000010                         ? 4'b0010 :  //I/O Read request
                                       s_axis_rq_tdata[31:24] == 8'b01000010                         ? 4'b0011 :  //I/O Write request
                                       s_axis_rq_tdata[31:24] == 8'b00000100                         ? 4'b1000 :  //Cfg Read Type 0
                                       s_axis_rq_tdata[31:24] == 8'b01000100                         ? 4'b1010 :  //Cfg Write Type 0
                                       s_axis_rq_tdata[31:24] == 8'b00000101                         ? 4'b1001 :  //Cfg Read Type 1
                                       s_axis_rq_tdata[31:24] == 8'b01000101                         ? 4'b1011 :  //Cfg Write Type 1
                                                                                                       4'b1111;
  wire            s_axis_rq_poisoning = s_axis_rq_tdata[14] | s_axis_rq_tuser[1];   //EP must be 0 for request
  wire [15:0]     s_axis_rq_requesterid = s_axis_rq_tdata[63:48];
  wire [7:0]      s_axis_rq_tag = s_axis_rq_tdata[47:40];
  wire [15:0]     s_axis_rq_completerid = 16'b0;   //applicable only to Configuration requests and messages routed by ID
  wire            s_axis_rq_requester_en = 1'b0;   //Must be 0 for Endpoint
  wire [2:0]      s_axis_rq_tc = s_axis_rq_tdata[22:20];
  wire [2:0]      s_axis_rq_attr = {1'b0, s_axis_rq_tdata[13:12]};
  wire            s_axis_rq_ecrc = s_axis_rq_tdata[15] | s_axis_rq_tuser[0];     //TLP Digest

  reg  [3:0]      s_axis_rq_firstbe;
  reg  [3:0]      s_axis_rq_lastbe;

  reg [63:0]      s_axis_rq_tdata_header;
  always @(posedge user_clk_out)
  begin
      if (s_axis_rq_tvalid && s_axis_rq_tready && s_axis_rq_tfirst)
          begin
              s_axis_rq_tdata_header <= {s_axis_rq_ecrc,
                                         s_axis_rq_attr,
                                         s_axis_rq_tc,
                                         s_axis_rq_requester_en,
                                         s_axis_rq_completerid,
                                         s_axis_rq_tag,
                                         s_axis_rq_requesterid,
                                         s_axis_rq_poisoning,
                                         s_axis_rq_reqtype,
                                         s_axis_rq_dwordcnt};
              s_axis_rq_firstbe <= s_axis_rq_tdata[35:32];
              s_axis_rq_lastbe <= s_axis_rq_tdata[39:36];
          end
      end
  
  assign          s_axis_rq_tready   = s_axis_rq_tready_a[0] & (!s_axis_rq_tready_mask);
  wire            s_axis_rq_tvalid_a = s_axis_rq_tvalid & (!s_axis_rq_tfirst);
  wire [63:0]     s_axis_rq_tdata_a  = (s_axis_rq_tsecond & (!s_axis_rq_tready_mask)) ? s_axis_rq_tdata_header : s_axis_rq_tdata;
  wire            s_axis_rq_tlast_a = s_axis_rq_tlast &  (!s_axis_rq_tready_mask);
  wire [1:0]      s_axis_rq_tkeep_a = s_axis_rq_tready_mask ? 2'b11 : {|s_axis_rq_tkeep[7:4], |s_axis_rq_tkeep[3:0]};
  wire [59:0]     s_axis_rq_tuser_a  = {32'b0, 4'b0, 1'b0, 8'b0, 2'b0, 1'b0, s_axis_rq_tuser[3], 3'b0, s_axis_rq_lastbe, s_axis_rq_firstbe};

  //-------------- RC AXIS Master------------//
  wire            m_axis_rc_tvalid_a;
  wire            m_axis_rc_tready_a;
  wire [1:0]      m_axis_rc_tkeep_a;
  wire [63:0]     m_axis_rc_tdata_a;
  wire [74:0]     m_axis_rc_tuser_a;
  wire            m_axis_rc_tlast_a;

  reg [1:0]       m_axis_rc_cnt;  //0-2
  always @(posedge user_clk_out)
      if (user_reset_out) m_axis_rc_cnt <= 2'd0;
      else if (m_axis_rc_tvalid_a && m_axis_rc_tready_a)
          begin
              if (m_axis_rc_tlast_a) m_axis_rc_cnt <= 2'd0;
              else if (!m_axis_rc_cnt[1]) m_axis_rc_cnt <= m_axis_rc_cnt + 1;
          end

  wire            m_axis_rc_sop = m_axis_rc_tuser_a[40];
  wire            m_axis_rc_second = m_axis_rc_cnt == 1;
 
  //mask ready
  reg             m_axis_rc_tready_mask;
  always @(posedge user_clk_out)
      if (user_reset_out) m_axis_rc_tready_mask <= 1'd0;
      else if (m_axis_rc_tvalid_a & m_axis_rc_tready_a & m_axis_rc_sop) m_axis_rc_tready_mask <= 1'd1;
      else m_axis_rc_tready_mask <= 1'd0;

  //latch header
  reg [63:0]      m_axis_rc_tdata_a1;
  always @(posedge user_clk_out)
     if (m_axis_rc_tvalid_a & m_axis_rc_tready_a)
          m_axis_rc_tdata_a1 <= m_axis_rc_tdata_a;

  wire [9:0]      m_axis_rc_dwordcnt = m_axis_rc_tdata_a1[41:32];
  wire [1:0]      m_axis_rc_attr = m_axis_rc_tdata_a[29:28];
  wire            m_axis_rc_ep = 1'b0;
  wire            m_axis_rc_td = 1'b0;
  wire [2:0]      m_axis_rc_tc = m_axis_rc_tdata_a[27:25];
  wire [4:0]      m_axis_rc_type;
  wire [2:0]      m_axis_rc_fmt;
  wire [11:0]     m_axis_rc_bytecnt = m_axis_rc_tdata_a1[27:16];
  wire            m_axis_rc_bmc = 1'b0;
  wire [2:0]      m_axis_rc_cmpstatus = m_axis_rc_tdata_a1[45:43];
  wire [15:0]     m_axis_rc_completerid = m_axis_rc_tdata_a[23:8];

  wire [6:0]      m_axis_rc_lowaddr = m_axis_rc_tdata_a1[6:0];
  wire [7:0]      m_axis_rc_tag = m_axis_rc_tdata_a[15:8];
  wire [15:0]     m_axis_rc_requesterid = m_axis_rc_tdata_a1[31:16];

  assign          {m_axis_rc_fmt, 
                   m_axis_rc_type} = m_axis_rc_tuser_a[29] ? ((m_axis_rc_bytecnt == 0) ? 8'b000_01011 :    //Read-Locked Completion w/o data
                                                                                        8'b010_01011) :    //Read-Locked Completion w/ data
                                                             ((m_axis_rc_bytecnt == 0) ? 8'b000_01010 :    //Completion w/o data
                                                                                        8'b010_01010);     //Completion w/ data
  
  wire [63:0]     m_axis_rc_header0 = {m_axis_rc_completerid,
                                       m_axis_rc_cmpstatus,
                                       m_axis_rc_bmc,
                                       m_axis_rc_bytecnt,
                                       1'b0, m_axis_rc_fmt, m_axis_rc_type,
                                       1'b0, m_axis_rc_tc, 4'b0,
                                       m_axis_rc_td, m_axis_rc_ep, m_axis_rc_attr, 
                                       2'b0, m_axis_rc_dwordcnt};
  wire [63:0]     m_axis_rc_header1 = {m_axis_rc_tdata_a[63:32],
                                       m_axis_rc_requesterid,
                                       m_axis_rc_tag,
                                       1'b0, m_axis_rc_lowaddr};

  assign          m_axis_rc_tvalid = m_axis_rc_tvalid_a & (|m_axis_rc_cnt);
  assign          m_axis_rc_tready_a = m_axis_rc_tready & (!m_axis_rc_tready_mask);
  assign          m_axis_rc_tlast = m_axis_rc_tlast_a & (!m_axis_rc_tready_mask);
  assign          m_axis_rc_tdata = m_axis_rc_tready_mask ? m_axis_rc_header0 : 
                                    m_axis_rc_second      ? m_axis_rc_header1 : m_axis_rc_tdata_a;
  assign          m_axis_rc_tkeep = m_axis_rc_second ? 8'hFF : m_axis_rc_tuser_a[7:0];
  assign          m_axis_rc_tuser = {
                                     5'b0,                         //rx_is_eof only for 128-bit I/F
                                     2'b0,                         //reserved
                                     m_axis_rc_tuser_a[32],4'b0,   //rx_is_sof, only for 128-bit I/F
                                     8'b0,                         //BAR hit no equivalent for RC
                                     m_axis_rc_tuser_a[46],        //rx_err_fwd mapped to Poisoned completion
                                     m_axis_rc_tuser_a[42]         //ECRC mapped to discontinue
                                     };

  //-------------- CQ AXIS Master------------//
  wire            m_axis_cq_tvalid_a;
  wire            m_axis_cq_tready_a;
  wire [1:0]      m_axis_cq_tkeep_a;
  wire [63:0]     m_axis_cq_tdata_a;
  wire [84:0]     m_axis_cq_tuser_a;
  wire            m_axis_cq_tlast_a;
  
  reg [1:0]       m_axis_cq_cnt;  //0-2

  always @(posedge user_clk_out)
      if (user_reset_out) m_axis_cq_cnt <= 2'd0;
      else if (m_axis_cq_tvalid_a && m_axis_cq_tready_a)
          begin
              if (m_axis_cq_tlast_a) m_axis_cq_cnt <= 2'd0;
              else if (!m_axis_cq_cnt[1]) m_axis_cq_cnt <= m_axis_cq_cnt + 1;
          end

  wire            m_axis_cq_sop = m_axis_cq_tuser_a[40];
  wire            m_axis_cq_second = m_axis_cq_cnt == 1;
 
  //mask ready
  reg             m_axis_cq_tready_mask;
  always @(posedge user_clk_out)
      if (user_reset_out) m_axis_cq_tready_mask <= 1'd0;
      else if (m_axis_cq_tvalid_a & m_axis_cq_tready_a & m_axis_cq_sop) m_axis_cq_tready_mask <= 1'd1;
      else m_axis_cq_tready_mask <= 1'd0;

  //latch address
  reg [63:0]      m_axis_cq_addr;
  always @(posedge user_clk_out)
     if (m_axis_cq_tvalid_a & m_axis_cq_tready_a)
          m_axis_cq_addr <= m_axis_cq_tdata_a;

  wire [9:0]      m_axis_cq_dwordcnt = m_axis_cq_tdata_a[9:0];
  wire [1:0]      m_axis_cq_attr = m_axis_cq_tdata_a[61:60];
  wire            m_axis_cq_ep = 1'b0;
  wire            m_axis_cq_td = 1'b0;
  wire [2:0]      m_axis_cq_tc = m_axis_cq_tdata_a[59:57];
  wire [4:0]      m_axis_cq_type;
  wire [2:0]      m_axis_cq_fmt;
  wire [7:0]      m_axis_cq_be = m_axis_cq_tuser_a[7:0];
  wire [7:0]      m_axis_cq_tag = m_axis_cq_tdata_a[39:32];
  wire [15:0]     m_axis_cq_requesterid = m_axis_cq_tdata_a[31:16];

  assign          {m_axis_cq_fmt, m_axis_cq_type} = m_axis_cq_tdata_a[14:11] == 4'b0000 ? 8'b000_00000 :  //Mem read Request
                                                    m_axis_cq_tdata_a[14:11] == 4'b0111 ? 8'b000_00001 :  //Mem Read request-locked
                                                    m_axis_cq_tdata_a[14:11] == 4'b0001 ? 8'b010_00000 :  //Mem write request
                                                    m_axis_cq_tdata_a[14:11] == 4'b0010 ? 8'b000_00010 :  //I/O Read request
                                                    m_axis_cq_tdata_a[14:11] == 4'b0011 ? 8'b010_00010 :  //I/O Write request
                                                    m_axis_cq_tdata_a[14:11] == 4'b1000 ? 8'b000_00100 :  //Cfg Read Type 0
                                                    m_axis_cq_tdata_a[14:11] == 4'b1010 ? 8'b010_00100 :  //Cfg Write Type 0
                                                    m_axis_cq_tdata_a[14:11] == 4'b1001 ? 8'b000_00101 :  //Cfg Read Type 1
                                                    m_axis_cq_tdata_a[14:11] == 4'b1011 ? 8'b010_00101 :  //Cfg Write Type 1
                                                                                          8'b000_00000;   //Mem read Request

  reg [7:0]        m_axis_cq_tuser_barhit;
  always @(posedge user_clk_out)
      if (m_axis_cq_tvalid_a && m_axis_cq_tready_a && m_axis_cq_sop)
          m_axis_cq_tuser_barhit <= {1'b0, m_axis_cq_tdata_a[50:48], m_axis_cq_tdata_a[14:11]};  //only valid @sop

  wire [63:0]     m_axis_cq_header = {m_axis_cq_requesterid,
                                      m_axis_cq_tag,
                                      m_axis_cq_be,
                                      1'b0, m_axis_cq_fmt, m_axis_cq_type,
                                      1'b0, m_axis_cq_tc, 4'b0,
                                      m_axis_cq_td, m_axis_cq_ep, m_axis_cq_attr, 
                                      2'b0, m_axis_cq_dwordcnt};
  assign          m_axis_cq_tvalid = m_axis_cq_tvalid_a & (|m_axis_cq_cnt);
  assign          m_axis_cq_tready_a = m_axis_cq_tready & (!m_axis_cq_tready_mask);
  assign          m_axis_cq_tlast = m_axis_cq_tlast_a & (!m_axis_cq_tready_mask);
  assign          m_axis_cq_tdata = m_axis_cq_tready_mask ? m_axis_cq_header : 
                                    m_axis_cq_second      ? m_axis_cq_addr : m_axis_cq_tdata_a;
  assign          m_axis_cq_tkeep = m_axis_cq_second ? 8'hFF : m_axis_cq_tuser_a[15:8];
  assign          m_axis_cq_tuser = {
                                     5'b0,                     //rx_is_eof only for 128-bit I/F
                                     2'b0,                     //reserved
                                     m_axis_cq_tuser_a[40],4'b0,     //rx_is_sof only for 128-bit I/F
                                     m_axis_cq_tuser_barhit,
                                     1'b0,                    //rx_err_fwd -> no equivalent
                                     m_axis_cq_tuser_a[41]      //ECRC mapped to discontinue
                                     };

  //-------------- CC AXIS Slave ------------//
  reg [1:0]       s_axis_cc_cnt;  //0-2
  always @(posedge user_clk_out)
      if (user_reset_out) s_axis_cc_cnt <= 2'd0;
      else if (s_axis_cc_tvalid && s_axis_cc_tready)
          begin
              if (s_axis_cc_tlast) s_axis_cc_cnt <= 2'd0;
              else if (!s_axis_cc_cnt[1]) s_axis_cc_cnt <= s_axis_cc_cnt + 1;
          end
  
  wire            s_axis_cc_tfirst = s_axis_cc_cnt == 0;
  wire            s_axis_cc_tsecond = s_axis_cc_cnt == 1;

  //mask tready
  wire [3:0]      s_axis_cc_tready_a;
  reg             s_axis_cc_tready_mask;
  always @(posedge user_clk_out)
      if (user_reset_out) s_axis_cc_tready_mask <= 1'b0;
      else if (s_axis_cc_tvalid && s_axis_cc_tready && s_axis_cc_tfirst) s_axis_cc_tready_mask <= 1'b1;
      else s_axis_cc_tready_mask <= 1'b0;

  reg [63:0]      s_axis_cc_tdata1;
  reg             s_axis_cc_tuser_td;
  always @(posedge user_clk_out)
      if (s_axis_cc_tvalid && s_axis_cc_tready)
          begin
              s_axis_cc_tdata1 <= s_axis_cc_tdata;
              s_axis_cc_tuser_td <= s_axis_cc_tuser[0];  //ECRC @sop
          end

  wire [6:0]      s_axis_cc_lowaddr = s_axis_cc_tdata[6:0];
  wire [1:0]      s_axis_cc_at = 0; //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  wire [12:0]     s_axis_cc_bytecnt = {1'b0, s_axis_cc_tdata1[43:32]};
  wire [1:0]      s_axis_cc_lockedrdcmp = (s_axis_cc_tdata1[29:24] == 6'b0_01011);    //Read-Locked Completion
  wire [9:0]      s_axis_cc_dwordcnt = s_axis_cc_tdata1[9:0];
  wire [2:0]      s_axis_cc_cmpstatus = s_axis_cc_tdata1[47:45];
  wire            s_axis_cc_poison = s_axis_cc_tdata1[14];
  wire [15:0]     s_axis_cc_requesterid = s_axis_cc_tdata[31:16];

  wire [7:0]      s_axis_cc_tag = s_axis_cc_tdata[15:8];
  wire [15:0]     s_axis_cc_completerid = s_axis_cc_tdata1[63:48];
  wire            s_axis_cc_completerid_en = 1'b0;     //must be 0 for End-point
  wire [2:0]      s_axis_cc_tc = s_axis_cc_tdata1[22:20];
  wire [1:0]      s_axis_cc_attr = s_axis_cc_tdata1[13:12];
  wire            s_axis_cc_td = s_axis_cc_tdata[15] | s_axis_cc_tuser_td;


  wire [63:0]     s_axis_cc_header0 = {s_axis_cc_requesterid,                                       
                                       1'b0, s_axis_cc_poison, s_axis_cc_cmpstatus, s_axis_cc_dwordcnt,
                                       2'b0, s_axis_cc_lockedrdcmp, s_axis_cc_bytecnt,
                                       6'b0, s_axis_cc_at, 
                                       1'b0, s_axis_cc_lowaddr};
  wire [63:0]     s_axis_cc_header1 = {s_axis_cc_tag,
                                       s_axis_cc_completerid,
                                       s_axis_cc_td, s_axis_cc_attr, s_axis_cc_tc, s_axis_cc_completerid_en};

  reg  [3:0]      s_axis_cc_firstbe;
  reg  [3:0]      s_axis_cc_lastbe;

  
  assign          s_axis_cc_tready   = s_axis_cc_tready_a[0] & (!s_axis_cc_tready_mask);
  wire            s_axis_cc_tvalid_a = s_axis_cc_tvalid & (!s_axis_cc_tfirst);
  wire [63:0]     s_axis_cc_tdata_a  = s_axis_cc_tready_mask ? s_axis_cc_header0 : 
                                       s_axis_cc_tsecond     ? s_axis_cc_header1 : s_axis_cc_tdata;
  wire            s_axis_cc_tlast_a = s_axis_cc_tlast &  (!s_axis_cc_tready_mask);
  wire [1:0]      s_axis_cc_tkeep_a = s_axis_cc_tready_mask ? 2'b11 : {|s_axis_cc_tkeep[7:4], |s_axis_cc_tkeep[3:0]};
  wire [32:0]     s_axis_cc_tuser_a  = {32'b0, s_axis_cc_tuser[3]};    //{parity, discontinue}


  //----------------------------------------------------------------------------------------------------------------//
  //   Core instance                                                                                                //
  //----------------------------------------------------------------------------------------------------------------//

  pcie_us_x4  pcie_us_x4_i (

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
    .cfg_interrupt_msi_int                          ( cfg_interrupt_msi_int ),
    .cfg_interrupt_msi_sent                         ( cfg_interrupt_msi_sent ),
    .cfg_interrupt_msi_fail                         ( cfg_interrupt_msi_fail ),

    .cfg_interrupt_msi_vf_enable                    ( cfg_interrupt_msi_vf_enable ),
    .cfg_interrupt_msi_mmenable                     ( cfg_interrupt_msi_mmenable ),
    .cfg_interrupt_msi_mask_update                  ( cfg_interrupt_msi_mask_update ),
    .cfg_interrupt_msi_data                         ( cfg_interrupt_msi_data ),
    .cfg_interrupt_msi_select                       ( 4'b0 ),
    .cfg_interrupt_msi_pending_status               ( 31'b0 ),
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
