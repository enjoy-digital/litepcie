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


// Transceiver Reconfiguration 
// calibration Start-up sequencer block
//

// $Header$

`timescale 1 ns / 1 ns

module alt_xcvr_reconfig_cal_seq  #(
parameter arb_count = 10
) (
  input  wire        reconfig_clk,
  input  wire        reset,
  input  wire [arb_count-1:0]  busy,
  input  wire        cal_busy_in,

  // user reconfiguration management interface
  output wire [arb_count-1:0]	hold,
  output reg   			reconfig_busy,
  output reg   			tx_cal_busy,
  output reg 			rx_cal_busy,
  output wire 			oc_cal_busy
  
  );
  import alt_xcvr_reconfig_h::*;

    // decoder block index, for 8-word address blocks
  localparam arb_offset = INDEX_XR_OFFSET;
  localparam arb_analog = INDEX_XR_ANALOG;
  localparam arb_eyemon = INDEX_XR_EYEMON;
  localparam arb_dfe    = INDEX_XR_DFE;
  localparam arb_direct = INDEX_XR_DIRECT;
  localparam arb_adce   = INDEX_XR_ADCE;
  localparam arb_lc     = INDEX_XR_LC;
  localparam arb_mif    = INDEX_XR_MIF;
  localparam arb_pll    = INDEX_XR_PLL;
  localparam arb_dcd    = INDEX_XR_DCD;
  
  wire  w_rx_cal_busy;
  wire  w_tx_cal_busy;
  wire  reconfig_busy_fe;
  wire  next_reconfig_busy;
  
  reg  startup_cal_done;

  
  ///////////////////////////////////////////////////////////////////////
  // Generate the hold signals to sequence start-up calibration
  // Current calibration order is as follows
  // Offset -> LC tuning -> DCD -> DFE -> ADCE -> Done
  // Expection is the start-up cal IP comes out of reset with busy set.
  ///////////////////////////////////////////////////////////////////////
  
  //offset cancellation is first block. No dependancy
  assign hold[arb_offset] = ~(startup_cal_done); 
  
  //LC tuning waits for Offset cancellation
  assign hold[arb_lc] = busy[arb_offset] & ~(startup_cal_done); 
  
  
  //DCD tuning waits for Offset cancellation & LC tuning
  assign hold[arb_dcd]  =  (busy[arb_offset] |
			    busy[arb_lc]  |
			    cal_busy_in)    &
		 	   ~(startup_cal_done); //only hold off IP during initial start-up cal
  
  
  //DFE cal waits for Offset cancellation & LC tuning & DCD
  assign hold[arb_dfe]  =  (busy[arb_offset] |
   			    busy[arb_dcd] |
			    busy[arb_lc] ) &
		           ~(startup_cal_done); //only hold off IP during initial start-up cal

  //DFE cal waits for Offset cancellation & LC tuning & DCD & DFE
  assign hold[arb_adce]  =  (busy[arb_offset] |
   			     busy[arb_dcd] |
			     busy[arb_dfe] | 
			     busy[arb_lc] ) &
			    ~(startup_cal_done); //only hold off IP during initial start-up cal
  
  //Non-startup IPs									 
  assign hold[arb_analog]  	= 1'b0;
  assign hold[arb_eyemon]  	= 1'b0;
  assign hold[arb_direct]  	= 1'b0;
  assign hold[arb_mif] 		= 1'b0;
  assign hold[arb_pll] 		= 1'b0;
  

  ///////////////////////////////////////////
  // Status to external mgmt interface
  ///////////////////////////////////////////
  assign next_reconfig_busy = |busy;
  
  always @ (posedge reconfig_clk or posedge reset) begin
   	if(reset) 
		reconfig_busy <= 1'b1;
	else 
		reconfig_busy <= next_reconfig_busy;
  end
  
  ///////////////////////////////////////////////////////////
  // Generate cal busy status to PHY-IP to hold
  // off tx_ready and rx_ready assertion during
  // startup calibration
  // oc_cal_busy is needed to allow rx_analog_reset to de-assert 
  ///////////////////////////////////////////////////////////
  
  //detect the completeion of initial start-up calibration (falling edge of combined busy)
  assign reconfig_busy_fe = reconfig_busy & ~(next_reconfig_busy);
  
  always @ (posedge reconfig_clk or posedge reset) begin
   	if(reset) 
		startup_cal_done <= 1'b0;
	else begin
		if(reconfig_busy_fe)
			startup_cal_done <= 1'b1;
   	end
  end
  
  //tx_cal_busy is provided to the PHY-IP reset conntroller to indicate that tx_ready should no be asserted
  //waits for LC tuning and DCD calibration to finish
  assign w_tx_cal_busy = busy[arb_lc] |
   			 busy[arb_dcd]; 
  always @ (posedge reconfig_clk or posedge reset) begin
   	if(reset) 
		tx_cal_busy <= 1'b1;
	else begin
		if(!w_tx_cal_busy)
			tx_cal_busy <= 1'b0;
   	end
  end
  
   //tx_cal_busy is provided to the PHY-IP reset conntroller to indicate that rx_ready should no be asserted
	//waits for Offset, DFE, DCD and ADCE calibration to finish
  assign w_rx_cal_busy = busy[arb_offset] |
   			 busy[arb_adce]   |
   			 busy[arb_dcd]    |
			 busy[arb_dfe];  
 always @ (posedge reconfig_clk or posedge reset) begin
	if(reset) 
	   rx_cal_busy <= 1'b1;
	else begin
		if(!w_rx_cal_busy)
			rx_cal_busy <= 1'b0;
   	end
  end
  
  assign oc_cal_busy = busy[arb_offset];

endmodule
