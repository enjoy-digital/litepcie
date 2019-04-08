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


// Master-to-slave access fabric
//
// Combined with external multi-master arbitration, this block gates
// master read, write, address, and writedata outputs, and generates
// a waitrequest when arbiter indicates access is not granted

// $Header$

`timescale 1 ns / 1 ns

module alt_xcvr_m2s #(
	parameter width_addr = 3,
	parameter width_data = 32
) (
	input  wire clock,
	output wire req,	// request to arbiter for slave access
	input  wire grant,

	// signals from/to master
	input  wire m_read,
	input  wire m_write,
	input  wire [width_addr-1:0] m_address,
	input  wire [width_data-1:0] m_writedata,
	output wire [width_data-1:0] m_readdata,
	output wire m_waitrequest,

	// signals from/to slave
	output wire s_read,
	output wire s_write,
	output wire [width_addr-1:0] s_address,
	output wire [width_data-1:0] s_writedata,
	input  wire [width_data-1:0] s_readdata,
	input  wire s_waitrequest
);

	// If master is requesting access, generate waitreq until granted
	assign req = m_read | m_write;	// master access requests
	assign m_waitrequest = grant ? s_waitrequest : req;

	// gate outputs to slave with grant signal
	assign s_read = m_read & grant;
	assign s_write = m_write & grant;
	assign s_address = m_address & {width_addr{grant}};
	assign s_writedata = m_writedata & {width_data{grant}};

	// slave data outputs pass through directly
	assign m_readdata = s_readdata;
endmodule
