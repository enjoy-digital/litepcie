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


//
// Logical offset address to physical address mapping
//
// $Header$
//

`timescale 1 ns / 1 ns

module av_xrbasic_l2p_addr #(
	parameter w_pch = 3,	// bits needed to represent physical channel numbers (offsets within a physical interface)
	parameter w_paddr = 11	// bits needed to represent physical addresses
) (
	input  wire clk,
	input  wire [w_paddr-1:0] offset_addr,	// logical offset address
	input  wire [w_pch  -1:0] physical_ch,	// physical channel number
	output reg  [w_paddr-1:0] physical_addr = {w_paddr{1'b0}}	// physical address
);
	import av_xcvr_h::*;
	
	reg [w_paddr-1:0] pch_start_addr = {w_paddr{1'b0}};	// physical channel start address

	always @(*) begin
		case (physical_ch)
		// Map logical channel offsets to physical addresses
		0: pch_start_addr = {w_paddr{1'b0}};
		1: pch_start_addr = {w_paddr{1'b0}} + RECONFIG_PMA_CH1_BASE;
		2: pch_start_addr = {w_paddr{1'b0}} + RECONFIG_PMA_CH2_BASE;
		// LC PLL needs special mapping
		3: pch_start_addr = {w_paddr{1'b0}};	// fill-in PLL offset addr remapping
		default: pch_start_addr = {w_paddr{1'b0}};
		endcase
	end

	// add offset, and register output for performance
	always @(posedge clk) begin
		physical_addr <= offset_addr + pch_start_addr;
	end
endmodule
