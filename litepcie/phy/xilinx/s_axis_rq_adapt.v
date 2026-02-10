// This file is part of LitePCIe.
//
// Copyright (c) 2020-2026 Enjoy-Digital <enjoy-digital.fr>
// SPDX-License-Identifier: BSD-2-Clause

module s_axis_rq_adapt #(
    parameter DATA_WIDTH    = 128,
    parameter KEEP_WIDTH    = DATA_WIDTH/8,
    parameter TUSER_WIDTH_A = (DATA_WIDTH == 512) ? 137 : 60
) (
    input                  user_clk,
    input                  user_reset,

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
    output [TUSER_WIDTH_A-1:0] s_axis_rq_tuser_a,
    output                    s_axis_rq_tvalid_a
);

    localparam IS_128 = (DATA_WIDTH == 128);
    localparam IS_256 = (DATA_WIDTH == 256);

    wire [KEEP_WIDTH/4-1:0] s_axis_rq_tkeep_or;

    generate
        if (IS_128) begin : gen_keep_or_128
            assign s_axis_rq_tkeep_or = {
                |s_axis_rq_tkeep[15:12],
                |s_axis_rq_tkeep[11:8],
                |s_axis_rq_tkeep[7:4],
                |s_axis_rq_tkeep[3:0]
            };
        end else begin : gen_keep_or_256_512
            genvar i;
            for (i = 0; i < KEEP_WIDTH/4; i = i + 1) begin : gen_keep_or_bits
                assign s_axis_rq_tkeep_or[KEEP_WIDTH/4-1-i] = s_axis_rq_tkeep[4*(KEEP_WIDTH/4-1-i)];
            end
        end
    endgenerate

    wire                    s_axis_rq_tready_ff;
    wire                    s_axis_rq_tvalid_ff;
    wire                    s_axis_rq_tlast_ff;
    wire              [3:0] s_axis_rq_tuser_ff;
    wire [KEEP_WIDTH/4-1:0] s_axis_rq_tkeep_ff;
    wire   [DATA_WIDTH-1:0] s_axis_rq_tdata_ff;

    axis_iff #(.DAT_B(DATA_WIDTH + KEEP_WIDTH/4 + 4)) s_axis_rq_iff (
        .clk   (user_clk),
        .rst   (user_reset),

        .i_vld (s_axis_rq_tvalid),
        .o_rdy (s_axis_rq_tready),
        .i_sop (1'b0),
        .i_eop (s_axis_rq_tlast),
        .i_dat ({s_axis_rq_tuser, s_axis_rq_tkeep_or, s_axis_rq_tdata}),

        .o_vld (s_axis_rq_tvalid_ff),
        .i_rdy (s_axis_rq_tready_ff),
        .o_sop (),
        .o_eop (s_axis_rq_tlast_ff),
        .o_dat ({s_axis_rq_tuser_ff, s_axis_rq_tkeep_ff, s_axis_rq_tdata_ff})
    );

    wire [10:0] s_axis_rq_dwlen = {1'b0, s_axis_rq_tdata_ff[9:0]};
    wire [3:0]  s_axis_rq_reqtype =
        {s_axis_rq_tdata_ff[31:30], s_axis_rq_tdata_ff[28:24]} == 7'b0000000 ? 4'b0000 :
        {s_axis_rq_tdata_ff[31:30], s_axis_rq_tdata_ff[28:24]} == 7'b0000001 ? 4'b0111 :
        {s_axis_rq_tdata_ff[31:30], s_axis_rq_tdata_ff[28:24]} == 7'b0100000 ? 4'b0001 :
         s_axis_rq_tdata_ff[31:24] == 8'b00000010                            ? 4'b0010 :
         s_axis_rq_tdata_ff[31:24] == 8'b01000010                            ? 4'b0011 :
         s_axis_rq_tdata_ff[31:24] == 8'b00000100                            ? 4'b1000 :
         s_axis_rq_tdata_ff[31:24] == 8'b01000100                            ? 4'b1010 :
         s_axis_rq_tdata_ff[31:24] == 8'b00000101                            ? 4'b1001 :
         s_axis_rq_tdata_ff[31:24] == 8'b01000101                            ? 4'b1011 :
                                                                               4'b1111;

    wire        s_axis_rq_poisoning    = s_axis_rq_tdata_ff[14] | s_axis_rq_tuser_ff[1];
    wire [15:0] s_axis_rq_requesterid  = s_axis_rq_tdata_ff[63:48];
    wire  [7:0] s_axis_rq_tag          = s_axis_rq_tdata_ff[47:40];
    wire [15:0] s_axis_rq_completerid  = 16'b0;
    wire        s_axis_rq_requester_en = 1'b0;
    wire  [2:0] s_axis_rq_tc           = s_axis_rq_tdata_ff[22:20];
    wire  [2:0] s_axis_rq_attr         = {1'b0, s_axis_rq_tdata_ff[13:12]};
    wire        s_axis_rq_ecrc         = s_axis_rq_tdata_ff[15] | s_axis_rq_tuser_ff[0];

    wire [63:0] s_axis_rq_tdata_header = {
        s_axis_rq_ecrc,
        s_axis_rq_attr,
        s_axis_rq_tc,
        s_axis_rq_requester_en,
        s_axis_rq_completerid,
        s_axis_rq_tag,
        s_axis_rq_requesterid,
        s_axis_rq_poisoning,
        s_axis_rq_reqtype,
        s_axis_rq_dwlen
    };

    wire [3:0] s_axis_rq_firstbe = s_axis_rq_tdata_ff[35:32];
    wire [3:0] s_axis_rq_lastbe  = s_axis_rq_tdata_ff[39:36];

    generate
        if (IS_128) begin : gen_128
            reg [1:0]  s_axis_rq_cnt;
            reg        s_axis_rq_tlast_dly_en;
            reg        s_axis_rq_tlast_lat;
            reg  [3:0] s_axis_rq_firstbe_l;
            reg  [3:0] s_axis_rq_lastbe_l;
            reg [31:0] s_axis_rq_tdata_l;

            wire s_axis_rq_tfirst = (s_axis_rq_cnt == 0) && (!s_axis_rq_tlast_lat);
            wire s_axis_rq_read   = (s_axis_rq_tdata_ff[31:30] == 2'b0);
            wire s_axis_rq_write  = !s_axis_rq_read;

            always @(posedge user_clk)
                if (user_reset)
                    s_axis_rq_cnt <= 2'd0;
                else if (s_axis_rq_tvalid_ff && s_axis_rq_tready_ff) begin
                    if (s_axis_rq_tlast_ff)
                        s_axis_rq_cnt <= 2'd0;
                    else if (!s_axis_rq_cnt[1])
                        s_axis_rq_cnt <= s_axis_rq_cnt + 1;
                end

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
                else if (s_axis_rq_tvalid_ff && s_axis_rq_tlast_ff && s_axis_rq_tready_a) begin
                    if (s_axis_rq_tfirst)
                        s_axis_rq_tlast_lat <= s_axis_rq_write ? 1'b1 : 1'b0;
                    else
                        s_axis_rq_tlast_lat <= s_axis_rq_tlast_dly_en;
                end

            always @(posedge user_clk)
                if (s_axis_rq_tvalid_ff && s_axis_rq_tfirst) begin
                    s_axis_rq_firstbe_l <= s_axis_rq_firstbe;
                    s_axis_rq_lastbe_l  <= s_axis_rq_lastbe;
                end

            always @(posedge user_clk)
                if (s_axis_rq_tvalid_ff && s_axis_rq_tready_ff)
                    s_axis_rq_tdata_l <= s_axis_rq_tdata_ff[127:96];

            assign s_axis_rq_tlast_a = s_axis_rq_tfirst ? s_axis_rq_read :
                s_axis_rq_tlast_dly_en ? s_axis_rq_tlast_lat : s_axis_rq_tlast_ff;

            assign s_axis_rq_tready_ff = s_axis_rq_tready_a && (!s_axis_rq_tlast_lat);
            assign s_axis_rq_tvalid_a  = s_axis_rq_tvalid_ff | s_axis_rq_tlast_lat;

            assign s_axis_rq_tdata_a = s_axis_rq_tfirst ?
                {s_axis_rq_tdata_header, 32'b0, s_axis_rq_tdata_ff[95:64]} :
                {s_axis_rq_tdata_ff[95:0], s_axis_rq_tdata_l[31:0]};

            assign s_axis_rq_tkeep_a = s_axis_rq_tlast_lat ? 4'b0001 : 4'b1111;

            assign s_axis_rq_tuser_a[59:8] = {32'b0, 4'b0, 1'b0, 8'b0, 2'b0, 1'b0, s_axis_rq_tuser_ff[3], 3'b0};
            assign s_axis_rq_tuser_a[7:0]  = s_axis_rq_tfirst ?
                {s_axis_rq_lastbe, s_axis_rq_firstbe} :
                {s_axis_rq_lastbe_l, s_axis_rq_firstbe_l};
        end else if (IS_256) begin : gen_256
            reg       s_axis_rq_tfirst_ff;
            reg [3:0] s_axis_rq_firstbe_l;
            reg [3:0] s_axis_rq_lastbe_l;

            always @(posedge user_clk)
                if (user_reset)
                    s_axis_rq_tfirst_ff <= 1'd1;
                else if (s_axis_rq_tvalid_ff && s_axis_rq_tready_ff) begin
                    s_axis_rq_tfirst_ff <= 1'd0;
                    if (s_axis_rq_tlast_ff)
                        s_axis_rq_tfirst_ff <= 1'd1;
                end

            always @(posedge user_clk)
                if (s_axis_rq_tvalid_ff && s_axis_rq_tfirst_ff) begin
                    s_axis_rq_firstbe_l <= s_axis_rq_firstbe;
                    s_axis_rq_lastbe_l  <= s_axis_rq_lastbe;
                end

            assign s_axis_rq_tlast_a   = s_axis_rq_tlast_ff;
            assign s_axis_rq_tready_ff = s_axis_rq_tready_a;
            assign s_axis_rq_tvalid_a  = s_axis_rq_tvalid_ff;

            assign s_axis_rq_tdata_a = s_axis_rq_tfirst_ff ?
                {s_axis_rq_tdata_ff[255:128], s_axis_rq_tdata_header, s_axis_rq_tdata_ff[95:64], s_axis_rq_tdata_ff[127:96]} :
                s_axis_rq_tdata_ff;

            assign s_axis_rq_tkeep_a = s_axis_rq_tkeep_ff;

            assign s_axis_rq_tuser_a[59:8] = {32'b0, 4'b0, 1'b0, 8'b0, 2'b0, 1'b0, s_axis_rq_tuser_ff[3], 3'b0};
            assign s_axis_rq_tuser_a[7:0]  = s_axis_rq_tfirst_ff ?
                {s_axis_rq_lastbe, s_axis_rq_firstbe} :
                {s_axis_rq_lastbe_l, s_axis_rq_firstbe_l};
        end else begin : gen_512
            reg [1:0]  s_axis_rq_cnt;
            reg        s_axis_rq_tlast_dly_en;
            reg        s_axis_rq_tlast_lat;
            reg  [3:0] s_axis_rq_firstbe_l;
            reg  [3:0] s_axis_rq_lastbe_l;
            reg [31:0] s_axis_rq_tdata_l;

            wire s_axis_rq_tfirst = (s_axis_rq_cnt == 0) && (!s_axis_rq_tlast_lat);
            wire s_axis_rq_read   = (s_axis_rq_tdata_ff[31:30] == 2'b0);
            wire s_axis_rq_write  = !s_axis_rq_read;

            always @(posedge user_clk)
                if (user_reset)
                    s_axis_rq_cnt <= 2'd0;
                else if (s_axis_rq_tvalid_ff && s_axis_rq_tready_ff) begin
                    if (s_axis_rq_tlast_ff)
                        s_axis_rq_cnt <= 2'd0;
                    else if (!s_axis_rq_cnt[1])
                        s_axis_rq_cnt <= s_axis_rq_cnt + 1;
                end

            always @(posedge user_clk)
                if (user_reset)
                    s_axis_rq_tlast_dly_en <= 1'd0;
                else if (s_axis_rq_tvalid_ff && s_axis_rq_tfirst && s_axis_rq_write)
                    s_axis_rq_tlast_dly_en <= (s_axis_rq_tdata_ff[3:0] == 5'd13);

            always @(posedge user_clk)
                if (user_reset)
                    s_axis_rq_tlast_lat <= 1'd0;
                else if (s_axis_rq_tlast_lat && s_axis_rq_tready_a)
                    s_axis_rq_tlast_lat <= 1'd0;
                else if (s_axis_rq_tvalid_ff && s_axis_rq_tlast_ff && s_axis_rq_tready_a) begin
                    if (s_axis_rq_tfirst)
                        s_axis_rq_tlast_lat <= s_axis_rq_write ? (s_axis_rq_dwlen == 11'd13) : 1'b0;
                    else
                        s_axis_rq_tlast_lat <= s_axis_rq_tlast_dly_en;
                end

            always @(posedge user_clk)
                if (s_axis_rq_tvalid_ff && s_axis_rq_tfirst) begin
                    s_axis_rq_firstbe_l <= s_axis_rq_firstbe;
                    s_axis_rq_lastbe_l  <= s_axis_rq_lastbe;
                end

            always @(posedge user_clk)
                if (s_axis_rq_tvalid_ff && s_axis_rq_tready_ff)
                    s_axis_rq_tdata_l <= s_axis_rq_tdata_ff[511:480];

            assign s_axis_rq_tlast_a = s_axis_rq_tfirst ? (s_axis_rq_read | (s_axis_rq_dwlen < 11'd13)) :
                s_axis_rq_tlast_dly_en ? s_axis_rq_tlast_lat : s_axis_rq_tlast_ff;

            assign s_axis_rq_tready_ff = s_axis_rq_tready_a && (!s_axis_rq_tlast_lat);
            assign s_axis_rq_tvalid_a  = s_axis_rq_tvalid_ff | s_axis_rq_tlast_lat;

            assign s_axis_rq_tdata_a = s_axis_rq_tfirst ?
                {s_axis_rq_tdata_ff[479:96], s_axis_rq_tdata_header, 32'b0, s_axis_rq_tdata_ff[95:64]} :
                {s_axis_rq_tdata_ff[479:0], s_axis_rq_tdata_l[31:0]};

            assign s_axis_rq_tkeep_a = s_axis_rq_tlast_lat ?
                16'h1 :
                {s_axis_rq_tkeep_ff[14:0], 1'b1};

            assign s_axis_rq_tuser_a = {
                100'b0,
                s_axis_rq_tuser_ff[3],
                20'b0,
                4'b0,
                s_axis_rq_lastbe,
                4'b0,
                s_axis_rq_firstbe
            };
        end
    endgenerate

endmodule
