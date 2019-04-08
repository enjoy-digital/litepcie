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
// Logical-to-physical channel number translator for transceiver reconfig 'basic' block
//
// $Header$
//

`timescale 1 ns / 1 ns

//(* ALTERA_ATTRIBUTE = {"BLOCK_RAM_TO_MLAB_CELL_CONVERSION=ON"} *)
module av_xrbasic_l2p_ch #(
	parameter logical_interface = 0,	// which logical interface is the mapping for?
	parameter native_ifs = 1,	// number of native reconfig interfaces, used when no physical mapping available
	parameter w_lch = 5,	// bits needed to represent logical channel numbers
	parameter w_pif = 5,	// bits needed to represent physical interface numbers
	parameter w_pch = 3,	// bits needed to represent physical channel numbers (offsets within a physical interface)
	parameter physical_channel_mapping = ""	// string notation to define logical-to-physical channel mapping
) (
	input  wire clk,
	input  wire [w_lch-1:0] logical_ch,	// logical channel input
	output reg  [w_pif-1:0] physical_if = 0,	// physical interface output
	output reg  [w_pch-1:0] physical_ch = 0 	// physical channel output (offset within a physical interface)
);

	localparam logical_ch_max = (1<<w_lch);
	localparam l2p_bits = w_pif + w_pch;	// physical interface bits + physical channel bits
	typedef bit [l2p_bits-1:0] t_l2p_bits;

	// declare a ROM to hold the logical-to-physical channel mapping
	(* romstyle = "MLAB" *) reg [l2p_bits-1:0] rom_l2p_ch[logical_ch_max-1:0];
/*
	// function to extract logical-to-physical channel mapping table from string parameter
	localparam MAX_CHARS = 1024;
	function [logical_ch_max-1:0][l2p_bits-1:0] get_logical_to_physical_mapping (
		integer interface_number,
		input [MAX_CHARS*8-1:0] l2p_str
	);
		integer i;
		begin
			for (i=0; i<logical_ch_max; ++i) begin
				get_logical_to_physical_mapping[i][l2p_bits-1:0] = l2p_str[i*8 +:8];
			end
		end
	endfunction
	localparam [logical_ch_max-1:0][l2p_bits-1:0] l2p_mapping =
		get_logical_to_physical_mapping(logical_interface, physical_channel_mapping);
*/
	// logical-to-physical channel mapping table
	integer i;
	initial begin
		for (i=0; i<logical_ch_max; ++i) begin//: map
			if (physical_channel_mapping == "") begin
				// NULL mapping case when string mapping is not defined
				// For this case, map every logical channel to its own phys interface, and use only phys ch 0 on each phys if
				rom_l2p_ch[i] = (i < native_ifs)
									? t_l2p_bits'(i << w_pch)	// physical channel index always 0 when no mapping data
									: t_l2p_bits'(-1);	// value of -1 means logical channel does not exist
			end
			else begin
				// infer a ROM for the logical channel to physical (interface, channel) mapping
			
				// The following section implements a logical-to-physical translation table in the form of a large mux.
				// The mux data inputs are the physical interface and channel numbers, and the select input is 'logical_channel_addr_reg'
		/*		wire [w_lch-1:0] l2p_pif_wire [logical_ch_max-1:0];
				wire [w_pch-1:0] l2p_pch_wire [logical_ch_max-1:0];
				wire [logical_ch_max-1:0] lch_decode;
				for (i=0; i<logical_ch_max && l2p_mapping[i][l2p_bits-1:0] != {l2p_bits{1'b1}}; ++i) begin: l2p
					assign lch_decode[i] = (logical_ch == i);
					if (i > 0) begin
						assign l2p_pif_wire[i]= l2p_pif_wire[i-1] | (l2p_mapping[i][l2p_bits-1:0] >> 4) & {w_lch{lch_decode[i]}};
						assign l2p_pch_wire[i]= l2p_pif_wire[i-1] | (l2p_mapping[i][l2p_bits-1:0] & 32'hf) & {w_pch{lch_decode[i]}};
					end else begin
						assign l2p_pif_wire[i]= (l2p_mapping[i][l2p_bits-1:0] >> 4) & {w_lch{lch_decode[i]}};
						assign l2p_pch_wire[i]= (l2p_mapping[i][l2p_bits-1:0] & 32'hf) & {w_pch{lch_decode[i]}};
					end
					// must check termination condition inside the loop to assign to outputs
					if ((i+1) == logical_ch_max || l2p_mapping[i+1][l2p_bits-1:0] == {l2p_bits{1'b1}}) begin
						// mux output is from last logical channel
						assign physical_interface = l2p_pif_wire[i];
						assign physical_channel = l2p_pch_wire[i];
					end
				end */
			end
		end
	end//generate

	// registered ROM outputs
	always @(posedge clk) begin
		{physical_if, physical_ch} <= rom_l2p_ch[logical_ch];
	end
endmodule
