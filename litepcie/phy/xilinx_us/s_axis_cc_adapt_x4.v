// This file is part of LitePCIe.
//
// Copyright (c) 2020-2023 Enjoy-Digital <enjoy-digital.fr>
// SPDX-License-Identifier: BSD-2-Clause

module s_axis_cc_adapt # (
      parameter DATA_WIDTH  = 128,
      parameter KEEP_WIDTH  = DATA_WIDTH/8
    )(

       input user_clk,
       input user_reset,

       input [DATA_WIDTH-1:0] s_axis_cc_tdata,
       input [KEEP_WIDTH-1:0] s_axis_cc_tkeep,
       input                  s_axis_cc_tlast,
       output                 s_axis_cc_tready,
       input            [3:0] s_axis_cc_tuser,
       input                  s_axis_cc_tvalid,

       output   [DATA_WIDTH-1:0] s_axis_cc_tdata_a,
       output [KEEP_WIDTH/4-1:0] s_axis_cc_tkeep_a,
       output                    s_axis_cc_tlast_a,
       input                     s_axis_cc_tready_a,
       output             [32:0] s_axis_cc_tuser_a,
       output                    s_axis_cc_tvalid_a
    );

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
        .clk    (user_clk),
        .rst    (user_reset),

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
  always @(posedge user_clk)
      if (user_reset) s_axis_cc_cnt <= 2'd0;
      else if (s_axis_cc_tvalid_ff && s_axis_cc_tready_ff)
          begin
              if (s_axis_cc_tlast_ff) s_axis_cc_cnt <= 2'd0;
              else if (!s_axis_cc_cnt[1]) s_axis_cc_cnt <= s_axis_cc_cnt + 1;
          end

  wire            s_axis_cc_tfirst = s_axis_cc_cnt == 0;
  wire            s_axis_cc_tsecond = s_axis_cc_cnt == 1;

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
  always @(posedge user_clk)
      if (user_reset) s_axis_cc_tvalid_ff_lat <= 1'd0;
      else if (s_axis_cc_tvalid_ff && s_axis_cc_tready_ff)
          begin
              if (s_axis_cc_tlast_ff) s_axis_cc_tvalid_ff_lat <= 1'd0;
              else if (s_axis_cc_tfirst) s_axis_cc_tvalid_ff_lat <= 1'd1;
          end

  assign s_axis_cc_tvalid_a = s_axis_cc_tvalid_ff;
  assign s_axis_cc_tready_ff = s_axis_cc_tready_a;
  assign s_axis_cc_tdata_a  = s_axis_cc_tfirst ? {s_axis_cc_header1, s_axis_cc_header0} : s_axis_cc_tdata_ff;
  assign s_axis_cc_tlast_a = s_axis_cc_tlast_ff;
  assign s_axis_cc_tkeep_a = s_axis_cc_tkeep_ff;
  assign s_axis_cc_tuser_a  = {32'b0, s_axis_cc_tuser_ff[3]};    //{parity, discontinue}

endmodule