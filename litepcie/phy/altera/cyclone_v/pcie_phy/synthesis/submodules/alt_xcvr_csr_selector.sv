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
// Select a sub-group from a wide register
// Useful for indirection indexing
//
// $Header$
//

`timescale 1 ns / 1 ns

module csr_mux #(
	parameter groups = 2,
	parameter grp_size = 1,
	parameter sel_size = 1
)
(
	input  wire [groups*grp_size-1:0]	in_wide,
	input  tri0 [sel_size-1:0]		sel,
	output wire [grp_size-1:0]		out_narrow
);
//	lpm_mux #(.lpm_size(groups), .lpm_width(grp_size), .lpm_widths(sel_size))
//		mux (.data(in_wide), .sel(sel), .result(out_narrow));
	wire [grp_size-1:0] in_groups [groups-1:0];

	// a synthesizable mux, with a parameterized number of inputs
	genvar i;
	assign in_groups[0] = in_wide[grp_size-1:0] & {grp_size{sel == 0}};
	generate for (i=1; i<groups; i = i+1) begin: mux
		assign in_groups[i] = in_groups[i-1] | in_wide[i*grp_size +: grp_size] & {grp_size{sel == i}};
	end
	endgenerate
	assign out_narrow = in_groups[groups-1];
endmodule

//
// write to a sub-group of a wide register
// Useful for indirection indexing on write
//
module csr_indexed_write_mux #(
	parameter groups = 2,
	parameter grp_size = 1,
	parameter sel_size = 1,
	parameter init_value = 0
)
(
	input  wire [grp_size-1:0]			in_narrow,
	input  tri0 [sel_size-1:0]			sel,
	output wire [grp_size-1:0]			out_narrow, // for read back to mgmt interface
	input  wire [groups*grp_size-1:0]	in_wide,	// full-width control reg state
	output wire [groups*grp_size-1:0]	out_wide	// to write to full-width control reg
);
	wire [groups*grp_size-1:0] wire_wide [groups-1:0];

	// in_narrow is output in the group position indicated by .sel() input
	genvar i;
	assign wire_wide[0] = (in_wide & {grp_size{sel != 0}}) | (in_narrow & {grp_size{sel == 0}});
	generate for (i=1; i<groups; i = i+1) begin: mux
		assign wire_wide[i] = wire_wide[i-1]
			 | (in_wide & {{grp_size{sel != i}}, {(grp_size*i){1'b0}}})
			 | ({in_narrow & {grp_size{sel == i}}, {(grp_size*i){1'b0}}});
	end
	endgenerate
	assign out_wide = wire_wide[groups-1];

	// generate out_narrow as ordinary mux of in_wide
	csr_mux #(.groups(groups), .grp_size(grp_size), .sel_size(sel_size))
		o_narrow(.in_wide(in_wide), .sel(sel), .out_narrow(out_narrow));

endmodule

//
// read from a sub-group of a wide, async status input
// Creates synchronization logic to sample in local clock domain
// Useful for indirection indexing on read-only status bits
//
module csr_indexed_read_only_reg #(
	parameter groups = 2,
	parameter grp_size = 1,
	parameter sel_size = 1,
	parameter sync_stages = 2
)
(
	input  wire clk,
	input  tri0 [sel_size-1:0]			sel,
	output wire [grp_size-1:0]			out_narrow, // for read back to mgmt interface
	input  wire [groups*grp_size-1:0]	async_in_wide	// full-width async status inputs
);
  localparam sync_stages_str  = sync_stages[7:0] + 8'd48; // number of sync stages specified as string (for timing constraints)
  localparam SYNC_SREG_CONSTRAINT = {"-name SDC_STATEMENT \"set regs [get_registers -nowarn *csr_indexed_read_only_reg*sreg[",sync_stages_str,"]*]; if {[llength [query_collection -report -all $regs]] > 0} {set_false_path -to $regs}\""};
  localparam SDC_CONSTRAINTS = {SYNC_SREG_CONSTRAINT};

	// read-only status registers are synchronized forms of async status signals
	// async inputs go to sreg [sync_stages], and come out synchronized at sreg [1]
  // Apply false path timing constraints to synchronization registers.
  (* altera_attribute = SDC_CONSTRAINTS *)
	reg  [groups*grp_size-1:0]	sreg [sync_stages:1];
	integer stage;
	always @(posedge clk) begin
		sreg[sync_stages] <= async_in_wide;
		for (stage=2; stage <= sync_stages; stage = stage + 1) begin
			// additional sync stages
			sreg[stage-1] <= sreg[stage];
		end
	end

	// generate out_narrow as ordinary mux of out_wide
	csr_mux #(.groups(groups), .grp_size(grp_size), .sel_size(sel_size))
		o_narrow(.in_wide(sreg[1]), .sel(sel), .out_narrow(out_narrow));

endmodule
