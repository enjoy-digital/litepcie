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


// Transceiver Reconfiguration Basic Arbiter Acquisition
//
// Client must make request to see grant.  While not granted,
// all outputs to basic reconfig block will be gated to '0'

// $Header$

`timescale 1 ps / 1 ps
module alt_arbiter_acq #(
	parameter addr_width = 3,
    parameter data_width = 32
)
(
	input wire clk,        // this will be the reconfig clk
	input wire reset,
	
	// Internal interface for the bigger controlling module, like analog reconfig
	input  wire [addr_width-1:0] address,             // MM address
	input  wire [data_width-1:0] writedata,
	input  wire                  write,
	input  wire                  read,
	output reg                   waitrequest,    // can use to tell internal master to wait when auto-request+release
	output wire [data_width-1:0] readdata,

	// MM master external interface, that connects to mutex-slave, like the reconfig_basic block
	output wire [addr_width-1:0] master_address,             // MM address
	output wire [data_width-1:0] master_writedata,
	output wire                  master_write,
	output wire                  master_read,
	input  wire                  master_waitrequest,    // needed for a valid master interface
	input  wire [data_width-1:0] master_readdata,      // from mutex-slave

	// external connect to switch fabric: request basic access from arbiter
	output wire arb_req,
	input  wire arb_grant,

	// internal request from local client: request mutex access and should be held high as long as mutex is used
	input  wire mutex_req,
	output wire mutex_grant
);

	wire granted;	// true when request is active, and grant is active

	assign arb_req = mutex_req;	// forward client request to arbiter
	assign granted = mutex_req & arb_grant;	// only tell client they're granted access to basic is they are requesting
	assign mutex_grant = granted;

	// basic-block facing: master Avalon interface
	assign master_address   = address   & {addr_width{granted}};
	assign master_writedata = writedata & {data_width{granted}};
	assign master_write     = write     & granted;
	assign master_read      = read      & granted;

	// internal client facing: slave Avalon interface
	assign waitrequest = master_waitrequest | ~granted;	// always in wait request if not granted access
	assign readdata    = master_readdata;

endmodule
