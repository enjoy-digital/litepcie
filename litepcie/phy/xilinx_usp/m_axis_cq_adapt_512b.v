// This file is part of LitePCIe.
//
// Copyright (c) 2020-2023 Enjoy-Digital <enjoy-digital.fr>
// SPDX-License-Identifier: BSD-2-Clause

module m_axis_cq_adapt # (
      parameter DATA_WIDTH  = 512,
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

  //dword counter: //0-2 & latch
  reg [1:0]       m_axis_cq_cnt;
  always @(posedge user_clk)
      if (user_reset) m_axis_cq_cnt <= 2'd0;
      else if (m_axis_cq_tvalid_a && m_axis_cq_tready_a)
          begin
              if (m_axis_cq_tlast_a) m_axis_cq_cnt <= 2'd0;
              else if (!m_axis_cq_cnt[1]) m_axis_cq_cnt <= m_axis_cq_cnt + 1;
          end

  wire            m_axis_cq_sop    = (m_axis_cq_cnt == 0) && (!m_axis_cq_tlast_lat);
  wire            m_axis_cq_second = m_axis_cq_cnt == 1;

  reg             m_axis_cq_rdwr_l;
  always @(posedge user_clk)
      if (user_reset) m_axis_cq_rdwr_l <= 1'd0;
      else if (m_axis_cq_tvalid_a && m_axis_cq_sop) m_axis_cq_rdwr_l <= m_axis_cq_tlast_a;

  //processing for tlast: generate new last in case write & last num of dword != 13 + i*16
  wire            m_axis_cq_read = (m_axis_cq_fmt[1:0] == 2'b0);  //Read request
  wire            m_axis_cq_write = !m_axis_cq_read;
  wire [9:0]      m_axis_cq_dwlen;
  reg             m_axis_cq_tlast_dly_en;
  always @(posedge user_clk)
      if (user_reset) m_axis_cq_tlast_dly_en <= 1'd0;
      else if (m_axis_cq_tlast_lat && m_axis_cq_tready) m_axis_cq_tlast_dly_en <= 1'd0;
      else if (m_axis_cq_tvalid_a && m_axis_cq_sop) m_axis_cq_tlast_dly_en <= m_axis_cq_tlast_a | (m_axis_cq_dwlen[3:0] != 4'd13);

  reg             m_axis_cq_tlast_lat;
  always @(posedge user_clk)
      if (user_reset) m_axis_cq_tlast_lat <= 1'd0;
      else if (m_axis_cq_tlast_lat && m_axis_cq_tready) m_axis_cq_tlast_lat <= 1'd0;
      else if (m_axis_cq_tvalid_a && m_axis_cq_tready_a && m_axis_cq_tlast_a)
          begin
          if (m_axis_cq_sop) m_axis_cq_tlast_lat <= 1'b1;  //read or write
          else if (m_axis_cq_tlast_dly_en) m_axis_cq_tlast_lat <= 1'b1;
          end

  //Generae ready for PCIe IP
  assign          m_axis_cq_tready_a = ((m_axis_cq_cnt == 0) | m_axis_cq_tready) && (!m_axis_cq_tlast_lat);

  //output for TLP
  assign          m_axis_cq_tlast = m_axis_cq_tlast_dly_en ? m_axis_cq_tlast_lat : m_axis_cq_tlast_a;
  assign          m_axis_cq_tvalid = (m_axis_cq_tvalid_a & (|m_axis_cq_cnt)) | m_axis_cq_tlast_lat;


  ////keep address (low) or data (high), not header
  reg [511:0]     m_axis_cq_tdata_a1;
  reg [63:0]      m_axis_cq_tlast_be1;
  always @(posedge user_clk)
     if (m_axis_cq_tvalid_a && m_axis_cq_tready_a)
          begin
          m_axis_cq_tdata_a1 <= m_axis_cq_tdata_a;
          m_axis_cq_tlast_be1 <= m_axis_cq_tuser_a[79:16];
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
  wire [7:0]      m_axis_cq_be = {m_axis_cq_tuser_a[11:8], m_axis_cq_tuser_a[3:0]};
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
  always @(posedge user_clk)
      if (m_axis_cq_tvalid_a && m_axis_cq_sop)
          m_axis_cq_tuser_barhit <= {1'b0, m_axis_cq_tdata_hdr[50:48], m_axis_cq_tdata_hdr[14:11]};  //only valid @sop

  reg [63:0]       m_axis_cq_header;
  always @(posedge user_clk)
      if (m_axis_cq_tvalid_a && m_axis_cq_sop)
          m_axis_cq_header = {m_axis_cq_requesterid,
                              m_axis_cq_tag,
                              m_axis_cq_be,
                              m_axis_cq_fmt, m_axis_cq_type,
                              1'b0, m_axis_cq_tc, 4'b0,
                              m_axis_cq_td, m_axis_cq_ep, m_axis_cq_attr,
                              2'b0, m_axis_cq_dwlen};

  assign          m_axis_cq_tdata = (m_axis_cq_rdwr_l | m_axis_cq_second) ? {m_axis_cq_tdata_a[31:0], m_axis_cq_tdata_a1[511:128], m_axis_cq_tdata_a1[31:0], m_axis_cq_header} :
                                                                            {m_axis_cq_tdata_a[31:0], m_axis_cq_tdata_a1[511:32]};
  assign          m_axis_cq_tkeep = m_axis_cq_rdwr_l    ? {4'b0, m_axis_cq_tlast_be1[63:16], 12'hFFF} :
                                    m_axis_cq_tlast_lat ? {4'b0, m_axis_cq_tlast_be1[63:4]} : {64{1'b1}};
  assign          m_axis_cq_tuser = {
                                     5'b0,                     //rx_is_eof only for 128-bit I/F
                                     2'b0,                     //reserved
                                     5'b0,                     //rx_is_sof only for 128-bit I/F
                                     m_axis_cq_tuser_barhit,
                                     1'b0,                    //rx_err_fwd -> no equivalent
                                     m_axis_cq_tuser_a[96]    //ECRC mapped to discontinue
                                     };

endmodule