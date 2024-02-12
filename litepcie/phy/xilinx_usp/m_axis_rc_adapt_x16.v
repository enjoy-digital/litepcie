// This file is part of LitePCIe.
//
// Copyright (c) 2020-2023 Enjoy-Digital <enjoy-digital.fr>
// SPDX-License-Identifier: BSD-2-Clause

module m_axis_rc_adapt # (
      parameter DATA_WIDTH  = 512,
      parameter KEEP_WIDTH  = DATA_WIDTH/8
    )(

       input user_clk,
       input user_reset,

       output [DATA_WIDTH-1:0] m_axis_rc_tdata,
       output [KEEP_WIDTH-1:0] m_axis_rc_tkeep,
       output                  m_axis_rc_tlast,
       input             [3:0] m_axis_rc_tready,
       output           [84:0] m_axis_rc_tuser,
       output                  m_axis_rc_tvalid,

       input   [DATA_WIDTH-1:0] m_axis_rc_tdata_a,
       input [KEEP_WIDTH/4-1:0] m_axis_cq_tkeep_a,
       input                    m_axis_rc_tlast_a,
       output             [3:0] m_axis_rc_tready_a,
       input             [84:0] m_axis_rc_tuser_a,
       input                    m_axis_rc_tvalid_a
    );

  reg [1:0]       m_axis_rc_cnt;  //0-2
  always @(posedge user_clk)
      if (user_reset) m_axis_rc_cnt <= 2'd0;
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
  always @(posedge user_clk)
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
  assign          m_axis_rc_tdata = m_axis_rc_sop ? {m_axis_rc_tdata_a[511:128], m_axis_rc_header1, m_axis_rc_header0} : m_axis_rc_tdata_a;
  assign          m_axis_rc_tkeep = m_axis_rc_sop ? {m_axis_rc_tuser_a[63:12], 12'hFFF} : m_axis_rc_tuser_a[63:0];
  assign          m_axis_rc_tuser = {
                                     5'b0,                         //rx_is_eof only for 128-bit I/F
                                     2'b0,                         //reserved
                                     5'b0,                         //m_axis_rc_tuser_a[32],4'b0,   //rx_is_sof, only for 128-bit I/F  ?????????????????????
                                     8'b0,                         //BAR hit no equivalent for RC
                                     m_axis_rc_sop ? m_axis_rc_poisoning : m_axis_rc_poisoning_l,  //rx_err_fwd mapped to Poisoned completion
                                     m_axis_rc_tuser_a[42]         //ECRC mapped to discontinue
                                     };

endmodule