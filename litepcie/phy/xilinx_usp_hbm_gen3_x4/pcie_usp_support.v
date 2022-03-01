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
// AXIS FIFO                                                                                                      //
//----------------------------------------------------------------------------------------------------------------//

module axis_iff
   #(
        parameter           DAT_B  = 32
    )
    (
        input               clk,
        input               rst,

        input               i_vld,
        output              o_rdy,
        input               i_sop,
        input               i_eop,
        input  [DAT_B-1:0]  i_dat,


        output              o_vld,
        input               i_rdy,
        output              o_sop,
        output              o_eop,
        output  [DAT_B-1:0] o_dat
    );

    ///////////////////////////////////////////////////////////////////////////
    //FIFO instance
    localparam     FF_B = 8;
    localparam     FF_L = 256;

    wire           ff_empt, ff_full;
    reg [FF_B:0]   ff_len;

    wire           ff_wr, ff_rd;

    reg [FF_B-1:0] wrcnt;
    always @(posedge clk)
        if (rst) wrcnt <= {FF_B{1'b0}};
        else if (ff_wr) wrcnt <= wrcnt + 1;

    always @(posedge clk)
        if (rst) ff_len <= {FF_B+1{1'b0}};
        else
            case ({ff_wr, ff_rd})
                2'b10: ff_len <= ff_len + 1;
                2'b01: ff_len <= ff_len - 1;
                default: ff_len <= ff_len;
            endcase

    wire [FF_B-1:0] rdcnt;
    assign          rdcnt = wrcnt - ff_len[FF_B-1:0];

    wire [FF_B-1:0] rda, wra;
    assign          rda = ff_rd ? (rdcnt + 1) : rdcnt;
    assign          wra = wrcnt;

    wire [DAT_B+1:0] ff_wdat;
    wire [DAT_B+1:0] ff_rdat;
    assign           ff_wdat = {i_sop, i_eop, i_dat};
    assign           {o_sop, o_eop, o_dat} = ff_rdat;
    assign           o_rdy = !(ff_len[FF_B] | pktcnt[3]);
    assign           o_vld = (pktcnt > 0);

    reg [3:0]        pktcnt;
    assign           ff_wr = i_vld & (!(ff_len[FF_B] | pktcnt[3]));
    assign           ff_rd = i_rdy & (pktcnt > 0);

    ///////////////////////////////////////////////////////////////////////////
    //Single dual port RAM 1-clock

    (* ram_style="block" *)
    reg [DAT_B+1:0] ram [FF_L-1:0];

    always @(posedge clk)
        if (ff_wr) ram[wra] <= ff_wdat;

    reg [DAT_B+1:0]  ff_rdat_m;
    always @(posedge clk)
        ff_rdat_m <= ram[rda];

    ///////////////////////////////////////////////////////////////////////////
    //same read/write

    wire              readsame = ff_wr & (wra == rda);
    reg               readsame1;
    always @(posedge clk)
        if (rst) readsame1 <= 1'b0;
        else readsame1 <= readsame;

    reg [DAT_B+1:0] ff_wdat1;
    always @(posedge clk)
        ff_wdat1 <= ff_wdat;

    assign            ff_rdat = readsame1 ? ff_wdat1 : ff_rdat_m;

    ///////////////////////////////////////////////////////////////////////////
    //Store max 8 packet

    always @(posedge clk)
        if (rst) pktcnt <= 4'd0;
        else begin
            case ({(ff_wr & i_eop), (ff_rd & o_eop)})
                2'b10: pktcnt <= pktcnt + 1;
                2'b01: pktcnt <= pktcnt - 1;
                default: pktcnt <= pktcnt;
            endcase
            end

endmodule

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
  output                            [2:0]    cfg_negotiated_width,
  output                            [1:0]    cfg_current_speed,
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
  output                            [7:0]     cfg_interrupt_msi_vf_enable,

  //Debug
  output [15:0]                               debug              //for cmp_source {error_code[3:], error_trigger}
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

  //----------------------------------------------------- RQ AXIS --------------------------------------------------//
  wire          s_axis_rq_tready_ff,
                s_axis_rq_tvalid_ff,
                s_axis_rq_tlast_ff;
  wire [3:0]    s_axis_rq_tkeep_or = {|s_axis_rq_tkeep[15:12], |s_axis_rq_tkeep[11:8], |s_axis_rq_tkeep[7:4], |s_axis_rq_tkeep[3:0]};

  wire [3:0]    s_axis_rq_tuser_ff;
  wire [3:0]    s_axis_rq_tkeep_ff;
  wire [127:0]  s_axis_rq_tdata_ff;

  axis_iff #(.DAT_B(128+4+4))  s_axis_rq_iff
  (
        .clk    (user_clk_out),
        .rst    (user_reset_out),

        .i_vld  (s_axis_rq_tvalid),
        .o_rdy  (s_axis_rq_tready),
        .i_sop  (1'b0),
        .i_eop  (s_axis_rq_tlast),
        .i_dat  ({s_axis_rq_tuser, s_axis_rq_tkeep_or, s_axis_rq_tdata}),

        .o_vld  (s_axis_rq_tvalid_ff),
        .i_rdy  (s_axis_rq_tready_ff),
        .o_sop  (),
        .o_eop  (s_axis_rq_tlast_ff),
        .o_dat  ({s_axis_rq_tuser_ff, s_axis_rq_tkeep_ff, s_axis_rq_tdata_ff})
    );


  reg [1:0]       s_axis_rq_cnt;  //0-2
  always @(posedge user_clk_out)
      if (user_reset_out) s_axis_rq_cnt <= 2'd0;
      else if (s_axis_rq_tvalid_ff && s_axis_rq_tready_ff)
          begin
              if (s_axis_rq_tlast_ff) s_axis_rq_cnt <= 2'd0;
              else if (!s_axis_rq_cnt[1]) s_axis_rq_cnt <= s_axis_rq_cnt + 1;
          end

  wire            s_axis_rq_tfirst = (s_axis_rq_cnt == 0) && (!s_axis_rq_tlast_lat);
  wire            s_axis_rq_tsecond = s_axis_rq_cnt == 1;

  //processing for tlast: generate new last in case write & last num of dword = 5, 9, 13, ...
  wire            s_axis_rq_read = (s_axis_rq_tdata_ff[31:30] == 2'b0);  //Read request
  wire            s_axis_rq_write = !s_axis_rq_read;
  reg             s_axis_rq_tlast_dly_en;
  reg             s_axis_rq_tlast_lat;
  wire [3:0]      s_axis_rq_tready_a;
  always @(posedge user_clk_out)
      if (user_reset_out) s_axis_rq_tlast_dly_en <= 1'd0;
      else if (s_axis_rq_tvalid_ff && s_axis_rq_tfirst && s_axis_rq_tready_ff && s_axis_rq_write) s_axis_rq_tlast_dly_en <= (s_axis_rq_tdata_ff[1:0] == 2'd1);

  always @(posedge user_clk_out)
      if (user_reset_out) s_axis_rq_tlast_lat <= 1'd0;
      else if (s_axis_rq_tlast_lat && s_axis_rq_tready_a[0]) s_axis_rq_tlast_lat <= 1'd0;
      else if (s_axis_rq_tvalid_ff && s_axis_rq_tlast_ff && s_axis_rq_tready_a[0])
          begin
          if (s_axis_rq_tfirst) s_axis_rq_tlast_lat <= s_axis_rq_write ? 1'b1 : 1'b0; //write 1-dword
          else s_axis_rq_tlast_lat <= s_axis_rq_tlast_dly_en;
          end

  wire            s_axis_rq_tlast_a  = s_axis_rq_tfirst       ? s_axis_rq_read :
                                       s_axis_rq_tlast_dly_en ? s_axis_rq_tlast_lat : s_axis_rq_tlast_ff;

  //Generae ready for TLP
  assign          s_axis_rq_tready_ff = s_axis_rq_tready_a[0] && (!s_axis_rq_tlast_lat);

   //latch valid because it is uncontigous when coming from TLP request
  reg             s_axis_rq_tvalid_lat;
  always @(posedge user_clk_out)
      if (user_reset_out) s_axis_rq_tvalid_lat <= 1'b0;
      else if (s_axis_rq_tvalid_lat && s_axis_rq_tready_a[0])
          begin
          if (s_axis_rq_tlast_dly_en) s_axis_rq_tvalid_lat <= !s_axis_rq_tlast_lat;
          else s_axis_rq_tvalid_lat <= !(s_axis_rq_tlast_ff && s_axis_rq_tvalid_ff);
          end
      else if (s_axis_rq_tvalid_ff & s_axis_rq_tfirst & s_axis_rq_write) s_axis_rq_tvalid_lat <= 1'b1;   //latche input valid (required by PCIe IP)

  wire            s_axis_rq_tvalid_a = s_axis_rq_tvalid_ff | s_axis_rq_tlast_lat;

  wire [10:0]     s_axis_rq_dwlen = {1'b0, s_axis_rq_tdata_ff[9:0]};
  wire [3:0]      s_axis_rq_reqtype = {s_axis_rq_tdata_ff[31:30], s_axis_rq_tdata_ff[28:24]} == 7'b0000000 ? 4'b0000 :  //Mem read Request
                                      {s_axis_rq_tdata_ff[31:30], s_axis_rq_tdata_ff[28:24]} == 7'b0000001 ? 4'b0111 :  //Mem Read request-locked
                                      {s_axis_rq_tdata_ff[31:30], s_axis_rq_tdata_ff[28:24]} == 7'b0100000 ? 4'b0001 :  //Mem write request
                                       s_axis_rq_tdata_ff[31:24] == 8'b00000010                           ? 4'b0010 :  //I/O Read request
                                       s_axis_rq_tdata_ff[31:24] == 8'b01000010                           ? 4'b0011 :  //I/O Write request
                                       s_axis_rq_tdata_ff[31:24] == 8'b00000100                           ? 4'b1000 :  //Cfg Read Type 0
                                       s_axis_rq_tdata_ff[31:24] == 8'b01000100                           ? 4'b1010 :  //Cfg Write Type 0
                                       s_axis_rq_tdata_ff[31:24] == 8'b00000101                           ? 4'b1001 :  //Cfg Read Type 1
                                       s_axis_rq_tdata_ff[31:24] == 8'b01000101                           ? 4'b1011 :  //Cfg Write Type 1
                                                                                                          4'b1111;
  wire            s_axis_rq_poisoning = s_axis_rq_tdata_ff[14] | s_axis_rq_tuser_ff[1];   //EP must be 0 for request
  wire [15:0]     s_axis_rq_requesterid = s_axis_rq_tdata_ff[63:48];
  wire [7:0]      s_axis_rq_tag = s_axis_rq_tdata_ff[47:40];
  wire [15:0]     s_axis_rq_completerid = 16'b0;   //applicable only to Configuration requests and messages routed by ID
  wire            s_axis_rq_requester_en = 1'b0;   //Must be 0 for Endpoint
  wire [2:0]      s_axis_rq_tc = s_axis_rq_tdata_ff[22:20];
  wire [2:0]      s_axis_rq_attr = {1'b0, s_axis_rq_tdata_ff[13:12]};
  wire            s_axis_rq_ecrc = s_axis_rq_tdata_ff[15] | s_axis_rq_tuser_ff[0];     //TLP Digest

  wire [63:0]     s_axis_rq_tdata_header  = {s_axis_rq_ecrc,
                                             s_axis_rq_attr,
                                             s_axis_rq_tc,
                                             s_axis_rq_requester_en,
                                             s_axis_rq_completerid,
                                             s_axis_rq_tag,
                                             s_axis_rq_requesterid,
                                             s_axis_rq_poisoning, s_axis_rq_reqtype, s_axis_rq_dwlen};

  wire [3:0]      s_axis_rq_firstbe = s_axis_rq_tdata_ff[35:32];
  wire [3:0]      s_axis_rq_lastbe = s_axis_rq_tdata_ff[39:36];
  reg  [3:0]      s_axis_rq_firstbe_l;
  reg  [3:0]      s_axis_rq_lastbe_l;

  always @(posedge user_clk_out)
  begin
      if (s_axis_rq_tvalid_ff && s_axis_rq_tfirst)
          begin
          s_axis_rq_firstbe_l <= s_axis_rq_firstbe;
          s_axis_rq_lastbe_l <= s_axis_rq_lastbe;
          end
      end

  reg [31:0]       s_axis_rq_tdata_l;
  always @(posedge user_clk_out)
      if (s_axis_rq_tvalid_ff && s_axis_rq_tready_ff)
          s_axis_rq_tdata_l <= s_axis_rq_tdata_ff[127:96];

  wire [127:0]    s_axis_rq_tdata_a  = s_axis_rq_tfirst ? {s_axis_rq_tdata_header, 32'b0, s_axis_rq_tdata_ff[95:64]} : {s_axis_rq_tdata_ff[95:0], s_axis_rq_tdata_l[31:0]};
  wire [3:0]      s_axis_rq_tkeep_a  = s_axis_rq_tlast_lat ? 4'b0001 : 4'b1111;
  wire [59:0]     s_axis_rq_tuser_a;
  assign          s_axis_rq_tuser_a[59:8] = {32'b0, 4'b0, 1'b0, 8'b0, 2'b0, 1'b0, s_axis_rq_tuser_ff[3], 3'b0};
  assign          s_axis_rq_tuser_a[7:0]  = s_axis_rq_tfirst ? {s_axis_rq_lastbe, s_axis_rq_firstbe} : {s_axis_rq_lastbe_l, s_axis_rq_firstbe_l};

  //----------------------------------------------------- RC AXIS --------------------------------------------------//
  wire            m_axis_rc_tvalid_a;
  wire            m_axis_rc_tready_a;
  wire [3:0]      m_axis_rc_tkeep_a;
  wire [127:0]    m_axis_rc_tdata_a;
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

  wire            m_axis_rc_sop = (m_axis_rc_cnt == 0); //m_axis_rc_tuser_a[40]
  wire            m_axis_rc_second = m_axis_rc_cnt == 1;

  //header process
  wire            m_axis_rc_poisoning = m_axis_rc_tdata_a[46];
  reg             m_axis_rc_poisoning_l;
  always @(posedge user_clk_out)
     if (m_axis_rc_tvalid_a && m_axis_rc_sop)
         begin
             m_axis_rc_poisoning_l <= m_axis_rc_poisoning;
         end

  wire [9:0]      m_axis_rc_dwlen = m_axis_rc_tdata_a[41:32];
  wire [1:0]      m_axis_rc_attr = m_axis_rc_tdata_a[93:92];
  wire            m_axis_rc_ep = 1'b0;
  wire            m_axis_rc_td = 1'b0;
  wire [2:0]      m_axis_rc_tc = m_axis_rc_tdata_a[91:89];
  wire [4:0]      m_axis_rc_type;
  wire [2:0]      m_axis_rc_fmt;
  wire [11:0]     m_axis_rc_bytecnt = m_axis_rc_tdata_a[27:16];
  wire            m_axis_rc_bmc = 1'b0;
  wire [2:0]      m_axis_rc_cmpstatus = m_axis_rc_tdata_a[45:43];
  wire [15:0]     m_axis_rc_completerid = m_axis_rc_tdata_a[87:72];

  wire [6:0]      m_axis_rc_lowaddr = m_axis_rc_tdata_a[6:0];
  wire [7:0]      m_axis_rc_tag = m_axis_rc_tdata_a[71:64];
  wire [15:0]     m_axis_rc_requesterid = m_axis_rc_tdata_a[63:48];

  assign          {m_axis_rc_fmt,
                   m_axis_rc_type} = m_axis_rc_tdata_a[29] ? ((m_axis_rc_bytecnt == 0) ? 8'b000_01011 :    //Read-Locked Completion w/o data
                                                                                         8'b010_01011) :   //Read-Locked Completion w/ data
                                                             ((m_axis_rc_bytecnt == 0) ? 8'b000_01010 :    //Completion w/o data
                                                                                         8'b010_01010);    //Completion w/ data

  wire [63:0]     m_axis_rc_header0 = {m_axis_rc_completerid,
                                       m_axis_rc_cmpstatus,
                                       m_axis_rc_bmc,
                                       m_axis_rc_bytecnt,
                                       m_axis_rc_fmt[2:0], m_axis_rc_type,
                                       1'b0, m_axis_rc_tc, 4'b0,
                                       m_axis_rc_td, m_axis_rc_ep, m_axis_rc_attr,
                                       2'b0, m_axis_rc_dwlen};
  wire [63:0]     m_axis_rc_header1 = {m_axis_rc_tdata_a[127:96],
                                       m_axis_rc_requesterid,
                                       m_axis_rc_tag,
                                       1'b0, m_axis_rc_lowaddr};

  assign          m_axis_rc_tvalid = m_axis_rc_tvalid_a;
  assign          m_axis_rc_tready_a = m_axis_rc_tready;
  assign          m_axis_rc_tlast = m_axis_rc_tlast_a;
  assign          m_axis_rc_tdata = m_axis_rc_sop ? {m_axis_rc_header1, m_axis_rc_header0} : m_axis_rc_tdata_a;
  assign          m_axis_rc_tkeep = m_axis_rc_sop ? 16'hFFFF : m_axis_rc_tuser_a[15:0];
  assign          m_axis_rc_tuser = {
                                     5'd0,                         //m_axis_rc_tlast_a, 4'b0,      //rx_is_eof only for 128-bit I/F
                                     2'b0,                         //reserved
                                     m_axis_rc_sop, 4'b0,          //m_axis_rc_tuser_a[32],4'b0,   //rx_is_sof, only for 128-bit I/F  ?????????????????????
                                     8'b0,                         //BAR hit no equivalent for RC
                                     m_axis_rc_sop ? m_axis_rc_poisoning : m_axis_rc_poisoning_l,  //rx_err_fwd mapped to Poisoned completion
                                     m_axis_rc_tuser_a[42]         //ECRC mapped to discontinue
                                     };

  wire [3:0]      rc_errcode = m_axis_rc_tdata_a[15:12];
  wire            rc_status_err = ((m_axis_rc_cmpstatus != 3'b0) | (rc_errcode != 4'b0)) && m_axis_rc_tvalid && m_axis_rc_tready && m_axis_rc_sop;

  //----------------------------------------------------- CQ AXIS --------------------------------------------------//
  wire            m_axis_cq_tvalid_a;
  wire            m_axis_cq_tready_a;
  wire [3:0]      m_axis_cq_tkeep_a;
  wire [127:0]    m_axis_cq_tdata_a;
  wire [84:0]     m_axis_cq_tuser_a;
  wire            m_axis_cq_tlast_a;

  //dword counter: //0-2 & latch
  reg [1:0]       m_axis_cq_cnt;
  always @(posedge user_clk_out)
      if (user_reset_out) m_axis_cq_cnt <= 2'd0;
      else if (m_axis_cq_tvalid_a && m_axis_cq_tready_a)
          begin
              if (m_axis_cq_tlast_a) m_axis_cq_cnt <= 2'd0;
              else if (!m_axis_cq_cnt[1]) m_axis_cq_cnt <= m_axis_cq_cnt + 1;
          end

  wire            m_axis_cq_sop    = (m_axis_cq_cnt == 0) && (!m_axis_cq_tlast_lat); //m_axis_cq_tuser_a[40]
  wire            m_axis_cq_second = m_axis_cq_cnt == 1;

  wire            m_axis_cq_read = (m_axis_cq_fmt[1:0] == 2'b0);  //Read request
  wire            m_axis_cq_write = !m_axis_cq_read;
  reg             m_axis_cq_read_l;
  always @(posedge user_clk_out)
      if (user_reset_out) m_axis_cq_read_l <= 1'd0;
      else if (m_axis_cq_tvalid_a && m_axis_cq_sop) m_axis_cq_read_l <= m_axis_cq_read;

  //processing for tlast
  wire [9:0]      m_axis_cq_dwlen;
  reg             m_axis_cq_tlast_dly_en;
  always @(posedge user_clk_out)
      if (user_reset_out) m_axis_cq_tlast_dly_en <= 1'd0;
      else if (m_axis_cq_tlast_lat && m_axis_cq_tready) m_axis_cq_tlast_dly_en <= 1'd0;
      else if (m_axis_cq_tvalid_a && m_axis_cq_sop)
         begin
         if (m_axis_cq_read) m_axis_cq_tlast_dly_en <= 1'b1;
         else m_axis_cq_tlast_dly_en <= (m_axis_cq_dwlen[1:0] != 2'd1);
         end

  reg             m_axis_cq_tlast_lat;
  always @(posedge user_clk_out)
      if (user_reset_out) m_axis_cq_tlast_lat <= 1'd0;
      else if (m_axis_cq_tlast_lat && m_axis_cq_tready) m_axis_cq_tlast_lat <= 1'd0;
      else if (m_axis_cq_tvalid_a && m_axis_cq_tready_a && m_axis_cq_tlast_a)
          begin
          if (m_axis_cq_sop) m_axis_cq_tlast_lat <= 1'd1; //read
          else if (m_axis_cq_tlast_dly_en) m_axis_cq_tlast_lat <= 1'b1;
          end

  //Generae ready for PCIe IP
  assign          m_axis_cq_tready_a = ((m_axis_cq_cnt == 0) | m_axis_cq_tready) && (!m_axis_cq_tlast_lat);

  //output for TLP
  assign          m_axis_cq_tlast = m_axis_cq_tlast_dly_en ? m_axis_cq_tlast_lat : m_axis_cq_tlast_a;
  assign          m_axis_cq_tvalid = (m_axis_cq_tvalid_a & (|m_axis_cq_cnt)) | m_axis_cq_tlast_lat;


  ////keep address (low) or data (high), not header
  reg [127:0]     m_axis_cq_tdata_a1;
  reg [15:0]      m_axis_cq_tlast_be1;
  always @(posedge user_clk_out)
     if (m_axis_cq_tvalid_a && m_axis_cq_tready_a)
          begin
          m_axis_cq_tdata_a1 <= m_axis_cq_tdata_a;
          m_axis_cq_tlast_be1 <= m_axis_cq_tuser_a[23:8];
          end

  //data processing
  wire [63:0]     m_axis_cq_tdata_hdr = m_axis_cq_tdata_a[127:64];

  assign          m_axis_cq_dwlen = m_axis_cq_tdata_hdr[9:0];
  wire [1:0]      m_axis_cq_attr = m_axis_cq_tdata_hdr[61:60];
  wire            m_axis_cq_ep = 1'b0;
  wire            m_axis_cq_td = 1'b0;
  wire [2:0]      m_axis_cq_tc = m_axis_cq_tdata_hdr[59:57];
  wire [4:0]      m_axis_cq_type;
  wire [2:0]      m_axis_cq_fmt;
  wire [7:0]      m_axis_cq_be = m_axis_cq_tuser_a[7:0];
  wire [7:0]      m_axis_cq_tag = m_axis_cq_tdata_hdr[39:32];
  wire [15:0]     m_axis_cq_requesterid = m_axis_cq_tdata_hdr[31:16];

  assign          {m_axis_cq_fmt, m_axis_cq_type} = m_axis_cq_tdata_hdr[14:11] == 4'b0000 ? 8'b000_00000 :  //Mem read Request
                                                    m_axis_cq_tdata_hdr[14:11] == 4'b0111 ? 8'b000_00001 :  //Mem Read request-locked
                                                    m_axis_cq_tdata_hdr[14:11] == 4'b0001 ? 8'b010_00000 :  //Mem write request
                                                    m_axis_cq_tdata_hdr[14:11] == 4'b0010 ? 8'b000_00010 :  //I/O Read request
                                                    m_axis_cq_tdata_hdr[14:11] == 4'b0011 ? 8'b010_00010 :  //I/O Write request
                                                    m_axis_cq_tdata_hdr[14:11] == 4'b1000 ? 8'b000_00100 :  //Cfg Read Type 0
                                                    m_axis_cq_tdata_hdr[14:11] == 4'b1010 ? 8'b010_00100 :  //Cfg Write Type 0
                                                    m_axis_cq_tdata_hdr[14:11] == 4'b1001 ? 8'b000_00101 :  //Cfg Read Type 1
                                                    m_axis_cq_tdata_hdr[14:11] == 4'b1011 ? 8'b010_00101 :  //Cfg Write Type 1
                                                                                            8'b000_00000;   //Mem read Request

  reg [7:0]        m_axis_cq_tuser_barhit;
  always @(posedge user_clk_out)
      if (m_axis_cq_tvalid_a && m_axis_cq_sop)
          m_axis_cq_tuser_barhit <= {1'b0, m_axis_cq_tdata_hdr[50:48], m_axis_cq_tdata_hdr[14:11]};  //only valid @sop

  reg              m_axis_cq_ecrc;
  always @(posedge user_clk_out)
      begin
          m_axis_cq_ecrc <= m_axis_cq_tuser_a[41];
      end

  reg [63:0]       m_axis_cq_header;
  always @(posedge user_clk_out)
      if (m_axis_cq_tvalid_a && m_axis_cq_sop)
          m_axis_cq_header = {m_axis_cq_requesterid,
                              m_axis_cq_tag,
                              m_axis_cq_be,
                              m_axis_cq_fmt, m_axis_cq_type,
                              1'b0, m_axis_cq_tc, 4'b0,
                              m_axis_cq_td, m_axis_cq_ep, m_axis_cq_attr,
                              2'b0, m_axis_cq_dwlen};

  wire [31:0]     m_axis_cq_hiaddr_mask = m_axis_cq_read_l ? 32'b0 : m_axis_cq_tdata_a[31:0];
  assign          m_axis_cq_tdata = (m_axis_cq_read_l | m_axis_cq_second) ? {m_axis_cq_hiaddr_mask, m_axis_cq_tdata_a1[31:0], m_axis_cq_header} :
                                                                            {m_axis_cq_tdata_a[31:0], m_axis_cq_tdata_a1[127:32]};

  assign          m_axis_cq_tkeep = m_axis_cq_read_l    ? 16'h0FFF :
                                    m_axis_cq_tlast_lat ? {4'b0, m_axis_cq_tlast_be1[15:4]} : 16'hFFFF;


  assign          m_axis_cq_tuser = {
                                     5'b0,                     //rx_is_eof only for 128-bit I/F
                                     2'b0,                     //reserved
                                     5'b0,                     //m_axis_cq_tuser_a[40],4'b0,     //rx_is_sof only for 128-bit I/F
                                     m_axis_cq_tuser_barhit,
                                     1'b0,                    //rx_err_fwd -> no equivalent
                                     m_axis_cq_ecrc           //ECRC mapped to discontinue
                                     };

  //----------------------------------------------------- CC AXIS --------------------------------------------------//
  wire          s_axis_cc_tready_ff,
                s_axis_cc_tvalid_ff,
                s_axis_cc_tlast_ff;
  wire [3:0]    s_axis_cc_tkeep_or = {|s_axis_cc_tkeep[15:12], |s_axis_cc_tkeep[11:8],
                                      |s_axis_cc_tkeep[7:4], |s_axis_cc_tkeep[3:0]};

  wire [3:0]    s_axis_cc_tuser_ff;
  wire [3:0]    s_axis_cc_tkeep_ff;
  wire [127:0]  s_axis_cc_tdata_ff;

  axis_iff #(.DAT_B(128+4+4))  s_axis_cc_iff
  (
        .clk    (user_clk_out),
        .rst    (user_reset_out),

        .i_vld  (s_axis_cc_tvalid),
        .o_rdy  (s_axis_cc_tready),
        .i_sop  (1'b0),
        .i_eop  (s_axis_cc_tlast),
        .i_dat  ({s_axis_cc_tuser, s_axis_cc_tkeep_or, s_axis_cc_tdata}),

        .o_vld  (s_axis_cc_tvalid_ff),
        .i_rdy  (s_axis_cc_tready_ff),
        .o_sop  (),
        .o_eop  (s_axis_cc_tlast_ff),
        .o_dat  ({s_axis_cc_tuser_ff, s_axis_cc_tkeep_ff, s_axis_cc_tdata_ff})
    );

  reg [1:0]       s_axis_cc_cnt;  //0-2
  always @(posedge user_clk_out)
      if (user_reset_out) s_axis_cc_cnt <= 2'd0;
      else if (s_axis_cc_tvalid_ff && s_axis_cc_tready_ff)
          begin
              if (s_axis_cc_tlast_ff) s_axis_cc_cnt <= 2'd0;
              else if (!s_axis_cc_cnt[1]) s_axis_cc_cnt <= s_axis_cc_cnt + 1;
          end

  wire            s_axis_cc_tfirst = s_axis_cc_cnt == 0;
  wire            s_axis_cc_tsecond = s_axis_cc_cnt == 1;

  wire [3:0]      s_axis_cc_tready_a;

  wire [6:0]      s_axis_cc_lowaddr = s_axis_cc_tdata_ff[70:64];
  wire [1:0]      s_axis_cc_at = 2'b0; //address translation
  wire [12:0]     s_axis_cc_bytecnt = {1'b0, s_axis_cc_tdata_ff[43:32]};
  wire            s_axis_cc_lockedrdcmp = (s_axis_cc_tdata_ff[29:24] == 6'b0_01011);    //Read-Locked Completion
  wire [9:0]      s_axis_cc_dwordcnt = s_axis_cc_tdata_ff[9:0];
  wire [2:0]      s_axis_cc_cmpstatus = s_axis_cc_tdata_ff[47:45];
  wire            s_axis_cc_poison = s_axis_cc_tdata_ff[14];
  wire [15:0]     s_axis_cc_requesterid = s_axis_cc_tdata_ff[95:80];

  wire [7:0]      s_axis_cc_tag = s_axis_cc_tdata_ff[79:72];
  wire [15:0]     s_axis_cc_completerid = s_axis_cc_tdata_ff[63:48];
  wire            s_axis_cc_completerid_en = 1'b0;     //must be 0 for End-point
  wire [2:0]      s_axis_cc_tc = s_axis_cc_tdata_ff[22:20];
  wire [2:0]      s_axis_cc_attr = {1'b0, s_axis_cc_tdata_ff[13:12]};
  wire            s_axis_cc_td = s_axis_cc_tdata_ff[15] | s_axis_cc_tuser_ff[0];  //ECRC @sop


  wire [63:0]     s_axis_cc_header0 = {s_axis_cc_requesterid,
                                       2'b0, s_axis_cc_poison, s_axis_cc_cmpstatus, s_axis_cc_dwordcnt,
                                       2'b0, s_axis_cc_lockedrdcmp, s_axis_cc_bytecnt,
                                       6'b0, s_axis_cc_at,
                                       1'b0, s_axis_cc_lowaddr};
  wire [63:0]     s_axis_cc_header1 = {s_axis_cc_tdata_ff[127:96],
                                       s_axis_cc_td, s_axis_cc_attr, s_axis_cc_tc, s_axis_cc_completerid_en,
                                       s_axis_cc_completerid,
                                       s_axis_cc_tag
                                       };

  reg  [3:0]      s_axis_cc_firstbe;
  reg  [3:0]      s_axis_cc_lastbe;

  reg             s_axis_cc_tvalid_ff_lat;
  always @(posedge user_clk_out)
      if (user_reset_out) s_axis_cc_tvalid_ff_lat <= 1'd0;
      else if (s_axis_cc_tvalid_ff && s_axis_cc_tready_ff)
          begin
              if (s_axis_cc_tlast_ff) s_axis_cc_tvalid_ff_lat <= 1'd0;
              else if (s_axis_cc_tfirst) s_axis_cc_tvalid_ff_lat <= 1'd1;
          end

  wire            s_axis_cc_tvalid_a = s_axis_cc_tvalid_ff;
  assign          s_axis_cc_tready_ff = s_axis_cc_tready_a[0];
  wire [127:0]    s_axis_cc_tdata_a  = s_axis_cc_tfirst ? {s_axis_cc_header1, s_axis_cc_header0} : s_axis_cc_tdata_ff;
  wire            s_axis_cc_tlast_a = s_axis_cc_tlast_ff;
  wire [3:0]      s_axis_cc_tkeep_a = s_axis_cc_tkeep_ff;
  wire [32:0]     s_axis_cc_tuser_a  = {32'b0, s_axis_cc_tuser_ff[3]};    //{parity, discontinue}

  wire            cc_status_err = (s_axis_cc_cmpstatus != 3'b0) && s_axis_cc_tvalid_ff && s_axis_cc_tready_ff && s_axis_cc_tfirst;

  reg [31:0]      cccnt;
  always @(posedge user_clk_out)
      if (user_reset_out) cccnt <= 16'b0;
      else if (s_axis_cc_tvalid_a && s_axis_cc_tready_a[0] && s_axis_cc_tfirst) cccnt <= cccnt + s_axis_cc_dwordcnt;

  //----------------------------------------------------------------------------------------------------------------//
  //Debug only

  //Condition trigger
  wire            cmperr_trigger = (m_axis_rc_tdata_a[15:12] != 4'b0) & m_axis_rc_tvalid_a & m_axis_rc_tready_a & m_axis_rc_sop;
  assign          debug  = {m_axis_rc_tdata_a[15:12], cmperr_trigger};

  //----------------------------------------------------------------------------------------------------------------//
  //   MSI Adaption Logic                                                                                          //
  //----------------------------------------------------------------------------------------------------------------//

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
      else cfg_interrupt_msi_int_valid_sh <= {cfg_interrupt_msi_int_valid_sh[0], cfg_interrupt_msi_int_valid};

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

  pcie_usp  pcie_usp_i (

    //---------------------------------------------------------------------------------------//
    //  PCI Express (pci_exp) Interface                                                      //
    //---------------------------------------------------------------------------------------//

    // Tx
    .pci_exp_txn                                    ( pci_exp_txn ),
    .pci_exp_txp                                    ( pci_exp_txp ),

    // Rx
    .pci_exp_rxn                                    ( pci_exp_rxn ),
    .pci_exp_rxp                                    ( pci_exp_rxp ),

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
    .cfg_ltssm_state                                ( cfg_ltssm_state ),
    .cfg_rcb_status                                 ( cfg_rcb_status ),
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
    .cfg_mgmt_function_number                       ( 8'b0 ),
    .cfg_mgmt_debug_access                          ( 1'b0 ),

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

    //-----------------------------------------------------------------------------//
    // Configuration Control Interface                                             //
    // ----------------------------------------------------------------------------//

    // Hot reset enable
    .cfg_hot_reset_in                               ( pl_transmit_hot_rst ),
    .cfg_hot_reset_out                              ( pl_received_hot_rst ),

    //Power state change interupt
    .cfg_power_state_change_ack                     ( cfg_power_state_change_ack ),
    .cfg_power_state_change_interrupt               ( cfg_power_state_change_interrupt ),

    .cfg_err_cor_in                                 ( 1'b0 ),  // Never report Correctable Error
    .cfg_err_uncor_in                               ( 1'b0 ),  // Never report UnCorrectable Error

    .cfg_flr_in_process                             ( cfg_flr_in_process ),
    .cfg_flr_done                                   ( {2'b0,cfg_flr_done} ),
    .cfg_vf_flr_in_process                          ( cfg_vf_flr_in_process ),
    .cfg_vf_flr_done                                ( {2'b0,cfg_vf_flr_done} ),
    .cfg_vf_flr_func_num                            ( 8'b0 ),

    .cfg_link_training_enable                       ( 1'b1 ),  // Always enable LTSSM to bring up the Link

    .cfg_pm_aspm_l1_entry_reject                    ( 1'b0 ),
    .cfg_pm_aspm_tx_l0s_entry_disable               ( 1'b0 ),

    // EP only
    .cfg_config_space_enable                        ( 1'b1 ),  //ref pcie_app_uscale
    .cfg_req_pm_transition_l23_ready                ( 1'b0 ),

    //----------------------------------------------------------------------------------------------------------------//
    // Indentication & Routing                                                                                        //
    //----------------------------------------------------------------------------------------------------------------//

    .cfg_dsn                                        ( cfg_dsn ),
    .cfg_ds_bus_number                              ( cfg_ds_bus_number ),
    .cfg_ds_device_number                           ( cfg_ds_device_number ),
    .cfg_ds_port_number                             ( cfg_ds_port_number ),

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
    //  System(SYS) Interface                                                               //
    //--------------------------------------------------------------------------------------//

    .sys_clk                                        ( sys_clk ),
    .sys_clk_gt                                     ( sys_clk_gt ),
    .sys_reset                                      ( sys_rst_n )
  );

endmodule
