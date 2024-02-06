// This file is part of LitePCIe.
//
// Copyright (c) 2020-2023 Enjoy-Digital <enjoy-digital.fr>
// SPDX-License-Identifier: BSD-2-Clause

module s_axis_rq_adapt # (
      parameter DATA_WIDTH  = 256,
      parameter KEEP_WIDTH  = DATA_WIDTH/8
    )(

       input user_clk,
       input user_reset,

       input  [DATA_WIDTH-1:0] s_axis_rq_tdata,
       input  [KEEP_WIDTH-1:0] s_axis_rq_tkeep,
       input                   s_axis_rq_tlast,
       output                  s_axis_rq_tready,
       input             [3:0] s_axis_rq_tuser,
       input                   s_axis_rq_tvalid,

       output   [DATA_WIDTH-1:0] s_axis_rq_tdata_a,
       output [KEEP_WIDTH/4-1:0] s_axis_rq_tkeep_a,
       output                    s_axis_rq_tlast_a,
       input                     s_axis_rq_tready_a,
       output             [59:0] s_axis_rq_tuser_a,
       output                    s_axis_rq_tvalid_a
    );

  wire [7:0]    s_axis_rq_tkeep_or = {s_axis_rq_tkeep[28], s_axis_rq_tkeep[24], s_axis_rq_tkeep[20], s_axis_rq_tkeep[16],
                                      s_axis_rq_tkeep[12], s_axis_rq_tkeep[ 8], s_axis_rq_tkeep[ 4], s_axis_rq_tkeep[ 0]};

  wire          s_axis_rq_tvalid_ff;
  wire          s_axis_rq_tready_ff;
  wire          s_axis_rq_tlast_ff;
  wire [3:0]    s_axis_rq_tuser_ff;
  wire [7:0]    s_axis_rq_tkeep_ff;
  wire [255:0]  s_axis_rq_tdata_ff;

  axis_iff #(.DAT_B(256+8+4))  s_axis_rq_iff
  (
    .clk    (user_clk),
    .rst    (user_reset),

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

  reg s_axis_rq_tfirst_ff;
  always @(posedge user_clk)
      if (user_reset) begin
        s_axis_rq_tfirst_ff <= 1'd1;
      end
      else if (s_axis_rq_tvalid_ff && s_axis_rq_tready_ff) begin
          s_axis_rq_tfirst_ff <= 1'd0;
          if (s_axis_rq_tlast_ff) begin
             s_axis_rq_tfirst_ff <= 1'd1;
          end
      end

  assign s_axis_rq_tlast_a   = s_axis_rq_tlast_ff;
  assign s_axis_rq_tready_ff = s_axis_rq_tready_a;
  assign s_axis_rq_tvalid_a  = s_axis_rq_tvalid_ff;

  wire [10:0] s_axis_rq_dwlen_ff = {1'b0, s_axis_rq_tdata_ff[9:0]};
  wire [3:0]  s_axis_rq_reqtype_ff =
    {s_axis_rq_tdata_ff[31:30], s_axis_rq_tdata_ff[28:24]} == 7'b0000000 ? 4'b0000 :  // Mem Read request.
    {s_axis_rq_tdata_ff[31:30], s_axis_rq_tdata_ff[28:24]} == 7'b0000001 ? 4'b0111 :  // Mem Read  request-locked
    {s_axis_rq_tdata_ff[31:30], s_axis_rq_tdata_ff[28:24]} == 7'b0100000 ? 4'b0001 :  // Mem Write request.
     s_axis_rq_tdata_ff[31:24] == 8'b00000010                            ? 4'b0010 :  // I/O Read request.
     s_axis_rq_tdata_ff[31:24] == 8'b01000010                            ? 4'b0011 :  // I/O Write request.
     s_axis_rq_tdata_ff[31:24] == 8'b00000100                            ? 4'b1000 :  // Cfg Read Type 0.
     s_axis_rq_tdata_ff[31:24] == 8'b01000100                            ? 4'b1010 :  // Cfg Write Type 0.
     s_axis_rq_tdata_ff[31:24] == 8'b00000101                            ? 4'b1001 :  // Cfg Read Type 1.
     s_axis_rq_tdata_ff[31:24] == 8'b01000101                            ? 4'b1011 :  // Cfg Write Type 1.
                                                                           4'b1111;

  wire            s_axis_rq_poisoning_ff    = s_axis_rq_tdata_ff[14] | s_axis_rq_tuser_ff[1]; // EP must be 0 for request.
  wire [15:0]     s_axis_rq_requesterid_ff  = s_axis_rq_tdata_ff[63:48];
  wire [7:0]      s_axis_rq_tag_ff          = s_axis_rq_tdata_ff[47:40];
  wire [15:0]     s_axis_rq_completerid_ff  = 16'b0; // Applicable only to Configuration requests and messages routed by ID.
  wire            s_axis_rq_requester_en_ff = 1'b0;  // Must be 0 for Endpoint.
  wire [2:0]      s_axis_rq_tc_ff           = s_axis_rq_tdata_ff[22:20];
  wire [2:0]      s_axis_rq_attr_ff         = {1'b0, s_axis_rq_tdata_ff[13:12]};
  wire            s_axis_rq_ecrc_ff         = s_axis_rq_tdata_ff[15] | s_axis_rq_tuser_ff[0];     //TLP Digest

  wire [63:0]     s_axis_rq_tdata_header  = {
    s_axis_rq_ecrc_ff,
    s_axis_rq_attr_ff,
    s_axis_rq_tc_ff,
    s_axis_rq_requester_en_ff,
    s_axis_rq_completerid_ff,
    s_axis_rq_tag_ff,
    s_axis_rq_requesterid_ff,
    s_axis_rq_poisoning_ff, s_axis_rq_reqtype_ff, s_axis_rq_dwlen_ff
  };

  wire [3:0] s_axis_rq_firstbe_ff = s_axis_rq_tdata_ff[35:32];
  wire [3:0] s_axis_rq_lastbe_ff  = s_axis_rq_tdata_ff[39:36];
  reg  [3:0] s_axis_rq_firstbe_l;
  reg  [3:0] s_axis_rq_lastbe_l;

  always @(posedge user_clk)
  begin
      if (s_axis_rq_tvalid_ff && s_axis_rq_tfirst_ff)
          begin
          s_axis_rq_firstbe_l <= s_axis_rq_firstbe_ff;
          s_axis_rq_lastbe_l  <= s_axis_rq_lastbe_ff;
          end
      end

  assign s_axis_rq_tdata_a       = s_axis_rq_tfirst_ff ? {s_axis_rq_tdata_ff[255:128], s_axis_rq_tdata_header, s_axis_rq_tdata_ff[95:64], s_axis_rq_tdata_ff[127:96]} : s_axis_rq_tdata_ff;
  assign s_axis_rq_tkeep_a       = s_axis_rq_tkeep_ff;
  assign s_axis_rq_tuser_a[59:8] = {32'b0, 4'b0, 1'b0, 8'b0, 2'b0, 1'b0, s_axis_rq_tuser_ff[3], 3'b0};
  assign s_axis_rq_tuser_a[7:0]  = s_axis_rq_tfirst_ff ? {s_axis_rq_lastbe_ff, s_axis_rq_firstbe_ff} : {s_axis_rq_lastbe_l, s_axis_rq_firstbe_l};

endmodule
