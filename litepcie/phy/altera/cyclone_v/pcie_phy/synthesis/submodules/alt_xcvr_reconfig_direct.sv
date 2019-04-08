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



`timescale 1 ns / 1 ps

module alt_xcvr_reconfig_direct #(
	parameter device_family = "Stratix V"
) (
	// avalon clock interface
	input wire clk,
	input wire reset,
	
	// user avalon MM slave interface
	input  wire        write,
	input  wire        read,
	input  wire [31:0] writedata,
	input  wire [2:0]  address,
	
	output reg  [31:0] readdata,
	output wire        waitrequest,
	
	// master interface to control "basic" block
	output wire        basic_write,
	output wire        basic_read,
	output wire [31:0] basic_writedata,
	output wire [2:0]  basic_address,
	
	input  wire [31:0] basic_readdata,
	input  wire        basic_waitrequest,

	// external connect to switch fabric: request basic access from arbiter
	output wire arb_req,
	input  wire arb_grant
);
	import altera_xcvr_functions::*;
	import alt_xcvr_reconfig_h::*;

	localparam ADDR_XCVR_RECONFIG_DIRECT_CONTROL = 3'(ADDR_XR_DIRECT_ARB_ACQ - ADDR_XR_DIRECT_BASE);

	reg reg_arb_req = 0;

	// 161000: added to block outbound waitrequest when arbitration is not requested
        wire waitrequest_int; 
        assign waitrequest = waitrequest_int & reg_arb_req;

	////////////////////////////////////////////
	// Memory-mapped register write interface
	////////////////////////////////////////////

	// logical channel register
	always @(posedge clk or posedge reset) begin
		if (reset == 1) begin
			reg_arb_req <= 0;
		end
		else if (write && address == ADDR_XCVR_RECONFIG_DIRECT_CONTROL) begin
			// Manually control arbiter request signal
			reg_arb_req <= writedata[0];
		end
	end

	//////////////////////////////////////////////
	// Pass-through to basic block for everything
	//////////////////////////////////////////////

	alt_arbiter_acq #(
		.addr_width(3),
		.data_width(32)
	)
	mutex_inst (
		.clk(clk),
		.reset(reset),
		// local slave-side connections
		.address    (address),
		.writedata  (writedata),
		.write      (write),
		.read       (read),
		.waitrequest(waitrequest_int),
		.readdata   (readdata),
		
		// connections to the basic block
		.master_address    (basic_address),
		.master_writedata  (basic_writedata),
		.master_write      (basic_write),
		.master_read       (basic_read),
		.master_waitrequest(basic_waitrequest),
		.master_readdata   (basic_readdata),
		
		// request access to fabric & basic block
		.mutex_req(reg_arb_req),
		.mutex_grant(),
		// external arbiter connections for fabric access
		.arb_req(arb_req),
		.arb_grant(arb_grant)
	);

endmodule
