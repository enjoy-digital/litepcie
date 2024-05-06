// This file is part of LitePCIe.
//
// Copyright (c) 2020-2023 Enjoy-Digital <enjoy-digital.fr>
// SPDX-License-Identifier: BSD-2-Clause

module s_axis_rq_adapt # (
      parameter DATA_WIDTH  = 128,
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

  wire          s_axis_rq_tready_ff,
                s_axis_rq_tvalid_ff,
                s_axis_rq_tlast_ff;
  wire [3:0]    s_axis_rq_tkeep_or = {|s_axis_rq_tkeep[15:12], |s_axis_rq_tkeep[11:8], |s_axis_rq_tkeep[7:4], |s_axis_rq_tkeep[3:0]};

  wire [3:0]    s_axis_rq_tuser_ff;
  wire [3:0]    s_axis_rq_tkeep_ff;
  wire [127:0]  s_axis_rq_tdata_ff;

  axis_iff #(.DAT_B(128+4+4))  s_axis_rq_iff
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


  reg [1:0]       s_axis_rq_cnt;  //0-2
  always @(posedge user_clk)
      if (user_reset)
        s_axis_rq_cnt <= 2'd0;
      else if (s_axis_rq_tvalid_ff && s_axis_rq_tready_ff)
          begin
              if (s_axis_rq_tlast_ff)
                s_axis_rq_cnt <= 2'd0;
              else if (!s_axis_rq_cnt[1])
                s_axis_rq_cnt <= s_axis_rq_cnt + 1;
          end

  wire s_axis_rq_tfirst = (s_axis_rq_cnt == 0) && (!s_axis_rq_tlast_lat);
  wire s_axis_rq_tsecond = s_axis_rq_cnt == 1;

  // processing for tlast: generate new last in case write & last num of dword = 5, 9, 13, ...
  wire       s_axis_rq_read  = (s_axis_rq_tdata_ff[31:30] == 2'b0);  //Read request
  wire       s_axis_rq_write = !s_axis_rq_read;
  reg        s_axis_rq_tlast_dly_en;
  reg        s_axis_rq_tlast_lat;
  always @(posedge user_clk)
      if (user_reset)
        s_axis_rq_tlast_dly_en <= 1'd0;
      else if (s_axis_rq_tvalid_ff && s_axis_rq_tfirst && s_axis_rq_tready_ff && s_axis_rq_write)
        s_axis_rq_tlast_dly_en <= (s_axis_rq_tdata_ff[1:0] == 2'd1);

  always @(posedge user_clk)
      if (user_reset)
        s_axis_rq_tlast_lat <= 1'd0;
      else if (s_axis_rq_tlast_lat && s_axis_rq_tready_a)
        s_axis_rq_tlast_lat <= 1'd0;
      else if (s_axis_rq_tvalid_ff && s_axis_rq_tlast_ff && s_axis_rq_tready_a)
          begin
          if (s_axis_rq_tfirst)
            s_axis_rq_tlast_lat <= s_axis_rq_write ? 1'b1 : 1'b0; //write 1-dword
          else
            s_axis_rq_tlast_lat <= s_axis_rq_tlast_dly_en;
          end

  assign  s_axis_rq_tlast_a  = s_axis_rq_tfirst ? s_axis_rq_read :
        s_axis_rq_tlast_dly_en ? s_axis_rq_tlast_lat : s_axis_rq_tlast_ff;

  // Generate ready for TLP
  assign s_axis_rq_tready_ff = s_axis_rq_tready_a && (!s_axis_rq_tlast_lat);

  // Latch valid because it is uncontigous when coming from TLP request
  reg s_axis_rq_tvalid_lat;
  always @(posedge user_clk)
      if (user_reset)
        s_axis_rq_tvalid_lat <= 1'b0;
      else if (s_axis_rq_tvalid_lat && s_axis_rq_tready_a)
          begin
          if (s_axis_rq_tlast_dly_en)
            s_axis_rq_tvalid_lat <= !s_axis_rq_tlast_lat;
          else
            s_axis_rq_tvalid_lat <= !(s_axis_rq_tlast_ff && s_axis_rq_tvalid_ff);
          end
      else if (s_axis_rq_tvalid_ff & s_axis_rq_tfirst & s_axis_rq_write)
        s_axis_rq_tvalid_lat <= 1'b1;   //latche input valid (required by PCIe IP)

  assign s_axis_rq_tvalid_a = s_axis_rq_tvalid_ff | s_axis_rq_tlast_lat;

  wire [10:0] s_axis_rq_dwlen = {1'b0, s_axis_rq_tdata_ff[9:0]};
  wire [3:0]  s_axis_rq_reqtype =
    {s_axis_rq_tdata_ff[31:30], s_axis_rq_tdata_ff[28:24]} == 7'b0000000  ? 4'b0000 :  //Mem read Request
    {s_axis_rq_tdata_ff[31:30], s_axis_rq_tdata_ff[28:24]} == 7'b0000001  ? 4'b0111 :  //Mem Read request-locked
    {s_axis_rq_tdata_ff[31:30], s_axis_rq_tdata_ff[28:24]} == 7'b0100000  ? 4'b0001 :  //Mem write request
                                 s_axis_rq_tdata_ff[31:24] == 8'b00000010 ? 4'b0010 :  //I/O Read request
                                 s_axis_rq_tdata_ff[31:24] == 8'b01000010 ? 4'b0011 :  //I/O Write request
                                 s_axis_rq_tdata_ff[31:24] == 8'b00000100 ? 4'b1000 :  //Cfg Read Type 0
                                 s_axis_rq_tdata_ff[31:24] == 8'b01000100 ? 4'b1010 :  //Cfg Write Type 0
                                 s_axis_rq_tdata_ff[31:24] == 8'b00000101 ? 4'b1001 :  //Cfg Read Type 1
                                 s_axis_rq_tdata_ff[31:24] == 8'b01000101 ? 4'b1011 :  //Cfg Write Type 1
                                 4'b1111;
  wire            s_axis_rq_poisoning    = s_axis_rq_tdata_ff[14] | s_axis_rq_tuser_ff[1];   //EP must be 0 for request
  wire [15:0]     s_axis_rq_requesterid  = s_axis_rq_tdata_ff[63:48];
  wire [7:0]      s_axis_rq_tag          = s_axis_rq_tdata_ff[47:40];
  wire [15:0]     s_axis_rq_completerid  = 16'b0; // Applicable only to Configuration requests and messages routed by ID.
  wire            s_axis_rq_requester_en = 1'b0;  // Must be 0 for Endpoint.
  wire [2:0]      s_axis_rq_tc           = s_axis_rq_tdata_ff[22:20];
  wire [2:0]      s_axis_rq_attr         = {1'b0, s_axis_rq_tdata_ff[13:12]};
  wire            s_axis_rq_ecrc         = s_axis_rq_tdata_ff[15] | s_axis_rq_tuser_ff[0];     //TLP Digest

  wire [63:0]     s_axis_rq_tdata_header  = {
    s_axis_rq_ecrc,
    s_axis_rq_attr,
    s_axis_rq_tc,
    s_axis_rq_requester_en,
    s_axis_rq_completerid,
    s_axis_rq_tag,
    s_axis_rq_requesterid,
    s_axis_rq_poisoning, s_axis_rq_reqtype, s_axis_rq_dwlen
  };

  wire [3:0] s_axis_rq_firstbe = s_axis_rq_tdata_ff[35:32];
  wire [3:0] s_axis_rq_lastbe  = s_axis_rq_tdata_ff[39:36];
  reg  [3:0] s_axis_rq_firstbe_l;
  reg  [3:0] s_axis_rq_lastbe_l;

  always @(posedge user_clk)
  begin
      if (s_axis_rq_tvalid_ff && s_axis_rq_tfirst)
          begin
          s_axis_rq_firstbe_l <= s_axis_rq_firstbe;
          s_axis_rq_lastbe_l  <= s_axis_rq_lastbe;
          end
      end

  reg [31:0]       s_axis_rq_tdata_l;
  always @(posedge user_clk)
      if (s_axis_rq_tvalid_ff && s_axis_rq_tready_ff)
          s_axis_rq_tdata_l <= s_axis_rq_tdata_ff[127:96];

  assign s_axis_rq_tdata_a  = s_axis_rq_tfirst ? {s_axis_rq_tdata_header, 32'b0, s_axis_rq_tdata_ff[95:64]} : {s_axis_rq_tdata_ff[95:0], s_axis_rq_tdata_l[31:0]};
  assign s_axis_rq_tkeep_a  = s_axis_rq_tlast_lat ? 4'b0001 : 4'b1111;
  assign s_axis_rq_tuser_a[59:8] = {32'b0, 4'b0, 1'b0, 8'b0, 2'b0, 1'b0, s_axis_rq_tuser_ff[3], 3'b0};
  assign s_axis_rq_tuser_a[7:0]  = s_axis_rq_tfirst ? {s_axis_rq_lastbe, s_axis_rq_firstbe} : {s_axis_rq_lastbe_l, s_axis_rq_firstbe_l};


endmodule