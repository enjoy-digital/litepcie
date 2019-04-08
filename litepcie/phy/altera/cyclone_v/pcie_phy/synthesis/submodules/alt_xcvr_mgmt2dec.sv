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


// Management interface address decoder for Altera Transceiver PHY
//
// Addresses common case of 2 modules to be stitched together:
//	- 'top' PHY channel blocks (includes reset control, CSR, ...)
//	- dynamic reconfiguration block

// $Header$

`timescale 1 ns / 1 ns

module alt_xcvr_mgmt2dec ( 

	// user-visible external management interface
	input  wire        mgmt_clk_reset,
	input  wire        mgmt_clk,
	
	input  wire [8:0]  mgmt_address,
	input  wire        mgmt_read,
	output reg  [31:0] mgmt_readdata = ~32'd0,
	output reg         mgmt_waitrequest = 0,
	input  wire        mgmt_write,

	// internal interface to 'top' csr block
	output wire [7:0]  topcsr_address,
	output wire        topcsr_read,
	input  wire [31:0] topcsr_readdata,
	input  wire        topcsr_waitrequest,
	output wire        topcsr_write,

	// internal interface to 'top' csr block
	output wire [7:0]  reconf_address,
	output wire        reconf_read,
	input  wire [31:0] reconf_readdata,
	input  wire        reconf_waitrequest,
	output wire        reconf_write	
);
	localparam width_swa = 7;	// word address width of interface to slaves (2 for top.CSR and 1 for reconfig)
	localparam dec_count = 2;	// count of the total number of sub-components that can act
								// as slaves to the mgmt interface
	localparam dec_topcsr = 0;	// uses 2 128-word address blocks
	localparam dec_reconf = 1;	// uses 1 128-word address block


	///////////////////////////////////////////////////////////////////////
	// Decoder for multiple slaves of reconfig_mgmt interface
	///////////////////////////////////////////////////////////////////////
	wire [dec_count-1:0] r_decode;
	assign r_decode = 
		  (mgmt_address[8:width_swa+1] == dec_topcsr) ? (({dec_count-dec_topcsr{1'b0}} | 1'b1) << dec_topcsr)
		: (mgmt_address[8:width_swa] == 2'd2) ? (({dec_count-dec_reconf{1'b0}} | 1'b1) << dec_reconf)
		: {dec_count{1'b0}};

	// reconfig_mgmt output generation is muxing of decoded slave output
	always @(*) begin
		if (r_decode[dec_topcsr] == 1'b1) begin
			mgmt_readdata = topcsr_readdata;
			mgmt_waitrequest = topcsr_waitrequest;
		end else if (r_decode[dec_reconf] == 1'b1) begin
			mgmt_readdata = reconf_readdata;
			mgmt_waitrequest = reconf_waitrequest;
		end else begin
			mgmt_readdata = -1;
			mgmt_waitrequest = 1'b0;
		end
	end

	// internal interface to 'top' csr block
	assign topcsr_address = mgmt_address[width_swa:0];	// top.csr uses 2 128-word blocks
	assign topcsr_read = mgmt_read & r_decode[dec_topcsr];
	assign topcsr_write = mgmt_write & r_decode[dec_topcsr];

	// internal interface to 'top' csr block
	assign reconf_address = mgmt_address[width_swa-1:0];	// reconfig uses 1 128-word block
	assign reconf_read = mgmt_read & r_decode[dec_reconf];
	assign reconf_write = mgmt_write & r_decode[dec_reconf];

endmodule
