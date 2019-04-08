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


// Verilog RBC parameter resolution wrapper for arriav_hssi_tx_pcs_pma_interface
//

`timescale 1 ns / 1 ps

module av_hssi_tx_pcs_pma_interface_rbc #(
	// unconstrained parameters

	// extra unconstrained parameters found in atom map
	parameter avmm_group_channel_index = 0,	// 0..2
	parameter selectpcs = "eight_g_pcs",	// default, eight_g_pcs
	parameter use_default_base_address = "true",	// false, true
	parameter user_base_address = 0	// 0..2047

	// constrained parameters
) (
	// ports
	output wire         	asynchdatain,
	input  wire   [10:0]	avmmaddress,
	input  wire    [1:0]	avmmbyteen,
	input  wire         	avmmclk,
	input  wire         	avmmread,
	output wire   [15:0]	avmmreaddata,
	input  wire         	avmmrstn,
	input  wire         	avmmwrite,
	input  wire   [15:0]	avmmwritedata,
	output wire         	blockselect,
	input  wire         	clockinfrompma,
	output wire         	clockoutto8gpcs,
	input  wire   [19:0]	datainfrom8gpcs,
	output wire   [79:0]	dataouttopma,
	input  wire         	pcs8gtxclkiqout,
	input  wire         	pmarxfreqtxcmuplllockin,
	output wire         	pmarxfreqtxcmuplllockout,
	output wire         	pmatxclkout,
	output wire         	reset
);
	import altera_xcvr_functions::*;

	// selectpcs external parameter (no RBC)
	localparam rbc_all_selectpcs = "(default,eight_g_pcs)";
	localparam rbc_any_selectpcs = "eight_g_pcs";
	localparam fnl_selectpcs = (selectpcs == "<auto_any>" || selectpcs == "<auto_single>") ? rbc_any_selectpcs : selectpcs;

	// use_default_base_address external parameter (no RBC)
	localparam rbc_all_use_default_base_address = "(false,true)";
	localparam rbc_any_use_default_base_address = "true";
	localparam fnl_use_default_base_address = (use_default_base_address == "<auto_any>" || use_default_base_address == "<auto_single>") ? rbc_any_use_default_base_address : use_default_base_address;

	// Validate input parameters against known values or RBC values
	initial begin
		//$display("selectpcs = orig: '%s', any:'%s', all:'%s', final: '%s'", selectpcs, rbc_any_selectpcs, rbc_all_selectpcs, fnl_selectpcs);
		if (!is_in_legal_set(selectpcs, rbc_all_selectpcs)) begin
			$display("Critical Warning: parameter 'selectpcs' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", selectpcs, rbc_all_selectpcs, fnl_selectpcs);
		end
		//$display("use_default_base_address = orig: '%s', any:'%s', all:'%s', final: '%s'", use_default_base_address, rbc_any_use_default_base_address, rbc_all_use_default_base_address, fnl_use_default_base_address);
		if (!is_in_legal_set(use_default_base_address, rbc_all_use_default_base_address)) begin
			$display("Critical Warning: parameter 'use_default_base_address' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", use_default_base_address, rbc_all_use_default_base_address, fnl_use_default_base_address);
		end
	end

	arriav_hssi_tx_pcs_pma_interface #(
		.avmm_group_channel_index(avmm_group_channel_index),
		.selectpcs(fnl_selectpcs),
		.use_default_base_address(fnl_use_default_base_address),
		.user_base_address(user_base_address)
	) wys (
		// ports
		.asynchdatain(asynchdatain),
		.avmmaddress(avmmaddress),
		.avmmbyteen(avmmbyteen),
		.avmmclk(avmmclk),
		.avmmread(avmmread),
		.avmmreaddata(avmmreaddata),
		.avmmrstn(avmmrstn),
		.avmmwrite(avmmwrite),
		.avmmwritedata(avmmwritedata),
		.blockselect(blockselect),
		.clockinfrompma(clockinfrompma),
		.clockoutto8gpcs(clockoutto8gpcs),
		.datainfrom8gpcs(datainfrom8gpcs),
		.dataouttopma(dataouttopma),
		.pcs8gtxclkiqout(pcs8gtxclkiqout),
		.pmarxfreqtxcmuplllockin(pmarxfreqtxcmuplllockin),
		.pmarxfreqtxcmuplllockout(pmarxfreqtxcmuplllockout),
		.pmatxclkout(pmatxclkout),
		.reset(reset)
	);
endmodule
