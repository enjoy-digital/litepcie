// (C) 2001-2018 Intel Corporation. All rights reserved.
// Your use of Intel Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Intel Program License Subscription 
// Agreement, Intel FPGA IP License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Intel and sold by 
// Intel or its authorized distributors.  Please refer to the applicable 
// agreement for further details.


// (C) 2001-2014 Altera Corporation. All rights reserved.
// Your use of Altera Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Altera Program License Subscription 
// Agreement, Altera MegaCore Function License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Altera and sold by 
// Altera or its authorized distributors.  Please refer to the applicable 
// agreement for further details.


// $Id: //acds/rel/18.0std/ip/merlin/altera_merlin_multiplexer/altera_merlin_multiplexer.sv.terp#1 $
// $Revision: #1 $
// $Date: 2018/01/31 $
// $Author: psgswbuild $

// ------------------------------------------
// Merlin Multiplexer
// ------------------------------------------

`timescale 1 ns / 1 ns


// ------------------------------------------
// Generation parameters:
//   output_name:         alt_xcvr_reconfig_cpu_mm_interconnect_0_rsp_mux
//   NUM_INPUTS:          2
//   ARBITRATION_SHARES:  1 1
//   ARBITRATION_SCHEME   "no-arb"
//   PIPELINE_ARB:        0
//   PKT_TRANS_LOCK:      54 (arbitration locking enabled)
//   ST_DATA_W:           86
//   ST_CHANNEL_W:        2
// ------------------------------------------

module alt_xcvr_reconfig_cpu_mm_interconnect_0_rsp_mux
(
    // ----------------------
    // Sinks
    // ----------------------
    input                       sink0_valid,
    input [86-1   : 0]  sink0_data,
    input [2-1: 0]  sink0_channel,
    input                       sink0_startofpacket,
    input                       sink0_endofpacket,
    output                      sink0_ready,

    input                       sink1_valid,
    input [86-1   : 0]  sink1_data,
    input [2-1: 0]  sink1_channel,
    input                       sink1_startofpacket,
    input                       sink1_endofpacket,
    output                      sink1_ready,


    // ----------------------
    // Source
    // ----------------------
    output                      src_valid,
    output [86-1    : 0] src_data,
    output [2-1 : 0] src_channel,
    output                      src_startofpacket,
    output                      src_endofpacket,
    input                       src_ready,

    // ----------------------
    // Clock & Reset
    // ----------------------
    input clk,
    input reset
);
    localparam PAYLOAD_W        = 86 + 2 + 2;
    localparam NUM_INPUTS       = 2;
    localparam SHARE_COUNTER_W  = 1;
    localparam PIPELINE_ARB     = 0;
    localparam ST_DATA_W        = 86;
    localparam ST_CHANNEL_W     = 2;
    localparam PKT_TRANS_LOCK   = 54;

    // ------------------------------------------
    // Signals
    // ------------------------------------------
    wire [NUM_INPUTS - 1 : 0]      request;
    wire [NUM_INPUTS - 1 : 0]      valid;
    wire [NUM_INPUTS - 1 : 0]      grant;
    wire [NUM_INPUTS - 1 : 0]      next_grant;
    reg [NUM_INPUTS - 1 : 0]       saved_grant;
    reg [PAYLOAD_W - 1 : 0]        src_payload;
    wire                           last_cycle;
    reg                            packet_in_progress;
    reg                            update_grant;

    wire [PAYLOAD_W - 1 : 0] sink0_payload;
    wire [PAYLOAD_W - 1 : 0] sink1_payload;

    assign valid[0] = sink0_valid;
    assign valid[1] = sink1_valid;


    // ------------------------------------------
    // ------------------------------------------
    // Grant Logic & Updates
    // ------------------------------------------
    // ------------------------------------------
    reg [NUM_INPUTS - 1 : 0] lock;
    always @* begin
      lock[0] = sink0_data[54];
      lock[1] = sink1_data[54];
    end

    assign last_cycle = src_valid & src_ready & src_endofpacket & ~(|(lock & grant));

    // ------------------------------------------
    // We're working on a packet at any time valid is high, except
    // when this is the endofpacket.
    // ------------------------------------------
    always @(posedge clk or posedge reset) begin
      if (reset) begin
        packet_in_progress <= 1'b0;
      end
      else begin
        if (last_cycle)
          packet_in_progress <= 1'b0; 
        else if (src_valid)
          packet_in_progress <= 1'b1;
      end
    end


    // ------------------------------------------
    // Shares
    //
    // Special case: all-equal shares _should_ be optimized into assigning a
    // constant to next_grant_share.
    // Special case: all-1's shares _should_ result in the share counter
    // being optimized away.
    // ------------------------------------------
    // Input  |  arb shares  |  counter load value
    // 0      |      1       |  0
    // 1      |      1       |  0
     wire [SHARE_COUNTER_W - 1 : 0] share_0 = 1'd0;
     wire [SHARE_COUNTER_W - 1 : 0] share_1 = 1'd0;

    // ------------------------------------------
    // Choose the share value corresponding to the grant.
    // ------------------------------------------
    reg [SHARE_COUNTER_W - 1 : 0] next_grant_share;
    always @* begin
      next_grant_share =
    share_0 & { SHARE_COUNTER_W {next_grant[0]} } |
    share_1 & { SHARE_COUNTER_W {next_grant[1]} };
    end

    // ------------------------------------------
    // Flag to indicate first packet of an arb sequence.
    // ------------------------------------------
    wire grant_changed = ~packet_in_progress && ~(|(saved_grant & valid));
    reg first_packet_r;
    wire first_packet = grant_changed | first_packet_r;
    always @(posedge clk or posedge reset) begin
      if (reset) begin
        first_packet_r <= 1'b0;
      end
      else begin 
        if (update_grant)
          first_packet_r <= 1'b1;
        else if (last_cycle)
          first_packet_r <= 1'b0;
        else if (grant_changed)
          first_packet_r <= 1'b1;
      end
    end

    // ------------------------------------------
    // Compute the next share-count value.
    // ------------------------------------------
    reg [SHARE_COUNTER_W - 1 : 0] p1_share_count;
    reg [SHARE_COUNTER_W - 1 : 0] share_count;
    reg share_count_zero_flag;

    always @* begin
      if (first_packet) begin
        p1_share_count = next_grant_share;
      end
      else begin
            // Update the counter, but don't decrement below 0.
        p1_share_count = share_count_zero_flag ? '0 : share_count - 1'b1;
      end
     end

    // ------------------------------------------
    // Update the share counter and share-counter=zero flag.
    // ------------------------------------------
    always @(posedge clk or posedge reset) begin
      if (reset) begin
        share_count <= '0;
        share_count_zero_flag <= 1'b1;
      end
      else begin
        if (last_cycle) begin
          share_count <= p1_share_count;
          share_count_zero_flag <= (p1_share_count == '0);
        end
      end
    end

    // ------------------------------------------
    // For each input, maintain a final_packet signal which goes active for the
    // last packet of a full-share packet sequence.  Example: if I have 4
    // shares and I'm continuously requesting, final_packet is active in the
    // 4th packet.
    // ------------------------------------------
    wire final_packet_0 = 1'b1;

    wire final_packet_1 = 1'b1;


    // ------------------------------------------
    // Concatenate all final_packet signals (wire or reg) into a handy vector.
    // ------------------------------------------
    wire [NUM_INPUTS - 1 : 0] final_packet = {
    final_packet_1,
    final_packet_0
    };

    // ------------------------------------------
    // ------------------------------------------
    wire p1_done = |(final_packet & grant);

    // ------------------------------------------
    // Flag for the first cycle of packets within an 
    // arb sequence
    // ------------------------------------------
    reg first_cycle;
    always @(posedge clk, posedge reset) begin
      if (reset)
        first_cycle <= 0;
      else
        first_cycle <= last_cycle && ~p1_done;
    end


    always @* begin
      update_grant = 0;

        // ------------------------------------------
        // No arbitration pipeline, update grant whenever
        // the current arb winner has consumed all shares,
        // or all requests are low
        // ------------------------------------------
  update_grant = (last_cycle && p1_done) || (first_cycle && ~(|valid));
  update_grant = last_cycle;
    end

    wire save_grant;
    assign save_grant = 1;
    assign grant = next_grant;

    always @(posedge clk, posedge reset) begin
      if (reset)
        saved_grant <= '0;
      else if (save_grant)
        saved_grant <= next_grant;
    end

    // ------------------------------------------
    // ------------------------------------------
    // Arbitrator
    // ------------------------------------------
    // ------------------------------------------

    // ------------------------------------------
    // Create a request vector that stays high during
    // the packet for unpipelined arbitration.
    //
    // The pipelined arbitration scheme does not require
    // request to be held high during the packet.
    // ------------------------------------------
    assign request = valid;

    wire [NUM_INPUTS - 1 : 0] next_grant_from_arb;
                               
    altera_merlin_arbitrator
    #(
    .NUM_REQUESTERS(NUM_INPUTS),
    .SCHEME ("no-arb"),
    .PIPELINE (0)
    ) arb (
    .clk (clk),
    .reset (reset),
    .request (request),
    .grant (next_grant_from_arb),
    .save_top_priority (src_valid),
    .increment_top_priority (update_grant)
    );

   assign next_grant = next_grant_from_arb;
                         
    // ------------------------------------------
    // ------------------------------------------
    // Mux
    //
    // Implemented as a sum of products.
    // ------------------------------------------
    // ------------------------------------------

    assign sink0_ready = src_ready && grant[0];
    assign sink1_ready = src_ready && grant[1];

    assign src_valid = |(grant & valid);

    always @* begin
      src_payload =
      sink0_payload & {PAYLOAD_W {grant[0]} } |
      sink1_payload & {PAYLOAD_W {grant[1]} };
    end

    // ------------------------------------------
    // Mux Payload Mapping
    // ------------------------------------------

    assign sink0_payload = {sink0_channel,sink0_data,
    sink0_startofpacket,sink0_endofpacket};
    assign sink1_payload = {sink1_channel,sink1_data,
    sink1_startofpacket,sink1_endofpacket};

    assign {src_channel,src_data,src_startofpacket,src_endofpacket} = src_payload;
endmodule


