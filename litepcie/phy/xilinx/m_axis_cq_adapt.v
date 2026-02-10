// This file is part of LitePCIe.
//
// Copyright (c) 2020-2026 Enjoy-Digital <enjoy-digital.fr>
// SPDX-License-Identifier: BSD-2-Clause

module m_axis_cq_adapt # (
      parameter DATA_WIDTH  = 128,
      parameter KEEP_WIDTH  = DATA_WIDTH/8
    )(

       input user_clk,
       input user_reset,

       output [DATA_WIDTH-1:0] m_axis_cq_tdata,
       output [KEEP_WIDTH-1:0] m_axis_cq_tkeep,
       output                  m_axis_cq_tlast,
       input             [3:0] m_axis_cq_tready,
       output           [84:0] m_axis_cq_tuser,
       output                  m_axis_cq_tvalid,

       input   [DATA_WIDTH-1:0] m_axis_cq_tdata_a,
       input [KEEP_WIDTH/4-1:0] m_axis_cq_tkeep_a,
       input                    m_axis_cq_tlast_a,
       output             [3:0] m_axis_cq_tready_a,
       input             [84:0] m_axis_cq_tuser_a,
       input                    m_axis_cq_tvalid_a
    );

  localparam IS_128 = (DATA_WIDTH == 128);
  localparam IS_256 = (DATA_WIDTH == 256);

  // Dword counter: 0-2 & latch.
  reg [1:0] m_axis_cq_cnt;
  always @(posedge user_clk)
      if (user_reset) m_axis_cq_cnt <= 2'd0;
      else if (m_axis_cq_tvalid_a && m_axis_cq_tready_a)
          begin
              if (m_axis_cq_tlast_a) m_axis_cq_cnt <= 2'd0;
              else if (!m_axis_cq_cnt[1]) m_axis_cq_cnt <= m_axis_cq_cnt + 1;
          end

  reg             m_axis_cq_tlast_lat;
  wire            m_axis_cq_sop    = (m_axis_cq_cnt == 0) && (!m_axis_cq_tlast_lat);
  wire            m_axis_cq_second = m_axis_cq_cnt == 1;

  // Data processing.
  wire [63:0]     m_axis_cq_tdata_hdr = m_axis_cq_tdata_a[127:64];
  wire [9:0]      m_axis_cq_dwlen     = m_axis_cq_tdata_hdr[9:0];
  wire [1:0]      m_axis_cq_attr      = m_axis_cq_tdata_hdr[61:60];
  wire            m_axis_cq_ep        = 1'b0;
  wire            m_axis_cq_td        = 1'b0;
  wire [2:0]      m_axis_cq_tc        = m_axis_cq_tdata_hdr[59:57];
  wire [4:0]      m_axis_cq_type;
  wire [2:0]      m_axis_cq_fmt;
  wire [7:0]      m_axis_cq_be        = IS_128 | IS_256 ? m_axis_cq_tuser_a[7:0] : {m_axis_cq_tuser_a[11:8], m_axis_cq_tuser_a[3:0]};
  wire [7:0]      m_axis_cq_tag       = m_axis_cq_tdata_hdr[39:32];
  wire [15:0]     m_axis_cq_requesterid = m_axis_cq_tdata_hdr[31:16];

  assign {m_axis_cq_fmt, m_axis_cq_type} = m_axis_cq_tdata_hdr[14:11] == 4'b0000 ? 8'b000_00000 :
                                            m_axis_cq_tdata_hdr[14:11] == 4'b0111 ? 8'b000_00001 :
                                            m_axis_cq_tdata_hdr[14:11] == 4'b0001 ? 8'b010_00000 :
                                            m_axis_cq_tdata_hdr[14:11] == 4'b0010 ? 8'b000_00010 :
                                            m_axis_cq_tdata_hdr[14:11] == 4'b0011 ? 8'b010_00010 :
                                            m_axis_cq_tdata_hdr[14:11] == 4'b1000 ? 8'b000_00100 :
                                            m_axis_cq_tdata_hdr[14:11] == 4'b1010 ? 8'b010_00100 :
                                            m_axis_cq_tdata_hdr[14:11] == 4'b1001 ? 8'b000_00101 :
                                            m_axis_cq_tdata_hdr[14:11] == 4'b1011 ? 8'b010_00101 :
                                                                                    8'b000_00000;

  wire m_axis_cq_read = (m_axis_cq_fmt[1:0] == 2'b0);

  reg [7:0] m_axis_cq_tuser_barhit;
  always @(posedge user_clk)
      if (m_axis_cq_tvalid_a && m_axis_cq_sop)
          m_axis_cq_tuser_barhit <= {1'b0, m_axis_cq_tdata_hdr[50:48], m_axis_cq_tdata_hdr[14:11]};

  reg [63:0] m_axis_cq_header;
  always @(posedge user_clk)
      if (m_axis_cq_tvalid_a && m_axis_cq_sop)
          m_axis_cq_header <= {m_axis_cq_requesterid,
                               m_axis_cq_tag,
                               m_axis_cq_be,
                               m_axis_cq_fmt, m_axis_cq_type,
                               1'b0, m_axis_cq_tc, 4'b0,
                               m_axis_cq_td, m_axis_cq_ep, m_axis_cq_attr,
                               2'b0, m_axis_cq_dwlen};

  reg             m_axis_cq_mode_l;
  reg             m_axis_cq_tlast_dly_en;
  reg [DATA_WIDTH-1:0] m_axis_cq_tdata_a1;
  reg [KEEP_WIDTH-1:0] m_axis_cq_tlast_be1;
  reg             m_axis_cq_ecrc_128_l;

  always @(posedge user_clk)
      if (user_reset) begin
          m_axis_cq_mode_l      <= 1'd0;
          m_axis_cq_tlast_dly_en <= 1'd0;
          m_axis_cq_tlast_lat   <= 1'd0;
      end else begin
          if (m_axis_cq_tvalid_a && m_axis_cq_sop)
              m_axis_cq_mode_l <= IS_128 ? m_axis_cq_read : m_axis_cq_tlast_a;

          if (m_axis_cq_tlast_lat && m_axis_cq_tready) m_axis_cq_tlast_dly_en <= 1'd0;
          else if (m_axis_cq_tvalid_a && m_axis_cq_sop) begin
              if (IS_128) begin
                  if (m_axis_cq_read) m_axis_cq_tlast_dly_en <= 1'b1;
                  else                m_axis_cq_tlast_dly_en <= (m_axis_cq_dwlen[1:0] != 2'd1);
              end else if (IS_256) begin
                  m_axis_cq_tlast_dly_en <= m_axis_cq_tlast_a | (m_axis_cq_dwlen[2:0] != 3'd5);
              end else begin
                  m_axis_cq_tlast_dly_en <= m_axis_cq_tlast_a | (m_axis_cq_dwlen[3:0] != 4'd13);
              end
          end

          if (m_axis_cq_tlast_lat && m_axis_cq_tready) m_axis_cq_tlast_lat <= 1'd0;
          else if (m_axis_cq_tvalid_a && m_axis_cq_tready_a && m_axis_cq_tlast_a) begin
              if (m_axis_cq_sop) m_axis_cq_tlast_lat <= 1'b1;
              else if (m_axis_cq_tlast_dly_en) m_axis_cq_tlast_lat <= 1'b1;
          end

          if (m_axis_cq_tvalid_a && m_axis_cq_tready_a) begin
              m_axis_cq_tdata_a1 <= m_axis_cq_tdata_a;
              if (IS_128)       m_axis_cq_tlast_be1 <= m_axis_cq_tuser_a[23:8];
              else if (IS_256)  m_axis_cq_tlast_be1 <= m_axis_cq_tuser_a[39:8];
              else              m_axis_cq_tlast_be1 <= m_axis_cq_tuser_a[79:16];
          end

          m_axis_cq_ecrc_128_l <= m_axis_cq_tuser_a[41];
      end

  // Generate ready for PCIe IP.
  assign m_axis_cq_tready_a = ((m_axis_cq_cnt == 0) | m_axis_cq_tready) && (!m_axis_cq_tlast_lat);

  // Output for TLP.
  assign m_axis_cq_tlast  = m_axis_cq_tlast_dly_en ? m_axis_cq_tlast_lat : m_axis_cq_tlast_a;
  assign m_axis_cq_tvalid = (m_axis_cq_tvalid_a & (|m_axis_cq_cnt)) | m_axis_cq_tlast_lat;

  wire [31:0] m_axis_cq_hiaddr_mask = m_axis_cq_mode_l ? 32'b0 : m_axis_cq_tdata_a[31:0];

  assign m_axis_cq_tdata = IS_128 ?
      ((m_axis_cq_mode_l | m_axis_cq_second) ? {m_axis_cq_hiaddr_mask, m_axis_cq_tdata_a1[31:0], m_axis_cq_header} :
                                               {m_axis_cq_tdata_a[31:0], m_axis_cq_tdata_a1[127:32]}) :
      ((m_axis_cq_mode_l | m_axis_cq_second) ? {m_axis_cq_tdata_a[31:0], m_axis_cq_tdata_a1[DATA_WIDTH-1:128], m_axis_cq_tdata_a1[31:0], m_axis_cq_header} :
                                               {m_axis_cq_tdata_a[31:0], m_axis_cq_tdata_a1[DATA_WIDTH-1:32]});

  assign m_axis_cq_tkeep = IS_128 ?
      (m_axis_cq_mode_l ? 16'h0FFF : (m_axis_cq_tlast_lat ? {4'b0, m_axis_cq_tlast_be1[15:4]} : 16'hFFFF)) :
      (m_axis_cq_mode_l ? {4'b0, m_axis_cq_tlast_be1[KEEP_WIDTH-1:16], 12'hFFF} :
                          (m_axis_cq_tlast_lat ? {4'b0, m_axis_cq_tlast_be1[KEEP_WIDTH-1:4]} : {KEEP_WIDTH{1'b1}}));

  wire m_axis_cq_ecrc = IS_128 ? m_axis_cq_ecrc_128_l : (IS_256 ? m_axis_cq_tuser_a[41] : m_axis_cq_tuser_a[96]);
  assign m_axis_cq_tuser = {
                            5'b0,
                            2'b0,
                            5'b0,
                            m_axis_cq_tuser_barhit,
                            1'b0,
                            m_axis_cq_ecrc
                            };

endmodule
