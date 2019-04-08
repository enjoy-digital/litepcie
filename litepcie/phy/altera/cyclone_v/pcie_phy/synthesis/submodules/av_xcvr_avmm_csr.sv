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


`timescale 1ps/1ps

module av_xcvr_avmm_csr
  #(
    parameter pll_type            = 0,      // 0-None,1-CMU,2-LC/ATX,3-fPLL
    parameter rx_enable           = 0,      // Indicates whether this interface contains an rx channel.
    parameter tx_enable           = 0,      // Indicates whether this interface contains a tx channel
    // Service request parameters
    parameter request_dcd         = 0,      // Request Duty Cycle Distortion correction at startup
    parameter request_vrc         = 0,       // Request Voltage Regulator Calibration at startup
    parameter request_offset      = 1       // Request RX Offset Cancellation at startup - defaults to enabled, only PCIE w/HIP should disable this request
  ) (
  // Avalon interface
  input  wire         av_clk,
  input  wire         av_reset,
  input  wire [15:0]  av_writedata,
  input  wire [ 3:0]  av_address,
  input  wire         av_write,
  input  wire         av_read,
  output reg  [15:0]  av_readdata,
  // Offset Cancellation
  input  wire         hardoccaldone,
  output wire         hardoccalen,
  // PRBS
  input  wire         pcs_8g_prbs_done,
  input  wire         pcs_8g_prbs_err,
  // DCD
  input  wire         dcd_ack, 
  input  wire [7:0]   dcd_sum_a,
  input  wire [7:0]   dcd_sum_b,
  // SLPBK
  output wire         seriallpbken,
  // Channel STATUS
  input  wire         stat_pll_locked,
  input  wire         stat_tx_digital_reset,
  input  wire         stat_rx_digital_reset,
  // Reset overrides 
  output wire         tx_rst_ovr,  
  output wire         tx_digital_rst_n_val,
  output wire         rx_rst_ovr,
  output wire         rx_digital_rst_n_val,
  output wire         rx_analog_rst_n_val
);

import av_xcvr_h::*;

localparam  [15:0]  RD_UNUSED = 16'h0000;

wire  [3:0] loc_address;

//*******************
// Readback registers
wire  [15:0]  rd_dummy;
wire  [15:0]  rd_oc;
wire  [15:0]  rd_prbs;
wire  [15:0]  rd_slpbk;
wire  [15:0]  rd_status;
wire  [15:0]  rd_id;
wire  [15:0]  rd_request;
wire  [15:0]  rd_rstctl;

//*********************
// Avalon readback data
assign  loc_address = av_address[3:0];
always @(posedge av_clk)
  if(~av_read)          av_readdata <= RD_UNUSED;
  else case(loc_address)
    AV_XR_ADDR_DUMMY:   av_readdata <= rd_dummy;
    AV_XR_ADDR_OC:      av_readdata <= rd_oc;
    AV_XR_ADDR_PRBS:    av_readdata <= rd_prbs;
    AV_XR_ADDR_SLPBK:   av_readdata <= rd_slpbk;
    AV_XR_ADDR_STATUS:  av_readdata <= rd_status;
    AV_XR_ADDR_ID:      av_readdata <= rd_id;
    AV_XR_ADDR_REQUEST: av_readdata <= rd_request;
    AV_XR_ADDR_RSTCTL:  av_readdata <= rd_rstctl;
    default:            av_readdata <= RD_UNUSED;
  endcase

//***************
// DUMMY register
reg r_dummy = 1'b0;

// Readback data
assign  rd_dummy  = {15'd0,r_dummy};
always @(posedge av_clk or posedge av_reset)
  if(av_reset)      r_dummy <= 1'b0;
  else if(av_write & (loc_address == AV_XR_ADDR_DUMMY))
                    r_dummy <= av_writedata[AV_XR_DUMMY_DUMMY_OFST];

//************
// OC register
generate if (rx_enable == 1) begin:gen_oc_reg
  reg r_hardoccalen = 1'b0;

  // Control outputs
  assign  hardoccalen  = r_hardoccalen;
  // Readback data
  assign  rd_oc[AV_XR_OC_CALEN_OFST  ]  = r_hardoccalen;
  assign  rd_oc[AV_XR_OC_CALDONE_OFST]  = hardoccaldone;  // TODO - meta
  assign  rd_oc[AV_XR_OC_UNUSED_OFST
                +:AV_XR_OC_UNUSED_LEN]  = {AV_XR_OC_UNUSED_LEN{1'b0}};
  // Avalon registers
  always @(posedge av_clk or posedge av_reset)
    if(av_reset) begin
                        r_hardoccalen <= 1'b0;
    end else if(av_write & (loc_address == AV_XR_ADDR_OC)) begin
                        r_hardoccalen <= av_writedata[AV_XR_OC_CALEN_OFST];
    end
end else begin
  // Register unused
  assign  hardoccalen = 1'b0;
  assign  rd_oc       = RD_UNUSED;
end
endgenerate
    

//**************
// PRBS register
generate if (rx_enable == 1) begin:gen_prbs_reg
  reg   r_prbs_err_clr = 1'b0;

  // Readback data
  assign  rd_prbs[AV_XR_PRBS_CLR_OFST     ] = r_prbs_err_clr;
  assign  rd_prbs[AV_XR_PRBS_8G_ERR_OFST  ] = pcs_8g_prbs_err;  // TODO - meta
  assign  rd_prbs[AV_XR_PRBS_8G_DONE_OFST ] = pcs_8g_prbs_done; // TODO - meta
  assign  rd_prbs[AV_XR_PRBS_UNUSED_OFST
                  +:AV_XR_PRBS_UNUSED_LEN ] = {AV_XR_PRBS_UNUSED_LEN{1'b0}};
  // Avalon registers
  always @(posedge av_clk or posedge av_reset)
    if(av_reset) begin
                        r_prbs_err_clr  <= 1'b0;
    end else if(av_write & (loc_address == AV_XR_ADDR_PRBS)) begin
                        r_prbs_err_clr  <= av_writedata[AV_XR_PRBS_CLR_OFST];
    end
end else begin
  // Register unused
  assign  rd_prbs               = RD_UNUSED;
end
endgenerate
 

//***************
// SLPBK register
generate if (tx_enable == 1) begin:gen_slpbk_reg
  reg r_seriallpbken = 1'b0;

  // Control outputs
  assign  seriallpbken  = r_seriallpbken;
  // Readback data
  assign  rd_slpbk[AV_XR_SLPBK_SLPBKEN_OFST] = r_seriallpbken;
  assign  rd_slpbk[AV_XR_SLPBK_UNUSED_OFST
                   +:AV_XR_SLPBK_UNUSED_LEN] = {AV_XR_SLPBK_UNUSED_LEN{1'b0}};
  // Avalon registers
  always @(posedge av_clk or posedge av_reset)
    if(av_reset) begin
                        r_seriallpbken  <= 1'b0;
    end else if(av_write & (loc_address == AV_XR_ADDR_SLPBK)) begin
                        r_seriallpbken  <= av_writedata[AV_XR_SLPBK_SLPBKEN_OFST];
    end
end else begin
  // Register unused
  assign  seriallpbken  = 1'b0;
  assign  rd_slpbk      = RD_UNUSED;
end
endgenerate


//****************
// STATUS register
// Readback data
// TX status
generate if (tx_enable == 1) begin:gen_status_reg_tx
  wire stat_tx_digital_reset_r;  
  // Resynchronize input signals
  alt_xcvr_resync #(
          .WIDTH(1)
   ) alt_xcvr_resync_inst (
          .clk    (av_clk),
          .reset  (av_reset),
          .d      (stat_tx_digital_reset),
          .q      (stat_tx_digital_reset_r)
  );
  assign  rd_status[AV_XR_STATUS_TX_DIGITAL_RESET_OFST] = stat_tx_digital_reset_r; 
end else begin
  assign  rd_status[AV_XR_STATUS_TX_DIGITAL_RESET_OFST] = 1'b0;
end
endgenerate
// RX status
generate if (rx_enable == 1) begin:gen_status_reg_rx
  wire stat_rx_digital_reset_r;  
  // Resynchronize input signals
  alt_xcvr_resync #(
          .WIDTH(1)
   ) alt_xcvr_resync_inst (
          .clk    (av_clk),
          .reset  (av_reset),
          .d      (stat_rx_digital_reset),
          .q      (stat_rx_digital_reset_r)
  );
  assign  rd_status[AV_XR_STATUS_RX_DIGITAL_RESET_OFST] = stat_rx_digital_reset_r;  
end else begin
  assign  rd_status[AV_XR_STATUS_RX_DIGITAL_RESET_OFST] = 1'b0;
end
endgenerate
// PLL status
generate if (pll_type != AV_XR_ID_PLL_TYPE_NONE) begin:gen_status_reg_pll
  wire  stat_pll_locked_r;
  reg   r_pll_locked_flag;
  // Resynchronize input signals
  alt_xcvr_resync #(
          .WIDTH(1)
  ) alt_xcvr_resync_inst (
          .clk    (av_clk),
          .reset  (av_reset),
          .d      (stat_pll_locked),
          .q      (stat_pll_locked_r)
  );

  // pll_locked flag logic
  // Set by AVMM interface, cleared by pll_locked deassertion
  always @(posedge av_clk or posedge av_reset) begin
    if(av_reset)
      r_pll_locked_flag <= 1'b0;
    else if(av_write & (loc_address == AV_XR_ADDR_STATUS))
      r_pll_locked_flag <= av_writedata[AV_XR_STATUS_PLL_LOCKED_FLAG_OFST];
    else if(!stat_pll_locked_r)
      r_pll_locked_flag <= 1'b0;
  end

  assign  rd_status[AV_XR_STATUS_PLL_LOCKED_OFST      ] = stat_pll_locked_r;
  assign  rd_status[AV_XR_STATUS_PLL_LOCKED_FLAG_OFST ] = r_pll_locked_flag;
end else begin
  assign  rd_status[AV_XR_STATUS_PLL_LOCKED_OFST      ] = 1'b0;
  assign  rd_status[AV_XR_STATUS_PLL_LOCKED_FLAG_OFST ] = 1'b0;
end
endgenerate

assign  rd_status[AV_XR_STATUS_UNUSED_OFST+:AV_XR_STATUS_UNUSED_LEN] = {AV_XR_STATUS_UNUSED_LEN{1'b0}};


//************
// ID register
// Readback data
assign  rd_id[AV_XR_ID_TX_CHANNEL_OFST ]  = (tx_enable == 1) ? 1'b1 : 1'b0;
assign  rd_id[AV_XR_ID_RX_CHANNEL_OFST ]  = (rx_enable == 1) ? 1'b1 : 1'b0;
assign  rd_id[AV_XR_ID_PLL_TYPE_OFST+:AV_XR_ID_PLL_TYPE_LEN]
            = pll_type[1:0];
assign  rd_id[AV_XR_ID_UNUSED_OFST+:AV_XR_ID_UNUSED_LEN]
            = {AV_XR_ID_UNUSED_LEN{1'b0}};


//**************************
// REQUEST services register
assign  rd_request[AV_XR_REQUEST_DCD_OFST        ]  = (request_dcd          == 0) ? 1'b0 : 1'b1;
assign  rd_request[AV_XR_REQUEST_VRC_OFST        ]  = (request_vrc          == 0) ? 1'b0 : 1'b1;
assign  rd_request[AV_XR_REQUEST_OFFSET_OFST     ]  = (request_offset       == 0) ? 1'b0 : 1'b1;
assign  rd_request[AV_XR_REQUEST_UNUSED_OFST+:AV_XR_REQUEST_UNUSED_LEN]
            = {AV_XR_REQUEST_UNUSED_LEN{1'b0}};
//************************
// RSTCTL register
// User reset controls

// Avalon registers for Tx digital reset
generate if (tx_enable == 1) begin:gen_rstctl_reg_tx
  reg r_tx_rst_ovr            = 1'b0;
  reg r_tx_digital_rst_n_val  = 1'b0;

  always @(posedge av_clk or posedge av_reset) begin
    if(av_reset) begin
      r_tx_rst_ovr            <= 1'b0;
      r_tx_digital_rst_n_val  <= 1'b0;
    end else if(av_write & (loc_address == AV_XR_ADDR_RSTCTL)) begin
      r_tx_rst_ovr            <= av_writedata[AV_XR_RSTCTL_TX_RST_OVR_OFST];
      r_tx_digital_rst_n_val  <= av_writedata[AV_XR_RSTCTL_TX_DIGITAL_RST_N_VAL_OFST];
    end
  end

  assign tx_rst_ovr           = r_tx_rst_ovr;
  assign tx_digital_rst_n_val = r_tx_digital_rst_n_val;
end
else begin
  assign tx_rst_ovr           = 1'b0;
  assign tx_digital_rst_n_val = 1'b0; 
end
endgenerate

// Avalon registers for Rx digital and analog resets
generate if (rx_enable == 1) begin:gen_rstctl_reg_rx
  reg r_rx_rst_ovr              = 1'b0;
  reg r_rx_digital_rst_n_val    = 1'b0;
  reg r_rx_analog_rst_n_val     = 1'b0;

  always @(posedge av_clk or posedge av_reset) begin
    if(av_reset) begin
      r_rx_rst_ovr            <= 1'b0;
      r_rx_digital_rst_n_val  <= 1'b0;
      r_rx_analog_rst_n_val   <= 1'b0;
    end else if(av_write & (loc_address == AV_XR_ADDR_RSTCTL)) begin
      r_rx_rst_ovr            <= av_writedata[AV_XR_RSTCTL_RX_RST_OVR_OFST];
      r_rx_digital_rst_n_val  <= av_writedata[AV_XR_RSTCTL_RX_DIGITAL_RST_N_VAL_OFST];
      r_rx_analog_rst_n_val   <= av_writedata[AV_XR_RSTCTL_RX_ANALOG_RST_N_VAL_OFST];
    end
  end

  assign rx_rst_ovr               = r_rx_rst_ovr;
  assign rx_digital_rst_n_val     = r_rx_digital_rst_n_val;
  assign rx_analog_rst_n_val      = r_rx_analog_rst_n_val;
end
else begin
  assign rx_rst_ovr               = 1'b0;
  assign rx_digital_rst_n_val     = 1'b0;
  assign rx_analog_rst_n_val      = 1'b0; 
end
endgenerate

assign rd_rstctl[AV_XR_RSTCTL_TX_RST_OVR_OFST       ]     = tx_rst_ovr;
assign rd_rstctl[AV_XR_RSTCTL_TX_DIGITAL_RST_N_VAL_OFST]  = tx_digital_rst_n_val;
assign rd_rstctl[AV_XR_RSTCTL_RX_RST_OVR_OFST       ]     = rx_rst_ovr;
assign rd_rstctl[AV_XR_RSTCTL_RX_DIGITAL_RST_N_VAL_OFST]  = rx_digital_rst_n_val;
assign rd_rstctl[AV_XR_RSTCTL_RX_ANALOG_RST_N_VAL_OFST ]  = rx_analog_rst_n_val;
assign rd_rstctl[AV_XR_RSTCTL_UNUSED_OFST+:AV_XR_RSTCTL_UNUSED_LEN]
                = {AV_XR_RSTCTL_UNUSED_LEN{1'b0}};

endmodule
