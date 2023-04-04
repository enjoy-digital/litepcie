// This file is part of LitePCIe.
//
// Copyright (c) 2020-2023 Enjoy-Digital <enjoy-digital.fr>
// SPDX-License-Identifier: BSD-2-Clause

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